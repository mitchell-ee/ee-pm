---
name: setup
description: Scaffold a project to use the EE PM Workflow (ee-pm) — create the product/ artifact tree and add the workflow conventions to CLAUDE.md. Non-destructive and idempotent; safe to run in an existing repo. Use once after installing the plugin.
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
  - If it exists, does it contain a `<!-- BEGIN ee-pm` marker? If so, the conventions block is already installed.
  - **Read the schema version off the marker** — `<!-- BEGIN ee-pm v0.7.0 -->`. A bare
    `<!-- BEGIN ee-pm -->` with no version predates this convention; treat it as **0.5.0**.
    Compare against `.claude-plugin/plugin.json`'s `version`. A gap means migrations are pending
    (§7). Report it; don't act on it yet.
- Does `<root>/product/` exist? If so, what's already in it — is it the empty scaffold, or does it hold real content (files/subdirs other than `iterations/` and `README.md`)?
- Does `<root>/product/iterations/` exist?
- **Legacy layout (pre-0.6.0):** does `<root>/product/context/` exist? That was the old home for
  durable context; 0.6.0 collapsed it into `product/` itself. **Don't move anything** — report it
  and offer the migration in §7.
- **Miro MCP wiring (for the board workers):** the board workers (`board-builder`, `absorb-interpreter`, `board-writer`) build and round-trip Miro boards through the official Miro MCP. They reach it by registering `miro-official` as a **project-level MCP server** (see §5). Detect, without modifying anything:
  - Is `miro-official` already a configured MCP server? (`claude mcp get miro-official` succeeds, or a `<root>/.mcp.json` declares it.)
  - If not, Miro MCP is **not wired** — the board workers will lack `mcp__miro-official__*` and can't build or read boards. Plan to offer wiring in §5.

### 2. Plan and report (dry run)

Build a plan from the detection results and **print it to the PM before writing anything**. For each item state the action: **create**, **append**, **skip (already present)**, or **ask first**.

- **`product/` tree:**
  - Missing → plan to create `product/`, `product/iterations/`, and `product/README.md` (from `templates/product-README.md`).
  - Exists but missing some subdirs → plan to create only the missing subdirs / README; skip what exists.
  - Exists and holds unrelated content (not just the scaffold) → **ask first**: tell the PM what's already there and confirm it's the right place to add `iterations/` before touching it. Never overwrite existing files.
