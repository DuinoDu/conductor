import httpx
import pytest

from conductor.backend import BackendApiClient, BackendApiError, ProjectSummary
from conductor.config import ConductorConfig


def make_config():
    return ConductorConfig.model_validate(
        {
            "agent_token": "token",
            "backend_url": "https://backend.local",
        }
    )


def make_client(response_cb):
    transport = httpx.MockTransport(response_cb)
    return BackendApiClient(make_config(), transport=transport)


@pytest.mark.asyncio
async def test_list_projects_returns_summaries():
    def handler(request):
        assert request.headers["Authorization"] == "Bearer token"
        return httpx.Response(
            200,
            json=[
                {"id": "p1", "name": "Demo", "description": "Project"},
                {"id": "p2", "name": None},
                {"name": "missing-id"},
            ],
        )

    client = make_client(handler)
    projects = await client.list_projects()
    assert [p.id for p in projects] == ["p1", "p2"]
    assert projects[0].name == "Demo"


@pytest.mark.asyncio
async def test_list_projects_handles_http_error():
    def handler(_request):
        return httpx.Response(500, json={"message": "boom"})

    client = make_client(handler)
    with pytest.raises(BackendApiError):
        await client.list_projects()


@pytest.mark.asyncio
async def test_list_projects_validates_response_shape():
    def handler(_request):
        return httpx.Response(200, json={"unexpected": True})

    client = make_client(handler)
    with pytest.raises(BackendApiError):
        await client.list_projects()
