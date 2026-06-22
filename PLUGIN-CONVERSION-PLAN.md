# Plugin conversion plan — visual-collab-workflow

Convert this repo from a plain shareable repo into a **Claude Code plugin** (pure plugin at root). Plan only — no changes made yet. Reviewed decisions are baked in below.

## Locked decisions

- **Shape:** pure plugin at root (`.claude-plugin/plugin.json` + `skills/` + `agents/` + `scripts/` at top level).
- **Workspace setup:** a user-run `setup` skill (`/visual-collab-workflow:setup`) scaffolds the user's project. No automatic install/SessionStart hook (plugins have no install-time hook; an auto-hook writing into someone's existing repo would be surprising).
- **Existing-repo safety:** the setup skill is idempotent and non-destructive — never overwrites an existing `CLAUDE.md` or `product/` content; dry-run report + confirm before writing.
- **Timing instrumentation:** strip entirely (demo-only; writes `product/metrics/timing-log.jsonl`, not load-bearing). Keep functional helper scripts.

## Verified facts (from inventory + script reads)

- Git: branch `main`, HEAD `8ce1e3d`, clean working tree, **no remote**.
- `.claude/` holds: 16 capability skills + routers, 5 worker agents (+ `agents/README.md`), 3 shared Miro REST scripts, a `settings.json` (`worktree.bgIsolation: none`).
- Shared Miro REST scripts at `.claude/scripts/`: `read-connectors.sh`, `write-connectors.sh`, `miro-copy-board.sh`.
- `append-timing.sh` confirmed demo instrumentation — writes to `product/metrics/timing-log.jsonl`, navigates `SCRIPT_DIR/../../../..` (4 levels) to repo root.

---

## Stage 1 — Move `.claude/` contents to plugin root

Plugins read `skills/`, `agents/`, `scripts/` from the **plugin root**, not from `.claude/`.

| From | To | Note |
|---|---|---|
| `.claude/skills/` | `skills/` | `git mv` |
| `.claude/agents/` | `agents/` | `git mv` |
| `.claude/scripts/` | `scripts/` | `git mv` (the 3 shared Miro REST scripts) |
| `.claude/settings.json` | **delete** | harness-dev setting, not portable plugin config |
| `.claude/skills/slack-conversation/` | (already empty/untracked) | leave; nothing tracked |

Result: no more `.claude/` dir in the repo.

## Stage 2 — Add the manifest

New file `.claude-plugin/plugin.json`:

```json
{
  "name": "vcw",
  "displayName": "Visual Collaboration with AI",
  "version": "0.1.0",
  "description": "Portable skills and agents for LLM-assisted, human-led visual collaboration in product management — opportunity trees, assumption maps, story maps, prototypes.",
  "license": "MIT",
  "keywords": ["product-management", "miro", "discovery", "story-mapping", "prototyping"]
}
```

Skills/agents/scripts at root are auto-discovered — no path fields needed. Skills namespace as `/vcw:<skill>` (e.g. `/vcw:setup`, `/vcw:story-map`) — short prefix chosen deliberately; `displayName` carries the full name.

## Stage 3 — Fix shared-script paths

Remap shared Miro REST script references to `${CLAUDE_PLUGIN_ROOT}/scripts/<script>.sh`. Current strings are inconsistent (`./.claude/scripts/...`, `.claude/scripts/...`, bare `scripts/...`) — normalize all to the plugin-root form.

Files to edit:
- `skills/opportunity-tree/SKILL.md` — read ×2, write ×3, copy
- `skills/opportunity-tree/reference/create-ost.md`
- `skills/opportunity-tree/reference/accept-mode.md`
- `skills/opportunity-tree/reference/interpret-changes.md`
- `skills/assumption-map/SKILL.md` — write ×2, copy
- `skills/story-map/reference/read-board-state.md`
- `skills/story-map/reference/accept-mode.md`
- `skills/README.md` (meta docs)

Functional per-skill helpers stay **relative** (`./scripts/<name>.sh`) — they're invoked from within their own skill and don't cross skill boundaries:
- `skills/story-management/scripts/find-highest-story.sh`
- `skills/iteration-setup/scripts/create-iteration-dirs.sh`

