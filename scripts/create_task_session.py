from __future__ import annotations

import asyncio
import json
import os
from dataclasses import dataclass
from typing import Any, Mapping
from urllib import request

import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent
SDK_PACKAGE = REPO_ROOT / "../sdk"
if SDK_PACKAGE.exists() and str(SDK_PACKAGE) not in sys.path:
    # Allow running `python test_conduct.py` without exporting PYTHONPATH.
    sys.path.insert(0, str(SDK_PACKAGE))

from conductor.config import load_config
from conductor.message import MessageRouter
from conductor.mcp import MCPServer
from conductor.orchestrator import SDKOrchestrator
from conductor.reporter import EventReporter
from conductor.session import SessionManager
from conductor.ws import ConductorWebSocketClient

DEFAULT_PREFILL = "Hahahahahaha"
DEFAULT_LISTEN_SECONDS = 15.0


@dataclass
class ProjectInfo:
    id: str
    name: str


def _fetch_projects(base_url: str) -> list[ProjectInfo]:
    url = f"{base_url.rstrip('/')}/projects"
    req = request.Request(url)
    req.add_header("Accept", "application/json")
    with request.urlopen(req) as resp:  # type: ignore[arg-type]
        payload = json.load(resp)
    projects: list[ProjectInfo] = []
    for entry in payload:
        proj_id = entry.get("id")
        if isinstance(proj_id, str):
            projects.append(ProjectInfo(id=proj_id, name=entry.get("name", proj_id)))
    return projects


def _resolve_project_id(base_url: str, env: Mapping[str, str]) -> ProjectInfo:
    explicit = env.get("PROJECT_ID")
    if explicit:
        return ProjectInfo(id=explicit, name=explicit)
    projects = _fetch_projects(base_url)
    if not projects:
        raise RuntimeError(
            "No projects found on the backend. POST /projects before running this script.",
        )
    return projects[0]


async def main() -> None:
    # Ensure local connections bypass proxies so requests hit localhost.
    os.environ.setdefault("NO_PROXY", "127.0.0.1,localhost")
    os.environ.setdefault("no_proxy", "127.0.0.1,localhost")

    config = load_config()
    project = _resolve_project_id(str(config.backend_url), os.environ)
    print(f"Using project {project.name} ({project.id})")

    sessions = SessionManager()
    router = MessageRouter(sessions)
    ws_client = ConductorWebSocketClient(config)

    async def backend_sender(envelope: Mapping[str, Any]) -> None:
        await ws_client.send_json(dict(envelope))

    reporter = EventReporter(backend_sender)
    mcp_server = MCPServer(
        config,
        session_manager=sessions,
        message_router=router,
        backend_sender=backend_sender,
    )
    orchestrator = SDKOrchestrator(
        ws_client=ws_client,
        message_router=router,
        session_manager=sessions,
        mcp_server=mcp_server,
        reporter=reporter,
    )
    
    print("DEBUG: orchestrator.start()")
    await orchestrator.start()
    try:
        task_title = os.environ.get("TASK_TITLE", "SDK Demo Task")
        prefill = os.environ.get("TASK_PREFILL", DEFAULT_PREFILL)

        print("DEBUG: mcp_server.handle_request")
        task_result = await mcp_server.handle_request(
            "create_task_session",
            {
                "project_id": project.id,
                "task_title": task_title,
                "prefill": prefill,
            },
        )
        print("create_task_session result:")
        print(json.dumps(task_result, indent=2))

        listen_seconds = float(os.environ.get("TASK_LISTEN_SECONDS", DEFAULT_LISTEN_SECONDS))
        await _listen_for_messages(
            mcp_server,
            task_result["task_id"],
            duration=listen_seconds,
        )
    finally:
        await orchestrator.stop()


async def _listen_for_messages(mcp_server: MCPServer, task_id: str, *, duration: float) -> None:
    """Continuously fetch and ack new messages for a limited amount of time."""

    print(f"Listening for replies for up to {duration:.1f}s...")
    loop = asyncio.get_running_loop()
    deadline = loop.time() + max(duration, 0.0)
    while loop.time() < deadline:
        response = await mcp_server.handle_request(
            "receive_messages",
            {"task_id": task_id},
        )
        messages = response.get("messages", [])
        if messages:
            for message in messages:
                role = message.get("role", "unknown")
                content = message.get("content", "")
                message_id = message.get("message_id", "unknown")
                print(f"[{role}] {message_id}: {content}")

            ack_token = response.get("next_ack_token")
            if ack_token:
                await mcp_server.handle_request(
                    "ack_messages",
                    {
                        "task_id": task_id,
                        "ack_token": ack_token,
                    },
                )

        await asyncio.sleep(0.5)


if __name__ == "__main__":
    asyncio.run(main())
