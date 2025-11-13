from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Awaitable, Callable, Dict


class EventReporter:
    """Lightweight helper for emitting structured events to the backend."""

    def __init__(self, backend_sender: Callable[[Dict[str, Any]], Awaitable[None]]) -> None:
        self._backend_sender = backend_sender

    async def emit(self, event_type: str, payload: Dict[str, Any]) -> None:
        envelope = {
            "type": event_type,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "payload": payload,
        }
        await self._backend_sender(envelope)

    async def task_status(self, task_id: str, status: str, summary: str | None = None) -> None:
        await self.emit(
            "task_status_update",
            {"task_id": task_id, "status": status, "summary": summary},
        )
