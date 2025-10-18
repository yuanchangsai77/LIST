from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from typing import Optional

from .cards import CardConflictError, CardRepository, CardValidationError
from .runner import TaskRunner

BASE_DIR = Path(__file__).resolve().parent.parent
TEMPLATES_DIR = BASE_DIR / "frontend" / "templates"
STATIC_DIR = BASE_DIR / "frontend" / "static"
DATA_DIR = BASE_DIR / "data"
DATA_FILE = DATA_DIR / "cards.json"

app = FastAPI(title="Task List Runner")

templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

card_repository = CardRepository(DATA_FILE)
runner = TaskRunner(card_repository)


@app.on_event("startup")
async def startup_event() -> None:
    await card_repository.load()
    await runner.start()


@app.on_event("shutdown")
async def shutdown_event() -> None:
    await runner.shutdown()


app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


class QueueRequest(BaseModel):
    card_id: str


class CardCreateRequest(BaseModel):
    name: str
    description: str
    source: str


class CardUpdateRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    source: Optional[str] = None


@app.get("/", response_class=HTMLResponse)
async def index(request: Request) -> HTMLResponse:
    return templates.TemplateResponse("index.html", {"request": request})


@app.get("/api/cards")
async def get_cards():
    return await runner.list_cards()


@app.get("/api/state")
async def get_state():
    return await runner.get_state()


@app.post("/api/queue")
async def add_to_queue(request: QueueRequest):
    try:
        return await runner.add_to_queue(request.card_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.delete("/api/queue/{queue_id}")
async def remove_from_queue(queue_id: int):
    await runner.remove_from_queue(queue_id)
    return {"status": "ok"}


@app.post("/api/control/run-once")
async def control_run_once():
    await runner.run_once()
    return {"status": "started"}


@app.post("/api/control/run-all")
async def control_run_all():
    await runner.run_all()
    return {"status": "started"}


@app.post("/api/control/run-endless")
async def control_run_endless():
    await runner.run_endless()
    return {"status": "started"}


@app.post("/api/control/stop")
async def control_stop():
    await runner.stop()
    return {"status": "stopping"}


@app.post("/api/control/clear-output")
async def control_clear_output():
    await runner.clear_output()
    return {"status": "cleared"}


@app.post("/api/cards")
async def create_card(request: CardCreateRequest):
    try:
        card = await card_repository.create_card(
            name=request.name, description=request.description, source=request.source
        )
        return card.to_dict()
    except CardValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.put("/api/cards/{card_id}")
async def update_card(card_id: str, request: CardUpdateRequest):
    try:
        card = await card_repository.update_card(
            card_id, name=request.name, description=request.description, source=request.source
        )
        return card.to_dict()
    except CardConflictError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except CardValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.delete("/api/cards/{card_id}")
async def delete_card(card_id: str):
    await card_repository.delete_card(card_id)
    return {"status": "deleted"}