- **Legacy `product/context/`** (if detected in §1) → **ask first**, never automatic. See §7.
- **`CLAUDE.md`:**
  - Missing → plan to create it with the conventions block (`templates/claude-md-block.md`).
  - Exists, already contains a `<!-- BEGIN ee-pm` marker → **skip** the block itself (idempotent). Mention it's already installed, and — if §1 found a version gap — that migrations are pending in §7.
  - Exists, no block → plan to **append** the conventions block. Show the PM the exact block that will be appended (it's delimited by `<!-- BEGIN ee-pm v{version} -->` / `<!-- END ee-pm -->`, so it can be found and removed later). Never modify their existing content.
- **Pending migrations** (if §1 found a version gap) → list them and note they'll be dry-run first in §7. Never automatic.

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
  - Do nothing if the block is already present — **except** to stamp its version marker in §7.3.

  **Stamp the version when writing the block.** `templates/claude-md-block.md` opens with
  `<!-- BEGIN ee-pm v{{VERSION}} -->`; replace `{{VERSION}}` with the `version` from
  `.claude-plugin/plugin.json` (e.g. `<!-- BEGIN ee-pm v0.7.0 -->`). A block written without a
  version is indistinguishable from a pre-0.6.0 project and will re-run every migration on the
  next setup.

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

### 7. Run migrations

The plugin cannot execute anything when it is updated — there is no install hook. So migration is
**lazy**: the version marker in `CLAUDE.md` (§4) makes the gap visible the next time any skill
runs, and this step applies the fix.

**Skip this section entirely** if §1 found no `product/` — a project being scaffolded for the
first time has nothing to migrate.

#### 7.1 Read the project's version

From the `CLAUDE.md` block marker: `<!-- BEGIN ee-pm v{X.Y.Z} -->`.

- **Marker carries a version** → that's the project's version.
- **Marker has no version** (`<!-- BEGIN ee-pm -->`, written before this convention) → treat the
  project as **0.5.0**, the last release before the marker existed. Every migration applies; each
  one's guard decides what actually runs.
- **No block at all** but `product/` exists → same as above; the project predates the block.

Compare against the plugin's version in `.claude-plugin/plugin.json`. This tells you whether to
*expect* work — but it does **not** decide what runs. See §7.2.

#### 7.2 Select and run

**Run every migration in `migrations/`, in version order — including ones at or below the
project's recorded version.** Do not filter by version, and do not reason about which ones
"already ran": that is what the guards are for. Each migration inspects the data, acts only if
the old shape is present, and is a no-op otherwise, so re-running an already-applied migration is
safe and expected. See `migrations/README.md` for the contract every migration honors.

Running the full set — rather than only what's newer — is deliberate. It is what makes two
otherwise-broken cases work:

- **A migration added retroactively.** If `0.6.0-sidecar-rekey.sh` is written *after* projects
  already reached 0.6.0, a newer-than filter would never select it for them — and their sidecars
  would stay broken. Data-shape guards catch it; version arithmetic does not.
- **A project migrated by hand.** Someone who already fixed their personas or sidecars manually
  is at the fixed point, so every guard finds nothing and reports a clean no-op.

The version marker is a **prompt trigger** — it tells skills to stop and tell the PM to run
setup. It is not the thing that selects migrations.

| Migration | Kind | Applies when | Requires |
|---|---|---|---|
| `0.6.0-context-collapse.md` | prose | `product/context/` exists | — |
| `0.6.0-sidecar-rekey.sh` | script | any 2-digit ref-id (`OPP-01`) in `product/` files or dir names | — |
| `0.7.0-persona-frontmatter.md` | prose | a `product/personas/*.md` lacks `type`/`slug`/`name` | `0.6.0-context-collapse.md` |
| `0.7.0-priority-p0p3.sh` | script | any `Priority:`/`priority:` field uses Critical/High/Medium/Low | — |

*(This table grows as migrations are added. A migration's version is when the **convention**
changed, not when the migration was written — one added late for an already-released version
still applies, because selection is by data shape, not version arithmetic.)*

**Order by dependency first, then by version.** A migration may declare `Requires:` in its header
naming migrations that must run before it. Version order alone is not sufficient: a migration can
*produce* data that a later-versioned one fixes up (the context collapse splits `personas.md` into
files that `0.7.0-persona-frontmatter.md` then annotates), and nothing guarantees the version
numbers happen to encode that. Honor `Requires:` explicitly rather than trusting the sort.

If a `Requires:` names a migration that doesn't exist, **stop and say so** — a broken dependency
means the migration set is inconsistent, and guessing at the order risks writing data the missing
migration was meant to fix.

For each selected migration:

1. **Dry run first.** Scripts: `--dry-run`. Prose: work out the change set without writing.
2. **Show the PM** what it would change — file-by-file, and the count.
3. **Ask before applying.** Never migrate without approval. If they decline one, honor that,
   skip it, and **do not stamp the version** (§7.3) — the project is still mid-migration.
4. **Apply** — scripts: `--apply`; prose: follow its steps. Use `git mv` for moves.
5. **Report the result, including no-ops.** "Nothing to do" is a real outcome and must be said
   out loud — a silent no-op is indistinguishable from a silent failure.

#### 7.3 Validate, then stamp

**Do not stamp because the migrations ran. Stamp because the data is correct.**

The version marker is an **assertion about the project's data**, and every skill's entry check
trusts it. A marker stamped over invalid data is worse than no marker: the entry check passes,
nothing prompts, and the corruption is invisible. A migration set that is incomplete — or a
migration the PM declined — must not be able to certify a project as current.

**Run these checks before stamping.** They inspect the data, not the migration log:

| Check | Passes when |
|---|---|
| Personas | every `product/personas/*.md` has frontmatter with `type`, `slug`, `name` |
| Artifact IDs | no 2-digit ref-ids (`OPP-01`, `STORY-07`) remain in `product/` files or filenames |
| Miro sidecars | every `miro-metadata.json` keys `nodes`/`connectors` with the same width as the repo's ref-ids |
| Priority fields | every `Priority:` / `priority:` field uses the current scale |

Skip a check when the project has none of that artifact type — a project with no boards has no
sidecars to validate. Skipping is not failing.

**All checks pass** → update the marker to the plugin's current version:

```
<!-- BEGIN ee-pm v{plugin version} -->
```

**Any check fails, or the PM declined a migration that had real work to do** → **leave the marker
untouched.** Tell them exactly what is still wrong, file by file, and that the project remains on
its old version so the next skill invocation will prompt again. Say plainly which part needs a
hand: a persona slug only the PM can confirm is a *stop*, not a defect to work around.

This is the step that makes the framework honest about its own gaps. If a convention changed and
no migration exists for it yet, the matching check fails, the project stays unstamped, and the
gap is visible — instead of being stamped away.

### 8. Report and next steps

Summarize what was created, appended, or skipped. Then tell the PM the next steps:

1. **Restart if the MCP was newly registered** — if §5 wrote `.mcp.json` this run, restart the session first (see §6.5) before any board work.
2. **Connect Miro** — see `docs/miro-setup.md` in the plugin. The board workers reach the official hosted Miro MCP via the `miro-official` server registered in §5 (`<root>/.mcp.json`). Authorize Miro via `/mcp` → Authenticate `miro-official` in the main session, then (if just added) **exit and restart `claude` once** so the grant loads (see §6); background runs reuse the grant. This single OAuth grant covers boards **and** connectors — there is no second credential to configure. If §5 was skipped, the workers can't reach Miro until you re-run `/ee-pm:setup` and register the MCP.
3. **Point at a design system if the project has one** — record its rules path in `CLAUDE.md` so the prototyping skills reference it instead of improvising UI. Optional; skip if there isn't one.
4. **Establish product context** — run `/ee-pm:framework-setup` once.
5. **Start an iteration** — run `/ee-pm:iteration-setup` per iteration.

## Notes

- This skill writes only into the user's project — `product/`, `CLAUDE.md`, and (per §5, only with consent) `.mcp.json`. It never writes into the plugin's own directory.
- Re-running is safe: a second run detects the installed block, the existing scaffold, and the §5 `miro-official` registration, and skips rather than overwriting.
- To uninstall: delete the block between the `<!-- BEGIN ee-pm` marker (it carries a version, e.g. `<!-- BEGIN ee-pm v0.7.0 -->`) and `<!-- END ee-pm -->` in `CLAUDE.md`, and remove the `miro-official` key from `.mcp.json`.
