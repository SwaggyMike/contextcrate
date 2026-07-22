# Forward the desktop clipboard socket into sessions

Sessions on a graphical host get the compositor's socket — Wayland when
present (mounted at `/run/satchel/wayland-0`, named via an absolute
`WAYLAND_DISPLAY`), else the X11 socket directory plus `DISPLAY`/`XAUTHORITY`
— so pasting an image from the host clipboard (Ctrl+V) works inside claude
and codex. On by default; `SATCHEL_CLIPBOARD=0` (machine setting) turns it
off. Headless hosts are unaffected: no socket, nothing mounted.

## Context

Pasting a screenshot into a session failed with "no image found in
clipboard". Two independent gaps: the image shipped no clipboard tools
(claude shells out to `wl-paste`/`xclip`), and the container had no path to
the host compositor, which is the only place the clipboard lives (codex
speaks the Wayland/X11 protocols directly, so it too needs the socket).
Screenshots-into-agents is a core interaction, and the ssh-agent socket
(ADR 0005) set the precedent: forward a host socket rather than copy data
into the sandbox. Alternatives considered:

- **Per-session flag (`--clipboard`)** — rejected for the same reason as
  `--ssh`: a toll on every session for a permission that in practice is
  always wanted.
- **Snapshot the clipboard at launch** — no live socket in the sandbox, but
  paste happens mid-session; a launch-time copy is almost always stale.
- **X11 first** — X11 access is strictly wider (any client can observe
  input); Wayland is preferred whenever a socket exists, X11 is the
  fallback for hosts that genuinely run X.

## Decision

- `compose_clipboard_args` probes at session start: an existing Wayland
  socket (`$WAYLAND_DISPLAY`, absolute or under `$XDG_RUNTIME_DIR`) is
  mounted at the fixed path `/run/satchel/wayland-0` and named via an
  absolute `WAYLAND_DISPLAY`, which libwayland and codex's Rust client both
  accept — no `XDG_RUNTIME_DIR` inside the container. Otherwise, with
  `DISPLAY` set and `/tmp/.X11-unix` present, that directory is mounted and
  `XAUTHORITY` (if any) comes along read-only at `/run/satchel/Xauthority`.
- The image bakes in `wl-clipboard` and `xclip`; `satchel update` rebuilds.
- Both ordinary sessions and the baseline session get it. Host Sessions get
  it too — they could reach the socket via `/host` anyway.

## Consequences

- A running session can read and write the desktop clipboard for as long as
  it runs — including things copied mid-session, like a password from a
  manager. On wlroots compositors the socket can expose more of the desktop
  (screencopy, virtual input); GNOME/KDE gate those behind portals. This is
  the ADR 0005 trade again — contained mess, not contained desktop — and
  `SATCHEL_CLIPBOARD=0` restores the old behavior for the cautious.
- SELinux hosts already run sessions with label separation disabled, so the
  socket mount needs no extra relabeling.
- On docker (uid-mapped 1:1) and rootless podman with `--userns=keep-id`
  the container user matches the socket owner; root-run satchel on Unraid
  is headless, so the path never triggers there.
