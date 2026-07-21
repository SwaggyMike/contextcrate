# MCP tokens are synced through the private git repo by default

The point of the MCP Registry is "register a server once, every machine is preconfigured" — and that only fully works if tokens travel too. So tokens live in their own file (`mcp-tokens.env`, chmod 600) in the Sync Repo, separate from the registry (`mcp.json`), and sync by default. The threat model: the Sync Repo is a private repo the user owns, reached over their own SSH keys; anyone who can read it already has their handoffs and settings, so home-lab MCP tokens don't meaningfully raise the stakes. Agent login credentials (Claude/Codex OAuth) and transcripts still never sync — that line stays hard.

## Considered Options

- **Tokens per-machine only** (v1's rule): breaks set-up-once-everywhere; every new machine prompts per server.
- **Encrypted tokens** (age/sops + passphrase): reintroduces ceremony for an audience that doesn't exist yet.
- **Chosen — plaintext in the private repo, with a built-in opt-out**: satchel prompts for any token it can't find and offers to save it synced or local-only, so gitignoring `mcp-tokens.env` turns the per-machine mode on with zero extra code.

## Consequences

- Removed/rotated tokens persist in git history; users who care should rotate at the source.
- The opt-out must stay a one-liner (gitignore + prompt-on-missing), or this decision should be revisited.
