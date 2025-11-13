import asyncio
import pytest

from conductor.reporter import EventReporter


@pytest.mark.asyncio
async def test_event_reporter_emits_envelope():
    recorded = []

    async def backend_sender(payload):
        recorded.append(payload)

    reporter = EventReporter(backend_sender)
    await reporter.task_status("task1", "RUNNING", "Working")
    assert recorded[0]["type"] == "task_status_update"
    assert recorded[0]["payload"]["task_id"] == "task1"
