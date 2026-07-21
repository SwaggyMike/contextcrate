# ContextCrate

Run AI coding agents (Claude Code, Codex) in disposable Docker/Podman
containers, with session handoffs, MCP servers, and skills synced between
your machines through a private git repo you own.

One bash script. No daemon, no database, no cloud — plain files and plain
git. Built for home-lab Linux boxes, Unraid included. Deliberately not
production-grade: simple, readable, boring.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/SwaggyMike/contextcrate/main/install.sh | bash
crate init
```

`init` names the machine and connects your private Sync Repo (self-hosted
Gitea, private GitHub repo, or a bare repo on any SSH box). Then, in any
project:

```sh
claude        # Claude Code in a throwaway container, scoped to this directory
```

The container sees only the project directory, runs as a non-root user, and
is deleted when the session ends. Log in once (or `crate import claude` to
copy the host's login); every session after that starts authenticated. When
a session ends, the agent writes a short handoff; the next session on that
project — on any machine — picks it up.

## Commands

| command | what it does |
| --- | --- |
| `crate claude` / `crate codex` | run a session in `$PWD` (the `claude`/`codex` shims do the same) |
| `crate --host claude` | Host Session: sandbox off, host `/` at `/host` — for fixing the machine itself |
| `crate init` | name this machine, connect the Sync Repo |
| `crate sync` | commit, pull, push the Sync Repo |
| `crate status` | fleet roster, handoffs, MCP servers, skills |
| `crate import claude\|codex` | copy the host's agent login into crate's sessions |
| `crate mcp add\|list\|remove` | manage the MCP Registry (configured once, wired into every session) |
| `crate snapshot <name>` / `crate drift <name>` | snapshot a host container's config, later diff and restart — for UIs that regenerate containers |
| `crate update` | self-update from `main` and rebuild the agent image |

## What syncs, what doesn't

Handoffs, MCP registry + tokens (private repo, your SSH keys — see
[ADR 0002](docs/adr/0002-mcp-tokens-in-sync-repo.md)), and the per-agent
skill library ([ADR 0003](docs/adr/0003-skills-as-mounted-per-agent-libraries.md))
sync. Agent logins and transcripts never do.

Vocabulary lives in [CONTEXT.md](CONTEXT.md); decisions in [docs/adr/](docs/adr/).
