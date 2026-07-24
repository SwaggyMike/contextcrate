#!/usr/bin/env bash
set -uo pipefail

# Run from inside a live Satchel Session. This checks the container boundary
# that unit tests can only describe: identity, passwd home, mount direction,
# Linux privilege state, SSH forwarding, and agent-native configuration.

cleanup() {
  [ -z "$probe" ] || rm -f -- "$probe"
}

pass() {
  passes=$((passes + 1))
  printf 'PASS  %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf 'FAIL  %s\n' "$1" >&2
}

skip() {
  skips=$((skips + 1))
  printf 'SKIP  %s\n' "$1"
}

check() {
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

check_equal() {
  local description="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$description"
  else
    fail "$description (expected $expected, got ${actual:-<empty>})"
  fi
}

mount_has_option() {
  local target="$1" expected="$2" options
  options="$(findmnt -T "$target" -n -o OPTIONS 2>/dev/null | head -n 1)" || return 1
  case ",$options," in
    *",$expected,"*) return 0 ;;
    *) return 1 ;;
  esac
}

mount_exists() {
  findmnt -M "$1" >/dev/null 2>&1
}

codex_mcp_config_valid() {
  codex mcp list >/dev/null 2>&1
}

environment_has_name() {
  printenv "$1" >/dev/null 2>&1
}

pid_namespace_is_private() {
  local nspid_fields="$1" pid1_comm="$2"
  [ "$nspid_fields" -gt 1 ] && return 0
  # Rootless Podman can hide ancestor PID values even in a private namespace.
  # A supported engine's --init process can be PID 1 only in the container's
  # own PID namespace; --pid=host leaves the host's init at PID 1.
  case "$pid1_comm" in
    catatonit|docker-init|podman-init|tini) return 0 ;;
    *) return 1 ;;
  esac
}

probe_writable() {
  local directory="$1"
  probe="$(mktemp "$directory/.satchel-session-smoke.XXXXXX" 2>/dev/null)" || return 1
  rm -f -- "$probe" || return 1
  probe=""
}

probe_read_only() {
  local directory="$1"
  if probe="$(mktemp "$directory/.satchel-session-smoke.XXXXXX" 2>/dev/null)"; then
    rm -f -- "$probe"
    probe=""
    return 1
  fi
  probe=""
  return 0
}

usage() {
  printf 'usage: %s [host|sandbox]\n' "${0##*/}"
}

main() {
passes=0
failures=0
skips=0
probe=""
trap cleanup EXIT

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  ""|host|sandbox) ;;
  *) usage >&2; exit 2 ;;
esac

command -v findmnt >/dev/null || {
  printf 'FAIL  findmnt is required\n' >&2
  exit 1
}
command -v getent >/dev/null || {
  printf 'FAIL  getent is required\n' >&2
  exit 1
}

check_equal "Satchel Session marker" 1 "${SATCHEL_SESSION:-}"

requested_mode="${1:-}"
declared_mode="${SATCHEL_SESSION_MODE:-}"
if [ -n "$requested_mode" ] && [ -n "$declared_mode" ] \
   && [ "$requested_mode" != "$declared_mode" ]; then
  fail "requested mode $requested_mode conflicts with SATCHEL_SESSION_MODE=$declared_mode"
fi

mode="${requested_mode:-$declared_mode}"
if [ -z "$mode" ]; then
  if [ "$(id -u)" -eq 0 ] && mount_exists /host; then
    mode=host
  else
    mode=sandbox
  fi
  skip "SATCHEL_SESSION_MODE is absent; inferred $mode (Session predates the mode marker)"
elif [ -z "$declared_mode" ]; then
  skip "SATCHEL_SESSION_MODE is absent; checking requested $mode mode (Session predates the mode marker)"
else
  check_equal "declared Session mode" "$mode" "$declared_mode"
fi
case "$mode" in
  host|sandbox) ;;
  *) fail "invalid Session mode: $mode"; exit 1 ;;
esac

printf 'Satchel live Session smoke test: %s\n' "$mode"

check_equal "HOME" /home/satchel "${HOME:-}"
passwd_home="$(getent passwd "$(id -u)" | cut -d: -f6)"
check_equal "passwd home matches HOME" /home/satchel "$passwd_home"
check "agent home is writable" probe_writable /home/satchel

instructions=""
if [ -f /home/satchel/.codex/AGENTS.md ]; then
  instructions=/home/satchel/.codex/AGENTS.md
elif [ -f /home/satchel/.claude/CLAUDE.md ]; then
  instructions=/home/satchel/.claude/CLAUDE.md
