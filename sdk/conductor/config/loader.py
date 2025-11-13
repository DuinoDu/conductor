"""Load Conductor SDK configuration from disk and environment variables."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Mapping, MutableMapping

import yaml
from pydantic import ValidationError

from .errors import ConfigFileNotFound, ConfigValidationError
from .models import ConductorConfig

CONFIG_ENV_VAR = "CONDUCTOR_CONFIG"
AGENT_TOKEN_ENV_VAR = "CONDUCTOR_AGENT_TOKEN"
BACKEND_URL_ENV_VAR = "CONDUCTOR_BACKEND_URL"
WS_URL_ENV_VAR = "CONDUCTOR_WS_URL"
LOG_LEVEL_ENV_VAR = "CONDUCTOR_LOG_LEVEL"

DEFAULT_CONFIG_PATH = Path.home() / ".conductor" / "config.yaml"


def load_config(
    path: str | Path | None = None,
    *,
    env: Mapping[str, str] | None = None,
) -> ConductorConfig:
    """
    Load, parse, and validate the Conductor SDK configuration.

    Parameters
    ----------
    path:
        Optional explicit path to the config file. When omitted, the loader
        checks ``$CONDUCTOR_CONFIG`` before falling back to the default
        ``~/.conductor/config.yaml`` location.
    env:
        Mapping of environment variables. Defaults to ``os.environ`` which
        allows this function to be easily unit tested by passing a custom
        dictionary.

    Returns
    -------
    ConductorConfig
        The validated configuration model.
    """

    env_map = os.environ if env is None else env
    config_path = _resolve_config_path(path, env_map)
    raw_data = _read_yaml(config_path)
    merged_data = _apply_env_overrides(raw_data, env_map)

    try:
        return ConductorConfig.model_validate(merged_data)
    except ValidationError as exc:  # pragma: no cover - exercised via tests
        raise ConfigValidationError(_format_validation_errors(exc)) from exc


def _resolve_config_path(path: str | Path | None, env: Mapping[str, str]) -> Path:
    if path:
        return _normalise_path(path)

    env_path = env.get(CONFIG_ENV_VAR)
    if env_path:
        return _normalise_path(env_path)

    return _normalise_path(DEFAULT_CONFIG_PATH)


def _normalise_path(value: str | Path) -> Path:
    expanded = Path(value).expanduser()
    try:
        return expanded.resolve()
    except FileNotFoundError:
        return expanded.resolve(strict=False)


def _read_yaml(path: Path) -> MutableMapping[str, Any]:
    if not path.exists():
        raise ConfigFileNotFound(path)

    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}

    if not isinstance(data, MutableMapping):
        raise ConfigValidationError([f"Expected mapping at root of {path}"])

    return data


def _apply_env_overrides(
    data: MutableMapping[str, Any],
    env: Mapping[str, str],
) -> MutableMapping[str, Any]:
    merged: MutableMapping[str, Any] = dict(data)

    overrides = {
        "agent_token": env.get(AGENT_TOKEN_ENV_VAR),
        "backend_url": env.get(BACKEND_URL_ENV_VAR),
        "websocket_url": env.get(WS_URL_ENV_VAR),
        "log_level": env.get(LOG_LEVEL_ENV_VAR),
    }

    for key, value in overrides.items():
        if value:
            merged[key] = value

    return merged


def _format_validation_errors(exc: ValidationError) -> list[str]:
    formatted = []
    for error in exc.errors():
        loc = ".".join(str(part) for part in error.get("loc", ()))
        msg = error.get("msg", "Invalid value")
        formatted.append(f"{loc}: {msg}" if loc else msg)
    return formatted


__all__ = ["load_config", "ConductorConfig"]
