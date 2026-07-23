#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export SATCHEL_DIR="$tmp/state"
mkdir -p "$HOME" "$SATCHEL_DIR/sync/.git" "$tmp/work"
printf 'MACHINE=testbox\nSYNC_URL=test\n' > "$SATCHEL_DIR/config"

# Load functions without invoking main.
source <(sed '$d' "$repo_dir/satchel")
load_config

# Keep the mount test independent of the host's container engine.
podman_rootless() { return 1; }
SSH_STATE=none

# One source of truth drives the mount, environment contract, and generated
# instructions for each agent.
for agent in claude codex; do
  case "$agent" in
    claude) skills_dir=/home/satchel/.claude/skills; memory=.claude/CLAUDE.md ;;
    codex)  skills_dir=/home/satchel/.codex/skills;  memory=.codex/AGENTS.md ;;
  esac
  agent_home="$tmp/home_$agent"

  compose_run_args "$agent" "$agent_home" "$tmp/work"
  args=" ${RUN_ARGS[*]} "
  [[ "$args" == *" SATCHEL_SESSION=1 "* ]]
  [[ "$args" == *" $SATCHEL_DIR/sync/skills/shared:$skills_dir "* ]]
  [[ "$args" == *" SATCHEL_SKILLS_DIR=$skills_dir "* ]]

  write_memory_file "$agent" "$agent_home" "" "$tmp/work"
  preamble="$agent_home/$memory"
  grep -q '^## Satchel Skill Library$' "$preamble"
  grep -q "mounted read-write" "$preamble"
  grep -q "$skills_dir" "$preamble"
  grep -q 'Claude and Codex sessions on every' "$preamble"
  grep -q 'Preserve the whole bundle' "$preamble"
  grep -q 'commits and pushes Skill' "$preamble"
  grep -q 'Start a new session' "$preamble"
done

# Without a Sync Repo Satchel still identifies itself, but must not claim a
# shared/persistent Skill Library exists.
SYNC_URL=""
compose_run_args codex "$tmp/home_unsynced" "$tmp/work"
args=" ${RUN_ARGS[*]} "
[[ "$args" == *" SATCHEL_SESSION=1 "* ]]
[[ "$args" != *" SATCHEL_SKILLS_DIR="* ]]
write_memory_file codex "$tmp/home_unsynced" "" "$tmp/work"
! grep -q '^## Satchel Skill Library$' "$tmp/home_unsynced/.codex/AGENTS.md"

printf 'ok: Satchel-native Skill Library runtime contract\n'
