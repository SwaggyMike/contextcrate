# Satchel

Run AI coding agents (Claude Code, Codex) in disposable Docker/Podman
containers, with session handoffs, MCP servers, and skills synced between
your machines through a private git repo you own.

One bash script. No daemon, no database, no cloud — plain files and plain
git. Built for home-lab Linux boxes, Unraid included. Deliberately not
production-grade: simple, readable, boring.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/SwaggyMike/satchel/main/install.sh | bash
satchel init
```

`init` names the machine and connects your private Sync Repo (self-hosted
Gitea, private GitHub repo, or a bare repo on any SSH box). Then, in any
project:

```sh
claude        # Claude Code in a throwaway container, scoped to this directory
```

The container sees only the project directory, runs as a non-root user, and
is deleted when the session ends — and the agent is told exactly that, so it
answers "that file is outside the sandbox" instead of pretending your
machine's files don't exist (in a Host Session it knows the machine lives
at `/host`). Log in once (or `satchel import claude` to
copy the host's login); every session after that starts authenticated. When
a session ends, the agent writes a short handoff; the next session on that
project — on any machine — picks it up.

## Commands

| command | what it does |
| --- | --- |
| `satchel claude` / `satchel codex` | run a session in `$PWD` (the `claude`/`codex` shims do the same) |
| `satchel --host claude` | Host Session: sandbox off, host `/` at `/host` — for fixing the machine itself |
| `satchel init` | name this machine, connect the Sync Repo |
| `satchel sync` | commit, pull, push the Sync Repo |
| `satchel status` | fleet roster, handoffs, MCP servers, skills |
| `satchel key` | show this machine's SSH public key (generates one if needed) |
| `satchel retire [machine]` | remove a machine from the fleet — interactive picker without a name |
| `satchel import claude\|codex` | copy the host's agent login into satchel's sessions |
| `satchel mcp add\|list\|remove` | manage the MCP Registry (configured once, wired into every session) |
| `satchel settings` | show every setting and its value; `satchel settings <KEY> <value>` sets it fleet-wide, `--local` for one machine |
| `satchel doctor` | check this machine's setup end to end — engine, image, key, sync, MCP endpoints |
| `satchel snapshot <name>` / `satchel drift <name>` | snapshot a host container's config, later diff and restart — for UIs that regenerate containers |
| `satchel update` | self-update from `main` (lists the commits it pulls in) and rebuild the agent image |

## What syncs, what doesn't

Handoffs, MCP registry + tokens (private repo, your SSH keys — see
[ADR 0002](docs/adr/0002-mcp-tokens-in-sync-repo.md)), and the per-agent
skill library ([ADR 0003](docs/adr/0003-skills-as-mounted-per-agent-libraries.md))
sync. Agent logins and transcripts never do.

Vocabulary lives in [CONTEXT.md](CONTEXT.md); decisions in [docs/adr/](docs/adr/).
