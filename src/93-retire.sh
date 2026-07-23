
# ----------------------------------------------------------------- retire

cmd_retire() {
  sync_ready || die "sync is not set up — run 'satchel init' first"
  quiet_pull
  local target="${1:-}"
  if [ -z "$target" ]; then
    local names=() m marker i
    for m in "$SYNC_DIR"/machines/*/; do
      [ -d "$m" ] || continue
      names+=("$(basename "$m")")
    done
    [ "${#names[@]}" -gt 0 ] || die "the caravan is empty — nothing to retire"
    info "caravan:"
    for i in "${!names[@]}"; do
      marker=""
      [ "${names[$i]}" = "$MACHINE" ] && marker=" (this machine)"
      printf '  %s%d)%s %s%s\n' "$ERR_BOLD$ERR_BLUE" "$((i + 1))" "$ERR_RESET" "${names[$i]}" "$marker" >&2
    done
    local choice
    read -r -p "$(prompt_text "retire which machine? [1-${#names[@]}, empty to cancel]: ")" choice
    [ -n "$choice" ] || { info "cancelled"; return 0; }
    printf '%s' "$choice" | grep -Eq '^[0-9]+$' && [ "$choice" -ge 1 ] && [ "$choice" -le "${#names[@]}" ] \
      || die "not a valid choice: $choice"
    target="${names[$((choice - 1))]}"
  fi
  [ -d "$SYNC_DIR/machines/$target" ] || die "no machine '$target' in the caravan"

  confirm "retire '$target' — delete its folder from the Sync Repo? (git history keeps it)" || { info "cancelled"; return 0; }

  ensure_sync_identity
  git_sync rm -rq -- "machines/$target"
  git_sync commit -q -m "retire $target"
  if has_upstream && ! git_sync pull --rebase -q; then
    die "pull hit a conflict — resolve it in $SYNC_DIR with normal git, then 'satchel sync'"
  fi
  git_sync push -q -u origin HEAD || warn "could not push — run 'satchel sync' when the remote is reachable"
  info "'$target' retired from the caravan"

  if [ "$target" = "$MACHINE" ]; then
    warn "that was this machine — its local state ($SATCHEL_DIR) still exists: config, agent logins, the sync clone"
    if confirm "delete the local state too? (agent logins in sessions will be lost)"; then
      rm -rf "$SATCHEL_DIR"
      info "removed $SATCHEL_DIR — this machine is fully retired"
    fi
  fi
}