(No `../`-depth fix needed for these two — verify they don't climb to repo root. `find-highest-story.sh` and `create-iteration-dirs.sh` operate on `product/` via `CLAUDE_PROJECT_DIR` or relative cwd — confirm during execution.)

## Stage 4 — Strip timing instrumentation

Remove all three layers (demo-only):

**Scripts (6):**
- `skills/{story-management,discovery-synthesis,framework-setup,interview-management,backlog-management,iteration-setup}/scripts/append-timing.sh`

**Reference docs (6):**
- `skills/{story-management,discovery-synthesis,interview-management,framework-setup,backlog-management,iteration-setup}/reference/timing-log-format.md`

**Invocation lines embedded in SKILL.md (remove the step + any surrounding "record timing" framing):**
- `skills/story-management/SKILL.md` — lines ~74, ~109, ~148, ~299
- `skills/discovery-synthesis/SKILL.md` — line ~173

After removal, grep for residual `append-timing`, `timing-log`, `product/metrics` and clean any dangling references (e.g. a router or README mentioning timing capture).

## Stage 5 — The setup skill

New `skills/setup/SKILL.md`, invoked as `/vcw:setup`.

**Purpose:** scaffold the user's project safely, including into an existing repo with possible conflicts.

**Behavior:**
1. **Detect** existing: `CLAUDE.md`, `product/`, `product/context/`, `product/iterations/`.
2. **Dry-run report** — print exactly what will be created, appended, or skipped. No writes yet.
3. **On confirm:**
   - `product/` → create missing subdirs (`context/`, `iterations/`) + `product/README.md` only. Never overwrite existing files. If `product/` exists with unrelated content, surface it and ask before adding the scaffold.
   - `CLAUDE.md`:
     - absent → create with the Visual-Collab conventions, wrapped in delimiters:
       `<!-- BEGIN visual-collab-workflow -->` … `<!-- END visual-collab-workflow -->`
     - present, block already there → skip (idempotent).
     - present, no block → **append** the delimited block; show the diff first; never touch their existing content.
   - Print next steps: connect Miro (`docs/miro-setup.md`), run `framework-setup`, then `iteration-setup`.
4. **Idempotent** — safe to re-run; re-runs only fill gaps.

**Content the skill writes into CLAUDE.md:** the current root `CLAUDE.md` text, adjusted —
- Drop `.claude/` path prefixes (in the user's repo, skills are plugin-namespaced, not local files); reword "Router skills (in `.claude/skills/`)" → "Router skills (provided by the plugin)".
- Keep guiding principles, phase/router/worker model, artifact-storage convention, design-system swappability, working style.

**Templates the skill ships** (inside `skills/setup/templates/`): the `product/README.md` and the `CLAUDE.md` block source, so the skill has deterministic content to copy.

## Stage 6 — Remove root CLAUDE.md and product/ scaffold

- **Delete root `CLAUDE.md`** — plugins don't load it; its content now lives in the setup skill's template.
- **Delete root `product/`** scaffold (`context/.gitkeep`, `iterations/.gitkeep`, `README.md`) — the setup skill generates this in the *user's* repo. Move `product/README.md` content into `skills/setup/templates/` first.

(Keep `package.json` — harmless metadata; or optionally drop it since the plugin doesn't need npm. Decide at execution.)

## Stage 7 — Update docs + README

- `README.md`:
  - "Getting started" → install the plugin (`claude plugin install …` / `--plugin-dir`), then run `/visual-collab-workflow:setup`.
  - "Repo layout" → show plugin root (`.claude-plugin/`, `skills/`, `agents/`, `scripts/`, `docs/`) not `.claude/`.
  - Remove the "empty scaffold included" line (scaffold is now generated).
- `docs/miro-setup.md` → check for `.claude/scripts/` path references; update to `${CLAUDE_PLUGIN_ROOT}/scripts/` where they point at bundled scripts.

## Stage 8 — Validate

- `claude plugin validate .` (or test with `--plugin-dir .`).
- Re-grep: no surviving `.claude/scripts`, no 4-level `../../../..` script climbs, no `append-timing`/`timing-log`/`product/metrics`.
- Confirm all shell scripts still parse (`bash -n`).
- Manual: run `/visual-collab-workflow:setup` against (a) an empty dir and (b) a dir that already has a `CLAUDE.md` + `product/` — verify non-destructive behavior.

---

## Suggested commit sequence (staged)

1. Move `.claude/{skills,agents,scripts}` → root; drop `settings.json`.
2. Add `.claude-plugin/plugin.json`.
3. Fix shared-script paths to `${CLAUDE_PLUGIN_ROOT}`.
4. Strip timing instrumentation (scripts + docs + SKILL steps).
5. Add `setup` skill + templates.
6. Remove root `CLAUDE.md` + `product/` scaffold.
7. Update `README.md` + `docs/miro-setup.md`.
8. Validate.

## Open items to resolve at execution time

- Confirm `find-highest-story.sh` / `create-iteration-dirs.sh` don't climb to repo root (no `../`-depth bug like append-timing had).
- Decide whether to keep `package.json` (likely drop — plugin needs no npm).
- Whether the empty untracked `slack-conversation/` dir should be deleted from the working tree (cosmetic).
- ~~Namespace slug~~ — DECIDED: `name: vcw` (terse `/vcw:skill` invocation), `displayName: Visual Collaboration with AI`.
