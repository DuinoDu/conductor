"""Pydantic models that represent the Conductor SDK configuration."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable, List, Optional
from urllib.parse import urlparse

from pydantic import AnyHttpUrl, BaseModel, ConfigDict, Field, computed_field, field_validator


def _expand_path(value: str | Path) -> Path:
    path = Path(value).expanduser()
    try:
        return path.resolve()
    except FileNotFoundError:
        # resolve(strict=True) raises if the path does not exist; we only care
        # about normalising the user input, so fall back to strict=False.
        return path.resolve(strict=False)


class ProjectConfig(BaseModel):
    """Per-project execution context configuration."""

    model_config = ConfigDict(populate_by_name=True)

    path: Path = Field(description="Absolute directory path to the project root")
    name: Optional[str] = Field(
        default=None,
        description="Optional human friendly label used in logs/UI",
    )
    default_model: Optional[str] = Field(
        default=None, description="Preferred model name when requesting AI completions"
    )
    env: Optional[str] = Field(
        default=None,
        alias="environment",
        description="Execution environment hint (conda env, docker image, etc.)",
    )

    @field_validator("path", mode="before")
    @classmethod
    def _validate_path(cls, value: str | Path) -> Path:
        if not value:
            raise ValueError("project.path cannot be empty")
        return _expand_path(value)

    def matches(self, path: Path) -> bool:
        """Return True when ``path`` is inside this project root."""

        try:
            return path == self.path or path.is_relative_to(self.path)
        except AttributeError:
            # Python <3.9 compatibility: emulate Path.is_relative_to
            try:
                path.relative_to(self.path)
                return True
            except ValueError:
                return False


class ConductorConfig(BaseModel):
    """Top-level SDK configuration."""

    model_config = ConfigDict(extra="ignore")

    agent_token: str = Field(description="Token issued by the backend for this agent")
    backend_url: AnyHttpUrl = Field(
        default="https://api.conductor.local",
        description="Base HTTPS endpoint of the Conductor backend",
    )
    websocket_url: Optional[str] = Field(
        default=None,
        description="Optional override for the backend WebSocket endpoint",
    )
    log_level: str = Field(
        default="info",
        description="Default log verbosity for the SDK process",
    )
    projects: List[ProjectConfig] = Field(default_factory=list)

    @field_validator("agent_token")
    @classmethod
    def _token_not_blank(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("agent_token must be provided")
        return value.strip()

    @field_validator("log_level")
    @classmethod
    def _normalise_log_level(cls, value: str) -> str:
        allowed = {"debug", "info", "warning", "error", "critical"}
        lowered = value.strip().lower()
        if lowered not in allowed:
            raise ValueError(f"log_level must be one of {sorted(allowed)}")
        return lowered

    @computed_field(return_type=str)
    @property
    def resolved_websocket_url(self) -> str:
        """Final WebSocket URL derived from either websocket_url or backend_url."""

        if self.websocket_url:
            parsed = urlparse(self.websocket_url)
            if parsed.scheme not in {"ws", "wss"}:
                raise ValueError("websocket_url must start with ws:// or wss://")
            return self.websocket_url

        scheme = "wss" if self.backend_url.scheme == "https" else "ws"
        return f"{scheme}://{self.backend_url.host}/ws/agent"

    def default_project(self) -> Optional[ProjectConfig]:
        """Return the first configured project, if any."""

        return self.projects[0] if self.projects else None

    def find_project_for_path(self, path: Path | str | None = None) -> Optional[ProjectConfig]:
        """
        Return the most specific project whose root contains ``path``.

        If ``path`` is omitted, the current working directory is used.
        """

        if not self.projects:
            return None

        target = _expand_path(path or Path.cwd())

        matches = [proj for proj in self.projects if proj.matches(target)]
        if not matches:
            return None

        # Pick the deepest match so nested repositories are handled correctly.
        return max(matches, key=lambda proj: len(str(proj.path)))

    def require_project(self, path: Path | str | None = None) -> ProjectConfig:
        """
        Return the project for ``path`` or raise a ConfigError-like ValueError.
        """

        project = self.find_project_for_path(path)
        if project is None:
            raise ValueError(
                f"No project configured for path {path or Path.cwd()}. "
                "Update ~/.conductor/config.yaml to include it."
            )
        return project

    def iter_project_paths(self) -> Iterable[Path]:
        """Yield the root path for each configured project."""

        return (project.path for project in self.projects)
