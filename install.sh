#!/usr/bin/env bash
# Satchel installer:
#   curl -fsSL https://raw.githubusercontent.com/SwaggyMike/satchel/main/install.sh | bash
#
# Installs the `satchel` script plus the `claude` and `codex` shims (thin
# wrappers that exec `satchel claude` / `satchel codex`, so sessions feel like
# the real CLIs).
set -euo pipefail

RAW="https://raw.githubusercontent.com/SwaggyMike/satchel"

say() { printf 'install: %s\n' "$*" >&2; }
die() { printf 'install: error: %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v git  >/dev/null 2>&1 || die "git is required"
command -v jq   >/dev/null 2>&1 || die "jq is required"
command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1 \
  || die "docker or podman is required"

if [ -w /usr/local/bin ]; then BIN=/usr/local/bin
else BIN="$HOME/.local/bin"; mkdir -p "$BIN"; fi

# When run from a checkout, install the local copy; otherwise download main.
# The installed commit is recorded in ~/.satchel/script-sha so 'satchel
# update' can show the commits each update brings.
tmp="$(mktemp)"
sha=""
src="$(cd "$(dirname "${BASH_SOURCE[0]:-/nonexistent}")" 2>/dev/null && pwd || true)"
if [ -n "$src" ] && [ -f "$src/satchel" ]; then
  cp "$src/satchel" "$tmp"
  say "installing from local checkout"
  # Only a clean checkout's HEAD truthfully describes the installed script.
  if git -C "$src" diff --quiet HEAD -- satchel 2>/dev/null; then
    sha="$(git -C "$src" rev-parse HEAD 2>/dev/null || true)"
  fi
else
  # Resolve main to a commit and download by SHA: the raw 'main' URL sits
  # behind a ~5 min CDN cache and will happily serve a stale script.
  sha="$(curl -fsSL "https://api.github.com/repos/SwaggyMike/satchel/commits/main" 2>/dev/null | jq -r '.sha // empty' || true)"
  curl -fsSL "$RAW/${sha:-main}/satchel" -o "$tmp"
fi
bash -n "$tmp" || die "downloaded satchel script does not parse"
install -m 755 "$tmp" "$BIN/satchel"
rm -f "$tmp"
if [ -n "$sha" ]; then
  mkdir -p "$HOME/.satchel"
  printf '%s\n' "$sha" > "$HOME/.satchel/script-sha"
fi
say "installed $BIN/satchel${sha:+ (commit ${sha:0:7})}"

for agent in claude codex; do
  shim="$BIN/$agent"
  # -e is false for dangling symlinks. Treat -L as existing too, otherwise
  # redirecting into one follows its missing target and aborts the installer.
  if { [ -e "$shim" ] || [ -L "$shim" ]; } && ! grep -q "exec satchel" "$shim" 2>/dev/null; then
    say "SKIPPED shim '$agent': $shim exists and is not a satchel shim."
    say "  remove it (or the host CLI it points to) and rerun to route '$agent' through satchel."
    continue
  fi
  printf '#!/usr/bin/env bash\nexec satchel %s "$@"\n' "$agent" > "$shim"
  chmod 755 "$shim"
  say "installed shim $shim"
done

case ":$PATH:" in
  *":$BIN:"*) : ;;
  *)
    say "NOTE: $BIN is not on your PATH yet."
    say "  run:  export PATH=\"$BIN:\$PATH\""
    say "  (on Debian/Ubuntu a fresh login picks it up automatically once the directory exists)"
    ;;
esac

# Chain straight into setup. Under `curl | bash` stdin is the script itself,
# so give init the real terminal; skip when non-interactive (CI) or already
# set up (this is an update run).
initialized=0
if [ -f "$HOME/.satchel/config" ]; then
  SYNC_URL=""
  . "$HOME/.satchel/config" 2>/dev/null || true
  # a configured sync URL without a clone means a previous init didn't finish
  if [ -z "$SYNC_URL" ] || [ -d "$HOME/.satchel/sync/.git" ]; then initialized=1; fi
fi
if [ "$initialized" -eq 1 ]; then
  say "done — already initialized ('satchel status' to check the fleet)"
elif { : </dev/tty; } 2>/dev/null; then
  say "starting setup…"
  "$BIN/satchel" init </dev/tty || say "setup did not finish — fix the issue above and run: satchel init"
else
  say "done. next: satchel init"
fi
