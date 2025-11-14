import asyncio
import pytest

from conductor.backend import ProjectSummary
from conductor.config import ConductorConfig
from conductor.message import MessageRouter
from conductor.mcp import MCPServer
from conductor.session import SessionManager


def make_config():
    return ConductorConfig.model_validate(
        {
            "agent_token": "token",
            "backend_url": "https://backend.local",
        }
    )


class FakeBackendApi:
    def __init__(self, projects=None):
        self.projects = projects or []

    async def list_projects(self):
        return self.projects


@pytest.mark.asyncio
async def test_create_task_session_calls_backend_and_stores_session():
    recorded = []

    async def backend_sender(payload):
        recorded.append(payload)

    sessions = SessionManager()
    router = MessageRouter(sessions)
    server = MCPServer(
        make_config(),
        session_manager=sessions,
        message_router=router,
        backend_sender=backend_sender,
        backend_api=FakeBackendApi(),
    )

    result = await server.handle_request(
        "create_task_session", {"project_id": "proj1", "task_title": "Hello"}
    )
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
    server = MCPServer(
        make_config(),
        session_manager=sessions,
        message_router=router,
        backend_sender=backend_sender,
        backend_api=FakeBackendApi(),
    )

    received = await server.handle_request("receive_messages", {"task_id": "task1"})
    assert len(received["messages"]) == 1
    assert received["messages"][0]["content"] == "hi"

    ack_resp = await server.handle_request(
        "ack_messages", {"task_id": "task1", "ack_token": "ack1"}
    )
    assert ack_resp["status"] == "ok"


@pytest.mark.asyncio
async def test_send_message_proxies_to_backend():
    recorded = []

    async def backend_sender(payload):
        recorded.append(payload)

    sessions = SessionManager()
    router = MessageRouter(sessions)
    server = MCPServer(
        make_config(),
        session_manager=sessions,
        message_router=router,
        backend_sender=backend_sender,
        backend_api=FakeBackendApi(),
    )

    await server.handle_request("send_message", {"task_id": "task1", "content": "hello"})
    assert recorded[0]["type"] == "sdk_message"


@pytest.mark.asyncio
async def test_list_projects_tool_returns_backend_results():
    sessions = SessionManager()
    router = MessageRouter(sessions)

    backend_api = FakeBackendApi(
        projects=[
            ProjectSummary(id="p1", name="Demo", description=None),
            ProjectSummary(id="p2", name="Other", description="desc"),
        ]
    )

    async def backend_sender(_payload):
        pass

    server = MCPServer(
        make_config(),
        session_manager=sessions,
        message_router=router,
        backend_sender=backend_sender,
        backend_api=backend_api,
    )

    result = await server.handle_request("list_projects", {})
    assert len(result["projects"]) == 2
    assert result["projects"][0]["id"] == "p1"
