import os
import httpx
import pytest

from conductor.backend import BackendApiClient
from conductor.config import ConductorConfig
from conductor.mcp import MCPServer
from conductor.message import MessageRouter
from conductor.session import SessionManager

BACKEND_EVENTS_URL = os.environ.get('BACKEND_EVENTS_URL', 'http://127.0.0.1:4000/events')


def make_config():
    return ConductorConfig.model_validate({
        "agent_token": "token",
        "backend_url": "https://api.local"
    })


async def _backend_request(method: str, **kwargs):
    async with httpx.AsyncClient(trust_env=False) as client:
        request_fn = getattr(client, method)
        try:
            response = await request_fn(BACKEND_EVENTS_URL, **kwargs)
        except httpx.RequestError:
            pytest.skip(f"Backend not reachable at {BACKEND_EVENTS_URL}")
        if response.status_code == 404:
            pytest.skip("Backend events endpoint not available; ensure backend exposes /events")
        response.raise_for_status()
        return response


async def _clear_backend_events():
    await _backend_request('delete')


async def _fetch_events():
    resp = await _backend_request('get')
    return resp.json()


@pytest.mark.asyncio
async def test_create_task_session_hits_backend_api():
    await _clear_backend_events()

    async def backend_sender(payload):
        await _backend_request('post', json=payload)

    sessions = SessionManager()
    router = MessageRouter(sessions)
    backend_api = BackendApiClient(make_config())
    server = MCPServer(
        make_config(),
        session_manager=sessions,
        message_router=router,
        backend_sender=backend_sender,
        backend_api=backend_api,
    )

    await server.handle_request("create_task_session", {"project_id": "proj1", "task_title": "Hello"})
    events = await _fetch_events()
    assert events and events[-1]["type"] == "create_task"


@pytest.mark.asyncio
async def test_create_task_session_prefill_payload():
    await _clear_backend_events()

    async def backend_sender(payload):
        await _backend_request('post', json=payload)

    sessions = SessionManager()
    router = MessageRouter(sessions)
    backend_api = BackendApiClient(make_config())
    server = MCPServer(
        make_config(),
        session_manager=sessions,
        message_router=router,
        backend_sender=backend_sender,
        backend_api=backend_api,
    )

    await server.handle_request("create_task_session", {"project_id": "proj2", "task_title": "Hi", "prefill": "context"})
    events = await _fetch_events()
    assert events[-1]["payload"].get("prefill") == "context"


@pytest.mark.asyncio
async def test_send_message_hits_backend_api():
    await _clear_backend_events()

    async def backend_sender(payload):
        await _backend_request('post', json=payload)

    sessions = SessionManager()
    router = MessageRouter(sessions)
    backend_api = BackendApiClient(make_config())
    server = MCPServer(
        make_config(),
        session_manager=sessions,
        message_router=router,
        backend_sender=backend_sender,
        backend_api=backend_api,
    )

    await server.handle_request("send_message", {"task_id": "task1", "content": "reply"})
    events = await _fetch_events()
    assert events[-1]["type"] == "sdk_message"


@pytest.mark.asyncio
async def test_send_message_with_metadata():
    await _clear_backend_events()

    async def backend_sender(payload):
        await _backend_request('post', json=payload)

    sessions = SessionManager()
    router = MessageRouter(sessions)
    backend_api = BackendApiClient(make_config())
    server = MCPServer(
        make_config(),
        session_manager=sessions,
        message_router=router,
        backend_sender=backend_sender,
        backend_api=backend_api,
    )

    await server.handle_request("send_message", {"task_id": "task1", "content": "reply", "metadata": {"model": "codex"}})
    events = await _fetch_events()
    assert events[-1]["payload"].get("metadata", {}).get("model") == "codex"
