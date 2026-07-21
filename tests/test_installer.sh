#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; [ $# -gt 1 ] && printf '%s\n' "$2" >&2; exit 1; }

# The installer only checks that a container engine command exists; stub one
# so the tests run on machines without docker/podman.
stub_bin="$test_home/stub-bin"
mkdir -p "$stub_bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$stub_bin/docker"
chmod 755 "$stub_bin/docker"
export PATH="$stub_bin:$PATH"

# --- a dangling existing agent symlink is skipped, not fatal ---------------

mkdir -p "$test_home/.local/bin"
ln -s "$test_home/missing-node/lib/codex.js" "$test_home/.local/bin/codex"

set +e
output="$(HOME="$test_home" bash "$repo_dir/install.sh" </dev/null 2>&1)"
rc=$?
set -e

[ "$rc" -eq 0 ] || fail "installer rejected a dangling existing codex symlink (rc=$rc)" "$output"
grep -q "SKIPPED shim 'codex'" <<< "$output" \
  || fail "installer did not report the dangling codex symlink as skipped" "$output"

printf 'ok: installer handles dangling agent shims\n'

# --- SATCHEL_BIN makes a self-contained, relocatable install ---------------

bin="$test_home/appdata/satchel"
mkdir -p "$test_home/appdata"

set +e
output="$(HOME="$test_home" SATCHEL_BIN="$bin" bash "$repo_dir/install.sh" </dev/null 2>&1)"
rc=$?
set -e

[ "$rc" -eq 0 ] || fail "installer failed with SATCHEL_BIN (rc=$rc)" "$output"
[ -x "$bin/satchel" ] || fail "satchel was not installed into SATCHEL_BIN" "$output"
[ -d "$bin/.satchel" ] || fail "sibling .satchel state dir was not created" "$output"
for shim in claude codex; do
  [ -x "$bin/$shim" ] || fail "shim '$shim' was not installed into SATCHEL_BIN" "$output"
  grep -q "satchel shim" "$bin/$shim" || fail "shim '$shim' is missing the satchel-shim marker"
  grep -q "$bin/satchel" "$bin/$shim" || fail "shim '$shim' does not exec satchel by absolute path"
done

printf 'ok: SATCHEL_BIN install is self-contained\n'

# --- satchel finds sibling state without env or \$HOME ----------------------

printf 'MACHINE=sibling-detected\nSYNC_URL=\n' > "$bin/.satchel/config"
status_out="$(HOME="$test_home" "$bin/satchel" status 2>&1 || true)"
grep -q "on sibling-detected" <<< "$status_out" \
  || fail "installed satchel did not pick up the sibling .satchel state dir" "$status_out"

printf 'ok: sibling .satchel state dir is detected\n'
