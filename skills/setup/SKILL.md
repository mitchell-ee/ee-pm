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
  - If it exists, does it already contain the line `<!-- BEGIN ee-pm -->` (or the legacy `<!-- BEGIN vcw -->` from an earlier install)? If so, the conventions block is already installed.
- Does `<root>/product/` exist? If so, what's already in it — is it the empty scaffold, or does it hold real content (files/subdirs other than `context/`, `iterations/`, `README.md`)?
- Does `<root>/product/context/` exist?
- Does `<root>/product/iterations/` exist?
- **Miro MCP wiring (for the board workers):** the board workers (`board-builder`, `absorb-interpreter`, `board-writer`) build and round-trip Miro boards through the official Miro MCP. They reach it by registering `miro-official` as a **project-level MCP server** (see §5). Detect, without modifying anything:
  - Is `miro-official` already a configured MCP server? (`claude mcp get miro-official` succeeds, or a `<root>/.mcp.json` declares it.)
  - If not, Miro MCP is **not wired** — the board workers will lack `mcp__miro-official__*` and fall back to raw REST. Plan to offer wiring in §5.
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
  - Exists, already contains `<!-- BEGIN ee-pm -->` (or legacy `<!-- BEGIN vcw -->`) → **skip** (idempotent). Mention it's already installed.
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

Regardless: both auth paths from `docs/miro-setup.md` apply — the hosted MCP uses OAuth-at-connect; the connector REST scripts use `MIRO_ACCESS_TOKEN`. The next two steps wire that second path and verify both.

### 6. Wire the connector REST token (auto-refresh)

**Only needed if you draw opportunity-solution trees with connectors.** Story maps and assumption maps carry no connectors and use the hosted MCP alone — a PM who only uses those can decline this whole step. Offer it, default **yes** for OST users.

Opportunity-solution-tree connectors go through REST scripts (`write-connectors.sh` etc.) that read `MIRO_ACCESS_TOKEN` from the environment. Rather than have the PM hand-export a token that silently expires, setup installs the token-lifecycle scripts and a `SessionStart` hook that injects a freshly-refreshed token each session — *after* the PM provides the credentials once (step 3). Skip this step if §1 found the token automation already installed (the four `miro-*.sh` scripts present in `<root>/.claude/scripts/` **and** a `SessionStart` hook referencing `miro-fresh-token.sh` in `settings.local.json`) **and** credentials resolve.

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
   The `|| true` and `2>/dev/null` keep a session with no token configured from failing to start — the hook is a no-op until the credentials are provided and bootstrap runs. `miro-fresh-token.sh` resolves the client credentials itself (via `miro-token-lib.sh`, which reads the persisted `miro-client.env` written in step 3), so the hook needs no credentials in its own environment — that is exactly why step 3 persists them to a file rather than relying on a shell `export` that won't survive to the next session.
