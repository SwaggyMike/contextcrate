
# ----------------------------------------------------------------- import

cmd_import() {
  local agent="${1:-}" home
  [ "$agent" = claude ] || [ "$agent" = codex ] || die "usage: satchel import <claude|codex>"
  home="$HOMES_DIR/$agent"
  mkdir -p "$home"
  case "$agent" in
    claude)
      [ -f "$HOME/.claude/.credentials.json" ] || [ -f "$HOME/.claude.json" ] \
        || die "no Claude Code login found on this host (~/.claude)"
      mkdir -p "$home/.claude"
      [ -f "$HOME/.claude.json" ] && cp "$HOME/.claude.json" "$home/.claude.json"
      [ -f "$HOME/.claude/.credentials.json" ] && { cp "$HOME/.claude/.credentials.json" "$home/.claude/"; chmod 600 "$home/.claude/.credentials.json"; }
      ;;
    codex)
      [ -f "$HOME/.codex/auth.json" ] || die "no Codex login found on this host (~/.codex/auth.json)"
      mkdir -p "$home/.codex"
      cp "$HOME/.codex/auth.json" "$home/.codex/auth.json"
      chmod 600 "$home/.codex/auth.json"
      ;;
  esac
  info "imported the host's $agent login — sessions will start authenticated (credentials stay on this machine, never synced)"
}
