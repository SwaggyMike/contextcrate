#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export SATCHEL_DIR="$tmp/state"
mkdir -p "$HOME" "$SATCHEL_DIR"
printf 'MACHINE=testbox\nSYNC_URL=\n' > "$SATCHEL_DIR/config"

# Load functions without invoking main. Inside the sourced functions $0 is
# this test file, so script_blob hashes it - the stub below plays GitHub.
source <(sed '$d' "$repo_dir/satchel")
load_config

stub="$tmp/bin"; mkdir -p "$stub"; export PATH="$stub:$PATH"
export STUB_HIT="$tmp/hit"
set_remote_blob() {
  printf '#!/bin/sh\ntouch "$STUB_HIT"\necho "{\\"sha\\":\\"%s\\"}"\n' "$1" > "$stub/curl"
  chmod +x "$stub/curl"
}

# Newer script on GitHub: announce it.
set_remote_blob 0000000000000000000000000000000000000000
grep -q "satchel update" <(update_check 2>&1)

# Second call the same day: silent, and no network probe at all.
rm -f "$STUB_HIT"
[ -z "$(update_check 2>&1)" ]
[ ! -f "$STUB_HIT" ]

# Stale stamp but matching content: probe runs, nothing announced.
printf '0' > "$SATCHEL_DIR/update-check"
set_remote_blob "$(git hash-object "$0")"
[ -z "$(update_check 2>&1)" ]
[ -f "$STUB_HIT" ]

# Offline probe: silent, not fatal.
printf '0' > "$SATCHEL_DIR/update-check"
printf '#!/bin/sh\nexit 7\n' > "$stub/curl"; chmod +x "$stub/curl"
[ -z "$(update_check 2>&1)" ]

printf 'ok: update availability check\n'
