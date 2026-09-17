"""Strict deterministic app-owner status endpoint over A2A 1.0 JSON-RPC."""

from __future__ import annotations

import json
import os
from contextlib import asynccontextmanager
from pathlib import Path

import uvicorn
from a2a.helpers import get_message_text, new_text_message
from starlette.applications import Starlette

from a2a.server.agent_execution import AgentExecutor, RequestContext
from a2a.server.events import EventQueue
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.routes import (
    create_agent_card_routes,
    create_jsonrpc_routes,
)
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import AgentCard
from google.protobuf.json_format import ParseDict


STATUS = {"action": "status"}


def _json_response(payload: dict[str, object]) -> str:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"))


class AppExecutor(AgentExecutor):
    """Accept only the declared status request and expose no command facility."""

    async def handle_text(self, text: str) -> str:
        try:
            request = json.loads(text)
        except json.JSONDecodeError:
            return _json_response(
                {"status": "rejected", "error": "request must be strict JSON text"}
            )
        if request == STATUS:
            return _json_response(
                {"status": "ok", "action": "status", "component": "consumer-app"}
            )
        return _json_response(
            {
                "status": "unsupported",
                "error": "unsupported action",
                "supportedActions": ["status"],
            }
        )

    async def execute(self, context: RequestContext, queue: EventQueue) -> None:
        response = await self.handle_text(get_message_text(context.message))
        await queue.enqueue_event(
            new_text_message(
                response,
                context_id=context.context_id,
                task_id=context.task_id,
            )
        )

    async def cancel(self, context: RequestContext, queue: EventQueue) -> None:
        raise NotImplementedError("the deterministic app owner has no cancellable tasks")


def load_card(worktree: Path) -> AgentCard:
    data = json.loads((worktree / "agent-card.json").read_text())
    return ParseDict(data, AgentCard())


def create_app(worktree: Path | None = None) -> Starlette:
    root = (worktree or Path(os.environ.get("ACME_APP_WORKTREE", "."))).resolve()
    card = load_card(root)
    handler = DefaultRequestHandler(AppExecutor(), InMemoryTaskStore(), card)

    @asynccontextmanager
    async def lifespan(_app: Starlette):
        yield
        await handler.aclose()

    routes = create_agent_card_routes(card)
    routes.extend(create_jsonrpc_routes(handler, rpc_url="/a2a/jsonrpc"))
    return Starlette(routes=routes, lifespan=lifespan)


if __name__ == "__main__":
    uvicorn.run(create_app(), host="0.0.0.0", port=int(os.getenv("APP_AGENT_PORT", "8001")))
