import asyncio
import pytest

from conductor.session import SessionManager


@pytest.mark.asyncio
async def test_session_add_and_get():
    manager = SessionManager()
    await manager.add_session("task1", "sess1", "proj1")
    session = await manager.get_session("task1")
    assert session is not None
    assert session.session_id == "sess1"


@pytest.mark.asyncio
async def test_message_queue_and_ack():
    manager = SessionManager()
    await manager.add_session("task1", "sess1", "proj1")
    await manager.add_message("task1", "msg1", "user", "hello", ack_token="t1")
    await manager.add_message("task1", "msg2", "user", "world", ack_token="t2")
    batch = await manager.pop_messages("task1", limit=1)
    assert len(batch) == 1
    assert batch[0].message_id == "msg1"
    assert await manager.ack("task1", "t1") is True
    assert await manager.ack("task1", "bad") is False


@pytest.mark.asyncio
async def test_list_sessions():
    manager = SessionManager()
    await manager.add_session("task1", "sess1", "proj1")
    await manager.add_session("task2", "sess2", "proj1")
    sessions = await manager.list_sessions()
    assert {s.task_id for s in sessions} == {"task1", "task2"}
