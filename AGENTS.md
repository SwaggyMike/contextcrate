# Satchel development instructions

## Intent

Satchel should stay simple, reliable, understandable, and recoverable. It is
Linux orchestration around Bash, Git, Docker/Podman, and plain files—not a
platform or service.

This file is the working development contract. `CONTEXT.md` defines Satchel's
vocabulary, and `docs/adr/` records architectural decisions and their reasons.
Read those sources instead of inferring a new model from one function.

## Before changing code

1. Read `CONTEXT.md`.
2. Read the ADRs relevant to the subsystem being changed.
3. Trace the affected functions in `satchel` and their existing tests.
4. Check `git status` and preserve unrelated user changes.

The source repository and the user's private Sync Repo are separate systems.
Tests must never read or modify the live `~/.satchel` directory. Use a
temporary `HOME` and `SATCHEL_DIR`.

## Architecture

- Keep installation dependency-light and updates atomic. The installed
  `satchel` command is currently one self-contained Bash file.
- The single source file is a choice, not a permanent constraint. Improve
  function and section boundaries first. If modular source files would
  materially reduce coupling or editing risk, document the deployment impact
  in an ADR and preserve a single atomic installed artifact.
- Do not add a daemon, database, mandatory build toolchain, or additional
  long-lived state without a concrete need and an ADR.
- Prefer plain files, native agent conventions, and normal Git behavior over
  Satchel-specific abstractions.
- Keep Docker and Podman behavior aligned. Pure logic must not require a
  container engine merely to be tested.

## Safety invariants

- Preserve user data whenever practical. Quarantine or leave recoverable state
  instead of silently deleting malformed or uncertain data.
- Delete shims, files, containers, or configuration only when Satchel can
  prove ownership or the user named the exact target.
- Keep destructive paths explicit and validated. Never derive a deletion from
  an unchecked project ID, environment variable, glob, or symlink.
- A normal Session sees only its declared mount roots. Host Sessions are the
  explicit exception; do not quietly broaden sandbox visibility or privilege.
- Agent credentials and transcripts stay local. Only the documented Sync Repo
  state may sync.
- User-installed skills live in `skills/shared`. Agent-owned runtime content,
  including Codex `.system` skills, remains local.
- Validate synced state before committing it. A failed network operation must
  leave a retryable local state rather than losing the user's work.
- Ownership repair must target only the documented writable mounts.

## Bash implementation rules

- Use `set -euo pipefail` compatible control flow. Remember that a false final
  command can accidentally become a function's return status; return
  explicitly where callers require success.
- Quote path and user-derived values. Use arrays for command arguments.
- Keep functions narrow and name side effects clearly.
- Reuse the existing helpers for Git, JSON, engine selection, output, and
  confirmation instead of bypassing their safety behavior.
- Write structured files through a temporary file and atomic rename when a
  partial write would corrupt durable state.
- Treat generated session instructions as a public interface. Update their
  tests whenever their behavioral contract changes.
- Avoid adding dependencies for transformations Bash, Git, or the existing
  `jq` dependency can express clearly.

## Tests

Run the complete local verification from the repository root:

```bash
bash tests/run.sh
```

Every bug fix needs a regression test that fails for the original defect.
Tests should:

- create state under `mktemp -d` and clean it with a trap;
- source `satchel` without invoking `main` when testing functions;
- use local bare Git repositories for synchronization behavior;
- stub Docker/Podman for pure argument or lifecycle tests;
- avoid network access and host-specific state.

Subsystem mapping:

- baseline and machine knowledge: `tests/test_baseline.sh`
- clipboard forwarding: `tests/test_clipboard.sh`
- installation, shims, and uninstall: `tests/test_installer.sh`
- terminal output: `tests/test_output.sh`
- project identity and handoffs: `tests/test_projects.sh`
- shared skills: `tests/test_skills.sh`
- SSH forwarding: `tests/test_ssh.sh`
- Sync Repo Git behavior: `tests/test_sync.sh`
- update checks: `tests/test_update_check.sh`

## Documentation and decisions

- Update `README.md` for user-visible behavior.
- Update `CONTEXT.md` when vocabulary or a core concept changes.
- Add or supersede an ADR when changing an architectural decision. ADRs explain
  why; they are not immutable commandments.
- Keep comments focused on non-obvious constraints and failure modes.

## Definition of done

- `bash tests/run.sh` passes.
- New behavior and important failure paths are covered.
- The diff contains no unrelated changes or private Sync Repo content.
- User-visible behavior and architectural decisions are documented.
- Commits are cohesive. Fetch before publishing and push only when the task
  authorizes it.
