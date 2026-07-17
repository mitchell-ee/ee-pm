# Miro setup

The workflow reaches Miro one way: the official hosted Miro MCP, with a single OAuth auth path. It covers the full board build + absorb round-trip — including connectors.

## 1. The hosted Miro MCP (board build, read, update, and connectors)

The three board worker agents — `board-builder`, `absorb-interpreter`, `board-writer` — talk to Miro through the **official hosted Miro MCP** at `https://mcp.miro.com/`. You make it available by registering it as a **project-level MCP server** in your project's `.mcp.json`:

```json
{ "mcpServers": { "miro-official": { "type": "http", "url": "https://mcp.miro.com/" } } }
```

`/ee-pm:setup` (§5) writes (or merges) this for you. The agents stay fully plugin-managed — nothing is copied into your project, and they auto-update with the plugin. Their `tools:` allowlists already include `mcp__miro-official__*`, so once the server is registered the workers can reach it.

This covers everything Miro's layout DSL handles: frames, stickies, shapes, text, cards, docs, tables, **and connectors** — via `layout_get_dsl` (grammar, called once per run), `layout_create`, `layout_read`, `layout_update`. Connectors are a first-class DSL `CONNECTOR` item type, so tree edges are created, read (`layout_read` emits `CONNECTOR` lines), and rewired through this same MCP. There is no second credential.

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

## Which operation uses what

Everything goes through the one hosted MCP:

| Operation | Path |
|---|---|
| Create a new board | hosted MCP (`board_create` mints the empty board, then `layout_create` renders items into it) |
| Refresh an existing board | hosted MCP (`layout_update`) |
| Read board state for absorb | hosted MCP (`layout_read`) |
| Create / read / rewire / delete connectors | hosted MCP (DSL `CONNECTOR` via `layout_create` / `layout_read` / `layout_update`) |

There is no separate REST token, no connector scripts, and no board-copy script — a prior version of this workflow routed connectors through Miro's REST API because the layout DSL lacked a connector type; the DSL now has a first-class `CONNECTOR` type, so that second credential path is gone. The hosted MCP confirms itself the first time a board worker connects interactively (see §1).
