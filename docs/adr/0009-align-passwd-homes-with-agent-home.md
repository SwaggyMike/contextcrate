# ADR 0009: Align container passwd homes with the agent home

The image rewrites the passwd homes of `node` and `root` to `/home/satchel`,
and rootless-podman sessions template keep-id's invented passwd entry the
same way. Sessions additionally mount `sync/machines` read-only at
`/home/satchel/machines` so any session can read sibling machines' notes.

## Context

Sessions set `HOME=/home/satchel` and mount the persistent agent home there,
but OpenSSH resolves `~` through `getpwuid()`, not `$HOME`. The image's
passwd said `/home/node` (UID 1000) and `/root` (root Host Sessions), so ssh
kept its state in ephemeral container paths: known_hosts written there
evaporated with the container, defeating ADR 0005's trust-on-first-use
record, and on Unraid a root Host Session tripped over the host's
`/root/.ssh` symlink dangling inside the container. Every machine in the
caravan hit some form of this; Apollo carried a guide of explicit
`-o`/`-i` workarounds.

Separately, sessions could read their own machine's knowledge and every
project's handoffs, but not sibling machines' notes — even when a pending
task on this machine was documented on another ("the fix is in apollo's
notes"). The only reader of a machine's notes was that machine itself.

## Decision

- `build_image` runs `usermod -d /home/satchel node` and the same for
  `root`: every tool that consults passwd (ssh foremost) now agrees with
  `$HOME` about where home is. This covers the whole caravan — sandboxed
  sessions run as UID 1000, root Host Sessions as UID 0.
- Rootless podman launches add
  `--passwd-entry '$USERNAME:*:$UID:$GID::/home/satchel:/bin/bash'` beside
  `--userns=keep-id`, so a custom `SATCHEL_UID` absent from the image's
  passwd gets the same home. Docker with a custom UID keeps today's
  behavior (no passwd entry at all); accepted — no caravan machine does that.
- Host key files are still never copied or consumed automatically; auth
  stays with the forwarded agent (ADR 0005). This fix is about ssh's
  *state directory*, not its credentials.
- `compose_run_args` mounts `$SYNC_DIR/machines` read-only at
  `/home/satchel/machines`, and the preamble points to it. Writes still go
  only through the machine's own rw `/home/satchel/machine` mount, so
  authorship stays local while readership is caravan-wide.

## Consequences

- known_hosts (and anything else ssh drops in `~/.ssh`) now lands in the
  persistent agent home and survives across sessions; first-contact hosts
  are recorded once per machine instead of once per session.
- Apollo's outbound-SSH guide shrinks to the one part a passwd fix cannot
  replace: choosing the machine identity explicitly
  (`-i /host/boot/config/ssh/root/id_ed25519`) when no agent is available.
- The fix rides the normal `satchel update` (which always rebuilds the
  image); machines that skip the update keep the old behavior, nothing
  breaks harder than before.
- A session can now read every machine's notes; the sync repo already
  syncs them to every machine, so this widens visibility inside sessions,
  not the set of machines holding the data.
