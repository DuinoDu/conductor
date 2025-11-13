import asyncio

from fastmcp import FastMCP

from conductor.config import load_config
from conductor.message import MessageRouter
from conductor.mcp import MCPServer
from conductor.orchestrator import SDKOrchestrator
from conductor.reporter import EventReporter
from conductor.session import SessionManager
from conductor.ws import ConductorWebSocketClient


async def main() -> None:
    config = load_config()
    sessions = SessionManager()
    router = MessageRouter(sessions)
    ws_client = ConductorWebSocketClient(config)

    async def backend_sender(envelope):
        await ws_client.send_json(envelope)

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

    app = FastMCP(name="conductor-sdk", instructions="Bridge external AI with Conductor App")

    @app.tool()
    async def create_task_session(project_id: str, task_title: str = "Untitled", prefill: str | None = None):
        return await mcp_server.handle_request(
            "create_task_session",
            {"project_id": project_id, "task_title": task_title, "prefill": prefill},
        )

    @app.tool()
    async def send_message(task_id: str, content: str):
        return await mcp_server.handle_request("send_message", {"task_id": task_id, "content": content})

    @app.tool()
    async def receive_messages(task_id: str, limit: int = 20):
        return await mcp_server.handle_request("receive_messages", {"task_id": task_id, "limit": limit})

    @app.tool()
    async def ack_messages(task_id: str, ack_token: str):
        return await mcp_server.handle_request("ack_messages", {"task_id": task_id, "ack_token": ack_token})

    await orchestrator.start()
    try:
        await app.run_async()
    finally:
        await orchestrator.stop()


if __name__ == "__main__":
    asyncio.run(main())
