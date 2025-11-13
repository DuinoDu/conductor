"""
Conductor SDK package.

Only the config module is currently implemented according to the technical
plan. Additional modules (ws_client, project_context, etc.) will be layered
on top of this package in subsequent iterations.
"""

from .config.loader import ConductorConfig, load_config

__all__ = ["ConductorConfig", "load_config"]
