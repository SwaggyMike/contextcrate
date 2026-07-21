#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT

mkdir -p "$test_home/.local/bin"
ln -s "$test_home/missing-node/lib/codex.js" "$test_home/.local/bin/codex"

set +e
output="$(HOME="$test_home" bash "$repo_dir/install.sh" </dev/null 2>&1)"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  printf 'FAIL: installer rejected a dangling existing codex symlink (rc=%s)\n%s\n' "$rc" "$output" >&2
  exit 1
fi
if ! grep -q "SKIPPED shim 'codex'" <<< "$output"; then
  printf 'FAIL: installer did not report the dangling codex symlink as skipped\n%s\n' "$output" >&2
  exit 1
fi

printf 'ok: installer handles dangling agent shims\n'
