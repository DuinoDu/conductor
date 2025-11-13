from __future__ import annotations

from typing import Awaitable, Callable, Dict, List

from conductor.session import SessionManager

BackendPayload = Dict[str, object]
OutboundHandler = Callable[[BackendPayload], Awaitable[None] | None]


class MessageRouter:
    def __init__(self, session_manager: SessionManager) -> None:
        self._sessions = session_manager
        self._outbound_handlers: List[OutboundHandler] = []

    def register_outbound_handler(self, handler: OutboundHandler) -> None:
        self._outbound_handlers.append(handler)

    async def handle_backend_event(self, payload: BackendPayload) -> None:
        """
        Process WS events from Backend:
        - task_user_message: push to session pending queue.
        - task_status_update: update session meta.
        """
        event_type = payload.get("type")
        data = payload.get("payload", {}) if isinstance(payload.get("payload"), dict) else {}
        task_id = data.get("task_id")
        if event_type == "task_user_message" and task_id:
            await self._sessions.add_message(
                task_id=task_id,
                message_id=str(data.get("message_id")),
                role=data.get("role", "user"),
                content=data.get("content", ""),
                ack_token=data.get("ack_token"),
            )
        elif event_type == "task_status_update" and task_id:
            session = await self._sessions.get_session(task_id)
            if session:
                session.status = data.get("status", session.status)

    async def send_to_backend(self, payload: BackendPayload) -> None:
        for handler in self._outbound_handlers:
            result = handler(payload)
            if result and hasattr(result, "__await__"):
                await result
