"""Pydantic models for API responses."""

from __future__ import annotations

from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field


class CardModel(BaseModel):
    id: str
    name: str
    description: str
    source: str


class QueueItemModel(BaseModel):
    queue_id: int
    card_id: str
    card_name: str
    status: Literal["pending", "running", "completed"]
    enqueued_at: datetime
    started_at: Optional[datetime] = None
    finished_at: Optional[datetime] = None


class LogEntryModel(BaseModel):
    queue_id: int
    card_id: str
    card_name: str
    message: str
    timestamp: datetime


class StateModel(BaseModel):
    mode: Literal["idle", "single", "all", "endless"]
    is_running: bool = Field(..., description="True if the runner loop is active.")
    queue: List[QueueItemModel]
    output: List[LogEntryModel]
    available_cards: List[CardModel]
