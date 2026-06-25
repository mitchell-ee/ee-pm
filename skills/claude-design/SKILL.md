---
name: claude-design
description: Round-trip workflow between repo-resident prototype specs and Claude Design projects on claude.ai. Brief CD with a per-screen spec, ingest your design system as a linked reference (e.g. Equal Experts' Kuat), hand off the result back to the repo via "Handoff to Claude Code" or zip download. Use when a PM asks to prototype a feature, refresh a prototype after spec changes, or import CD output into an iteration's prototypes/ directory.
tags: [product-management, prototyping, claude-design, kuat]
---

# Claude Design Skill

Round-trip workflow between repo-resident prototype specs and Claude Design (claude.ai/design). The skill encodes the four-piece pattern (sidecar markdown spec, create on the surface, absorb back, accept-flow discipline) on a non-MCP surface.

This is the *adapted-shape* instantiation of the EE PM Workflow pattern — same shape as `story-map` and `opportunity-tree`, different mechanics (no MCP, manual project setup in the browser, handoff via CD's built-in features).

## When to use this skill

Invoke when the user asks to:

- **Brief** a new prototype — produce the project-creation instructions and per-screen brief that the user pastes into a fresh CD project (`brief` mode).
- **Refresh** an existing prototype after the spec or solution shape changed in the repo (`refresh` mode).
- **Import** CD output back into the iteration's `prototypes/` directory after a session in claude.ai/design (`import` mode).
- **Reference** prototype outputs from story files so engineering picks them up during extraction (`reference` mode).

If unsure which mode, ask: "Are we kicking off a new prototype, refreshing an existing one, or pulling CD output back into the repo?"

## Required environment

- Access to claude.ai/design with a workspace that contains **your design-system project** (e.g. Equal Experts' "Kuat Design System"). Set this up once; collaborators need to be invited.
- Filesystem access to the iteration's `product/iterations/{cycle}/prototypes/` directory.
- Optional: a local checkout of your design system's package (e.g. `node_modules` containing `@equal-experts/kuat-core` for Kuat) so Claude Code can pick up the bundled agent docs after handoff.

## Why this isn't MCP-driven

Claude Design is a research-preview surface inside claude.ai. There is no API or MCP. The skill therefore produces *instructions and briefs* the user follows in the browser, not direct tool calls. The four-piece pattern still holds:

| Piece | Miro-pattern (story-map, OST) | This skill (claude-design) |
|---|---|---|
| Sidecar | Markdown story / opportunity files | Per-screen markdown specs in `prototypes/` |
| Create | `mcp__miro__*` calls | Brief pasted into a new CD project; user runs CD |
| Absorb | `mcp__miro__get-board-items` + diff | "Handoff to Claude Code" / zip download / file copy |
| Accept-flow | Propose changes, PM approves | Identical — PM accepts/edits/rejects CD output before it lands in repo |

## Modes

### 1. Brief mode

Push repo → CD-ready brief.

**Inputs (caller-supplied):** cycle name, target screen(s) or the story/feature being prototyped, and the iteration's solution-shape doc. The baseline existing screen, persona, and relevant product specs are **discovered by the skill** (Step 0), not handed in — the caller passes *what* to prototype; the skill derives the existing context to ground it against.

### Step 0 — Review existing product specs and screens (always, before composing the brief)

A prototype almost always extends or sits adjacent to a screen the product already has. Find it before briefing — don't ask the PM for it unless the match is genuinely ambiguous. Keep this token-frugal: read names first, then only the one or two files that actually match.

1. **List `product/context/screens/`** (names only) to see the available baseline screen specs.
2. **Auto-match the baseline / adjacent screen** for this feature from the target story + persona, matching feature keywords and persona against screen filenames/titles. E.g. a handoff-confirmation feature for a given persona (STORY-019) matches `{persona}-pin-entry-in-app.md`; an order-status feature for that persona matches `{persona}-order-status.md`.
3. **Read only the matched screen spec** (not all of them) to populate the brief's baseline section — what exists today and what stays unchanged.
4. **Read the relevant product spec(s) only if the feature touches them** — `product/context/principles.md`, `product/context/product-as-built.md` — for constraints and existing behavior. Do not read all of `product/context/`.
5. **Read the persona** from `product/context/personas.md` (the matched persona's entry).
6. **Decide the relationship and record it in frontmatter:** use `baseline_screen:` when the prototype *extends* an existing screen (render the full screen, only the new section is new work), or `adjacent_existing_screen:` when it's a *new* screen and the existing one is navigation context. Point at the discovered `product/context/screens/{file}.md`.
7. **Ask the PM only when** two screens are equally plausible baselines, or when no existing screen fits the feature at all — otherwise proceed with the match.

**Output:** a single markdown brief the user pastes into a new CD project, plus step-by-step setup instructions:

1. **In claude.ai/design, create a new project** for this feature. One project per feature — do not pile prototypes into the design-system project or into a previous feature's project.
2. **Import your design-system project as a linked reference** (e.g. Equal Experts' "Kuat Design System"). From the new project's Import menu → "Link another project" → pick your design system's project. This gives CD read access to the rules, tokens, kits, and assets without duplicating them.
3. **Paste the brief** the skill produced. The brief includes:
   - Frontmatter: `baseline_screen:` or `adjacent_existing_screen:` pointing at the discovered `product/context/screens/{file}.md` (from Step 0), plus `stories`, `solution`, `persona`, `surface`.
   - Feature summary (what it does, who uses it, the surface)
   - Persona context (relevant excerpts from `product/context/personas.md`)
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

**Persona**: {persona slug from product/context/personas.md}
**Surface**: web app | mobile web | native | marketing page
**Solution shape**: {SOL-NN reference}
**Stories served**: {STORY-NNN, STORY-NNN}

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
| Surface | claude.ai/design (research preview) | magicpatterns.com |
| Mechanism | Browser; no API/MCP | API-driven; programmatic |
| Design-system ingestion | Native (linked project) | Per-prompt context injection |
| Output | React/HTML preview, PPTX, zip, Handoff to Claude Code | React/HTML, Figma export |
| Cost | Foundation-LLM tokens already approved | Specialty-tool subscription |
| Role | Primary prototyping surface | Stretch second-path comparison |

The pattern is the same in both cases (sidecar + create + absorb + accept-flow). The lowest-level-capable-tool point is that the lower-level path (claude-design) is sufficient, so the specialty layer (magic-patterns) is optional rather than necessary.

## Error handling

- User has no claude.ai/design access → tell the user how to request access from the workspace owner; stop cleanly.
- Your design-system project (e.g. Equal Experts' "Kuat Design System") not visible to the user → tell them which workspace it lives in; stop cleanly.
- Import zip extraction overwrites existing files → always show diff and require approval before write.
- Spec file missing for a target screen → offer to scaffold one from `templates/screen-spec.md` (when added).

## Related skills

- `story-map` — same four-piece pattern, Miro+MCP surface, grid topology.
- `opportunity-tree` — same four-piece pattern, Miro+MCP surface, tree topology.
- `magic-patterns` — alternate prototyping surface; stretch second-path comparison.
- `story-management` — invoked from `reference` mode to tighten ACs against finished screens.

## Calibration log

First real round-trip: **{screen-name}** (2026-05-18, iteration `YYYY-MM-DD-{iteration-slug}`). Findings for the next briefer:

- **Paste-friendliness.** Brief mode's setup blockquote (CD-project setup instructions for the human) must be either at the **bottom** of the file or in a separate `_briefs/SETUP.md` — selecting "everything below the H1" or "everything except this last block" is fragile. Default: put setup at the bottom; the brief itself begins at the H1.
- **Output README becomes the design source-of-truth.** CD's handoff README is consistently *richer* than the input brief — it documents chosen-variation rationale, full state spec, drift-cascade behaviours we didn't ask for, Kuat-gap recommendations, AC-checklist back-references. The brief's spec is the *input* artifact; the imported README is the *output* artifact and the spec engineering reads. Reference mode should point story `Prototype refs` at the **output README**, not the input spec. The input spec should carry a header note acknowledging the output is authoritative.
- **What to explicitly request in the brief's "What we want back from CD" section.** First-run output produced — without being asked — variation comparison, all-states-rendered, Kuat-gap surfacing, AC-checklist back-reference. Make these explicit in future briefs so they're guaranteed, not lucky:
  - 2–3 variations with a *chosen* one and one-line rejection rationale for the others
  - All listed states rendered (PNG per state in `screenshots/`)
  - Kuat selection-order audit, with gaps named as `KuatX` upstream candidates
  - AC checklist back-reference (the brief's binding behaviours checked off, one line each)
- **Zip handoff is the right default for first round-trips.** Inspectable before anything lands; `import` mode extracts → proposes → user accepts. "Handoff to Claude Code" is slicker for demo but skips the inspection step.
- **`cd-metadata.json` first-write shape.** Record `chosen_variation` and `states_rendered` alongside the spec'd fields — useful provenance for future refresh-mode diffs.
