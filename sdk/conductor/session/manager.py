from __future__ import annotations

import asyncio
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Deque, Dict, List, Optional


@dataclass
class MessageRecord:
    message_id: str
    role: str
    content: str
    created_at: datetime
    ack_token: Optional[str] = None


@dataclass
class SessionState:
    task_id: str
    session_id: str
    project_id: str
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    last_message_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    status: str = "ACTIVE"
    pending_messages: Deque[MessageRecord] = field(default_factory=deque)
    ack_token: Optional[str] = None


class SessionManager:
    def __init__(self) -> None:
        self._sessions: Dict[str, SessionState] = {}
        self._lock = asyncio.Lock()

    async def add_session(self, task_id: str, session_id: str, project_id: str) -> SessionState:
        async with self._lock:
            state = SessionState(task_id=task_id, session_id=session_id, project_id=project_id)
            self._sessions[task_id] = state
            return state

    async def get_session(self, task_id: str) -> Optional[SessionState]:
        async with self._lock:
            return self._sessions.get(task_id)

    async def add_message(
        self,
        task_id: str,
        message_id: str,
        role: str,
        content: str,
        *,
        ack_token: Optional[str] = None,
    ) -> None:
        async with self._lock:
            session = self._sessions.get(task_id)
            if not session:
                return
            record = MessageRecord(
                message_id=message_id,
                role=role,
                content=content,
                created_at=datetime.now(timezone.utc),
                ack_token=ack_token,
            )
            session.pending_messages.append(record)
            session.last_message_at = record.created_at

    async def pop_messages(self, task_id: str, limit: int = 20) -> List[MessageRecord]:
        async with self._lock:
            session = self._sessions.get(task_id)
            if not session:
                return []
            items: List[MessageRecord] = []
            while session.pending_messages and len(items) < limit:
                items.append(session.pending_messages.popleft())
            if items:
                session.ack_token = items[-1].ack_token
            return items

    async def ack(self, task_id: str, ack_token: str) -> bool:
        async with self._lock:
            session = self._sessions.get(task_id)
            if not session:
                return False
            if session.ack_token == ack_token:
                session.ack_token = None
                return True
            return False

    async def list_sessions(self) -> List[SessionState]:
        async with self._lock:
            return list(self._sessions.values())

    async def end_session(self, task_id: str) -> None:
        async with self._lock:
            session = self._sessions.get(task_id)
            if session:
                session.status = "ENDED"
