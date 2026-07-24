#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export SATCHEL_DIR="$tmp/state"
mkdir -p "$HOME" "$SATCHEL_DIR/sync/.git"
printf 'MACHINE=testbox\nSYNC_URL=test\n' > "$SATCHEL_DIR/config"

source <(sed '$d' "$repo_dir/satchel")
load_config

# URLs must be directly representable in Codex's generated TOML. Invalid
# synced state fails before either agent config is touched.
printf '{"servers":{"ok":{"url":"https://example.test/mcp","auth":"none"}}}\n' > "$MCP_FILE"
validate_mcp_state
mcp_url_valid "https://example.test/mcp"
! mcp_url_valid 'https://example.test/"bad'
! mcp_url_valid 'https://example.test/\bad'
printf '{"servers":{"bad":{"url":"https://example.test/\\"bad","auth":"none"}}}\n' > "$MCP_FILE"
! (validate_mcp_state 2>/dev/null)
printf '{"servers":{"bad":{"url":"https://example.test/\\nbad","auth":"none"}}}\n' > "$MCP_FILE"
! (validate_mcp_state 2>/dev/null)

# A valid managed block is replaced while unrelated settings on both sides
# remain intact.
printf '{"servers":{"ok":{"url":"https://example.test/mcp","auth":"none"}}}\n' > "$MCP_FILE"
codex_home="$tmp/codex"
mkdir -p "$codex_home/.codex"
cat > "$codex_home/.codex/config.toml" <<'EOF'
sandbox_mode = "workspace-write"
# >>> satchel mcp >>>
old managed content
# <<< satchel mcp <<<
model_reasoning_effort = "low"
EOF
materialize_mcp codex "$codex_home"
grep -q '^sandbox_mode = "workspace-write"$' "$codex_home/.codex/config.toml"
grep -q '^model_reasoning_effort = "low"$' "$codex_home/.codex/config.toml"
grep -q '^url = "https://example.test/mcp"$' "$codex_home/.codex/config.toml"
! grep -q 'old managed content' "$codex_home/.codex/config.toml"

# An interrupted or manually damaged marker pair never causes the tail of the
# user's Codex config to be discarded.
cat > "$codex_home/.codex/config.toml" <<'EOF'
sandbox_mode = "workspace-write"
# >>> satchel mcp >>>
incomplete managed content
model_reasoning_effort = "high"
EOF
cp "$codex_home/.codex/config.toml" "$tmp/config-before"
! (materialize_mcp codex "$codex_home" 2>/dev/null)
cmp "$tmp/config-before" "$codex_home/.codex/config.toml"
[ ! -e "$codex_home/.codex/config.toml.tmp" ]

printf 'ok: MCP validation and materialization\n'
