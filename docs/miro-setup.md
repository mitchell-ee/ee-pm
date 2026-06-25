# Miro setup

The workflow touches Miro two ways, with two independent auth paths. Both are needed for the full board build + absorb round-trip.

## 1. The hosted Miro MCP (board build, read, and update)

The three board worker agents — `board-builder`, `absorb-interpreter`, `board-writer` — talk to Miro through the **official hosted Miro MCP** at `https://mcp.miro.com/`. You make it available by registering it as a **project-level MCP server** in your project's `.mcp.json`:

```json
{ "mcpServers": { "miro-official": { "type": "http", "url": "https://mcp.miro.com/" } } }
```

`/ee-pm:setup` (§5) writes (or merges) this for you. The agents stay fully plugin-managed — nothing is copied into your project, and they auto-update with the plugin. Their `tools:` allowlists already include `mcp__miro-official__*`, so once the server is registered the workers can reach it.

This covers everything Miro's layout DSL handles: frames, stickies, shapes, text, cards, docs, tables — via `layout_create`, `layout_read`, `layout_update`.

**Auth is OAuth at connect time.** Once `miro-official` is registered, your LLM environment surfaces it for authentication (in Claude Code, via `/mcp`). The first time it connects, you walk through the Miro OAuth consent flow in the browser; after that the connection is authorized. There is no token to copy into a file and no custom server to run.

> This consent step needs a **browser handoff and the interactive main session** — it is harness-owned and cannot be initiated from a spawned subagent or a shell. Complete it once during `/ee-pm:setup` §7 (run `/mcp` → Authenticate `miro-official`, then restart Claude once if the server was just added). After that the grant is reused, including by later background/agent runs. If a board worker reports `status: auth-required` or the tools show as "No such tool available," either the server isn't registered yet (check `.mcp.json`) or this consent hasn't been completed.

> Note on harness portability: the project-level `.mcp.json` registration and the `tools:` allowlist syntax (`mcp__miro-official__*`) are written for an LLM environment that supports HTTP MCP servers. If your environment registers MCP servers differently, point it at the hosted Miro MCP using whatever mechanism your tool provides — the rest of the workflow is unchanged.

### Optional: agent-scoped MCP (an advanced token-saving optimization)

Registering `miro-official` at the project level loads its tool schemas onto the **main interactive thread** every turn, which costs context tokens. If that cost matters to you, there's a way to load the Miro MCP **only inside the three board workers** — off the main thread entirely:

1. Copy `board-builder.md`, `absorb-interpreter.md`, `board-writer.md` from the plugin's `agents/` into your project's `.claude/agents/`.
2. In each copy, **uncomment** the inline `mcpServers:` block (it ships commented for exactly this purpose).
3. **Do not** also register `miro-official` in `.mcp.json` — pick one or the other; running both reintroduces the main-thread load you were trying to avoid.
4. Spawn the **bare-named** local workers (`board-builder`), not the plugin-namespaced `ee-pm:board-builder` — the latter is the plugin agent whose inline `mcpServers` Claude Code strips (see below), so it returns "No such tool available."
5. Restart Claude once after copying so the local agents load.

**Why this isn't the default.** For security, Claude Code **ignores the `mcpServers` frontmatter on plugin-provided agents** — the inline block only takes effect on a *project-local* copy of the agent. So the plugin can't ship this working out of the box; it would silently do nothing. On top of that, the local copies stop auto-updating with the plugin, and the auth/runtime workflow gets more fiddly (bare-named spawns, restarts). The default project-level registration "just works" with none of that. Only adopt the agent-scoped route if main-thread token cost is a real concern for you.

## 2. A Miro REST token (connectors), auto-managed

Miro's layout DSL has **no connector type**, so the parent→child edges in an opportunity solution tree (and any cross-board connector) go through thin REST scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` (shared by all three board skills):

- `${CLAUDE_PLUGIN_ROOT}/scripts/read-connectors.sh <board_id>`
- `${CLAUDE_PLUGIN_ROOT}/scripts/write-connectors.sh create|update|delete <board_id> …`
- `${CLAUDE_PLUGIN_ROOT}/scripts/miro-copy-board.sh <source_board_id> <new_name>` (board copies, handy for absorb validation)

