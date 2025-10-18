"""Asynchronous task runner that executes queued cards in order."""

from __future__ import annotations

import asyncio
from collections import deque
from datetime import datetime
from itertools import count
from typing import Deque, Dict, List, Optional

from .cards.repository import CardRepository, CardValidationError
from .models import CardModel, LogEntryModel, QueueItemModel, StateModel


class TaskRunner:
    """Manage card queue execution modes: single, all, endless."""

    def __init__(self, repository: CardRepository) -> None:
        self._queue: Deque[Dict] = deque()
        self._output: List[Dict] = []
        self._mode: str = "idle"
        self._max_output = 200
        self._queue_ids = count(1)
        self._lock = asyncio.Lock()
        self._start_event = asyncio.Event()
        self._shutdown_event = asyncio.Event()
        self._loop_task: Optional[asyncio.Task] = None
        self._stop_requested = False
        self._cards = repository

    async def start(self) -> None:
        if self._loop_task is None:
            self._loop_task = asyncio.create_task(self._loop(), name="task-runner-loop")

    async def shutdown(self) -> None:
        self._shutdown_event.set()
        if self._loop_task:
            self._loop_task.cancel()
            try:
                await self._loop_task
            except asyncio.CancelledError:
                pass
            self._loop_task = None

    async def list_cards(self) -> List[CardModel]:
        records = await self._cards.list_cards()
        return [
            CardModel(
                id=card.id,
                name=card.name,
                description=card.description,
                source=card.source,
            )
            for card in records
        ]

    async def add_to_queue(self, card_id: str) -> QueueItemModel:
        card = await self._cards.get_card(card_id)
        if not card:
            raise ValueError(f"Unknown card: {card_id}")
        queue_item = {
            "queue_id": next(self._queue_ids),
            "card_id": card.id,
            "card_name": card.name,
            "status": "pending",
            "enqueued_at": datetime.utcnow(),
            "started_at": None,
            "finished_at": None,
        }
        async with self._lock:
            self._queue.append(queue_item)
        return QueueItemModel(**queue_item)

    async def remove_from_queue(self, queue_id: int) -> None:
        async with self._lock:
            self._queue = deque(item for item in self._queue if item["queue_id"] != queue_id)

    async def clear_queue(self) -> None:
        async with self._lock:
            self._queue.clear()

    async def get_state(self) -> StateModel:
        async with self._lock:
            queue_snapshot = [QueueItemModel(**item) for item in list(self._queue)]
            output_snapshot = [LogEntryModel(**entry) for entry in self._output]
            mode = self._mode
            is_running = any(item.status == "running" for item in queue_snapshot) or mode in {
                "single",
                "all",
                "endless",
            }
        cards_list = await self.list_cards()
        return StateModel(
            mode=mode,
            is_running=is_running,
            queue=queue_snapshot,
            output=output_snapshot,
            available_cards=cards_list,
        )

    async def run_once(self) -> None:
        await self._set_mode("single")

    async def run_all(self) -> None:
        await self._set_mode("all")

    async def run_endless(self) -> None:
        await self._set_mode("endless")

    async def stop(self) -> None:
        async with self._lock:
            self._stop_requested = True
            self._mode = "idle"
        self._start_event.set()

    async def clear_output(self) -> None:
        async with self._lock:
            self._output.clear()

    async def _set_mode(self, mode: str) -> None:
        async with self._lock:
            self._mode = mode
            self._stop_requested = False
        self._start_event.set()

    async def _loop(self) -> None:
        try:
            while not self._shutdown_event.is_set():
                await self._start_event.wait()
                self._start_event.clear()
                while True:
                    async with self._lock:
                        if self._stop_requested:
                            self._stop_requested = False
                            self._mode = "idle"
                            break
                        mode = self._mode
                        next_item = self._next_pending_locked()
                    if next_item is None:
                        if mode == "endless":
                            await asyncio.sleep(0.2)
                            continue
                        async with self._lock:
                            self._mode = "idle"
                        break
                    await self._execute_item(next_item)
                    async with self._lock:
                        current_mode = self._mode
                    if current_mode == "single":
                        async with self._lock:
                            self._mode = "idle"
                        break
                    await asyncio.sleep(0)
        except asyncio.CancelledError:
            raise

    def _next_pending_locked(self) -> Optional[Dict]:
        for item in self._queue:
            if item["status"] == "pending":
                return item
        return None

    async def _execute_item(self, item: Dict) -> None:
        card = await self._cards.get_card(item["card_id"])
        async with self._lock:
            item["status"] = "running"
            item["started_at"] = datetime.utcnow()
        if not card:
            await self._log(item, "Card definition missing. Skipping.")
        else:
            await self._log(item, f"Executing '{card.name}'.")

        async def log(message: str) -> None:
            await self._log(item, message)

        try:
            if card:
                runner_callable = await self._cards.build_runner(card.id)
                await runner_callable(log)
                await self._log(item, f"'{card.name}' completed.")
        except CardValidationError as exc:
            await self._log(item, f"Card failed validation: {exc}")
        except Exception as exc:  # noqa: BLE001
            await self._log(item, f"Card failed: {exc!r}")
        finally:
            async with self._lock:
                item["status"] = "completed"
                item["finished_at"] = datetime.utcnow()
                # Remove completed item from the queue
                self._queue = deque(
                    queued for queued in self._queue if queued["queue_id"] != item["queue_id"]
                )

    async def _log(self, item: Dict, message: str) -> None:
        entry = {
            "queue_id": item["queue_id"],
            "card_id": item["card_id"],
            "card_name": item["card_name"],
            "message": message,
            "timestamp": datetime.utcnow(),
        }
        async with self._lock:
            self._output.append(entry)
            if len(self._output) > self._max_output:
                self._output = self._output[-self._max_output :]
