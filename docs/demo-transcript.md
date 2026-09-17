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
app source: f5946b9c22280692bce405d8e0334defd29989fe
lib source: e42437fc28e277af0a0726552e3f7ef8972a6c28
app agent: {"action":"status","component":"consumer-app","status":"ok"}

added acme-lib-utils at 22d42a6052b0afe44113b7b8e5bb0548c2aa5638
bindings: submodule/git, cmake/cmake, golang/go, npm/npm, pypi/uv
card: .git-a2a/agents/acme-lib-utils/agent-card.json
surface: .git-a2a/surfaces/acme-lib-utils

npm blank => ''
uv blank => ''
Go blank => ''
CMake blank => ''

describe: supportsFallback=false, blankResult=""
unsupported action: status=unsupported
owner change: commit=95da3eb9af6f7f31d7ef0de6168a952a6d5b997c, version=1.1.0
fixture upstream: b64bf17c131cd6ebb24227b57c3e1404eb6445e0 -> e3b4d62870c83bf1869accc0998e951d66227013

npm blank => ''                 # still baseline before Pull
uv blank => ''
Go blank => ''
CMake blank => ''

targeted pull: acme-lib-utils updated; fixture commit and value remained at baseline
general pull: fixture updated to e3b4d62870c83bf1869accc0998e951d66227013 and fixture-stable-next

acme-lib-utils: pulled 95da3eb9af6f7f31d7ef0de6168a952a6d5b997c
npm blank+fallback => Anonymous
uv blank+fallback => Anonymous
Go blank+fallback => Anonymous
CMake blank+fallback => Anonymous

usage without materializations: FAIL (.venv absent; Go module lookup disabled by GOPROXY=off)
PASS: usage checks created no dependency materialization; Pull restored all four integrations
PASS: fresh clone populated a separate initially empty Go cache
PASS: ignored source sentinel absent from workspace and synthetic baseline
PASS: manager rollback, bad card, absent surface, remove retention, fallback, dirty preservation
PASS: owner A2A request, commit, Pull, and npm/uv/Go/CMake assertions
PASS: list remained offline; A2A transport failed while endpoint was stopped
```

## Independent clean-volume rerun

```json
{
  "status": "PASS",
  "appSource": "f5946b9c22280692bce405d8e0334defd29989fe",
  "libSource": "e42437fc28e277af0a0726552e3f7ef8972a6c28",
  "appBaseline": "68ae1c6b7e42a41e897ab891ace410ee78a820c2",
  "libBaseline": "3180f5b4bfd31b893338ef511d300a317a5bbace",
  "libFinal": "5342e0feeb2db48bd99c6ad31d245c5740853d4d",
  "stableBaseline": "664fd490a3696fe849394a1f58726362b4acc20d",
  "stableFinal": "c32c2355a5eba175e59d679583daafe91fa62fcb",
  "archiveSentinelExcluded": true,
  "usageChecksOffline": true,
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
app source: f5946b9c22280692bce405d8e0334defd29989fe
lib source: e42437fc28e277af0a0726552e3f7ef8972a6c28
baseline: 9c6b818d6de0e37ba910ea949eb19051e5c2d4b2
owner final: 4624027cc1ec11228f0b7f08041b0e31644866fb
binding: npm/npm
acme-lib-utils: pulled 4624027cc1ec11228f0b7f08041b0e31644866fb
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
| Install-free usage and repair | Direct `.venv` Python and offline Go fail on deleted state without repairing it; Pull restores all integrations |
| Fresh clone and repair | Fresh consumer and deleted native/submodule materialization are restored by Pull |
| Targeting and idempotency | Both upstreams advance; targeted Pull preserves the fixture SHA/value, general Pull updates them; repeated Pull leaves no tracked diff |
| Remove and unrelated data | Managed entry, lock, and materialization disappear; unrelated npm package still runs |
| Failure safety | Missing manager rolls back; unsafe card fails; absent surface is not invented |
| Submodule safety | Native-incompatible export falls back to submodule; dirty content blocks Pull/Remove intact |
| Offline boundary | `list` succeeds with owner stopped; A2A request fails with a concise network error |
| Workspace isolation | App container asserts that `/workspace/lib` is absent |
| Exact source snapshot | Synthetic repos use `git archive` of recorded SHAs; an ignored sentinel is absent from workspace and commit |

Raw per-run logs are intentionally ignored because they are regenerated by `./demo/run.sh`.
This checked-in transcript records the reviewed final runs; CI repeats both npm and full profiles.
