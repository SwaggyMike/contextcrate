# Modular Bash source, single installed artifact

ADR 0001 chose Bash and a single `satchel` script after an over-designed Go
version failed to produce a usable tool. That decision successfully kept
installation, updates, and deployment simple. As the implementation grew to
roughly 3,000 lines across projects, sync, skills, MCP, machine knowledge, and
session orchestration, treating deployment shape and source organization as
the same constraint began to work against maintainability.

## Decision

Satchel remains Bash and still ships as one self-contained executable. Its
development source is split into ordered modules under `src/`, and
`scripts/build.sh` concatenates them deterministically into the committed
`satchel` artifact.

The installer and updater continue to replace only that one artifact. Runtime
execution does not source files from the repository, and target machines need
no build tools beyond what Satchel already requires.

`tests/run.sh` rejects a generated artifact that does not exactly match the
modules before exercising the artifact itself. GitHub marks `satchel` as
generated so reviews focus on the source modules.

## Consequences

- Development changes are localized by subsystem without changing deployment.
- Installation and self-update remain atomic and keep the same failure modes.
- Contributors must rebuild `satchel` after changing a module.
- The generated artifact is committed so `curl | bash` and raw-main updates
  continue to work without a release pipeline.
- CI prevents source/artifact drift.
- Bash remains the deliberate complexity ceiling; this decision does not
  introduce a framework, package manager, or runtime module loader.

This ADR refines ADR 0001: the durable constraint is one installed Bash
artifact, not one development source file.
