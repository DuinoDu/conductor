from __future__ import annotations

from dataclasses import dataclass
from typing import Any, List, Optional

import httpx

from conductor.config import ConductorConfig


class BackendApiError(RuntimeError):
    """Raised when the backend HTTP API cannot be reached or returns an error."""

    def __init__(
        self,
        message: str,
        *,
        status_code: Optional[int] = None,
        details: Any = None,
    ) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.details = details


@dataclass(slots=True)
class ProjectSummary:
    """Simple container for project metadata surfaced to SDK tools."""

    id: str
    name: Optional[str]
    description: Optional[str]

    @classmethod
    def from_json(cls, payload: dict[str, Any]) -> "ProjectSummary":
        project_id = str(payload.get("id") or "")
        if not project_id:
            raise ValueError("Project payload missing 'id'")
        return cls(
            id=project_id,
            name=payload.get("name"),
            description=payload.get("description"),
        )

    def as_dict(self) -> dict[str, Optional[str]]:
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
        }


class BackendApiClient:
    """Minimal async HTTP client for Conductor backend endpoints."""

    def __init__(
        self,
        config: ConductorConfig,
        *,
        timeout: float = 10.0,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self._config = config
        self._timeout = timeout
        self._transport = transport
        self._base_url = str(config.backend_url).rstrip("/")
        self._headers = {
            "Authorization": f"Bearer {config.agent_token}",
            "Accept": "application/json",
        }

    async def list_projects(self) -> List[ProjectSummary]:
        response = await self._request("GET", "/projects")
        data = response.json()
        if not isinstance(data, list):
            raise BackendApiError(
                "Invalid projects response: expected list",
                status_code=response.status_code,
                details=data,
            )
        projects = []
        for entry in data:
            if isinstance(entry, dict):
                try:
                    projects.append(ProjectSummary.from_json(entry))
                except ValueError:
                    continue
        return projects

    async def _request(self, method: str, path: str, **kwargs) -> httpx.Response:
        url = f"{self._base_url}{path}"
        async with httpx.AsyncClient(
            trust_env=False,
            timeout=self._timeout,
            transport=self._transport,
        ) as client:
            try:
                response = await client.request(method, url, headers=self._headers, **kwargs)
            except httpx.HTTPError as exc:
                raise BackendApiError(f"Backend request failed: {exc}") from exc
        if response.is_error:
            message = f"Backend responded with {response.status_code}"
            try:
                error_payload = response.json()
            except ValueError:
                error_payload = response.text
            raise BackendApiError(
                message,
                status_code=response.status_code,
                details=error_payload,
            )
        return response
