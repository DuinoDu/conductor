import asyncio
import pytest

from conductor.message import MessageRouter
from conductor.session import SessionManager


@pytest.mark.asyncio
async def test_backend_user_message_enqueues():
    sessions = SessionManager()
    await sessions.add_session("task1", "sess1", "proj1")
    router = MessageRouter(sessions)
    payload = {
        "type": "task_user_message",
        "payload": {
            "task_id": "task1",
            "message_id": "msg1",
            "role": "user",
            "content": "hello",
            "ack_token": "ack1",
        },
    }
    await router.handle_backend_event(payload)
    messages = await sessions.pop_messages("task1")
    assert len(messages) == 1
    assert messages[0].content == "hello"


@pytest.mark.asyncio
async def test_backend_task_action_formats_command():
    sessions = SessionManager()
    await sessions.add_session("task42", "sess42", "proj1")
    router = MessageRouter(sessions)
    payload = {
        "type": "task_action",
        "payload": {
            "task_id": "task42",
            "action": "run_tests",
            "args": {"command": "pytest sdk/tests -k smoke"},
        },
    }
    await router.handle_backend_event(payload)
    messages = await sessions.pop_messages("task42")
    assert len(messages) == 1
    assert messages[0].role == "action"
    assert messages[0].content == "run_tests: pytest sdk/tests -k smoke"


@pytest.mark.asyncio
async def test_outbound_handler_invoked():
    sessions = SessionManager()
    router = MessageRouter(sessions)
    called = asyncio.Event()

    async def handler(payload):
        if payload.get("type") == "sdk_message":
            called.set()

    router.register_outbound_handler(handler)
    await router.send_to_backend({"type": "sdk_message"})
    await asyncio.wait_for(called.wait(), timeout=1)
