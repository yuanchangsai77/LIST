from __future__ import annotations

import asyncio
import json
import textwrap
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Awaitable, Callable, Dict, List, Optional
from uuid import uuid4

import asyncio as _asyncio
import random as _random

LogCallable = Callable[[str], Awaitable[None]]


@dataclass
class CardDefinition:
    id: str
    name: str
    description: str
    source: str

    def to_dict(self) -> Dict[str, str]:
        return asdict(self)


class CardValidationError(ValueError):
    """Raised when a card definition cannot be validated."""


class CardConflictError(RuntimeError):
    """Raised when attempting to create or update with conflicting identifiers."""


class CardRepository:
    """Persistent storage and runtime compilation for card definitions."""

    def __init__(self, storage_path: Path) -> None:
        self._storage_path = storage_path
        self._cards: Dict[str, CardDefinition] = {}
        self._lock = asyncio.Lock()
        self._runner_globals = {
            "__builtins__": __builtins__,
            "asyncio": _asyncio,
            "random": _random,
            "datetime": datetime,
        }

    async def load(self) -> None:
        async with self._lock:
            if self._cards:
                return
            if not self._storage_path.exists():
                self._storage_path.parent.mkdir(parents=True, exist_ok=True)
                self._storage_path.write_text(json.dumps(DEFAULT_CARDS, indent=2, ensure_ascii=False))
            data = json.loads(self._storage_path.read_text())
            self._cards = {
                raw["id"]: CardDefinition(
                    id=raw["id"],
                    name=raw["name"],
                    description=raw.get("description", ""),
                    source=raw.get("source", ""),
                )
                for raw in data
            }

    async def list_cards(self) -> List[CardDefinition]:
        async with self._lock:
            return list(self._cards.values())

    async def get_card(self, card_id: str) -> Optional[CardDefinition]:
        async with self._lock:
            return self._cards.get(card_id)

    async def create_card(self, *, name: str, description: str, source: str) -> CardDefinition:
        source = textwrap.dedent(source).strip()
        if not source:
            raise CardValidationError("Source cannot be empty.")
        self._validate_source(source)
        async with self._lock:
            card_id = uuid4().hex[:12]
            while card_id in self._cards:
                card_id = uuid4().hex[:12]
            card = CardDefinition(
                id=card_id,
                name=name.strip() or "未命名灵体",
                description=description.strip(),
                source=source,
            )
            self._cards[card.id] = card
            self._persist_locked()
            return card

    async def update_card(
        self, card_id: str, *, name: Optional[str] = None, description: Optional[str] = None, source: Optional[str] = None
    ) -> CardDefinition:
        async with self._lock:
            if card_id not in self._cards:
                raise CardConflictError(f"Card {card_id} does not exist.")
            card = self._cards[card_id]
            new_name = card.name
            if isinstance(name, str):
                stripped = name.strip()
                new_name = stripped or card.name
            updated = CardDefinition(
                id=card.id,
                name=new_name,
                description=description.strip() if isinstance(description, str) else card.description,
                source=textwrap.dedent(source).strip() if isinstance(source, str) else card.source,
            )
            self._validate_source(updated.source)
            self._cards[card_id] = updated
            self._persist_locked()
            return updated

    async def delete_card(self, card_id: str) -> None:
        async with self._lock:
            if card_id not in self._cards:
                return
            del self._cards[card_id]
            self._persist_locked()

    async def build_runner(self, card_id: str) -> Callable[[LogCallable], Awaitable[None]]:
        card = await self.get_card(card_id)
        if not card:
            raise CardValidationError(f"Card {card_id} not found.")
        namespace: Dict[str, object] = {}
        try:
            exec(card.source, self._runner_globals, namespace)
        except Exception as exc:  # noqa: BLE001
            raise CardValidationError(f"Card {card.name} 无法加载: {exc}") from exc
        run_callable = namespace.get("run")
        if not callable(run_callable):
            raise CardValidationError("卡片代码必须定义 `async def run(log): ...`")
        if not asyncio.iscoroutinefunction(run_callable):
            raise CardValidationError("`run` 必须是 async 协程函数。")

        async def runner(log: LogCallable) -> None:
            await run_callable(log)

        return runner

    def _persist_locked(self) -> None:
        payload = [card.to_dict() for card in self._cards.values()]
        self._storage_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False))

    def _validate_source(self, source: str) -> None:
        if "async def run" not in source:
            raise CardValidationError("源代码中需要定义 `async def run(log): ...`")
        namespace: Dict[str, object] = {}
        try:
            exec(source, self._runner_globals, namespace)
        except Exception as exc:  # noqa: BLE001
            raise CardValidationError(f"源代码非法: {exc}") from exc
        run_callable = namespace.get("run")
        if not callable(run_callable):
            raise CardValidationError("请定义名为 `run` 的函数。")
        if not asyncio.iscoroutinefunction(run_callable):
            raise CardValidationError("`run` 必须是 async 协程函数。")


DEFAULT_CARDS: List[Dict[str, str]] = [
    {
        "id": "timestamp",
        "name": "Show Timestamp",
        "description": "Displays the current system time and confirms completion.",
        "source": textwrap.dedent(
            """
            import asyncio
            from datetime import datetime

            async def run(log):
                await log("Current time is %s." % datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
                await asyncio.sleep(0.5)
                await log("Timestamp card completed.")
            """
        ).strip(),
    },
    {
        "id": "countdown",
        "name": "Countdown",
        "description": "Counts down from three with short delays.",
        "source": textwrap.dedent(
            """
            import asyncio

            async def run(log):
                await log("Starting countdown from 3.")
                for value in range(3, 0, -1):
                    await asyncio.sleep(0.5)
                    await log(f"... {value}")
                await asyncio.sleep(0.5)
                await log("Countdown finished!")
            """
        ).strip(),
    },
    {
        "id": "fibonacci",
        "name": "Fibonacci Demo",
        "description": "Outputs the first eight Fibonacci numbers.",
        "source": textwrap.dedent(
            """
            import asyncio

            async def run(log):
                await log("Calculating Fibonacci sequence up to 8 terms.")
                a, b = 0, 1
                for index in range(8):
                    await asyncio.sleep(0.4)
                    await log(f"F({index}) = {a}")
                    a, b = b, a + b
                await log("Fibonacci computation finished.")
            """
        ).strip(),
    },
    {
        "id": "random_fact",
        "name": "Random Fact",
        "description": "Picks and prints a random trivia fact.",
        "source": textwrap.dedent(
            """
            import asyncio
            import random

            FACTS = [
                "Honey never spoils because of its natural preservatives.",
                "Bananas are berries, but strawberries are not.",
                "Octopuses have three hearts pumping blue blood.",
                "The Eiffel Tower grows taller in the summer heat.",
            ]

            async def run(log):
                await log("Drawing a random fact.")
                await asyncio.sleep(0.6)
                fact = random.choice(FACTS)
                await log(f"Fact: {fact}")
                await asyncio.sleep(0.2)
                await log("Random fact card completed.")
            """
        ).strip(),
    },
]
