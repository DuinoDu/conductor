from __future__ import annotations

import asyncio
import json
from typing import Any, Callable

import pytest

from conductor.config import ConductorConfig
from conductor.ws import ConductorWebSocketClient


class FakeWebSocket:
    def __init__(self) -> None:
        self._incoming: asyncio.Queue[str | None] = asyncio.Queue()
        self.sent: list[str] = []
        self._closed = False

    @property
    def closed(self) -> bool:
        return self._closed

    async def send(self, data: str) -> None:
        self.sent.append(data)

    async def ping(self) -> None:
        if self._closed:
            raise RuntimeError("closed")

    async def close(self) -> None:
        self._closed = True
        await self._incoming.put(None)

    def feed(self, payload: dict[str, Any]) -> None:
        self._incoming.put_nowait(json.dumps(payload))

    def __aiter__(self) -> FakeWebSocket:
        return self

    async def __anext__(self) -> str:
        message = await self._incoming.get()
        if message is None:
            raise StopAsyncIteration
        return message


def make_config() -> ConductorConfig:
    return ConductorConfig.model_validate(
        {"agent_token": "token", "backend_url": "https://backend.local"}
    )


@pytest.mark.asyncio
async def test_ws_client_dispatches_messages():
    connections: list[FakeWebSocket] = []

    async def connect_mock(*_args, **_kwargs):
        conn = FakeWebSocket()
        connections.append(conn)
        return conn

    client = ConductorWebSocketClient(
        make_config(),
        reconnect_delay=0.05,
        heartbeat_interval=0.05,
        connect_impl=connect_mock,
    )

    received: list[dict[str, Any]] = []
    event = asyncio.Event()

    async def on_event(payload: dict[str, Any]) -> None:
        received.append(payload)
        event.set()

    client.register_handler(on_event)
    await client.connect()
    first_conn = connections[0]
    first_conn.feed({"type": "task_user_message"})
    await asyncio.wait_for(event.wait(), timeout=1)
    assert received == [{"type": "task_user_message"}]
    await client.disconnect()


@pytest.mark.asyncio
async def test_ws_client_reconnects_and_sends_after_close():
    connections: list[FakeWebSocket] = []

    async def connect_mock(*_args, **_kwargs):
        conn = FakeWebSocket()
        connections.append(conn)
        return conn

    client = ConductorWebSocketClient(
        make_config(),
        reconnect_delay=0.05,
        heartbeat_interval=0.05,
        connect_impl=connect_mock,
    )

    await client.connect()
    first_conn = connections[0]
    await first_conn.close()
    await asyncio.sleep(0.2)
    await client.send_json({"type": "ping"})
    assert len(connections) >= 2
    assert json.loads(connections[-1].sent[-1]) == {"type": "ping"}
    await client.disconnect()
