import asyncio
import pytest

from conductor.message import MessageRouter
from conductor.mcp import MCPServer
from conductor.orchestrator import SDKOrchestrator
from conductor.reporter import EventReporter
from conductor.session import SessionManager

class FakeWs:
    def __init__(self):
        self.handlers = []
        self.connected = False

    def register_handler(self, handler):
        self.handlers.append(handler)

    async def connect(self):
        self.connected = True

    async def disconnect(self):
        self.connected = False

class DummyMCP(MCPServer):
    pass

@pytest.mark.asyncio
async def test_orchestrator_start_stop_routes_events(monkeypatch):
    sessions = SessionManager()
    router = MessageRouter(sessions)

    async def backend_sender(payload):
        pass

    class DummyMCP:
        pass

    reporter = EventReporter(backend_sender)
    ws = FakeWs()
    mcp_server = DummyMCP()

    orchestrator = SDKOrchestrator(
        ws_client=ws,
        message_router=router,
        session_manager=sessions,
        mcp_server=mcp_server,
        reporter=reporter,
    )

    await orchestrator.start()
    assert ws.connected

    payload = {"type": "task_user_message", "payload": {"task_id": "task1", "message_id": "m1", "content": "Hi"}}
    await sessions.add_session("task1", "sess1", "proj1")
    for handler in ws.handlers:
        await handler(payload)

    messages = await sessions.pop_messages("task1")
    assert len(messages) == 1

    await orchestrator.stop()
    assert not ws.connected
