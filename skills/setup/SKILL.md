---
name: setup
description: Scaffold a project to use the EE PM Workflow (ee-pm) — create the product/ artifact tree and add the workflow conventions to CLAUDE.md. Non-destructive and idempotent; safe to run in an existing repo. Use once after installing the plugin.
version: 1.0.0
category: product-management
---

# Setup Skill

Prepares the current project to use the EE PM Workflow. It creates the `product/` artifact scaffold and adds the workflow conventions to the project's `CLAUDE.md`.

This skill is **non-destructive and idempotent**. It never overwrites existing files or existing `CLAUDE.md` content, and it is safe to run more than once or in a repo that already has its own `CLAUDE.md` and directories. It always reports what it will do and asks for confirmation before writing anything.

The conventions and scaffold templates live alongside this skill:
- `templates/claude-md-block.md` — the delimited workflow-conventions block to add to `CLAUDE.md`.
- `templates/product-README.md` — the `product/` scaffold README.

## When to use

- Right after installing the `ee-pm` plugin into a project, to lay down the artifact structure and conventions.
- The PM runs it explicitly (`/ee-pm:setup`). Nothing scaffolds automatically.

## Procedure

Work against the **user's project root** — `${CLAUDE_PROJECT_DIR}` if set, otherwise the current working directory. Refer to it as `<root>` below.

### 1. Detect current state

Check, without modifying anything:

- Does `<root>/CLAUDE.md` exist?
  - If it exists, does it already contain the line `<!-- BEGIN ee-pm -->`? If so, the conventions block is already installed.
- Does `<root>/product/` exist? If so, what's already in it — is it the empty scaffold, or does it hold real content (files/subdirs other than `context/`, `iterations/`, `README.md`)?
- Does `<root>/product/context/` exist?
- Does `<root>/product/iterations/` exist?
- **Miro MCP wiring (for the board workers):** the board workers (`board-builder`, `absorb-interpreter`, `board-writer`) build and round-trip Miro boards through the official Miro MCP. They reach it by registering `miro-official` as a **project-level MCP server** (see §5). Detect, without modifying anything:
  - Is `miro-official` already a configured MCP server? (`claude mcp get miro-official` succeeds, or a `<root>/.mcp.json` declares it.)
  - If not, Miro MCP is **not wired** — the board workers will lack `mcp__miro-official__*` and can't build or read boards. Plan to offer wiring in §5.

### 2. Plan and report (dry run)

Build a plan from the detection results and **print it to the PM before writing anything**. For each item state the action: **create**, **append**, **skip (already present)**, or **ask first**.

- **`product/` tree:**
  - Missing → plan to create `product/`, `product/context/`, `product/iterations/`, and `product/README.md` (from `templates/product-README.md`).
  - Exists but missing some subdirs → plan to create only the missing subdirs / README; skip what exists.
  - Exists and holds unrelated content (not just the scaffold) → **ask first**: tell the PM what's already there and confirm it's the right place to add `context/` and `iterations/` before touching it. Never overwrite existing files.
