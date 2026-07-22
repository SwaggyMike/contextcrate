# Satchel

A single bash script for running AI coding agents (Claude Code, Codex) in disposable Docker containers on home-lab Linux machines, with session handoffs and settings synced between machines via a private git remote. Deliberately not production-grade: simple, readable, boring.

## Language

**Satchel**:
The Satchel program itself — one bash script, installed as the `satchel` command.
_Avoid_: daemon, service, platform

**Shim**:
A tiny wrapper command named `claude` or `codex` on the host PATH that execs `satchel claude` / `satchel codex`, so using Satchel feels identical to using the real CLI.
_Avoid_: alias, symlink

**Session**:
A single run of an agent CLI inside a throwaway Docker container, scoped to one directory. The container is deleted when the session ends. A directory becomes a Project only after the user opts in.
_Avoid_: workspace, environment

**Project**:
A directory the user explicitly chose to track. Project identity and handoffs are global across the fleet; each machine keeps only its local path mapping. A Git remote links checkouts automatically when present, but Git is not required.
_Avoid_: every working directory, repository (not every repository is tracked)

**Sync Repo**:
The user-owned private git repository (cloned at `~/.satchel/sync/`) that carries handoffs, tool settings, the MCP Registry, and the Skill Library between machines. Agent login credentials and transcripts never enter it.
_Avoid_: cloud, backend, server

**MCP Registry**:
The single synced file listing the user's MCP servers (name, URL, token). At session start, satchel materializes it into each agent's native config format. Registered once, preconfigured everywhere.
_Avoid_: integrations list, connectors

**Skill Library**:
The folder of agent skills carried whole in the Sync Repo, shared by both agents. Satchel mounts it into every session as that agent's own skills directory (`~/.claude/skills`, `~/.codex/skills`) — installing or removing a skill is just writing or deleting a folder there, from inside any session, and sync makes the change available to both agents on every host.
_Avoid_: plugins, marketplace

**Handoff**:
A short per-project markdown summary (goal, done, in-flight, next steps, gotchas) written automatically after a meaningful session in a tracked Project, and injected into the next session's starting context — including on another machine. Handoffs live under `projects/<id>/handoffs/`; machine directories contain only host-specific state and path mappings. Semantic continuity, as opposed to literal transcript replay.
_Avoid_: summary, checkpoint, state file

**Host Session**:
A session with sandboxing deliberately off: the host's `/` mounted read-write, root inside the container, host PID namespace. Invoked only by explicit flag (`--host`); exists for troubleshooting the machine itself. The container is packaging, not protection.
_Avoid_: privileged mode, admin mode
