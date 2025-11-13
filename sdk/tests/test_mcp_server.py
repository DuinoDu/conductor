import asyncio
import pytest

from conductor.config import ConductorConfig
from conductor.message import MessageRouter
from conductor.mcp import MCPServer
from conductor.session import SessionManager


def make_config():
    return ConductorConfig.model_validate({
        "agent_token": "token",
        "backend_url": "https://backend.local"
    })


@pytest.mark.asyncio
async def test_create_task_session_calls_backend_and_stores_session():
    recorded = []

    async def backend_sender(payload):
        recorded.append(payload)

    sessions = SessionManager()
    router = MessageRouter(sessions)
    server = MCPServer(make_config(), session_manager=sessions, message_router=router, backend_sender=backend_sender)

    result = await server.handle_request("create_task_session", {"project_id": "proj1", "task_title": "Hello"})
    assert result["task_id"]
    assert recorded[0]["type"] == "create_task"
    session = await sessions.get_session(result["task_id"])
    assert session is not None


@pytest.mark.asyncio
async def test_receive_and_ack_messages():
    recorded = []

    async def backend_sender(payload):
        recorded.append(payload)

    sessions = SessionManager()
    await sessions.add_session("task1", "sess1", "proj1")
    await sessions.add_message("task1", "msg1", "user", "hi", ack_token="ack1")
    router = MessageRouter(sessions)
    server = MCPServer(make_config(), session_manager=sessions, message_router=router, backend_sender=backend_sender)

    received = await server.handle_request("receive_messages", {"task_id": "task1"})
    assert len(received["messages"]) == 1
    assert received["messages"][0]["content"] == "hi"

    ack_resp = await server.handle_request("ack_messages", {"task_id": "task1", "ack_token": "ack1"})
    assert ack_resp["status"] == "ok"


@pytest.mark.asyncio
async def test_send_message_proxies_to_backend():
    recorded = []

    async def backend_sender(payload):
        recorded.append(payload)

    sessions = SessionManager()
    router = MessageRouter(sessions)
    server = MCPServer(make_config(), session_manager=sessions, message_router=router, backend_sender=backend_sender)

    await server.handle_request("send_message", {"task_id": "task1", "content": "hello"})
    assert recorded[0]["type"] == "sdk_message"
