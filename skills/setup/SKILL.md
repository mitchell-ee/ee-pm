---
name: setup
description: Scaffold a project to use the Visual Collaboration with AI (vcw) workflow — create the product/ artifact tree and add the workflow conventions to CLAUDE.md. Non-destructive and idempotent; safe to run in an existing repo. Use once after installing the plugin.
version: 1.0.0
category: product-management
---

# Setup Skill

Prepares the current project to use the Visual Collaboration with AI workflow. It creates the `product/` artifact scaffold and adds the workflow conventions to the project's `CLAUDE.md`.

This skill is **non-destructive and idempotent**. It never overwrites existing files or existing `CLAUDE.md` content, and it is safe to run more than once or in a repo that already has its own `CLAUDE.md` and directories. It always reports what it will do and asks for confirmation before writing anything.

The conventions and scaffold templates live alongside this skill:
- `templates/claude-md-block.md` — the delimited workflow-conventions block to add to `CLAUDE.md`.
- `templates/product-README.md` — the `product/` scaffold README.

## When to use

- Right after installing the `vcw` plugin into a project, to lay down the artifact structure and conventions.
- The PM runs it explicitly (`/vcw:setup`). Nothing scaffolds automatically.

## Procedure

Work against the **user's project root** — `${CLAUDE_PROJECT_DIR}` if set, otherwise the current working directory. Refer to it as `<root>` below.

### 1. Detect current state

Check, without modifying anything:

- Does `<root>/CLAUDE.md` exist?
  - If it exists, does it already contain the line `<!-- BEGIN vcw -->`? (If so, the conventions block is already installed.)
- Does `<root>/product/` exist? If so, what's already in it — is it the empty scaffold, or does it hold real content (files/subdirs other than `context/`, `iterations/`, `README.md`)?
- Does `<root>/product/context/` exist?
- Does `<root>/product/iterations/` exist?
- **Miro MCP wiring (for the board workers):** check how — or whether — the board workers (`board-builder`, `absorb-interpreter`, `board-writer`) can reach the official Miro MCP in this project. Detect, without modifying anything:
  - Is `miro-official` already a configured MCP server? (`claude mcp get miro-official` succeeds, or a `<root>/.mcp.json` declares it.)
  - Do project-local copies of the three board workers already exist at `<root>/.claude/agents/{board-builder,absorb-interpreter,board-writer}.md`? If so, read the `vcw-source-version:` stamp in each (see §5) and compare against the installed plugin version (`.claude-plugin/plugin.json:version`).
  - If neither is present, Miro MCP is **not wired** — the board workers will silently lack `mcp__miro-official__*` and fall back to raw REST. Plan to offer wiring in §5.

### 2. Plan and report (dry run)

Build a plan from the detection results and **print it to the PM before writing anything**. For each item state the action: **create**, **append**, **skip (already present)**, or **ask first**.

- **`product/` tree:**
  - Missing → plan to create `product/`, `product/context/`, `product/iterations/`, and `product/README.md` (from `templates/product-README.md`).
  - Exists but missing some subdirs → plan to create only the missing subdirs / README; skip what exists.
  - Exists and holds unrelated content (not just the scaffold) → **ask first**: tell the PM what's already there and confirm it's the right place to add `context/` and `iterations/` before touching it. Never overwrite existing files.
