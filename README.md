# git-a2a: component change, owner response, installed result

This is the consumer half of a reproducible two-repository git-a2a 2.0 demo. It shows the part
that a manifest-only example cannot: a component is installed, its responsible agent is discovered
from dependency metadata, the owner changes and tests the component over real A2A transport, and
the consumer receives that exact Git revision only through `git-a2a pull`.

```text
app agent -> git-a2a list -> pinned card + surface -> A2A JSON-RPC -> lib owner
                                                                  -> tested Git commit
app code  <- npm / uv / Go / CMake <- git-a2a pull <---------------+
```

The story is deliberately small. `formatDisplayName("   ")` initially returns `""`. The app asks
the library owner for a backward-compatible optional fallback. Before Pull, installed code still
has the old behavior; after Pull, all four integrations return `"Anonymous"`. The package version
stays `1.1.0`, while the locked Git commit changes.

## Run it

Requirements are Docker Engine or Docker Desktop with Compose v2, Git, and the companion
[`git-a2a-demo-acme-lib`](https://github.com/neprel/git-a2a-demo-acme-lib) checkout next to this
one:

```text
parent/
  git-a2a-demo-acme-app/
  git-a2a-demo-acme-lib/
```

The library checkout must be clean and at the commit recorded in
[`demo/lib-source.sha`](demo/lib-source.sha). The runner also requires this app checkout to be
clean, records both real source SHAs, and refuses to build a synthetic baseline from uncommitted
files. To deliberately test two compatible current heads instead of the frozen pilot, use
`DEMO_LIB_SHA=$(git -C ../git-a2a-demo-acme-lib rev-parse HEAD) ./demo/run.sh`; this explicit
override is not used by CI.

From this repository run:

```sh
./demo/run.sh
```

For the shorter npm-only walkthrough, use:

```sh
DEMO_PROFILE=npm ./demo/run.sh
```

The first run downloads checksum-pinned toolchains and the published `git-a2a 2.0.0` release.
The gate then runs twice with newly created Docker volumes. A successful run ends with:

```text
PASS: owner A2A request, commit, Pull, and npm/uv/Go/CMake assertions
PASS: list remained offline; A2A transport failed while endpoint was stopped
PASS: 2 clean-volume run(s)
```

Evidence for each attempt is written below `demo/evidence/run-1/` and `run-2/`. It includes tool
versions, baseline/final discovery output, actual A2A responses, before/after consumer output,
negative-case results, and the two library commit IDs. Remove only demo-owned containers and
volumes with:

```sh
./demo/clean.sh
```

See the checked-in [verified transcript](docs/demo-transcript.md) for reviewed output and
[troubleshooting](docs/troubleshooting.md) for failure recovery.

Neither command mutates either host checkout or pushes to GitHub. The demo binds its two optional
host ports to loopback and mounts no credentials, home directory, or Docker socket.

## What the runner proves

The npm profile performs `add`, imports the baseline package, discovers the owner, sends the change
request, performs `pull`, and imports the changed package. The default extended profile saves the
same upstream commit through:

- npm as `@acme/lib-utils`;
- uv as `acme-lib-utils`;
- Go as `github.com/neprel/git-a2a-demo-acme-lib`;
- a normal Git submodule plus CMake target `acme_lib_utils`.

The automated gate also covers a fresh consumer clone, deleted-materialization repair at the same
commit, targeted Pull with an independent fixture dependency, idempotent Pull, Remove while
preserving an unrelated package, manager-failure rollback, an unsafe card path, an absent optional
surface, offline `list`, an unavailable endpoint, and dirty-submodule preservation. Destructive
cases use disposable consumers and local bare remotes.

Read [`demo/run-e2e.sh`](demo/run-e2e.sh) for the main proof and
[`demo/negative-cases.sh`](demo/negative-cases.sh) for failure cases. The app container has the app
workspace plus materialized dependency data; it does not mount the owner's library worktree.

## The protocol boundary

git-a2a has exactly five commands: `init`, `add`, `pull`, `remove`, and `list`. It resolves Git
revisions, invokes native dependency managers, and materializes the declared Agent Card and
optional surface. It does not send A2A messages.

The demo's separate [`demo/a2a_client.py`](demo/a2a_client.py) reads the card path returned by
`git-a2a list`, parses that card with the official Python SDK, and sends A2A 1.0 JSON-RPC. The owner
accepts only two fixed JSON actions; it cannot execute caller-provided commands. See the
[A2A 1.0 specification](https://a2a-protocol.org/v1.0.0/specification/) and the
[official Python SDK 1.1.2](https://github.com/a2aproject/a2a-python/releases/tag/v1.1.2).

Both agents are deterministic test automation, not LLMs. No model key or paid service is required.
The endpoints (`lib-agent:8000` and `app-agent:8001`) exist only inside the Compose network; the
loopback ports are for local inspection and are not public services. The verified execution
environment is Linux in Docker, not a claim of native coverage on every operating system.

## Manual map of the successful path

The runner executes these operations in disposable workspaces:

```sh
git-a2a add https://github.com/neprel/git-a2a-demo-acme-lib.git \
  --name acme-lib-utils --ref demo/fallback
git-a2a list acme-lib-utils --json
python /demo/a2a_client.py <card-from-list> describe-contract
python /demo/a2a_client.py <card-from-list> request-fallback
git-a2a pull acme-lib-utils
git-a2a remove acme-lib-utils
```

The two Python lines are external A2A client calls, not hidden git-a2a commands. Inside this demo
network, `github.com` is deliberately aliased to a credential-free, read-only smart-HTTPS server;
the generated one-run certificate is trusted only by the containers. Outside the demo, the same
URL addresses the public repository normally.

For the published component contract and controlled owner implementation, continue with the
[library README](https://github.com/neprel/git-a2a-demo-acme-lib#readme).
