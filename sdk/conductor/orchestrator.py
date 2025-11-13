from __future__ import annotations

from typing import Any, Awaitable, Callable, Dict

from conductor.mcp import MCPServer
from conductor.message import MessageRouter
from conductor.reporter import EventReporter
from conductor.session import SessionManager
from conductor.ws import ConductorWebSocketClient


class SDKOrchestrator:
    """Coordinates ws client, router, sessions, MCP server, and reporter."""

    def __init__(
        self,
        *,
        ws_client: ConductorWebSocketClient,
        message_router: MessageRouter,
        session_manager: SessionManager,
        mcp_server: MCPServer,
        reporter: EventReporter,
    ) -> None:
        self._ws_client = ws_client
        self._router = message_router
        self._sessions = session_manager
        self._mcp_server = mcp_server
        self._reporter = reporter
        self._ws_client.register_handler(self._handle_backend_event)

    async def start(self) -> None:
        await self._ws_client.connect()

    async def stop(self) -> None:
        await self._ws_client.disconnect()

    async def _handle_backend_event(self, payload: Dict[str, Any]) -> None:
        await self._router.handle_backend_event(payload)
