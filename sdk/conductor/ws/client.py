from __future__ import annotations

import asyncio
import json
from collections.abc import Awaitable, Callable
from typing import Any, Optional

import websockets
from websockets import WebSocketClientProtocol

from conductor.config import ConductorConfig

WebSocketEventHandler = Callable[[dict[str, Any]], Awaitable[None] | None]


class ConductorWebSocketClient:
    """Minimal async WS client with simple reconnect + heartbeat support."""

    def __init__(
        self,
        config: ConductorConfig,
        *,
        reconnect_delay: float = 3.0,
        heartbeat_interval: float = 20.0,
        connect_impl: Callable[..., Awaitable[WebSocketClientProtocol]] = websockets.connect,
    ) -> None:
        self._config = config
        self._url = config.resolved_websocket_url
        self._token = config.agent_token
        self._reconnect_delay = reconnect_delay
        self._heartbeat_interval = heartbeat_interval
        self._connect_impl = connect_impl
        self._conn: Optional[WebSocketClientProtocol] = None
        self._handlers: list[WebSocketEventHandler] = []
        self._stop = False
        self._listen_task: Optional[asyncio.Task[None]] = None
        self._heartbeat_task: Optional[asyncio.Task[None]] = None
        self._connection_lock = asyncio.Lock()

    def register_handler(self, handler: WebSocketEventHandler) -> None:
        self._handlers.append(handler)

    async def connect(self) -> None:
        self._stop = False
        await self._open_connection(force=True)

    async def disconnect(self) -> None:
        self._stop = True
        if self._listen_task:
            self._listen_task.cancel()
        if self._heartbeat_task:
            self._heartbeat_task.cancel()
        if self._conn and not self._conn.closed:
            await self._conn.close()
        self._conn = None

    async def send_json(self, payload: dict[str, Any]) -> None:
        await self._ensure_connection()
        assert self._conn  # mypy appeasement
        await self._conn.send(json.dumps(payload))

    async def _ensure_connection(self) -> None:
        if self._conn and not self._conn.closed:
            return
        await self._open_connection(force=True)

    async def _open_connection(self, *, force: bool = False) -> None:
        async with self._connection_lock:
            if self._conn and not self._conn.closed and not force:
                return
            await self._cancel_tasks()

            while not self._stop:
                try:
                    self._conn = await self._connect_impl(
                        self._url,
                        extra_headers={"Authorization": f"Bearer {self._token}"},
                    )
                    self._listen_task = asyncio.create_task(
                        self._listen_loop(self._conn),
                        name="conductor-ws-listen",
                    )
                    self._heartbeat_task = asyncio.create_task(
                        self._heartbeat_loop(self._conn),
                        name="conductor-ws-heartbeat",
                    )
                    return
                except Exception:
                    await asyncio.sleep(self._reconnect_delay)

    async def _cancel_tasks(self) -> None:
        for task in (self._listen_task, self._heartbeat_task):
            if task:
                task.cancel()
        self._listen_task = None
        self._heartbeat_task = None

    async def _listen_loop(self, conn: WebSocketClientProtocol) -> None:
        try:
            async for message in conn:
                await self._dispatch(message)
        except websockets.ConnectionClosed:
            pass
        finally:
            if not self._stop and conn is self._conn:
                await self._open_connection(force=True)

    async def _heartbeat_loop(self, conn: WebSocketClientProtocol) -> None:
        try:
            while not self._stop and not conn.closed:
                await asyncio.sleep(self._heartbeat_interval)
                try:
                    await conn.ping()
                except Exception:
                    break
        finally:
            if not self._stop and conn is self._conn:
                await self._open_connection(force=True)

    async def _dispatch(self, message: str) -> None:
        try:
            payload = json.loads(message)
        except json.JSONDecodeError:
            return

        for handler in self._handlers:
            result = handler(payload)
            if asyncio.iscoroutine(result):
                await result
