# Miro setup

The workflow touches Miro two ways, with two independent auth paths. Both are needed for the full board build + absorb round-trip.

## 1. The hosted Miro MCP (board build, read, and update)

The three board worker agents — `board-builder`, `absorb-interpreter`, `board-writer` — talk to Miro through the **official hosted Miro MCP** at `https://mcp.miro.com/`. They register it inline in their frontmatter:

```yaml
mcpServers:
  - miro-official:
      type: http
      url: https://mcp.miro.com/
```

This covers everything Miro's layout DSL handles: frames, stickies, shapes, text, cards, docs, tables — via `layout_create`, `layout_read`, `layout_update`.

**Auth is OAuth at connect time.** The first time a worker connects, your LLM environment walks you through the Miro OAuth consent flow in the browser; after that the connection is authorized. There is no token to copy into a file and no custom server to run.

**Scoping principle:** the Miro MCP loads in **only** these three board workers — never in a router skill, never in the main thread. Keeping it off the main thread keeps that context clean (MCP tool schemas aren't free) and matches least privilege. The main thread, following a router skill, delegates every Miro touch to one of the three workers.

> Note on harness portability: the inline `mcpServers` frontmatter and the `tools:` allowlist syntax (`mcp__miro-official__*`) are written for an LLM environment that supports per-agent MCP registration. If your environment registers MCP servers differently, point the same three workers at the hosted Miro MCP using whatever mechanism your tool provides — the rest of the workflow is unchanged.

## 2. A Miro REST token (connectors)

Miro's layout DSL has **no connector type**, so the parent→child edges in an opportunity solution tree (and any cross-board connector) go through thin REST scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` (shared by all three board skills):

- `${CLAUDE_PLUGIN_ROOT}/scripts/read-connectors.sh <board_id>`
- `${CLAUDE_PLUGIN_ROOT}/scripts/write-connectors.sh create|update|delete <board_id> …`
- `${CLAUDE_PLUGIN_ROOT}/scripts/miro-copy-board.sh <source_board_id> <new_name>` (board copies, handy for absorb validation)

These hit `api.miro.com` directly and authenticate with a **Miro REST access token** read from the environment:

```sh
export MIRO_ACCESS_TOKEN="<your-miro-rest-access-token>"
```

Scopes needed: `boards:read` (read-connectors), `boards:write` (write-connectors, copy-board).

To get a token, create an app in the [Miro Developer settings](https://miro.com/app/settings/user-profile/apps), grant it the board scopes, and install it to your team. Miro issues an OAuth access token; export it as `MIRO_ACCESS_TOKEN`. (Tokens expire — re-issue when a script returns a 401.)

Optional: set `MIRO_TEAM_ID` so `miro-copy-board.sh` lands copies in a specific team:

```sh
export MIRO_TEAM_ID="<your-team-id>"
```

## Which path does what

| Operation | Path |
|---|---|
| Build / refresh a board | hosted MCP (`layout_create` / `layout_update`) |
| Read board state for absorb | hosted MCP (`layout_read`) |
| Read / write / delete connectors | REST script + `MIRO_ACCESS_TOKEN` |
| Copy a board (validation) | REST script + `MIRO_ACCESS_TOKEN` (+ `MIRO_TEAM_ID`) |

Story maps and assumption maps carry no connectors in their base form, so they only need the hosted MCP. Opportunity solution trees need both paths.
