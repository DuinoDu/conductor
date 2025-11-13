from __future__ import annotations

from typing import Any, Awaitable, Callable, Dict, List
from uuid import uuid4

from conductor.config import ConductorConfig
from conductor.message import MessageRouter
from conductor.session import SessionManager


ToolFunc = Callable[[Dict[str, Any]], Awaitable[Dict[str, Any]]]


class MCPServer:
    """
    Lightweight MCP server facade that exposes SDK tools to external AI agents.
    """

    def __init__(
        self,
        config: ConductorConfig,
        *,
        session_manager: SessionManager,
        message_router: MessageRouter,
        backend_sender: Callable[[Dict[str, Any]], Awaitable[None]],
    ) -> None:
        self._config = config
        self._sessions = session_manager
        self._router = message_router
        self._backend_sender = backend_sender
        self._tools: Dict[str, ToolFunc] = {}
        self._register_tools()

    def _register_tools(self) -> None:
        self._tools = {
            "create_task_session": self._tool_create_task_session,
            "send_message": self._tool_send_message,
            "receive_messages": self._tool_receive_messages,
            "ack_messages": self._tool_ack_messages,
        }

    async def handle_request(self, tool_name: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        tool = self._tools.get(tool_name)
        if not tool:
            raise ValueError(f"Unknown tool: {tool_name}")
        return await tool(payload)

    async def _tool_create_task_session(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        project_id = payload["project_id"]
        title = payload.get("task_title", "Untitled")
        task_id = payload.get("task_id") or str(uuid4())
        session_id = payload.get("session_id") or task_id

        await self._sessions.add_session(task_id, session_id, project_id)

        await self._backend_sender(
            {
                "type": "create_task",
                "payload": {
                    "task_id": task_id,
                    "project_id": project_id,
                    "title": title,
                    "prefill": payload.get("prefill"),
                },
            }
        )

        return {
            "task_id": task_id,
            "session_id": session_id,
            "app_url": payload.get("app_url"),
        }

    async def _tool_send_message(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        task_id = payload["task_id"]
        await self._backend_sender(
            {
                "type": "sdk_message",
                "payload": {
                    "task_id": task_id,
                    "content": payload["content"],
                    "metadata": payload.get("metadata"),
                },
            }
        )
        return {"delivered": True}

    async def _tool_receive_messages(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        task_id = payload["task_id"]
        limit = payload.get("limit", 20)
        messages = await self._sessions.pop_messages(task_id, limit=limit)
        return {
            "messages": [
                {
                    "message_id": msg.message_id,
                    "role": msg.role,
                    "content": msg.content,
                    "ack_token": msg.ack_token,
                    "created_at": msg.created_at.isoformat(),
                }
                for msg in messages
            ],
            "next_ack_token": messages[-1].ack_token if messages else None,
            "has_more": False,
        }

    async def _tool_ack_messages(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        success = await self._sessions.ack(payload["task_id"], payload["ack_token"])
        return {"status": "ok" if success else "ignored"}
