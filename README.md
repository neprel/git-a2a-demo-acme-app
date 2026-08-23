# Acme polyglot consumer demo

This public repository is a living end-to-end consumer of
[`neprel/git-a2a-demo-acme-lib`](https://github.com/neprel/git-a2a-demo-acme-lib). One locked
library commit is wired into npm, uv, and Go; each small app calls the same utility contract.

## What to inspect, in order

1. Read `a2amodule.yml` and `a2amodule.lock` to see the declared ref and resolved commit.
2. Compare that commit in `package.json`, `pyproject.toml`, and `go.mod`.
3. Read the generated dependency roster in `AGENTS.md`.
4. Inspect `.github/workflows/ci.yml`, which checks health, updates, and all three implementations.
5. Run the lifecycle below from this repository.

```sh
git-a2a who acme-lib-utils --intent change
git-a2a show acme-lib-utils --surface
git-a2a status
git-a2a update --check
git-a2a set acme-lib-utils --ref v1.1.0
git-a2a pin acme-lib-utils
git-a2a card export acme-lib-utils
git-a2a catalog export
printf 'Describe the requested contract change.\n' | git-a2a contact acme-lib-utils --intent change --message -
```

The final command opens a real issue in the library repository with the `change-request` and
`from-agent` labels. Use it only when you intend to create that public issue. To return to the
moving demo after experimenting, run `git-a2a set acme-lib-utils --ref main`.

## The consumer is a module too

`consumer-app` has its own display name, language list, owner (`acme-app-cli`), GitHub Issue
contact, and consumer policy in `a2amodule.yml`. A consumer can therefore be imported and owned
by another module exactly like the library it consumes. Run `git-a2a who --intent change` to see
the app's own route, and inspect the “This module” section generated in `AGENTS.md`.

## Run the proof

```sh
git-a2a fetch
git-a2a status --offline
git-a2a update --check
npm ci && npm test
uv sync && uv run --with pytest pytest
go test ./...
```
