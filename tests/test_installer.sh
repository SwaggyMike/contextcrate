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

# --- installer skips shims when user answers 'n' ----------------------------

skip_bin="$test_home/appdata/satchel-skip"
mkdir -p "$test_home/appdata"

set +e
output="$(HOME="$test_home" SATCHEL_BIN="$skip_bin" SATCHEL_SHIMS=n bash "$repo_dir/install.sh" </dev/null 2>&1)"
rc=$?
set -e

[ "$rc" -eq 0 ] || fail "installer failed when declining shims (rc=$rc)" "$output"
[ -x "$skip_bin/satchel" ] || fail "satchel was not installed when declining shims" "$output"
for shim in claude codex; do
  [ ! -e "$skip_bin/$shim" ] || fail "shim '$shim' was installed despite user declining" "$output"
done
grep -q "skipped shims" <<< "$output" \
  || fail "installer did not report that shims were skipped" "$output"

printf 'ok: installer respects shim opt-out\n'

# --- satchel link / unlink --------------------------------------------------

link_bin="$test_home/link-test-bin"
mkdir -p "$link_bin"
cp "$repo_dir/satchel" "$link_bin/satchel"
chmod 755 "$link_bin/satchel"
mkdir -p "$link_bin/.satchel"
printf 'MACHINE=link-test\nSYNC_URL=\n' > "$link_bin/.satchel/config"

# link both
set +e
output="$(HOME="$test_home" SATCHEL_BIN="$link_bin" "$link_bin/satchel" link 2>&1)"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "satchel link failed (rc=$rc)" "$output"
for agent in claude codex; do
  [ -x "$link_bin/$agent" ] || fail "'$agent' shim was not created by link" "$output"
  grep -q "satchel shim" "$link_bin/$agent" || fail "'$agent' shim missing marker after link"
done
printf 'ok: satchel link creates shims\n'

# link again is a no-op
set +e
output="$(HOME="$test_home" SATCHEL_BIN="$link_bin" "$link_bin/satchel" link 2>&1)"
set -e
grep -q "already linked" <<< "$output" \
  || fail "satchel link did not report already-linked" "$output"
printf 'ok: satchel link is idempotent\n'

# unlink both
set +e
output="$(HOME="$test_home" SATCHEL_BIN="$link_bin" "$link_bin/satchel" unlink 2>&1)"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "satchel unlink failed (rc=$rc)" "$output"
for agent in claude codex; do
  [ ! -e "$link_bin/$agent" ] || fail "'$agent' shim still exists after unlink" "$output"
done
printf 'ok: satchel unlink removes shims\n'

# unlink again is a no-op
set +e
output="$(HOME="$test_home" SATCHEL_BIN="$link_bin" "$link_bin/satchel" unlink 2>&1)"
set -e
grep -q "not linked" <<< "$output" \
  || fail "satchel unlink did not report not-linked" "$output"
printf 'ok: satchel unlink is idempotent\n'

# link a single agent
set +e
output="$(HOME="$test_home" SATCHEL_BIN="$link_bin" "$link_bin/satchel" link claude 2>&1)"
set -e
[ -x "$link_bin/claude" ] || fail "claude shim was not created by single-agent link"
[ ! -e "$link_bin/codex" ] || fail "codex shim was created when only claude was requested"
printf 'ok: satchel link accepts a single agent\n'

# unlink refuses to remove a non-satchel binary
printf '#!/usr/bin/env bash\necho real\n' > "$link_bin/codex"
chmod 755 "$link_bin/codex"
set +e
output="$(HOME="$test_home" SATCHEL_BIN="$link_bin" "$link_bin/satchel" unlink codex 2>&1)"
set -e
[ -x "$link_bin/codex" ] || fail "unlink removed a non-satchel binary"
grep -q "not a Satchel shim" <<< "$output" \
  || fail "unlink did not warn about non-satchel binary" "$output"
printf 'ok: satchel unlink refuses non-satchel binaries\n'

# link refuses to overwrite a non-satchel binary
set +e
output="$(HOME="$test_home" SATCHEL_BIN="$link_bin" "$link_bin/satchel" link codex 2>&1)"
set -e
grep -q "not a Satchel shim" <<< "$output" \
  || fail "link did not warn about existing non-satchel binary" "$output"
printf 'ok: satchel link refuses to overwrite non-satchel binaries\n'

# status shows link state
rm -f "$link_bin/codex"
set +e
output="$(HOME="$test_home" SATCHEL_BIN="$link_bin" "$link_bin/satchel" status 2>&1)"
set -e
grep -q "linked" <<< "$output" || fail "status does not show link state" "$output"
grep -q "not linked" <<< "$output" || fail "status does not show unlinked state" "$output"
printf 'ok: satchel status shows link state\n'
