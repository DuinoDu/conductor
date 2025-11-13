"""Custom exceptions raised by the Conductor SDK config loader."""

from __future__ import annotations

from pathlib import Path
from typing import Sequence


class ConfigError(Exception):
    """Base exception for configuration related errors."""


class ConfigFileNotFound(ConfigError):
    """Raised when the config file cannot be located."""

    def __init__(self, path: Path) -> None:
        self.path = path
        super().__init__(f"Conductor config file not found at {path}")


class ConfigValidationError(ConfigError):
    """Raised when the config file contents are invalid."""

    def __init__(self, errors: Sequence[str]) -> None:
        message = "Invalid Conductor configuration:\n- " + "\n- ".join(errors)
        super().__init__(message)
        self.errors = list(errors)