3. **Provide and persist the credentials, then bootstrap — guide the PM through it.** The scripts can't work until the PM supplies their Miro app's client credentials once. The only step that genuinely can't be automated is creating the Miro app inside Miro's console — guide that with an explicit checklist, then help persist the credentials and bootstrap the token.

   First, **detect what's already resolvable** so you don't ask for what you don't need. Run `<root>/.claude/scripts/miro-verify.sh`. If credentials already resolve (env, 1Password, or a persisted `miro-client.env` from a prior run) **and** the token file exists and verifies, this step is done — say so and skip to §7.

   Otherwise walk the sub-flow:

   **3a. Create the Miro app (PM action — the one manual step).** Print this exact checklist and offer to open the URL:
   - Open <https://miro.com/app/settings/user-profile/apps> and click **Create new app**.
   - Name it (e.g. "ee-pm connectors"), leave it as a non-Expanded app.
   - Under **Permissions**, grant **`boards:read`** and **`boards:write`**.
   - **Install the app into a non-developer workspace.** Boards created under a developer team carry a "Created with <app>" watermark; installing into a normal team avoids it.
   - From the app page, copy the **Client ID** and **Client secret**.

   **3b. Persist the credentials durably — manual instructions for the PM.** The refresh script needs the credentials on **every** session, not just at bootstrap, and a shell `export` does not persist. So the PM writes them to a durable store once. Give them these instructions to run themselves (this keeps the secret out of the assistant's context):

   - **Portable default — persisted env file.** In a terminal (or via the `!` prefix in the session), with their real values substituted:
     ```bash
     mkdir -p ~/.config/<project>/ && chmod 700 ~/.config/<project>/
     ( umask 177; printf 'MIRO_CLIENT_ID=%s\nMIRO_CLIENT_SECRET=%s\n' 'YOUR_CLIENT_ID' 'YOUR_CLIENT_SECRET' > ~/.config/<project>/miro-client.env )
     chmod 600 ~/.config/<project>/miro-client.env
     ```
     `<project>` is the project name `miro-token-lib.sh` resolves (it prints the path it's looking for in `miro-verify.sh` output). `miro-token-lib.sh` reads this file as a credential source, so the `SessionStart` hook's `miro-fresh-token.sh` call picks it up automatically every session with nothing exported. This file is outside the repo and **must never be committed**.
   - **Alternative — 1Password.** If the `op` CLI is present: store the pair as a 1Password item and set `MIRO_OP_ITEM="op://<vault>/<item>"` in their durable shell profile. Nothing secret touches disk in the repo or `~/.config`.

   If the PM would rather paste the two values to the assistant and have it write the file, that's acceptable too — but offer the manual route first, since it keeps the client secret out of the assistant's context.

   **3c. Bootstrap the token (PM-approved, opens a browser).** With credentials now resolvable, run `<root>/.claude/scripts/miro-oauth-bootstrap.sh`. It opens the Miro consent page once, exchanges the code, and writes the refreshable token file (`~/.config/<project>/miro-tokens.json`, 0600). **Confirm before running — it opens a browser — and it requires an interactive session.** In a non-interactive (background/headless) run, do steps 3a–3b if possible but **defer 3c**: report that the bootstrap must be run once interactively (`<root>/.claude/scripts/miro-oauth-bootstrap.sh`), after which the `SessionStart` hook keeps the token fresh.

### 7. Verify both auth paths

After wiring, confirm the setup actually works rather than leaving the PM to discover a gap mid-board-build:

- **REST token:** run `<root>/.claude/scripts/miro-verify.sh` and report its table (credentials resolvable, token file present, refresh works, not expired). If it exits non-zero, surface the blocking line. If §6 just persisted credentials to `miro-client.env` and ran bootstrap, this should now be all-green; if it still shows "credentials not resolvable," the persist step (3b) didn't land — re-check the file path and mode before moving on.
- **Hosted MCP.** With `miro-official` registered in `<root>/.mcp.json` (§5), Claude Code surfaces it in the main thread's `/mcp` for authentication. The grant is **resolved at `claude` process startup**, so a session that was already running when §5 wrote `.mcp.json` will not see the server until restart. The OAuth handoff is harness-owned and **cannot be triggered by spawning a subagent or from a shell** — it must be done interactively via `/mcp`. Walk the PM through this exact order:
  1. **Run `/mcp`** in the main session. `miro-official` appears because `.mcp.json` declares it. Choose **Authenticate** and complete the Miro browser consent.
  2. **Exit and restart `claude` once** if `.mcp.json` was written this session — the server is picked up at startup.
  3. **Verify** by spawning `board-builder` on a trivial read (`mcp__miro-official__context_get` against any board). It should resolve the tools and return board context.

  Tell the PM plainly: *"Register `miro-official`, authenticate it via `/mcp`, then (if it was just added) exit and restart Claude once. Background runs reuse the grant."* If the current session is non-interactive (a background run), `/mcp` isn't available — report: *"Finish Miro auth in an interactive session: run `/mcp` → Authenticate `miro-official`, then restart Claude once."*

### 7.5. Restart the session if the token hook was just installed

The `SessionStart` token hook (§6) runs at session start and appends `MIRO_ACCESS_TOKEN` to the env file. A session that was already running when the hook was installed never executed it, so `MIRO_ACCESS_TOKEN` is unset and connector scripts 401. Likewise, a `miro-official` server added to `.mcp.json` this session is only picked up at the next `claude` startup.

So: **if this run installed the §6 hook or wrote `.mcp.json`, tell the PM to restart the session before building a board** (exit and relaunch Claude Code in this project). After the restart, have them run `<root>/.claude/scripts/miro-verify.sh` once more — it should be all-green with `MIRO_ACCESS_TOKEN` now exported — and only then start a board operation. If both were already in place (nothing newly wired this run), no restart is needed; say so.

### 8. Report and next steps

Summarize what was created, appended, or skipped. Then tell the PM the next steps:

1. **Restart if anything was newly wired** — if §5 wrote `.mcp.json` or §6 installed the hook this run, restart the session first (see §7.5), then run `miro-verify.sh` to confirm green before any board work.
2. **Connect Miro** — see `docs/miro-setup.md` in the plugin. The board workers reach the official hosted Miro MCP via the `miro-official` server registered in §5 (`<root>/.mcp.json`). Authorize Miro via `/mcp` → Authenticate `miro-official` in the main session, then (if just added) **exit and restart `claude` once** so the grant loads (see §7); background runs reuse the grant. The connector REST token is auto-managed if §6 was applied — the `SessionStart` hook refreshes and exports `MIRO_ACCESS_TOKEN` each session, using the client credentials persisted in §6 (`miro-client.env` or a 1Password ref) plus the token written by `miro-oauth-bootstrap.sh`. Run `miro-verify.sh` any time to check both paths. If §5 was skipped, the workers are REST-only until you re-run `/ee-pm:setup` and register the MCP.
3. **Bring a design system** — the prototyping skills ship with Equal Experts' Kuat as a worked example; point them at your own design system to use it.
4. **Establish product context** — run `/ee-pm:framework-setup` once.
5. **Start an iteration** — run `/ee-pm:iteration-setup` per iteration.

## Notes

- This skill writes only into the user's project — `product/`, `CLAUDE.md`, and (per §5–§6, only with consent) `.mcp.json`, `.claude/scripts/`, and `.claude/settings.local.json`. It never writes into the plugin's own directory. The two files it can create under `~/.config/<project>/` — `miro-tokens.json` (the rotating Miro grant) and `miro-client.env` (the app's client_id/secret) — both live outside the repo at mode 0600 and are the user's own secrets — never committed.
- Re-running is safe: a second run detects the installed block, the existing scaffold, the §5 `miro-official` registration, and the §6 token automation (scripts + `SessionStart` hook + resolvable credentials), and skips rather than overwriting.
- To uninstall: delete the block between `<!-- BEGIN ee-pm -->` and `<!-- END ee-pm -->` (or the legacy `vcw` markers) in `CLAUDE.md`; remove the `miro-official` key from `.mcp.json`; for §6, delete the `miro-*.sh` scripts from `.claude/scripts/`, remove the `SessionStart` token hook from `settings.local.json`, and (optionally) delete `~/.config/<project>/miro-tokens.json` and `~/.config/<project>/miro-client.env`.