These hit `api.miro.com` directly and authenticate with a **Miro REST access token** in the `MIRO_ACCESS_TOKEN` environment variable. Scopes needed: `boards:read` (read-connectors), `boards:write` (write-connectors, copy-board).

Rather than export a token by hand and re-issue it on every expiry, `/ee-pm:setup` (§6) installs a small token lifecycle so the token refreshes itself:

- `miro-oauth-bootstrap.sh` — **run once.** Opens the Miro consent page, exchanges the code, and writes `{access_token, refresh_token, expires_epoch}` to `~/.config/<project>/miro-tokens.json` (mode 0600, outside the repo).
- `miro-fresh-token.sh` — **runs every session,** via a `SessionStart` hook setup installs. Prints a valid token, transparently refreshing it (using the stored refresh token) when it's within 5 minutes of expiry, and exports it as `MIRO_ACCESS_TOKEN`.
- `miro-verify.sh` — **run any time** to check the path: credentials resolvable, token file present, refresh works, not expired.

### Providing the app's client credentials

The bootstrap and refresh scripts need a Miro app's `client_id`/`client_secret`. Create the app in the [Miro Developer settings](https://miro.com/app/settings/user-profile/apps), grant the board scopes (`boards:read`, `boards:write`), and install it to a **non-developer workspace** (developer-team boards carry a "Created with" watermark). Then make the credentials resolvable one of three ways (`miro-token-lib.sh` checks them in this order; an env var or 1Password ref overrides the persisted file):

```sh
# Option A — environment variables (transient; good for a one-off shell)
export MIRO_CLIENT_ID="<client id>"
export MIRO_CLIENT_SECRET="<client secret>"

# Option B — 1Password (or any tool exposing the `op` CLI)
export MIRO_OP_ITEM="op://<vault>/<item>"   # reads <item>/username and <item>/credential

# Option C — persisted env file (the portable cross-session default; what /ee-pm:setup writes)
#   ~/.config/<project>/miro-client.env  (mode 0600), two lines:
#     MIRO_CLIENT_ID=<client id>
#     MIRO_CLIENT_SECRET=<client secret>
```

**Why persistence matters.** `miro-fresh-token.sh` resolves the client credentials on *every* session — it needs them to exchange the refresh token, not just once at bootstrap. A shell `export` does not survive to the next session, so Option A alone leaves the `SessionStart` hook unable to refresh next time (you'd see `miro-verify.sh` report "credentials not resolvable" after a restart). Option B (1Password) and Option C (the 0600 `miro-client.env`) both persist, which is why `/ee-pm:setup` writes one of them. `/ee-pm:setup` also notes that a freshly-written `.mcp.json` and the `SessionStart` hook only take effect after a session restart.

Optional overrides: `MIRO_TOKEN_FILE` (token path), `MIRO_CLIENT_ENV_FILE` (persisted-credentials path), `MIRO_PROJECT_NAME` (the `<project>` segment of the default paths), `MIRO_REDIRECT_PORT` (OAuth callback port, default 8888), `MIRO_REFRESH_MARGIN_SEC` (refresh lead time, default 300), `MIRO_TEAM_ID` (so `miro-copy-board.sh` lands copies in a specific team).

### Manual fallback

If you'd rather not install the lifecycle, you can still export a token directly — `export MIRO_ACCESS_TOKEN="<token>"` — and re-issue it when a script returns 401. The scripts read the env var either way.

## Which path does what

| Operation | Path |
|---|---|
| Build / refresh a board | hosted MCP (`layout_create` / `layout_update`) |
| Read board state for absorb | hosted MCP (`layout_read`) |
| Read / write / delete connectors | REST script + `MIRO_ACCESS_TOKEN` |
| Copy a board (validation) | REST script + `MIRO_ACCESS_TOKEN` (+ `MIRO_TEAM_ID`) |

Story maps and assumption maps carry no connectors in their base form, so they only need the hosted MCP (path 1). Opportunity solution trees need both paths. Run `miro-verify.sh` to confirm the REST path; the hosted MCP confirms itself the first time a board worker connects interactively.
