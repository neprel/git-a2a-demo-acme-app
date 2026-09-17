"""Read-only smart-HTTP Git plus one fixed fixture control for the demo."""

import json
import os
import ssl
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path("/workspace/remotes")
BACKEND = "/usr/lib/git-core/git-http-backend"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/healthz":
            self.send_response(200)
            self.send_header("Content-Length", "3")
            self.end_headers()
            self.wfile.write(b"ok\n")
            return
        self._git()

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/__demo__/advance-fixture-stable":
            self._advance_fixture_stable()
            return
        self._git()

    def _advance_fixture_stable(self) -> None:
        repo = ROOT / "neprel" / "fixture-stable.git"
        try:
            before = subprocess.check_output(
                ["git", "--git-dir", str(repo), "rev-parse", "refs/heads/demo"],
                text=True,
            ).strip()
            after = subprocess.check_output(
                ["git", "--git-dir", str(repo), "rev-parse", "refs/heads/demo-next"],
                text=True,
            ).strip()
            if before != after:
                subprocess.run(
                    ["git", "--git-dir", str(repo), "update-ref", "refs/heads/demo", after, before],
                    check=True,
                )
            body = json.dumps({"before": before, "after": after}).encode() + b"\n"
        except subprocess.CalledProcessError as error:
            self.send_error(500, str(error))
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _git(self) -> None:
        parsed = urlsplit(self.path)
        length = int(self.headers.get("Content-Length", "0"))
        env = os.environ.copy()
        env.update({
            "GIT_PROJECT_ROOT": str(ROOT), "GIT_HTTP_EXPORT_ALL": "1",
            "PATH_INFO": parsed.path, "QUERY_STRING": parsed.query,
            "REQUEST_METHOD": self.command,
            "CONTENT_TYPE": self.headers.get("Content-Type", ""),
            "CONTENT_LENGTH": str(length), "REMOTE_ADDR": self.client_address[0],
            "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "safe.directory",
            "GIT_CONFIG_VALUE_0": "*",
        })
        result = subprocess.run(
            [BACKEND], input=self.rfile.read(length) if length else b"",
            env=env, capture_output=True, check=False,
        )
        headers, separator, response = result.stdout.partition(b"\r\n\r\n")
        if not separator:
            self.send_error(500, result.stderr.decode(errors="replace"))
            return
        status = 200
        outgoing = []
        for line in headers.decode("latin1").split("\r\n"):
            name, value = line.split(":", 1)
            if name.lower() == "status":
                status = int(value.strip().split()[0])
            elif name.lower() not in {"content-length", "connection"}:
                outgoing.append((name, value.strip()))
        self.send_response(status)
        for name, value in outgoing:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(response)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(response)
        self.wfile.flush()
        self.close_connection = True

    def log_message(self, message: str, *args: object) -> None:
        print(f"git-https: {message % args}", flush=True)


server = ThreadingHTTPServer(("0.0.0.0", 443), Handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain("/tls/public/cert.pem", "/tls/private/key.pem")
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
