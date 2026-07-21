# ContextCrate

A single bash script for running AI coding agents (Claude Code, Codex) in disposable Docker containers on home-lab Linux machines, with session handoffs and settings synced between machines via a private git remote. Deliberately not production-grade: simple, readable, boring.

## Language

**Crate**:
The ContextCrate program itself — one bash script, installed as the `crate` command.
_Avoid_: daemon, service, platform

**Shim**:
A tiny wrapper command named `claude` or `codex` on the host PATH that execs `crate claude` / `crate codex`, so using ContextCrate feels identical to using the real CLI.
_Avoid_: alias, symlink

**Session**:
A single run of an agent CLI inside a throwaway Docker container, scoped to one project directory. The container is deleted when the session ends.
_Avoid_: workspace, environment

**Sync Repo**:
The user-owned private git repository (cloned at `~/.contextcrate/sync/`) that carries handoffs, tool settings, and the MCP Registry between machines. Agent login credentials and transcripts never enter it.
_Avoid_: cloud, backend, server

**MCP Registry**:
The single synced file listing the user's MCP servers (name, URL, token). At session start, crate materializes it into each agent's native config format. Registered once, preconfigured everywhere.
_Avoid_: integrations list, connectors

**Handoff**:
A short per-project markdown summary (goal, done, in-flight, next steps, gotchas) written automatically by the agent when a session ends, and injected into the next session's starting context — including on another machine. Semantic continuity, as opposed to literal transcript replay.
_Avoid_: summary, checkpoint, state file

**Host Session**:
A session with sandboxing deliberately off: the host's `/` mounted read-write, root inside the container, host PID namespace. Invoked only by explicit flag (`--host`); exists for troubleshooting the machine itself. The container is packaging, not protection.
_Avoid_: privileged mode, admin mode
