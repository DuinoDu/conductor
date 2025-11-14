from __future__ import annotations

import argparse
import asyncio
import json
import os
from dataclasses import dataclass
from typing import Any, Mapping

import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent
SDK_PACKAGE = REPO_ROOT / "../sdk"
if SDK_PACKAGE.exists() and str(SDK_PACKAGE) not in sys.path:
    # Allow running `python sdk-test.py` without exporting PYTHONPATH.
    sys.path.insert(0, str(SDK_PACKAGE))

from conductor.backend import BackendApiClient
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


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run quick SDK smoke tests")
    parser.add_argument(
        "command",
        nargs="?",
        default="create-task",
        choices=("create-task", "list-project", "list-projects"),
        help="Action to run (default: create-task)",
    )
    return parser.parse_args()


async def _resolve_project_id(api: BackendApiClient, env: Mapping[str, str]) -> ProjectInfo:
    explicit = env.get("PROJECT_ID")
    if explicit:
        return ProjectInfo(id=explicit, name=explicit)
    projects = await api.list_projects()
    if not projects:
        raise RuntimeError(
            "No projects found on the backend. POST /projects before running this script.",
        )
    first = projects[0]
    return ProjectInfo(id=first.id, name=first.name or first.id)


async def _list_projects(api: BackendApiClient) -> None:
    projects = await api.list_projects()
    if not projects:
        print("No projects found.")
        return
    print("Projects available:")
    for project in projects:
        label = project.name or "<unnamed>"
        desc = f" - {project.description}" if project.description else ""
        print(f"- {label} ({project.id}){desc}")


async def main(args: argparse.Namespace) -> None:
    # Ensure local connections bypass proxies so requests hit localhost.
    os.environ.setdefault("NO_PROXY", "127.0.0.1,localhost")
    os.environ.setdefault("no_proxy", "127.0.0.1,localhost")

    config = load_config()
    backend_api = BackendApiClient(config)

    if args.command in ("list-project", "list-projects"):
        await _list_projects(backend_api)
        return

    project = await _resolve_project_id(backend_api, os.environ)
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
        backend_api=backend_api,
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
    CLI_ARGS = _parse_args()
    asyncio.run(main(CLI_ARGS))
