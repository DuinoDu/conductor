from __future__ import annotations

import json
from typing import Awaitable, Callable, Dict, List, Optional, Sequence
from uuid import uuid4

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
        - task_action: enqueue a readable command/event summary.
        """
        event_type = payload.get("type")
        data = payload.get("payload", {}) if isinstance(payload.get("payload"), dict) else {}
        task_id = data.get("task_id")
        if not isinstance(task_id, str):
            return

        if event_type == "task_user_message":
            await self._sessions.add_message(
                task_id=task_id,
                message_id=self._resolve_message_id(data),
                role=self._coerce_role(data.get("role"), default="user"),
                content=self._coerce_content(data.get("content")),
                ack_token=data.get("ack_token"),
            )
        elif event_type == "task_action":
            await self._sessions.add_message(
                task_id=task_id,
                message_id=self._resolve_message_id(data),
                role=self._coerce_role(data.get("role"), default="action"),
                content=self._format_action_content(data),
                ack_token=data.get("ack_token"),
            )
        elif event_type == "task_status_update":
            session = await self._sessions.get_session(task_id)
            if session:
                session.status = data.get("status", session.status)

    async def send_to_backend(self, payload: BackendPayload) -> None:
        for handler in self._outbound_handlers:
            result = handler(payload)
            if result and hasattr(result, "__await__"):
                await result

    @staticmethod
    def _resolve_message_id(data: Dict[str, object]) -> str:
        candidates: Sequence[Optional[object]] = (
            data.get("message_id"),
            data.get("action_id"),
            data.get("id"),
            data.get("request_id"),
        )
        for candidate in candidates:
            if isinstance(candidate, (str, int)):
                return str(candidate)
        return str(uuid4())

    @staticmethod
    def _coerce_role(role: object, *, default: str) -> str:
        if isinstance(role, str) and role.strip():
            return role
        return default

    @staticmethod
    def _coerce_content(content: object) -> str:
        if isinstance(content, str):
            return content
        if content is None:
            return ""
        try:
            return json.dumps(content, ensure_ascii=False)
        except TypeError:
            return str(content)

    def _format_action_content(self, data: Dict[str, object]) -> str:
        explicit = data.get("content")
        if isinstance(explicit, str) and explicit.strip():
            return explicit

        action = data.get("action")
        action_label = action if isinstance(action, str) and action else "action"
        args = data.get("args")
        if isinstance(args, dict) and args:
            command = args.get("command")
            if isinstance(command, str) and command.strip():
                return f"{action_label}: {command.strip()}"
            try:
                args_json = json.dumps(args, ensure_ascii=False)
            except TypeError:
                args_json = str(args)
            return f"{action_label}: {args_json}"

        return action_label
