
# --------------------------------------------------------------- handoffs

HANDOFF_MARK='<!-- satchel-handoff'

# Sessions outside any tracked project (Host Sessions fixing the machine
# itself, mostly) still produce context worth keeping - it is kept per
# machine instead of per project: machines/<name>/handoffs/. An empty
# project id selects that machine scope.
latest_handoff() { # latest_handoff <project-id> → prints newest handoff
  local slug="$1" dir best="" best_date="" f date
  if [ -n "$slug" ]; then dir="$SYNC_DIR/projects/$slug/handoffs"
  else dir="$SYNC_DIR/machines/$MACHINE/handoffs"; fi
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    date="$(sed -n "1s/.*date=\([^ ]*\).*/\1/p" "$f")"
    if [ -z "$best" ] || [[ "$date" > "$best_date" ]]; then best="$f"; best_date="$date"; fi
  done
  [ -n "$best" ] && printf '%s' "$best"
  return 0
}

# Agent-native path where Satchel mounts the one shared Skill Library.
# Keep the mount, runtime environment, and generated instructions on this
# single source of truth.
