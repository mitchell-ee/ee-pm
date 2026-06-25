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
- **Connector token automation (§6):** detect, without modifying anything, whether the REST-token lifecycle is already installed:
  - Are the token scripts present at `<root>/.claude/scripts/{miro-token-lib,miro-fresh-token,miro-oauth-bootstrap,miro-verify}.sh`?
  - Does `<root>/.claude/settings.local.json` contain a `SessionStart` hook referencing `miro-fresh-token.sh`?
  - Are client credentials already resolvable for this project — `MIRO_CLIENT_ID`/`MIRO_CLIENT_SECRET` in the environment, a `MIRO_OP_ITEM` 1Password reference, or a persisted `~/.config/<project>/miro-client.env` (mode 0600)? This drives whether §6 needs to run the credential sub-flow (3a–3c) or only the bootstrap.
  - If the scripts and hook are present **and** credentials resolve, the token path is wired — skip §6 (still let §7 verify it). If only some pieces are present, plan to install the missing ones. Note that the actual token file (`~/.config/<project>/miro-tokens.json`) is outside the repo; its presence/validity is checked by §7's verify, not here.

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
  - The first time a worker connects, the Miro MCP runs its OAuth-at-connect flow in the browser (the PM's own Miro account; nothing stored in the repo). **This OAuth grant is interactive and is meant to be completed here, during setup (§7) — it is harness-owned and cannot be triggered from a spawned subagent or a shell. Once granted, later background/agent sessions reuse it.**
  - **Runtime enforcement (consumer rule).** Once the local copies exist, the main thread MUST spawn the **bare-named** workers (`board-builder`, `absorb-interpreter`, `board-writer`) — the local override that carries the inline `mcpServers`. It MUST NOT spawn the plugin-namespaced `vcw:board-builder` / `vcw:absorb-interpreter` / `vcw:board-writer`: those are the plugin agents whose inline `mcpServers` Claude Code strips, so they return "No such tool available: mcp__miro-official__*". Both names may appear as selectable agent types; picking the namespaced one silently defeats Route A. If a board worker reports the Miro tools missing, first confirm the bare-named local agent was spawned before assuming an OAuth gap.
  - **Never also register a project/global `miro-official` server** (that is Route B). Route A and Route B are mutually exclusive by design; adding a `.mcp.json` / global `miro-official` entry loads the MCP onto the main thread and defeats the off-main-thread isolation Route A exists to provide. If a stray `miro-official` server appears in project or user config on a Route A project, remove it.

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

Regardless of route, both auth paths from `docs/miro-setup.md` still apply: the hosted MCP uses OAuth-at-connect; the connector REST scripts use `MIRO_ACCESS_TOKEN`. The next two steps automate that second path and verify both.

### 6. Wire the connector REST token (auto-refresh)

Opportunity-solution-tree connectors go through REST scripts (`write-connectors.sh` etc.) that read `MIRO_ACCESS_TOKEN` from the environment. Rather than have the PM hand-export a token that silently expires, setup installs the token-lifecycle scripts and a `SessionStart` hook that injects a freshly-refreshed token each session. Skip this step if §1 found the token automation already installed (the three `miro-*.sh` scripts present in `<root>/.claude/scripts/` **and** a `SessionStart` hook referencing `miro-fresh-token.sh` in `settings.local.json`).

Story maps and assumption maps carry no connectors, so a PM who only uses those can decline this step — the hosted MCP alone suffices. Offer it, default **yes** for OST users.

**Apply** (only after confirmation, non-destructively):

1. **Copy the token scripts.** `mkdir -p <root>/.claude/scripts`; copy `miro-token-lib.sh`, `miro-fresh-token.sh`, `miro-oauth-bootstrap.sh`, and `miro-verify.sh` from the plugin's `scripts/` into `<root>/.claude/scripts/` **only if they don't already exist** (or on an approved re-sync). `chmod +x` the copies. (`miro-token-lib.sh` is sourced by all the others — it must be copied too, not just the executables.) Never overwrite without prompting.
2. **Merge the SessionStart hook** into `<root>/.claude/settings.local.json` (create the file if absent; deep-merge the `hooks.SessionStart` array without disturbing existing hooks). The hook refreshes and exports the token:
   ```json
   {
     "hooks": {
       "SessionStart": [
         { "hooks": [ {
           "type": "command",
           "command": "tok=\"$(\"$CLAUDE_PROJECT_DIR/.claude/scripts/miro-fresh-token.sh\" 2>/dev/null)\" && [ -n \"$tok\" ] && printf 'MIRO_ACCESS_TOKEN=%s\\n' \"$tok\" >> \"$CLAUDE_ENV_FILE\" || true",
           "statusMessage": "Refreshing Miro REST token"
         } ] }
       ]
     }
   }
   ```
   The `|| true` and `2>/dev/null` keep a session with no token configured from failing to start — the hook is a no-op until bootstrap runs. `miro-fresh-token.sh` resolves the client credentials itself (via `miro-token-lib.sh`, which now reads the persisted `miro-client.env` written in step 3), so the hook needs no credentials in its own environment — that is exactly why step 3 persists them to a file rather than relying on a shell `export` that won't survive to the next session.
3. **Generate, persist, and bootstrap the credentials — walk the PM through it end to end.** Do not just tell the PM credentials are "needed" and stop; carry them all the way to a working, durable token. The only step that genuinely can't be automated is creating the Miro app inside Miro's console — guide that with an explicit checklist, then take the credentials back and do the rest.

   First, **detect what's already resolvable** so you don't ask for what you don't need. Run `<root>/.claude/scripts/miro-verify.sh` (or call `miro_resolve_client_creds` via a one-off source). If credentials already resolve (env, 1Password, or a persisted `miro-client.env` from a prior run) **and** the token file exists and verifies, this step is done — say so and skip to §7.

   Otherwise walk the sub-flow:

   **3a. Create the Miro app (PM action — the one manual step).** Print this exact checklist and offer to open the URL:
   - Open <https://miro.com/app/settings/user-profile/apps> and click **Create new app**.
   - Name it (e.g. "vcw connectors"), leave it as a non-Expanded app.
   - Under **Permissions**, grant **`boards:read`** and **`boards:write`**.
   - **Install the app into a non-developer workspace.** Boards created under a developer team carry a "Created with <app>" watermark; installing into a normal team avoids it.
   - From the app page, copy the **Client ID** and **Client secret**.

   **3b. Capture the credentials (paste-back).** Ask the PM to paste the `client_id` and `client_secret`. Treat them as secrets: don't echo them back in full in your narration, and don't write them anywhere except the chosen store below.

   **3c. Persist them durably — this is the step that makes it survive restarts.** The refresh script needs the credentials on **every** session, not just at bootstrap, and a shell `export` does not persist. Pick the store, defaulting by what's available:
   - If the `op` (1Password) CLI is present and the PM prefers it: store the pair as a 1Password item and set `MIRO_OP_ITEM="op://<vault>/<item>"` in their durable shell profile. Nothing secret touches disk in the repo or `~/.config`.
   - Otherwise (portable default): write them to the persisted env file at the path `miro_client_env_file` resolves to (`~/.config/<project>/miro-client.env`). Create the dir with `mkdir -p` + `chmod 700`, write the file with **mode 0600**, exactly two lines:
     ```
     MIRO_CLIENT_ID=<client id>
     MIRO_CLIENT_SECRET=<client secret>
     ```
     `miro-token-lib.sh` reads this file as its third credential source, so the `SessionStart` hook's `miro-fresh-token.sh` call picks it up automatically every session with nothing exported. This file is outside the repo and must never be committed.

   **3d. Bootstrap the token (PM-approved, opens a browser).** With credentials now resolvable, run `<root>/.claude/scripts/miro-oauth-bootstrap.sh`. It opens the Miro consent page once, exchanges the code, and writes the refreshable token file (`~/.config/<project>/miro-tokens.json`, 0600). **Confirm before running — it opens a browser — and it requires an interactive session.** In a non-interactive (background/headless) run, do steps 3a–3c if possible but **defer 3d**: report that the bootstrap must be run once interactively (`<root>/.claude/scripts/miro-oauth-bootstrap.sh`), after which the `SessionStart` hook keeps the token fresh.

### 7. Verify both auth paths

After wiring, confirm the setup actually works rather than leaving the PM to discover a gap mid-board-build:

- **REST token:** run `<root>/.claude/scripts/miro-verify.sh` and report its table (credentials resolvable, token file present, refresh works, not expired). If it exits non-zero, surface the blocking line. If §6 just persisted credentials to `miro-client.env` and ran bootstrap, this should now be all-green; if it still shows "credentials not resolvable," the persist step (3c) didn't land — re-check the file path and mode before moving on.
- **Hosted MCP (Route A — the authoritative sequence).** Under Route A the inline `miro-official` server is declared in the local agent files, so Claude Code surfaces it in the **main thread's `/mcp`** for authentication, yet only *connects* it (loads `mcp__miro-official__*`) when a board worker actually runs — exactly the off-main-thread property Route A wants. The grant is **resolved at `claude` process startup**, so a session that was already running when §5 wrote the agents (or before the grant) will not see the tools until restart. The OAuth handoff is harness-owned and **cannot be triggered by spawning a subagent or from a shell** — it must be done interactively via `/mcp`. Walk the PM through this exact order:
  1. **Run `/mcp`** in the main session. `miro-official` appears because the local agents declare it inline. Choose **Authenticate** and complete the Miro browser consent. (This is the one unavoidable manual step — that's fine.)
  2. **Exit and restart `claude` once.** The grant and the inline-agent server are picked up at startup; without the restart the next board-worker spawn still reports "No such tool available." After restart, the MCP loads **only inside the board workers**, never the main thread.
  3. **Verify** by spawning the **bare-named** local `board-builder` (NOT `vcw:board-builder`) on a trivial read (`mcp__miro-official__context_get` against any board). It should resolve the tools and return board context. If it still reports the tools missing, re-check that the bare-named local agent was spawned and that the restart actually happened.

  Tell the PM plainly: *"Authenticate `miro-official` via `/mcp`, then exit and restart Claude once. After that the Miro tools load only inside the board-worker subagents, and background runs reuse the grant."* If the current session is non-interactive (a background run), `/mcp` isn't available — report: *"Finish Miro auth in an interactive session: run `/mcp` → Authenticate `miro-official`, then restart Claude once."*

### 7.5. Restart the session if agents or the token hook were just wired

Two things wired by this setup only take effect on a **fresh session**, so a board build attempted in the *current* session can silently fail even though everything is configured correctly:

- **Route A agent copies (§5).** Claude Code loads project-local agent definitions (and their honored inline `mcpServers`) at session start. The three board workers just copied into `<root>/.claude/agents/` are not picked up mid-session — until a restart, a spawned `board-builder` may still resolve to the plugin's copy, whose inline MCP is dropped (the exact failure §5 exists to fix).
- **The `SessionStart` token hook (§6).** It runs at session start and appends `MIRO_ACCESS_TOKEN` to the env file. A session that was already running when the hook was installed never executed it, so `MIRO_ACCESS_TOKEN` is unset and connector scripts 401.

So: **if this run copied/updated any agent in §5, or installed the §6 hook, tell the PM to restart the session before building a board** (exit and relaunch Claude Code in this project). After the restart, have them run `<root>/.claude/scripts/miro-verify.sh` once more — it should be all-green with `MIRO_ACCESS_TOKEN` now exported — and only then start a board operation. If §5 and §6 were both already in place (nothing newly wired this run), no restart is needed; say so.

### 8. Report and next steps

Summarize what was created, appended, or skipped. Then tell the PM the next steps:

1. **Restart if anything was newly wired** — if §5 copied agents or §6 installed the hook this run, restart the session first (see §7.5), then run `miro-verify.sh` to confirm green before any board work.
2. **Connect Miro** — see `docs/miro-setup.md` in the plugin. The board workers reach the official hosted Miro MCP via the route chosen in §5 (Route A: local agent copies; Route B: project `.mcp.json`). For Route A, authorize Miro via `/mcp` → Authenticate `miro-official` in the main session, then **exit and restart `claude` once** so the grant loads (see §7); thereafter the Miro tools load only inside the board workers and background runs reuse the grant. The connector REST token is now auto-managed if §6 was applied — the `SessionStart` hook refreshes and exports `MIRO_ACCESS_TOKEN` each session, using the client credentials persisted in §6 (`miro-client.env` or a 1Password ref) plus the token written by `miro-oauth-bootstrap.sh`. Run `miro-verify.sh` any time to check both paths. If §5 was skipped (Route C), the workers are REST-only until you re-run `/vcw:setup` and pick A or B.
3. **Bring a design system** — the prototyping skills ship with Equal Experts' Kuat as a worked example; point them at your own design system to use it.
4. **Establish product context** — run `/vcw:framework-setup` once.
5. **Start an iteration** — run `/vcw:iteration-setup` per iteration.

## Notes

- This skill writes only into the user's project — `product/`, `CLAUDE.md`, and (per §5–§6, only with consent) `.claude/agents/`, `.mcp.json`, `.claude/scripts/`, and `.claude/settings.local.json`. It never writes into the plugin's own directory. The two files it can create under `~/.config/<project>/` — `miro-tokens.json` (the rotating Miro grant) and, if the persisted-env-file route is chosen in §6, `miro-client.env` (the app's client_id/secret) — both live outside the repo at mode 0600 and are the user's own secrets — never committed.
- Re-running is safe: a second run detects the installed block, the existing scaffold, the §5 Miro wiring (including the `vcw-source-version` stamp on local agent copies), and the §6 token automation (scripts + `SessionStart` hook), and skips or offers a re-sync rather than overwriting.
- To uninstall: delete the block between `<!-- BEGIN vcw -->` and `<!-- END vcw -->` in `CLAUDE.md`; for Route A, delete the three copied agents from `.claude/agents/`; for Route B, remove the `miro-official` key from `.mcp.json`; for §6, delete the `miro-*.sh` scripts from `.claude/scripts/`, remove the `SessionStart` token hook from `settings.local.json`, and (optionally) delete `~/.config/<project>/miro-tokens.json` and `~/.config/<project>/miro-client.env`.
- **Why §5 exists:** plugin-provided agents cannot carry agent-scoped MCP (Claude Code ignores `mcpServers` on plugin agents). Route A trades plugin-managed updates for main-thread token isolation; Route B trades token isolation for zero local copies. The PM owns that tradeoff per project.
