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

> This consent step is **interactive-only** — it needs a browser handoff, so it cannot be completed inside a background/headless run. Authorize once in an interactive session (run any board operation, or `/vcw:setup` §7 which probes it for you); background jobs work thereafter. If a board worker reports `status: auth-required` or the tools show as "No such tool available," this consent hasn't been done yet.

**Scoping principle:** the Miro MCP loads in **only** these three board workers — never in a router skill, never in the main thread. Keeping it off the main thread keeps that context clean (MCP tool schemas aren't free) and matches least privilege. The main thread, following a router skill, delegates every Miro touch to one of the three workers.

> Note on harness portability: the inline `mcpServers` frontmatter and the `tools:` allowlist syntax (`mcp__miro-official__*`) are written for an LLM environment that supports per-agent MCP registration. If your environment registers MCP servers differently, point the same three workers at the hosted Miro MCP using whatever mechanism your tool provides — the rest of the workflow is unchanged.

## 2. A Miro REST token (connectors), auto-managed

Miro's layout DSL has **no connector type**, so the parent→child edges in an opportunity solution tree (and any cross-board connector) go through thin REST scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` (shared by all three board skills):

- `${CLAUDE_PLUGIN_ROOT}/scripts/read-connectors.sh <board_id>`
- `${CLAUDE_PLUGIN_ROOT}/scripts/write-connectors.sh create|update|delete <board_id> …`
- `${CLAUDE_PLUGIN_ROOT}/scripts/miro-copy-board.sh <source_board_id> <new_name>` (board copies, handy for absorb validation)

These hit `api.miro.com` directly and authenticate with a **Miro REST access token** in the `MIRO_ACCESS_TOKEN` environment variable. Scopes needed: `boards:read` (read-connectors), `boards:write` (write-connectors, copy-board).

Rather than export a token by hand and re-issue it on every expiry, `/vcw:setup` (§6) installs a small token lifecycle so the token refreshes itself:

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

# Option C — persisted env file (the portable cross-session default; what /vcw:setup writes)
#   ~/.config/<project>/miro-client.env  (mode 0600), two lines:
#     MIRO_CLIENT_ID=<client id>
#     MIRO_CLIENT_SECRET=<client secret>
```

**Why persistence matters.** `miro-fresh-token.sh` resolves the client credentials on *every* session — it needs them to exchange the refresh token, not just once at bootstrap. A shell `export` does not survive to the next session, so Option A alone leaves the `SessionStart` hook unable to refresh next time (you'd see `miro-verify.sh` report "credentials not resolvable" after a restart). Option B (1Password) and Option C (the 0600 `miro-client.env`) both persist, which is why `/vcw:setup` writes one of them. `/vcw:setup` also notes that the freshly-installed agents and `SessionStart` hook only take effect after a session restart.

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
