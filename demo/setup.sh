#!/usr/bin/env bash
set -euo pipefail

wipe_volume() {
  local target=$1
  find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

copy_checkout() {
  local source=$1 target=$2
  tar -C "$source" \
    --exclude=.git --exclude=.venv --exclude=node_modules --exclude=build \
    --exclude=demo/evidence -cf - . | tar -C "$target" -xf -
  git -C "$target" init -q -b demo
  git -C "$target" config user.name "git-a2a demo"
  git -C "$target" config user.email "demo@example.invalid"
  git -C "$target" add -A
  git -C "$target" commit -q -m "Demo baseline"
}

source_head() {
  local source=$1
  git -c "safe.directory=$source" -C "$source" rev-parse HEAD
}

require_clean_source() {
  local source=$1 label=$2
  if test -n "$(git -c "safe.directory=$source" -C "$source" status --porcelain --untracked-files=all)"; then
    echo "$label source checkout must be clean" >&2
    exit 1
  fi
}

require_clean_source /seed/app app
require_clean_source /seed/lib library
app_source_sha=$(source_head /seed/app)
lib_source_sha=$(source_head /seed/lib)
expected_lib_sha=${DEMO_LIB_SHA:-$(cat /demo/lib-source.sha)}
if test "$lib_source_sha" != "$expected_lib_sha"; then
  echo "library source is $lib_source_sha; expected $expected_lib_sha" >&2
  echo "checkout the pinned commit, or set DEMO_LIB_SHA explicitly to test compatible current heads" >&2
  exit 1
fi

wipe_volume /workspace/app
wipe_volume /workspace/lib
wipe_volume /workspace/remotes
wipe_volume /tls/public
wipe_volume /tls/private
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout /tls/private/key.pem -out /tls/public/cert.pem -days 1 \
  -subj /CN=github.com -addext subjectAltName=DNS:github.com,DNS:localhost \
  >/dev/null 2>&1

copy_checkout /seed/app /workspace/app
copy_checkout /seed/lib /workspace/lib
mkdir -p /workspace/app/.git-a2a
printf '%s\n' "$app_source_sha" > /workspace/app/.git-a2a/source-app.sha
printf '%s\n' "$lib_source_sha" > /workspace/app/.git-a2a/source-lib.sha

mkdir -p /workspace/remotes/neprel
git init -q --bare /workspace/remotes/neprel/git-a2a-demo-acme-lib.git
git -C /workspace/lib remote add demo /workspace/remotes/neprel/git-a2a-demo-acme-lib.git
git -C /workspace/lib push -q -u demo HEAD:refs/heads/demo/fallback
git --git-dir=/workspace/remotes/neprel/git-a2a-demo-acme-lib.git symbolic-ref HEAD refs/heads/demo/fallback
touch /workspace/remotes/neprel/git-a2a-demo-acme-lib.git/git-daemon-export-ok

make_fixture() {
  local name=$1 manifest=$2 package_name=$3
  local source="/workspace/${name}-source"
  mkdir -p "$source/.a2a"
  printf '%s\n' "$manifest" > "$source/a2amodule.yml"
  printf '{"name":"%s","version":"1.0.0","type":"module","exports":"./index.js"}\n' \
    "$package_name" > "$source/package.json"
  printf 'export const fixtureValue = "%s";\n' "$name" > "$source/index.js"
  printf '%s\n' \
    '{"name":"Fixture owner","description":"Disposable demo fixture.",' \
    '"supportedInterfaces":[{"url":"http://lib-agent:8000/a2a/jsonrpc","protocolBinding":"JSONRPC","protocolVersion":"1.0"}],' \
    '"version":"1.0.0","capabilities":{},"defaultInputModes":["text/plain"],"defaultOutputModes":["text/plain"],' \
    '"skills":[{"id":"fixture","name":"Fixture","description":"Disposable fixture","tags":["fixture"]}]}' \
    | tr -d '\n' > "$source/.a2a/agent-card.json"
  printf '\n' >> "$source/.a2a/agent-card.json"
  git -C "$source" init -q -b demo
  git -C "$source" -c user.name=fixture -c user.email=fixture@example.invalid add -A
  git -C "$source" -c user.name=fixture -c user.email=fixture@example.invalid commit -q -m baseline
  git init -q --bare "/workspace/remotes/neprel/${name}.git"
  git -C "$source" push -q "/workspace/remotes/neprel/${name}.git" demo
  git --git-dir="/workspace/remotes/neprel/${name}.git" symbolic-ref HEAD refs/heads/demo
  touch "/workspace/remotes/neprel/${name}.git/git-daemon-export-ok"
  rm -rf "$source"
}

make_fixture fixture-stable $'schema: 2\ncomponent:\n  id: fixture-stable\n  exports:\n    - adapter: npm\n      name: "@acme/fixture-stable"\n  surface: .a2a\nagent:\n  card: .a2a/agent-card.json' '@acme/fixture-stable'
make_fixture no-surface $'schema: 2\ncomponent:\n  id: no-surface\n  exports:\n    - adapter: npm\n      name: "@acme/no-surface"\nagent:\n  card: .a2a/agent-card.json' '@acme/no-surface'
make_fixture bad-card $'schema: 2\ncomponent:\n  id: bad-card\n  exports:\n    - adapter: npm\n      name: "@acme/bad-card"\nagent:\n  card: ../../escape.json' '@acme/bad-card'
make_fixture fallback-only $'schema: 2\ncomponent:\n  id: fallback-only\n  exports:\n    - adapter: cargo\n      name: fallback-only\n  surface: .a2a\nagent:\n  card: .a2a/agent-card.json' 'fallback-only'

git -C /workspace/app config user.name "git-a2a app agent"
git -C /workspace/app config user.email "app-agent@example.invalid"

printf 'setup: app source %s; library source %s; synthetic baseline %s\n' \
  "$app_source_sha" "$lib_source_sha" "$(git -C /workspace/lib rev-parse HEAD)"
chown -R 1000:1000 /workspace /cache