- **`CLAUDE.md`:**
  - Missing → plan to create it with the conventions block (`templates/claude-md-block.md`).
  - Exists, already contains `<!-- BEGIN vcw -->` → **skip** (idempotent). Mention it's already installed.
  - Exists, no block → plan to **append** the conventions block. Show the PM the exact block that will be appended (it's delimited by `<!-- BEGIN vcw -->` / `<!-- END vcw -->`, so it can be found and removed later). Never modify their existing content.

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

### 5. Wire the board workers to Miro (MCP routing)

The three board workers (`board-builder`, `absorb-interpreter`, `board-writer`) build and round-trip Miro boards through the **official Miro MCP** (`mcp__miro-official__*` at `https://mcp.miro.com/`). They declare it inline in their frontmatter (`mcpServers: miro-official`). This works **only when the agents are project-local** — for security, **Claude Code ignores the `mcpServers`, `hooks`, and `permissionMode` frontmatter fields on plugin-provided agents** (verified behavior; see Claude Code sub-agents docs). Because vcw ships these agents *in the plugin*, their inline `mcpServers` is silently dropped, and the workers fall back to raw REST — which builds boards but cannot do the `layout_read`-based `absorb`/`refresh` round-trip.

There is no way to keep the MCP both plugin-managed **and** agent-scoped at once. So setup offers the PM a deliberate choice — skip this step entirely if §1 detected Miro MCP is already wired (a configured `miro-official` server, or up-to-date local agent copies).

Present the tradeoff and ask the PM to pick one route (default: **A**):

- **Route A — agent-scoped MCP (copy the 3 board workers local).** Keeps the (large) Miro MCP **off the main interactive thread** — its tool schemas load only inside the workers. Setup copies `board-builder.md`, `absorb-interpreter.md`, `board-writer.md` from the plugin's `agents/` into `<root>/.claude/agents/`, preserving their inline `mcpServers`. A project-local agent with the same `name:` overrides the plugin's. *Cost:* those three files become local overrides that don't auto-update with the plugin.
  - **Version stamp + re-sync.** When copying, inject a `vcw-source-version: {plugin version}` line into each copied agent's frontmatter (just below `name:`). On a later `/vcw:setup` run, §1 compares this stamp to the installed plugin version; if the plugin is newer, report it and **offer to re-copy** (re-apply the override from the new plugin source). Never silently overwrite — always prompt.
  - The first time a worker connects, the Miro MCP runs its OAuth-at-connect flow in the browser (the PM's own Miro account; nothing stored in the repo).

- **Route B — project-scoped MCP (register `miro-official` globally for the project).** Agents stay **fully plugin-managed** (no local copies, auto-update with the plugin). Setup writes/merges `<root>/.mcp.json` with:
  ```json
  { "mcpServers": { "miro-official": { "type": "http", "url": "https://mcp.miro.com/" } } }
  ```
  *Cost:* the MCP loads into the **main thread** too, so its tool schemas consume main-thread context every turn. Choose this if main-thread token cost is acceptable and zero local agent copies is preferred.

- **Route C — skip for now.** Do nothing. The board workers run REST-only: `create` works (boards build via the Miro REST API + `MIRO_ACCESS_TOKEN`), but `absorb`/`refresh` round-trips are unavailable until the PM wires the MCP (re-run `/vcw:setup` later to choose A or B).

**Apply** the chosen route only after confirmation, non-destructively:
- Route A: `mkdir -p <root>/.claude/agents`; copy only the three files **if they don't already exist** (or on an approved re-sync); add the `vcw-source-version` stamp. Never touch other agents.
- Route B: create `<root>/.mcp.json` if absent; if it exists, **merge** the `miro-official` key into its `mcpServers` object without disturbing other servers. Never overwrite an existing `miro-official` entry without asking.
- Route C: write nothing.

Regardless of route, both auth paths from `docs/miro-setup.md` still apply: the hosted MCP uses OAuth-at-connect; the connector REST scripts use `MIRO_ACCESS_TOKEN`.

### 6. Report and next steps

Summarize what was created, appended, or skipped. Then tell the PM the next steps:

1. **Connect Miro** — see `docs/miro-setup.md` in the plugin. The board workers reach the official hosted Miro MCP via the route chosen in §5 (Route A: local agent copies; Route B: project `.mcp.json`); the first connection runs Miro OAuth in the browser. The connector REST scripts additionally use a `MIRO_ACCESS_TOKEN` environment variable. If §5 was skipped (Route C), the workers are REST-only until you re-run `/vcw:setup` and pick A or B.
2. **Bring a design system** — the prototyping skills ship with Equal Experts' Kuat as a worked example; point them at your own design system to use it.
3. **Establish product context** — run `/vcw:framework-setup` once.
4. **Start an iteration** — run `/vcw:iteration-setup` per iteration.

## Notes

- This skill writes only into the user's project — `product/`, `CLAUDE.md`, and (per §5, only with consent) `.claude/agents/` or `.mcp.json`. It never writes into the plugin's own directory.
- Re-running is safe: a second run detects the installed block, the existing scaffold, and the §5 Miro wiring (including the `vcw-source-version` stamp on local agent copies) and skips or offers a re-sync rather than overwriting.
- To uninstall: delete the block between `<!-- BEGIN vcw -->` and `<!-- END vcw -->` in `CLAUDE.md`; for Route A, delete the three copied agents from `.claude/agents/`; for Route B, remove the `miro-official` key from `.mcp.json`.
- **Why §5 exists:** plugin-provided agents cannot carry agent-scoped MCP (Claude Code ignores `mcpServers` on plugin agents). Route A trades plugin-managed updates for main-thread token isolation; Route B trades token isolation for zero local copies. The PM owns that tradeoff per project.
