---
name: claude-design
description: Round-trip workflow between repo-resident prototype specs and Claude Design projects on claude.ai. Brief CD with a per-screen spec, ground it in your design system (synced separately by the built-in /design-sync), hand off the result back to the repo via "Handoff to Claude Code" or zip download. Use when a PM asks to prototype a feature, refresh a prototype after spec changes, or import CD output into an iteration's prototypes/ directory.
tags: [product-management, prototyping, claude-design]
---

# Claude Design Skill

Round-trip workflow between repo-resident prototype specs and Claude Design (claude.ai/design). The skill encodes the four-piece pattern (sidecar markdown spec, create on the surface, absorb back, accept-flow discipline) on a surface whose feature-prototype loop is human-mediated rather than MCP-driven.

This is the *adapted-shape* instantiation of the EE PM Workflow pattern — same shape as `story-map` and `opportunity-tree`, different mechanics (the feature-prototype loop is browser-mediated; handoff via CD's built-in features).

**Scope boundary — read this first.** Claude Code ships a first-class `DesignSync` tool and a bundled **`/design-sync`** skill that own the *design-system* half of Claude Design end to end. This skill does **not** reimplement any of it. The split:

| | `/design-sync` (built-in) | `claude-design` (this skill) |
|---|---|---|
| Artifact | Your **design system** — the component library | A **feature prototype** — screens for one feature |
| Direction | Push: repo `.tsx` → CD design-system project | Round-trip: brief → CD → back into `prototypes/` |
| Mechanism | `DesignSync` tool; converter builds, validates, uploads | Brief composed here; iteration happens in the CD project |
| Owns | Component cards, tokens, `conventions.md`, re-syncs | Per-screen specs, briefs, import, story references |
| Run from | The design-system repo | The product repo |

Never hand-build, hand-upload, or hand-author previews for a design system from this skill — **run `/design-sync`**. If a step below sounds like design-system work, it belongs to `/design-sync`.

## When to use this skill

Invoke when the user asks to:

- **Brief** a new prototype — produce the project-creation instructions and per-screen brief that the user pastes into a fresh CD project (`brief` mode).
- **Refresh** an existing prototype after the spec or solution shape changed in the repo (`refresh` mode).
- **Import** CD output back into the iteration's `prototypes/` directory after a session in claude.ai/design (`import` mode).
- **Reference** prototype outputs from story files so engineering picks them up during extraction (`reference` mode).

If unsure which mode, ask: "Are we kicking off a new prototype, refreshing an existing one, or pulling CD output back into the repo?"

## Required environment

- Access to claude.ai/design.
- **Optional — a design-system project**, if this product has a design system. Prototypes are grounded in it when present.
  - **If the design system lives in a repo you control, do not set this up by hand — run `/design-sync` from that repo.** It builds the library, compiles previews from the real `.tsx`, validates renders, and uploads the project. It also owns re-syncs when the library changes.
  - If someone else maintains it, you need read access to their design-system project; ask the owner.
  - If the product has no design system, brief without one — UI choices are made in the prototyping surface. This plugin does not create or supply design systems.
- Filesystem access to the iteration's `product/iterations/{cycle}/prototypes/` directory.
- Optional: a local checkout of the design system's package, so Claude Code can pick up its bundled agent docs after handoff.

## How the pieces map

The four-piece pattern still holds; only the *create* leg is browser-mediated, and the design-system prerequisite is now tool-driven:

| Piece | Miro-pattern (story-map, OST) | This skill (claude-design) |
|---|---|---|
| Sidecar | Markdown story / opportunity files | Per-screen markdown specs in `prototypes/` |
| Create | `mcp__miro__*` calls | Brief pasted into a CD project; user runs CD |
| Absorb | `mcp__miro__get-board-items` + diff | "Handoff to Claude Code" / zip download / file copy |
| Accept-flow | Propose changes, PM approves | Identical — PM accepts/edits/rejects CD output before it lands in repo |

The design-system *prerequisite* is not part of this table — it is a `DesignSync` tool call sequence owned by `/design-sync`.

## Modes

### 1. Brief mode

Push repo → CD-ready brief.

**Inputs (caller-supplied):** cycle name, target screen(s) or the story/feature being prototyped, and the iteration's solution-shape doc. The baseline existing screen, persona, and relevant product specs are **discovered by the skill** (Step 0), not handed in — the caller passes *what* to prototype; the skill derives the existing context to ground it against.

### Step 0 — Review existing product specs and screens (always, before composing the brief)

A prototype almost always extends or sits adjacent to a screen the product already has. Find it before briefing — don't ask the PM for it unless the match is genuinely ambiguous. Keep this token-frugal: read names first, then only the one or two files that actually match.

1. **List `product/screens/`** (names only) to see the available baseline screen specs.
2. **Auto-match the baseline / adjacent screen** for this feature from the target story + persona, matching feature keywords and persona against screen filenames/titles. E.g. a handoff-confirmation feature for a given persona (STORY-0019) matches `{persona}-pin-entry-in-app.md`; an order-status feature for that persona matches `{persona}-order-status.md`.
3. **Read only the matched screen spec** (not all of them) to populate the brief's baseline section — what exists today and what stays unchanged.
4. **Read the relevant product spec(s) only if the feature touches them** — `product/design-principles.md`, `product/product-as-built.md` — for constraints and existing behavior. Do not read all of `product/`.
5. **Read the persona** from `product/personas/{slug}.md` — that one file, not the whole directory.
6. **Decide the relationship and record it in frontmatter:** use `baseline_screen:` when the prototype *extends* an existing screen (render the full screen, only the new section is new work), or `adjacent_existing_screen:` when it's a *new* screen and the existing one is navigation context. Point at the discovered `product/screens/{file}.md`.
7. **Ask the PM only when** two screens are equally plausible baselines, or when no existing screen fits the feature at all — otherwise proceed with the match.

**Output:** a single markdown brief the user pastes into a new CD project, plus step-by-step setup instructions:

0. **Confirm the design-system project is current.** If the design system is repo-resident and has changed since the last sync, run **`/design-sync`** from the design-system repo before briefing — prototypes briefed against a stale component set will reference components that no longer match the code. This skill never performs that sync itself.
1. **In claude.ai/design, create a new project** for this feature. One project per feature — do not pile prototypes into the design-system project or into a previous feature's project.
2. **If the product has a design system, import its project as a linked reference.** From the new project's Import menu → "Link another project" → pick the design-system project. This gives CD read access to the rules, tokens, kits, and assets without duplicating them. The project on the other end of that link is the one `/design-sync` publishes. Skip this step if there is no design system.
3. **Paste the brief** the skill produced. The brief includes:
   - Frontmatter: `baseline_screen:` or `adjacent_existing_screen:` pointing at the discovered `product/screens/{file}.md` (from Step 0), plus `stories`, `solution`, `persona`, `surface`.
   - Feature summary (what it does, who uses it, the surface)
   - Persona context (relevant excerpts from `product/personas/{slug}.md`)
   - A **baseline section** describing the matched existing screen — what's there today and what stays unchanged — so CD renders the new work in context rather than redesigning the whole screen.
   - Per-screen specs (the existing markdown mockups in `prototypes/`)
   - Acceptance criteria pulled from the relevant story files
   - Known constraints (technical, brand, accessibility) — including any pulled from the product specs read in Step 0
4. **Iterate in the preview pane.** CD will propose 2–3 variations; refine the chosen one. For multi-screen flows, request a clickable prototype.
5. **When stable, switch to `import` mode** in this skill to pull the result back into the repo.

The brief is plain markdown and lives at `product/iterations/{cycle}/prototypes/_briefs/{screen}.md` so it's regenerable and version-controlled.

### 2. Refresh mode

Push repo → CD, when the spec changed after the prototype was first built.

1. Identify which screens have spec changes since `last_briefed_at` (read from `prototypes/cd-metadata.json` if present).
2. Generate an *update* brief noting only what changed (new acceptance criterion, persona swap, new edge case).
3. Instruct the user to paste the update brief into the existing CD project (don't start a new one — preserves the project's design history).
4. Re-run `import` mode after the user iterates.

### 3. Import mode

Pull CD → repo. After a session in claude.ai/design.

The user has three handoff options from CD:

- **"Handoff to Claude Code"** — CD's built-in feature. Recommended when the prototype is heading straight to implementation. CD packages the relevant files + agent docs and surfaces them in a Claude Code session.
- **Download as zip** — full project export. Recommended for archive / repo capture.
- **Copy specific files** — surgical, e.g. just one component's React source.

Skill steps:

1. Ask the user which handoff method they used.
2. If zip: ask for the zip path. Extract relevant files into `product/iterations/{cycle}/prototypes/{screen}/`.
3. If files: ask for the source paths and target screen.
4. If "Handoff to Claude Code": the files arrive in the working directory; move them under `prototypes/{screen}/`.
5. Update `prototypes/cd-metadata.json` with: project URL, last-imported timestamp, screen → file mapping.
6. **Propose, don't apply.** Show the user the diff between current `prototypes/` and the import. They accept, edit, or reject before commit.

**Next step after import.** The import lands files; it does not touch stories. To fold the design back into the canonical requirement set, run `story-management` Mode 4 (align) with `prototypes/` among the sources — it attaches `prototype_refs`, refines AC, **and proposes new stories for any flow the design surfaced that no story covers** (e.g. a dispute/problem-report exit the design shows but defers). Stories are written directly to `stories/`; no board/story-map step is required. Reference mode below is the lighter alternative when you only need to link existing stories, not capture new ones.

### 4. Reference mode

Once a prototype is imported, reference it from the relevant story files so engineering picks it up during extraction. (For capturing *new* stories the design surfaced, use `story-management` Mode 4 — see "Next step after import" above; reference mode only links the stories that already exist.)

For each story whose acceptance criteria reference a screen:

1. Add a `**Prototype**:` line to the story header pointing at the prototype's path in `prototypes/`.
2. If the prototype includes a clickable flow, add a `**Flow**:` line linking to the entry screen.
3. Re-run `story-management refine` if the AC needs to be tightened against the now-real screens.

## Spec file format

Per-screen specs live at `product/iterations/{cycle}/prototypes/{screen}.md`.

Recommended sections:

```
# {Screen name}

**Persona**: {persona slug — resolves to product/personas/{slug}.md}
**Surface**: web app | mobile web | native | marketing page
**Solution shape**: {SOL-NNNN reference}
**Stories served**: {STORY-NNNN, STORY-NNNN}

## What it does
{1-2 sentence description}

## Key elements
- {element 1, with brand/UX intent}
- {element 2}

## States
- {empty, loading, error, success — name and describe each}

## Constraints
- {accessibility, brand, technical}
```

## Sidecar format

`product/iterations/{cycle}/prototypes/cd-metadata.json` records the round-trip state:

```json
{
  "project_url": "https://claude.ai/design/projects/{id}",
  "linked_design_system": "{Your Design System}",
  "last_briefed_at": "2026-04-28T...",
  "last_imported_at": "2026-04-28T...",
  "screens": {
    "{screen-name}": {
      "spec": "prototypes/{screen-name}.md",
      "brief": "prototypes/_briefs/{screen-name}.md",
      "import_path": "prototypes/{screen-name}/",
      "handoff_method": "zip | files | claude-code"
    }
  }
}
```

## Comparison to `magic-patterns`

`claude-design` is the primary path; `magic-patterns` is a stretch second-path comparison that demonstrates the lowest-level-capable-tool principle ("we tried both — here's why the lower-level path was sufficient").

| | claude-design | magic-patterns |
|---|---|---|
| Surface | claude.ai/design | magicpatterns.com |
| Mechanism | Feature loop browser-mediated; design system tool-driven (`DesignSync` / `/design-sync`) | API-driven; programmatic |
| Design-system ingestion | Native (linked project, published by `/design-sync`) | Per-prompt context injection |
| Output | React/HTML preview, PPTX, zip, Handoff to Claude Code | React/HTML, Figma export |
| Cost | Foundation-LLM tokens already approved | Specialty-tool subscription |
| Role | Primary prototyping surface | Stretch second-path comparison |

The pattern is the same in both cases (sidecar + create + absorb + accept-flow). The lowest-level-capable-tool point is that the lower-level path (claude-design) is sufficient, so the specialty layer (magic-patterns) is optional rather than necessary.

## Error handling

- User has no claude.ai/design access → tell the user how to request access from the workspace owner; stop cleanly. (`/design-login` authorizes design-system access for the tool path.)
- A design-system project the product expects is not visible to the user → if the design system is repo-resident and simply hasn't been published yet, point them at **`/design-sync`** from that repo rather than treating it as an access problem. Otherwise tell them which workspace it lives in; stop cleanly.
- Design system exists but its components are out of date vs. the repo → **`/design-sync`** re-sync, not a manual re-upload from here.
- Import zip extraction overwrites existing files → always show diff and require approval before write.
- Spec file missing for a target screen → offer to scaffold one from `${CLAUDE_PLUGIN_ROOT}/skills/claude-design/templates/screen-spec.md` (when added).

## Related skills

- **`/design-sync` (built-in, not part of this repo)** — publishes the design system this skill briefs against. Owns the converter, preview authoring, validation, upload, and re-sync. Run it from the design-system repo whenever the library changes.
- `story-map` — same four-piece pattern, Miro+MCP surface, grid topology.
- `opportunity-tree` — same four-piece pattern, Miro+MCP surface, tree topology.
- `magic-patterns` — alternate prototyping surface; stretch second-path comparison.
- `story-management` — invoked from `reference` mode to tighten ACs against finished screens.

## Calibration log

First real round-trip: **{screen-name}** (2026-05-18, iteration `YYYY-MM-DD-{iteration-slug}`). Findings for the next briefer:

- **Paste-friendliness.** Brief mode's setup blockquote (CD-project setup instructions for the human) must be either at the **bottom** of the file or in a separate `_briefs/SETUP.md` — selecting "everything below the H1" or "everything except this last block" is fragile. Default: put setup at the bottom; the brief itself begins at the H1.
- **Output README becomes the design source-of-truth.** CD's handoff README is consistently *richer* than the input brief — it documents chosen-variation rationale, full state spec, drift-cascade behaviours we didn't ask for, design-system-gap recommendations, AC-checklist back-references. The brief's spec is the *input* artifact; the imported README is the *output* artifact and the spec engineering reads. Reference mode should point story `Prototype refs` at the **output README**, not the input spec. The input spec should carry a header note acknowledging the output is authoritative.
- **What to explicitly request in the brief's "What we want back from CD" section.** First-run output produced — without being asked — variation comparison, all-states-rendered, design-system-gap surfacing, AC-checklist back-reference. Make these explicit in future briefs so they're guaranteed, not lucky:
  - 2–3 variations with a *chosen* one and one-line rejection rationale for the others
  - All listed states rendered (PNG per state in `screenshots/`)
  - Design-system selection-order audit (when one is linked), with gaps named as upstream candidates
  - AC checklist back-reference (the brief's binding behaviours checked off, one line each)
- **Zip handoff is the right default for first round-trips.** Inspectable before anything lands; `import` mode extracts → proposes → user accepts. "Handoff to Claude Code" is slicker for demo but skips the inspection step.
- **`cd-metadata.json` first-write shape.** Record `chosen_variation` and `states_rendered` alongside the spec'd fields — useful provenance for future refresh-mode diffs.
