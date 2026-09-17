"""Send a real A2A 1.0 JSON-RPC request using a list-derived Agent Card."""

import argparse
import asyncio
import json
import sys
import uuid
from pathlib import Path

import httpx
from google.protobuf import json_format

from a2a.client import ClientConfig, ClientFactory
from a2a.helpers.proto_helpers import get_stream_response_text
from a2a.types import AgentCard, Message, Part, Role, SendMessageRequest


def load_card(path: Path) -> AgentCard:
    card = AgentCard()
    json_format.Parse(path.read_text(), card)
    return card


def format_failure(error: Exception) -> str:
    detail = str(error).strip() or error.__class__.__name__
    return f"A2A request failed: {detail}"


async def send(card_path: Path, payload: dict, timeout: float) -> dict:
    card = load_card(card_path)
    async with httpx.AsyncClient(timeout=timeout) as http:
        factory = ClientFactory(
            ClientConfig(
                streaming=False,
                httpx_client=http,
                supported_protocol_bindings=["JSONRPC"],
            )
        )
        client = factory.create(card)
        message = Message(
            role=Role.ROLE_USER,
            message_id=str(uuid.uuid4()),
            parts=[Part(text=json.dumps(payload, sort_keys=True))],
        )
        responses = [
            item
            async for item in client.send_message(
                SendMessageRequest(message=message)
            )
        ]
        await client.close()
    texts = [text for response in responses if (text := get_stream_response_text(response))]
    if not texts:
        raise RuntimeError("A2A response contained no text message or artifact")
    return json.loads(texts[-1])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("card", type=Path)
    parser.add_argument(
        "action",
        choices=["app-status", "describe-contract", "request-fallback", "unsupported"],
    )
    parser.add_argument("--timeout", type=float, default=15)
    args = parser.parse_args()
    requests = {
        "app-status": {"action": "status"},
        "describe-contract": {"action": "describe_blank_behavior"},
        "request-fallback": {
            "action": "request_fallback",
            "fallback": "Anonymous",
            "acceptance": {
                "blank": "Anonymous",
                "whitespace": "Anonymous",
                "name": "Ada Lovelace",
            },
        },
        "unsupported": {
            "action": "run-shell",
            "command": "/bin/touch /workspace/app/.git-a2a/unsupported-ran",
        },
    }
    try:
        response = asyncio.run(send(args.card, requests[args.action], args.timeout))
    except Exception as error:
        print(format_failure(error), file=sys.stderr)
        raise SystemExit(1) from None
    print(json.dumps(response, sort_keys=True))


if __name__ == "__main__":
    main()
