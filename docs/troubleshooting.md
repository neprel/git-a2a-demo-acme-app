# Demo troubleshooting

## The library checkout is missing

Place `git-a2a-demo-acme-lib` next to this repository. Compose mounts it read-only only into the
setup service. The app-agent service never receives that mount.

## A loopback port is already in use

The demo exposes `127.0.0.1:18080` and `127.0.0.1:18081` for local inspection. Stop the process
using the port, then run `./demo/clean.sh` before retrying. Nothing needs public ingress.

## A previous run was interrupted

Run `./demo/clean.sh`, then `./demo/run.sh`. Cleanup is scoped to this Compose project and removes
its containers, network, and named volumes. It does not delete host source files or global Docker
data.

## The first build cannot download a toolchain

The Docker build needs outbound HTTPS for its pinned Python base image, Node, Go, CMake, uv, and
the git-a2a v2.0.0 release archive. It verifies the downloaded archives by SHA-256. Retry after the
registry or upstream is reachable; do not bypass checksum failures.

## Git reports a certificate error

Each run creates a one-day self-signed certificate inside a demo-owned volume for the local
smart-HTTPS fixture. Containers receive only that certificate as their Git CA file; the private key
stays with the fixture server. Cleanup and retry so setup can create a fresh pair. Do not disable
TLS verification.

## The owner change times out

The change request runs npm, Python, Go, and CMake tests before it replies, so the full runner gives
that request five minutes. A timeout is a failed proof: inspect `demo/evidence/<run>/e2e.log` and
the lib-agent Compose log, then retry from clean volumes. Do not advance the ref or edit a lock by
hand.

## Inspecting evidence

Each profile writes a `summary.json`, `versions.txt`, before/after output, A2A responses, and list
snapshots below `demo/evidence/`. These raw files are regenerated and ignored. A successful run
must end with both the owner/Pull marker and the stopped-endpoint marker; a summary alone is not
sufficient.
