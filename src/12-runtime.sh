
load_config() {
  # Precedence: built-in default < synced settings.env < local config.
  # shellcheck disable=SC1090
  [ -f "$SYNC_SETTINGS_FILE" ] && . "$SYNC_SETTINGS_FILE"
  # shellcheck disable=SC1090
  [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
  MACHINE="${MACHINE:-$(hostname -s)}"
  local uid; uid="$(id -u)"
  # Never run agents as root inside the container; on root hosts (Unraid)
  # fall back to 1000:1000. Override with SATCHEL_UID/SATCHEL_GID in the config.
  if [ -z "$SATCHEL_UID" ]; then
    if [ "$uid" -eq 0 ]; then SATCHEL_UID=1000; SATCHEL_GID=1000
    else SATCHEL_UID="$uid"; SATCHEL_GID="$(id -g)"; fi
  fi
  SATCHEL_GID="${SATCHEL_GID:-$SATCHEL_UID}"
}

sync_ready() { [ -n "$SYNC_URL" ] && [ -d "$SYNC_DIR/.git" ]; }

engine() {
  if [ -z "$ENGINE" ]; then
    if [ -n "${SATCHEL_ENGINE:-}" ]; then ENGINE="$SATCHEL_ENGINE"
    elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then ENGINE=docker
    elif command -v podman >/dev/null 2>&1; then ENGINE=podman
    else die "neither docker nor podman is available"
    fi
  fi
  printf '%s' "$ENGINE"
}

podman_rootless() {
  [ "$(engine)" = podman ] && [ "$(id -u)" -ne 0 ]
}

# SELinux hosts (Fedora & co): confined containers cannot touch bind-mounted
# host paths (user_home_t), so sessions die reading their own agent home.
# Relabeling with :z/:Z is wrong here - it rewrites labels on arbitrary host
# dirs (the project itself) and cannot cover the ssh-agent socket - so label
# separation is disabled for the session instead, the podman-documented way
# to mount host paths. The sandbox is unchanged: mount namespace,
# unprivileged uid, cap-drop, no-new-privileges.
selinux_active() {
  command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled 2>/dev/null
}

# Sessions get the host ssh-agent socket, not key files: the agent inside can
# ask the host to sign (so git push works) but can never read or copy a key.
# ADR 0005 has the tradeoff; SATCHEL_SSH=0 turns it off.
#
# A socket alone proves nothing: it can point at a dead agent, or a live one
# with no identities loaded (common over SSH: the forwarded agent answers but
# ssh-add was never run on the client). ssh_agent_state probes once with
# ssh-add (exit 0 = identities loaded, 1 = agent reachable but empty,
# anything else = nothing answering) so launch messages and the session
# preamble describe what git push will actually do.
SSH_STATE=""
ssh_agent_state() {
  if [ "${SATCHEL_SSH:-1}" = 0 ]; then printf 'off'; return 0; fi
  if [ ! -S "${SSH_AUTH_SOCK:-}" ]; then printf 'none'; return 0; fi
  local rc=0
  ssh-add -l >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) printf 'ready' ;;
    1) printf 'empty' ;;
    *) printf 'dead' ;;
  esac
}

# Mount the socket when an agent is actually answering on it. An empty agent
# still gets mounted: keys the user ssh-adds on the host mid-session become
# usable inside immediately. A dead socket gets nothing - mounting it could
# only produce confusing in-container errors.
ssh_forwarding() {
  case "${SSH_STATE:=$(ssh_agent_state)}" in
    ready|empty) return 0 ;;
    *) return 1 ;;
  esac
}

# Session-start preflight: say up front what git-over-SSH will do, instead of
# letting the first push inside the sandbox fail mysteriously.
ssh_preflight() {
  case "${SSH_STATE:=$(ssh_agent_state)}" in
    empty)
      # Keys on disk but none in the agent: offer to load them now, while a
      # passphrase prompt can still reach a human. The key file stays on the
      # host either way; sessions only ever gain the ability to ask for
      # signatures, and only while the key stays loaded.
      if [ -t 0 ] && have_pubkey && confirm_yes "ssh-agent has no keys loaded - run 'ssh-add' now so this session can push over SSH?"; then
        if ssh-add; then SSH_STATE=ready; return 0; fi
      fi
      warn "ssh-agent has no keys loaded (ssh-add -l) - git push over SSH will fail inside the session until you run 'ssh-add' (on the machine you connected from, if this is a remote shell); keys added later work without restarting"
      ;;
    dead)  warn "SSH_AUTH_SOCK is set but no ssh-agent answered - git over SSH will not work inside the session" ;;
    none)  info "no ssh-agent on this host - git push over SSH will not work inside the session (SATCHEL_SSH=0 hides this note)" ;;
  esac
  return 0
}
