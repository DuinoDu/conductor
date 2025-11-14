from __future__ import annotations

import argparse
import asyncio
import contextlib
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
    parser.add_argument(
        "--chat",
        action="store_true",
        help="Enter interactive chat mode after ensuring a task session",
    )
    parser.add_argument("--task-title", default=None, help="Title for new tasks (default env TASK_TITLE)")
    parser.add_argument("--prefill", default=None, help="Optional initial user prompt for new tasks")
    parser.add_argument("--task-id", default=None, help="Use an existing task id (requires --project-id)")
    parser.add_argument("--project-id", default=None, help="Override the project id to target")
    parser.add_argument(
        "--poll-interval",
        type=float,
        default=1.0,
        help="Polling interval (seconds) for incoming messages in chat mode",
    )
    return parser.parse_args()
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


@dataclass
class RuntimeContext:
    orchestrator: SDKOrchestrator
    mcp_server: MCPServer
    sessions: SessionManager


async def main(args: argparse.Namespace) -> None:
    # Ensure local connections bypass proxies so requests hit localhost.
    os.environ.setdefault("NO_PROXY", "127.0.0.1,localhost")
    os.environ.setdefault("no_proxy", "127.0.0.1,localhost")

    config = load_config()
    backend_api = BackendApiClient(config)

    if args.command in ("list-project", "list-projects"):
        await _list_projects(backend_api)
        return

    if args.task_id and not args.project_id:
        raise SystemExit("--project-id must be provided when reusing --task-id")

    runtime = await _build_runtime(config, backend_api)
    project = await _resolve_target_project(backend_api, args.project_id, os.environ)
    print(f"Using project {project.name} ({project.id})")

    print("DEBUG: orchestrator.start()")
    await runtime.orchestrator.start()
    try:
        if args.chat:
            await _run_chat_mode(
                runtime,
                project=project,
                task_title=_resolve_task_title(args),
                prefill=_resolve_prefill(args),
                existing_task_id=args.task_id,
                poll_interval=max(args.poll_interval, 0.2),
            )
        else:
            await _run_create_task_flow(
                runtime,
                project=project,
                task_title=_resolve_task_title(args),
                prefill=_resolve_prefill(args),
            )
    finally:
        await runtime.orchestrator.stop()


def _resolve_task_title(args: argparse.Namespace) -> str:
    return args.task_title or os.environ.get("TASK_TITLE", "SDK Demo Task")


def _resolve_prefill(args: argparse.Namespace) -> str:
    return args.prefill or os.environ.get("TASK_PREFILL", DEFAULT_PREFILL)


async def _build_runtime(config, backend_api: BackendApiClient) -> RuntimeContext:
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
    return RuntimeContext(
        orchestrator=orchestrator,
        mcp_server=mcp_server,
        sessions=sessions,
    )


async def _resolve_target_project(
    backend_api: BackendApiClient,
    override: str | None,
    env: Mapping[str, str],
) -> ProjectInfo:
    if override:
        return ProjectInfo(id=override, name=override)
    return await _resolve_project_id(backend_api, env)


async def _run_create_task_flow(
    runtime: RuntimeContext,
    *,
    project: ProjectInfo,
    task_title: str,
    prefill: str,
) -> None:
    print("DEBUG: mcp_server.handle_request")
    task_result = await runtime.mcp_server.handle_request(
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
    await _listen_for_messages(runtime.mcp_server, task_result["task_id"], duration=listen_seconds)


async def _run_chat_mode(
    runtime: RuntimeContext,
    *,
    project: ProjectInfo,
    task_title: str,
    prefill: str,
    existing_task_id: str | None,
    poll_interval: float,
) -> None:
    if existing_task_id:
        task_id = existing_task_id
        await runtime.sessions.add_session(task_id, task_id, project.id)
        print(f"Attached to existing task {task_id}")
    else:
        result = await runtime.mcp_server.handle_request(
            "create_task_session",
            {
                "project_id": project.id,
                "task_title": task_title,
                "prefill": prefill,
            },
        )
        task_id = result["task_id"]
        print("Created new task session:")
        print(json.dumps(result, indent=2))

    print("\nInteractive chat mode. Type ':q' or 'exit' to quit.\n")
    await _chat_loop(runtime.mcp_server, task_id, poll_interval=poll_interval)


async def _listen_for_messages(mcp_server: MCPServer, task_id: str, *, duration: float) -> None:
    """Continuously fetch and ack new messages for a limited amount of time."""

    print(f"Listening for replies for up to {duration:.1f}s...")
    loop = asyncio.get_running_loop()
    deadline = loop.time() + max(duration, 0.0)
    while loop.time() < deadline:
        await _drain_messages(mcp_server, task_id)
        await asyncio.sleep(0.5)


async def _drain_messages(mcp_server: MCPServer, task_id: str) -> bool:
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
            created = message.get("created_at")
            prefix = f"[{role} @ {created}] " if created else f"[{role}] "
            print(f"{prefix}{message_id}: {content}")

        ack_token = response.get("next_ack_token")
        if ack_token:
            await mcp_server.handle_request(
                "ack_messages",
                {
                    "task_id": task_id,
                    "ack_token": ack_token,
                },
            )
        return True
    return False


async def _chat_loop(mcp_server: MCPServer, task_id: str, *, poll_interval: float) -> None:
    stop_event = asyncio.Event()

    async def poller():
        while not stop_event.is_set():
            await _drain_messages(mcp_server, task_id)
            await asyncio.sleep(poll_interval)

    poll_task = asyncio.create_task(poller(), name="sdk-chat-poller")
    try:
        while True:
            try:
                text = await _async_input("you> ")
            except (KeyboardInterrupt, EOFError):
                print("\nExiting chat.")
                break
            normalized = text.strip()
            if not normalized:
                continue
            if normalized.lower() in {"exit", "quit", ":q"}:
                break
            await mcp_server.handle_request(
                "send_message",
                {"task_id": task_id, "content": text},
            )
    finally:
        stop_event.set()
        poll_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await poll_task
        await _drain_messages(mcp_server, task_id)


async def _async_input(prompt: str) -> str:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, lambda: input(prompt))


if __name__ == "__main__":
    CLI_ARGS = _parse_args()
    asyncio.run(main(CLI_ARGS))