- **`CLAUDE.md`:**
  - Missing → plan to create it with the conventions block (`templates/claude-md-block.md`).
  - Exists, already contains `<!-- BEGIN ee-pm -->` → **skip** (idempotent). Mention it's already installed.
  - Exists, no block → plan to **append** the conventions block. Show the PM the exact block that will be appended (it's delimited by `<!-- BEGIN ee-pm -->` / `<!-- END ee-pm -->`, so it can be found and removed later). Never modify their existing content.

If everything is already in place, say so and stop — there's nothing to do.

### 3. Confirm

Ask the PM to confirm the plan. Do not write until they approve. If they decline a specific item, honor that and proceed with the rest.

### 4. Apply

On approval, perform exactly the planned actions:

- Create missing `product/` directories with `mkdir -p`.
- Write `product/README.md` from the template **only if it doesn't already exist**.
- For `CLAUDE.md`:
  - Create from the template block if missing.
  - Append the template block (with a blank line before it) if the file exists without the block.
  - Do nothing if the block is already present.

Never use a destructive write on an existing file. Appending to `CLAUDE.md` means adding to the end, preserving everything above.

### 5. Register the Miro MCP (project-level)

The three board workers (`board-builder`, `absorb-interpreter`, `board-writer`) build and round-trip Miro boards through the **official Miro MCP** (`mcp__miro-official__*` at `https://mcp.miro.com/`). They reach it by registering `miro-official` as a **project-level MCP server**. The agents stay fully plugin-managed — nothing is copied into the project, and they auto-update with the plugin.

Skip this step if §1 detected `miro-official` is already configured.

**Apply** (only after confirmation, non-destructively): create `<root>/.mcp.json` if absent; if it exists, **merge** the `miro-official` key into its `mcpServers` object without disturbing other servers. Never overwrite an existing `miro-official` entry without asking.

```json
{ "mcpServers": { "miro-official": { "type": "http", "url": "https://mcp.miro.com/" } } }
```

Auth is **OAuth-at-connect**: the first time the MCP connects, Miro runs its consent flow in the browser (the PM's own Miro account; nothing stored in the repo). The grant is resolved at `claude` process startup and reused by later background/agent sessions. §7 walks the PM through authorizing it.

> **Optional advanced optimization (not enabled by default).** Registering the MCP at project level loads its tool schemas onto the **main interactive thread** every turn, which costs context tokens. There's a way to keep the MCP *only* inside the board workers (off the main thread): copy the three board-worker agents into `<root>/.claude/agents/` and uncomment the inline `mcpServers:` block in each. This is **not** done by setup, because Claude Code strips inline `mcpServers` from *plugin-provided* agents for security — the block only takes effect on *project-local* copies — and the resulting local copies stop auto-updating with the plugin, plus the auth/runtime workflow gets more fiddly (you must spawn the bare-named local agents, restart after copying, etc.). The commented block and a fuller explanation live in each agent file (`agents/board-builder.md`) and in `docs/miro-setup.md`. Only reach for it if main-thread token cost is a real concern for you.

There is a single auth path (`docs/miro-setup.md`): the hosted MCP's OAuth-at-connect. It covers boards and connectors alike — no second credential to wire. The next step verifies it.

### 6. Verify Miro MCP auth

After wiring, confirm the setup actually works rather than leaving the PM to discover a gap mid-board-build. There is one path to verify — the hosted MCP's OAuth (boards and connectors both ride on it):

- With `miro-official` registered in `<root>/.mcp.json` (§5), Claude Code surfaces it in the main thread's `/mcp` for authentication. The grant is **resolved at `claude` process startup**, so a session that was already running when §5 wrote `.mcp.json` will not see the server until restart. The OAuth handoff is harness-owned and **cannot be triggered by spawning a subagent or from a shell** — it must be done interactively via `/mcp`. Walk the PM through this exact order:
  1. **Run `/mcp`** in the main session. `miro-official` appears because `.mcp.json` declares it. Choose **Authenticate** and complete the Miro browser consent.
  2. **Exit and restart `claude` once** if `.mcp.json` was written this session — the server is picked up at startup.
  3. **Verify** by spawning `board-builder` on a trivial read (`mcp__miro-official__context_get` against any board). It should resolve the tools and return board context.

  Tell the PM plainly: *"Register `miro-official`, authenticate it via `/mcp`, then (if it was just added) exit and restart Claude once. Background runs reuse the grant."* If the current session is non-interactive (a background run), `/mcp` isn't available — report: *"Finish Miro auth in an interactive session: run `/mcp` → Authenticate `miro-official`, then restart Claude once."*

### 6.5. Restart the session if the MCP was just registered

A `miro-official` server added to `.mcp.json` this session is only picked up at the next `claude` startup. So: **if this run wrote `.mcp.json`, tell the PM to restart the session before building a board** (exit and relaunch Claude Code in this project), then authorize via `/mcp` per §6. If `miro-official` was already registered (nothing newly wired this run), no restart is needed; say so.

### 7. Report and next steps

Summarize what was created, appended, or skipped. Then tell the PM the next steps:

1. **Restart if the MCP was newly registered** — if §5 wrote `.mcp.json` this run, restart the session first (see §6.5) before any board work.
2. **Connect Miro** — see `docs/miro-setup.md` in the plugin. The board workers reach the official hosted Miro MCP via the `miro-official` server registered in §5 (`<root>/.mcp.json`). Authorize Miro via `/mcp` → Authenticate `miro-official` in the main session, then (if just added) **exit and restart `claude` once** so the grant loads (see §6); background runs reuse the grant. This single OAuth grant covers boards **and** connectors — there is no second credential to configure. If §5 was skipped, the workers can't reach Miro until you re-run `/ee-pm:setup` and register the MCP.
3. **Bring a design system** — the prototyping skills ship with Equal Experts' Kuat as a worked example; point them at your own design system to use it.
4. **Establish product context** — run `/ee-pm:framework-setup` once.
5. **Start an iteration** — run `/ee-pm:iteration-setup` per iteration.

## Notes

- This skill writes only into the user's project — `product/`, `CLAUDE.md`, and (per §5, only with consent) `.mcp.json`. It never writes into the plugin's own directory.
- Re-running is safe: a second run detects the installed block, the existing scaffold, and the §5 `miro-official` registration, and skips rather than overwriting.
- To uninstall: delete the block between `<!-- BEGIN ee-pm -->` and `<!-- END ee-pm -->` in `CLAUDE.md`, and remove the `miro-official` key from `.mcp.json`.
