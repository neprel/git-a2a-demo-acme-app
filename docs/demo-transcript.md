# Verified demo transcript

This is a shortened, secret-free transcript from the final local verification on 2026-09-17.
The full profile ran twice after deleting the Compose volumes; the npm profile then ran once in a
third clean environment. Commit IDs below belong to those disposable local repositories and are
expected to differ on another run.

## Fixed runtime

```text
git-a2a 2.0.0 (752eda1db35315592154e7928e61a8f18454d733, linux/arm64, channel=binary)
Node v24.8.0 / npm 11.6.0
Python 3.13.7 / uv 0.8.17 / a2a-sdk 1.1.2
Go 1.25.1
CMake 4.1.1
Git 2.39.5
```

The git-a2a archives were verified against the v2.0.0 release checksums in the Docker build. The
container ran on Linux/arm64; this transcript is not evidence of native execution on other
operating systems or architectures.

```text
git-a2a_2.0.0_linux_amd64.tar.gz  sha256:396de4803687a13486eabefa5acde4af557274e705355d9b470c7e2a997dccfd
git-a2a_2.0.0_linux_arm64.tar.gz  sha256:5ff7a58f2cbb0986f813fd50200432cf0a86ffcd40f75e20a4d62a38c22fb4e7
```

## Full profile, run 1

```text
app source: 908109852e6fe048cfe15bb6be9c53cbd5db9cf4
lib source: e42437fc28e277af0a0726552e3f7ef8972a6c28
app agent: {"action":"status","component":"consumer-app","status":"ok"}

added acme-lib-utils at 073fd8e8c4cafff7e47cd925fbf509812d0b06f0
bindings: submodule/git, cmake/cmake, golang/go, npm/npm, pypi/uv
card: .git-a2a/agents/acme-lib-utils/agent-card.json
surface: .git-a2a/surfaces/acme-lib-utils

npm blank => ''
uv blank => ''
Go blank => ''
CMake blank => ''

describe: supportsFallback=false, blankResult=""
unsupported action: status=unsupported
owner change: commit=a45d347c014ac336051ce8576a5acd491b0f55d8, version=1.1.0

npm blank => ''                 # still baseline before Pull
uv blank => ''
Go blank => ''
CMake blank => ''

acme-lib-utils: pulled a45d347c014ac336051ce8576a5acd491b0f55d8
npm blank+fallback => Anonymous
uv blank+fallback => Anonymous
Go blank+fallback => Anonymous
CMake blank+fallback => Anonymous

PASS: repair emptied the complete Go module/build cache before Pull restored it
PASS: fresh clone populated a separate initially empty Go cache
PASS: manager rollback, bad card, absent surface, remove retention, fallback, dirty preservation
PASS: owner A2A request, commit, Pull, and npm/uv/Go/CMake assertions
PASS: list remained offline; A2A transport failed while endpoint was stopped
```

## Independent clean-volume rerun

```json
{
  "status": "PASS",
  "appSource": "908109852e6fe048cfe15bb6be9c53cbd5db9cf4",
  "libSource": "e42437fc28e277af0a0726552e3f7ef8972a6c28",
  "appBaseline": "6f82c96ba204efbd54b55c567d7f475ab977391b",
  "libBaseline": "c8185b3bd5dc55fa0a74750aab279069ee1a73dd",
  "libFinal": "e9e3b5c787598647b38cdb2e1cc5b77071d8723c",
  "gitA2A": "2.0.0",
  "a2aSDK": "1.1.2",
  "protocol": "A2A 1.0 JSON-RPC"
}
```

The second run repeated setup, add, A2A interaction, owner commit, Pull, all four runtime calls,
repair, fresh clone, idempotency, targeted Pull, Remove, negative cases, and stopped-endpoint
discovery without reusing the first run's volumes.

## Short npm profile

```text
app source: 908109852e6fe048cfe15bb6be9c53cbd5db9cf4
lib source: e42437fc28e277af0a0726552e3f7ef8972a6c28
baseline: d3e2ea9cd4f9b5838b77c4245034426ab82aa5b0
owner final: 3dfef74c3907c8002f85fb3bf925a22e7f034919
binding: npm/npm
acme-lib-utils: pulled 3dfef74c3907c8002f85fb3bf925a22e7f034919
npm blank+fallback => Anonymous
PASS: short npm add, discovery, A2A change, pull, and runtime assertion
A2A request failed: Network communication error: [Errno -2] Name or service not known
PASS: list remained offline; A2A transport failed while endpoint was stopped
```

The final error is intentional: the runner first proves that `git-a2a list` still reads pinned
metadata, then stops the owner endpoint and requires the separate A2A client to fail clearly.

## Acceptance evidence

| Scenario | Evidence in the automated gate |
| --- | --- |
| Published CLI, real native install | Exact v2.0.0 commit/channel check; five listed bindings; four runtime calls |
| Real owner discovery | Card and surface paths are parsed only from `git-a2a list --json` |
| Real A2A transport | describe, unsupported, and change requests use official SDK JSON-RPC |
| Owner-only change | Library service changes its worktree, runs four suites, commits, and pushes the local ref |
| Same version, new revision | Version remains 1.1.0 while baseline and final SHA differ |
| Pull boundary | All four baseline calls repeat after owner commit and before Pull; only Pull changes them |
| Fresh clone and repair | Fresh consumer and deleted native/submodule materialization are restored by Pull |
| Targeting and idempotency | Independent fixture SHA remains unchanged; repeated Pull leaves no tracked diff |
| Remove and unrelated data | Managed entry, lock, and materialization disappear; unrelated npm package still runs |
| Failure safety | Missing manager rolls back; unsafe card fails; absent surface is not invented |
| Submodule safety | Native-incompatible export falls back to submodule; dirty content blocks Pull/Remove intact |
| Offline boundary | `list` succeeds with owner stopped; A2A request fails with a concise network error |
| Workspace isolation | App container asserts that `/workspace/lib` is absent |

Raw per-run logs are intentionally ignored because they are regenerated by `./demo/run.sh`.
This checked-in transcript records the reviewed final runs; CI repeats both npm and full profiles.