fi
if [ -n "$instructions" ]; then
  check "generated Satchel instructions are present" \
    grep -q '^# Managed by Satchel' "$instructions"
  if [ "$mode" = host ]; then
    check "instructions identify a Host Session" \
      grep -q 'This is a Satchel Host Session' "$instructions"
  else
    check "instructions identify a sandboxed Session" \
      grep -q 'This is a sandboxed Satchel session' "$instructions"
  fi
else
  fail "generated Satchel instructions are missing"
fi

if [ -n "${SATCHEL_SKILLS_DIR:-}" ]; then
  check "Skill Library directory exists" test -d "$SATCHEL_SKILLS_DIR"
  check "Skill Library is writable" probe_writable "$SATCHEL_SKILLS_DIR"
else
  skip "Skill Library is unavailable (Session has no ready Sync Repo)"
fi

if [ -d /home/satchel/machine ]; then
  check "current-machine knowledge is writable" probe_writable /home/satchel/machine
else
  skip "current-machine knowledge is unavailable"
fi
if [ -d /home/satchel/projects ]; then
  check "Project handoffs are mounted read-only" mount_has_option /home/satchel/projects ro
  check "Project handoffs reject writes" probe_read_only /home/satchel/projects
else
  skip "Project handoffs are unavailable"
fi
if [ -d /home/satchel/machines ]; then
  check "other-machine knowledge is mounted read-only" mount_has_option /home/satchel/machines ro
  check "other-machine knowledge rejects writes" probe_read_only /home/satchel/machines
else
  skip "other-machine knowledge is unavailable"
fi

if [ -n "${SSH_AUTH_SOCK:-}" ]; then
  check "forwarded ssh-agent socket exists" test -S "$SSH_AUTH_SOCK"
  ssh_status=0
  ssh-add -l >/dev/null 2>&1 || ssh_status=$?
  case "$ssh_status" in
    0) pass "forwarded ssh-agent has an identity" ;;
    1) pass "forwarded ssh-agent responds (no identity loaded)" ;;
    *) fail "forwarded ssh-agent does not respond" ;;
  esac
else
  skip "SSH forwarding is disabled or unavailable"
fi

if [ -f /home/satchel/.codex/config.toml ]; then
  check "Codex accepts its materialized MCP configuration" \
    codex_mcp_config_valid
  mapfile -t mcp_token_vars < <(
    sed -n 's/^bearer_token_env_var = "\([^"]*\)"$/\1/p' \
      /home/satchel/.codex/config.toml
  )
  if [ "${#mcp_token_vars[@]}" -gt 0 ]; then
    for mcp_token_var in "${mcp_token_vars[@]}"; do
      check "Codex MCP token variable is present ($mcp_token_var)" \
        environment_has_name "$mcp_token_var"
    done
  else
    skip "Codex has no bearer-auth MCP server"
  fi
else
  skip "Codex MCP configuration is not present for this agent"
fi

nspid_fields="$(awk '/^NSpid:/ { print NF - 1 }' /proc/self/status)"
pid1_comm="$(cat /proc/1/comm 2>/dev/null)"
cap_eff="$(awk '/^CapEff:/ { print $2 }' /proc/self/status)"
no_new_privs="$(awk '/^NoNewPrivs:/ { print $2 }' /proc/self/status)"
if [ "$mode" = host ]; then
  check_equal "Host Session runs as root" 0 "$(id -u)"
  check "host filesystem is mounted at /host" mount_exists /host
  check "host /etc is visible" test -d /host/etc
  check "host persistent /etc is writable when the host says it is" \
    mount_has_option /host/etc rw
  check "host persistent /var is writable when the host says it is" \
    mount_has_option /host/var rw
  check_equal "Host Session shares the host PID namespace" 1 "$nspid_fields"
  if [ "$cap_eff" != 0000000000000000 ]; then
    pass "Host Session retains capabilities"
  else
    fail "Host Session unexpectedly has no effective capabilities"
  fi
  check_equal "Host Session permits privilege changes" 0 "$no_new_privs"
else
  if [ "$(id -u)" -ne 0 ]; then
    pass "sandboxed Session runs as a non-root user"
  else
    fail "sandboxed Session unexpectedly runs as root"
  fi
  if mount_exists /host; then
    fail "sandboxed Session unexpectedly mounts /host"
  else
    pass "sandboxed Session does not mount /host"
  fi
  if pid_namespace_is_private "$nspid_fields" "$pid1_comm"; then
    pass "sandboxed Session has a private PID namespace"
  else
    fail "sandboxed Session unexpectedly shares the host PID namespace"
  fi
  check_equal "sandboxed Session has no effective capabilities" \
    0000000000000000 "$cap_eff"
  check_equal "sandboxed Session forbids privilege escalation" 1 "$no_new_privs"
fi

printf '\nResult: %s passed, %s failed, %s skipped\n' "$passes" "$failures" "$skips"
[ "$failures" -eq 0 ]
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
