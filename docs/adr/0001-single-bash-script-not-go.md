# Satchel is a single bash script, not a Go binary

This decision is refined by ADR 0010: Satchel still ships as one
self-contained Bash artifact, while its development source is modular.

v1 of Satchel was a Go project with a full spec/architecture doc suite and an `internal/` package tree; two days of work produced no working tool. v2 reverses that: the entire program is one bash script (`satchel`), because every target machine (Linux + docker/podman, Unraid included) already has bash, all the real work is orchestrating other programs (`docker run`, `git pull/push`, writing config files), and a self-hosted community can read and patch a script where they'd have to trust and build a binary. `curl | bash` install and self-replacing `satchel update` fall out for free.

## Consequences

- No build pipeline, releases, or cross-compilation; `main` is the only release channel.
- The complexity ceiling is deliberate: if a feature can't be written sanely in bash, that's a signal the feature is too complex for this tool, not a signal to switch languages.
