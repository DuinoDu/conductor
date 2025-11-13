from __future__ import annotations

from pathlib import Path

import pytest

from conductor.config import ConfigFileNotFound, ConfigValidationError, load_config
from conductor.config.loader import (
    AGENT_TOKEN_ENV_VAR,
    BACKEND_URL_ENV_VAR,
    CONFIG_ENV_VAR,
    LOG_LEVEL_ENV_VAR,
    WS_URL_ENV_VAR,
)


def create_config(tmp_path, text: str) -> Path:
    config_path = tmp_path / "config.yaml"
    config_path.write_text(text, encoding="utf-8")
    return config_path


def test_load_config_from_explicit_path(tmp_path):
    config_path = create_config(
        tmp_path,
        """
        agent_token: foo
        backend_url: https://backend.local
        projects:
          - path: {project}
            default_model: gpt-4.1
        """.format(
            project=tmp_path / "repo"
        ),
    )
    config = load_config(config_path)

    assert config.agent_token == "foo"
    assert config.backend_url.host == "backend.local"
    assert config.default_project() is not None
    assert config.default_project().default_model == "gpt-4.1"


def test_missing_config_file_raises(tmp_path):
    missing_path = tmp_path / "does-not-exist.yaml"
    with pytest.raises(ConfigFileNotFound):
        load_config(missing_path)


def test_environment_overrides(tmp_path):
    config_path = create_config(
        tmp_path,
        """
        agent_token: foo
        backend_url: https://backend.local
        log_level: warning
        """,
    )
    env = {
        CONFIG_ENV_VAR: str(config_path),
        AGENT_TOKEN_ENV_VAR: "override-token",
        BACKEND_URL_ENV_VAR: "https://override.local",
        WS_URL_ENV_VAR: "wss://override.local/ws/agent",
        LOG_LEVEL_ENV_VAR: "ERROR",
    }

    config = load_config(env=env)

    assert config.agent_token == "override-token"
    assert config.backend_url.host == "override.local"
    assert config.resolved_websocket_url == "wss://override.local/ws/agent"
    assert config.log_level == "error"


def test_find_project_for_nested_path(tmp_path):
    repo_a = tmp_path / "repo"
    repo_b = repo_a / "nested"
    repo_a.mkdir()
    repo_b.mkdir()

    config_path = create_config(
        tmp_path,
        f"""
        agent_token: foo
        projects:
          - path: {repo_a}
            name: repo-a
          - path: {repo_b}
            name: repo-b
        """,
    )
    config = load_config(config_path)

    project = config.find_project_for_path(repo_b / "src")
    assert project is not None
    assert project.name == "repo-b"


def test_require_project_raises_meaningful_error(tmp_path):
    repo = tmp_path / "repo"
    repo.mkdir()
    config_path = create_config(
        tmp_path,
        f"""
        agent_token: foo
        projects:
          - path: {repo}
        """,
    )
    config = load_config(config_path)

    with pytest.raises(ValueError):
        config.require_project(tmp_path / "other")


def test_invalid_log_level_is_reported(tmp_path):
    config_path = create_config(
        tmp_path,
        """
        agent_token: foo
        log_level: verbose
        """,
    )

    with pytest.raises(ConfigValidationError) as exc:
        load_config(config_path)

    assert "log_level" in str(exc.value)
