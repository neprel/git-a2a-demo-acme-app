"""Pin the A2A client imports used by the demo to the installed SDK API."""

import asyncio
import json
import os
import unittest
from pathlib import Path

from a2a.types import AgentCard, StreamResponse
from google.protobuf.json_format import MessageToDict, ParseDict
from starlette.testclient import TestClient

import a2a_client
from app_agent import AppExecutor, STATUS, create_app, load_card


ROOT = Path(os.environ.get("ACME_APP_WORKTREE", "/workspace/app"))
if not (ROOT / "agent-card.json").is_file():
    ROOT = Path(__file__).parents[1]


class ClientCompatibilityTest(unittest.TestCase):
    def test_repository_card_is_valid_a2a_1_0(self) -> None:
        source = json.loads((ROOT / "agent-card.json").read_text())
        card = load_card(ROOT)
        self.assertIsInstance(card, AgentCard)
        self.assertEqual(card.supported_interfaces[0].protocol_version, "1.0")
        self.assertEqual(card.supported_interfaces[0].protocol_binding, "JSONRPC")
        self.assertEqual(
            card.supported_interfaces[0].url,
            "http://app-agent:8001/a2a/jsonrpc",
        )
        self.assertEqual(card.skills[0].id, "status")
        ParseDict(source, AgentCard())

    def test_served_card_is_the_checked_in_card(self) -> None:
        source = json.loads((ROOT / "agent-card.json").read_text())
        with TestClient(create_app(ROOT)) as client:
            response = client.get("/.well-known/agent-card.json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), source)
        self.assertEqual(
            MessageToDict(load_card(ROOT), preserving_proto_field_name=False), source
        )

    def test_status_requires_the_exact_declared_request(self) -> None:
        response = json.loads(
            asyncio.run(AppExecutor().handle_text(json.dumps(STATUS)))
        )
        self.assertEqual(
            response,
            {"action": "status", "component": "consumer-app", "status": "ok"},
        )

    def test_unknown_and_non_json_requests_are_rejected(self) -> None:
        executor = AppExecutor()
        unsupported = json.loads(
            asyncio.run(
                executor.handle_text(
                    '{"action":"status","command":"touch /tmp/pwned"}'
                )
            )
        )
        invalid = json.loads(asyncio.run(executor.handle_text("not json")))
        self.assertEqual(unsupported["status"], "unsupported")
        self.assertNotIn("command", unsupported)
        self.assertEqual(unsupported["supportedActions"], ["status"])
        self.assertEqual(
            invalid,
            {"status": "rejected", "error": "request must be strict JSON text"},
        )

    def test_empty_stream_response_has_no_text(self) -> None:
        self.assertEqual(a2a_client.get_stream_response_text(StreamResponse()), "")

    def test_missing_card_is_reported(self) -> None:
        with self.assertRaises(FileNotFoundError):
            a2a_client.load_card(Path("/does/not/exist/agent-card.json"))

    def test_failure_is_concise(self) -> None:
        self.assertEqual(
            a2a_client.format_failure(TimeoutError("endpoint stopped")),
            "A2A request failed: endpoint stopped",
        )


if __name__ == "__main__":
    unittest.main()
