---
name: assumption-map
description: Create, refresh, or absorb a Teresa Torres assumption map on Miro. Use when a PM asks to prioritize the riskiest assumptions under a candidate solution and design tests for the "test first" cluster, per Continuous Discovery Habits.
tags: [product-management, visualization, miro, discovery, torres, assumption-mapping]
---

# Assumption Map Skill

Round-trip workflow between repo-resident assumption-test files and a Miro assumption map. The map plots each assumption on a 2×2 of *importance* × *evidence*; the high-importance / weak-evidence quadrant is the "test first" cluster. Tests are designed only for assumptions in that quadrant.

This is the **third Miro instantiation** of the EE PM Workflow four-piece pattern (sidecar + create + absorb + accept-flow), after `story-map` and `opportunity-tree`. Together with those two, this skill is evidence that the same three-piece visual pattern generalizes across Miro artifacts: same shape, three artifact types.

> **Status note (2026-05-17).** Native-toolchain spike PASSED — coordinate math, sticky colors, the axis-line-as-rectangle technique, axis-tip labels, title positioning, and the right-side legend all validated end-to-end on a native-toolchain spike board (see `product/_test/assumption-map/native-spike/findings.md` for the spike record and the 4 DSL gaps it surfaced). What remains: the per-phase absorb harness (mirroring `product/_test/{story-map,ost-absorb}/`) — until that lands, the absorb-mode interpretation rules in this file are still paper.

## When to use this skill

Invoke when the user asks to:

- **Build** an assumption map for a candidate solution that the team wants to de-risk. Per Torres (*Continuous Discovery Habits*, ch. 6), assumption mapping happens *after* candidate solutions have been generated for a target opportunity and *before* committing to one — the "test first" cluster drives which experiments to run and which candidate(s) to pursue. Each candidate under consideration can have its own map; typically 1–3 are live at any time.
- **Refresh** the board after assumption files changed in the repo (new assumption added; importance/evidence updated; result recorded).
- **Absorb** workshop edits to the board back into repo files — assumptions moved between quadrants, new assumptions added under a solution, tests scaffolded for the "test first" cluster.

If unsure which mode, ask: "Are we pushing repo → board, pulling board → repo, or interpreting what changed on the board?"

## Lifecycle and lazy materialization

Assumption files and the per-solution assumption-map sidecar exist only for solutions the team has **committed to pursue**. The chain:

1. **Synthesis** writes candidate solutions and their initial assumptions **inline** in `product/iterations/{slug}/synthesis.md`. No `assumption-NN-*.md` files are created here.
2. **PM promotes a candidate solution to the OST** (via interactive instruction or OST absorb). A `solution-{NN}-{slug}.md` file is created with `Status: Proposed`. Inline assumptions stay inline.
3. **PM commits to pursue that solution** (flips `Status:` to `Committed` — typically a one-line interactive instruction). **This is the materialization trigger.** The inline assumptions for that solution in `synthesis.md` are written out as separate files at `product/context/opportunity-solution-tree/assumptions/assumption-{NNN}-{slug}.md`, one per assumption, using the file format below. Their `Importance` / `Evidence` values come from the synthesis defaults; `Method`, `Success Criterion`, `Result` start empty / `Pending`.
4. **First `/assumption-map create from solution-{NN}`** reads those just-materialized files, renders the 2×2 Miro board, and writes the per-map sidecar at `assumption-maps/SOL-{NN}-{slug}/miro-metadata.json`.

Solutions still at `Status: Proposed` (uncommitted) have **no** assumption files and **no** assumption-map board. They live only in the OST and in the synthesis doc. This matches the "no orphan files for branches the team never pursued" principle.

If the PM wants to map assumptions for a `Proposed` (uncommitted) solution — for example, to compare two candidates before commitment — they explicitly invoke `/assumption-map create from solution-{NN}`; the skill detects no assumption files exist, reads the inline assumptions from `synthesis.md`, materializes them, and proceeds. The commit/flip is the *default* trigger, not the *only* trigger.

## Required tools

- **Native Miro toolchain** (same as `story-map` and `opportunity-tree`):
  - Official Miro MCP at `mcp.miro.com` — `mcp__miro-official__layout_get_dsl` (load the DSL grammar **once** at the start of a run, then reuse — a prerequisite of `layout_create`), `mcp__miro-official__layout_create` (axes/labels/stickies/quadrant border), `mcp__miro-official__layout_read` (round-trip read for absorb), `mcp__miro-official__layout_update` (refresh-mode mutations), `mcp__miro-official__context_get` (board metadata).
  - Everything the assumption map needs goes through the MCP's layout DSL — a single credential (the MCP's OAuth-at-connect), no separate connector or copy token.
- Filesystem access to `product/context/opportunity-solution-tree/assumptions/` for canonical assumption-test files (one file per assumption) and `product/context/assumption-maps/SOL-{NN}-{slug}/miro-metadata.json` for per-map sidecars (see "Sidecar format" below).

## Repo conventions

Assumption files live at **product-level**, in their own surface — decoupled from the OST so an assumption can be referenced from the OST, a story map, or both without coupling sidecars together. Assumption objects (canonical content) and assumption-map boards (rendering) are stored in separate trees:

```
product/context/opportunity-solution-tree/assumptions/
  assumption-{NNN}-{slug}.md            # one file per assumption (canonical object)
product/context/assumption-maps/
  SOL-{NN}-{solution-slug}/
    miro-metadata.json                  # per-map sidecar — see "Sidecar format" below
```

The map is **per-solution**: one Miro board per candidate solution that's currently being de-risked, with its own sidecar dir keyed by `SOL-{NN}-{slug}`. A solution typically has 5–15 assumptions surfaced; only 2–4 land in the "test first" cluster and get test-design treatment. The `Parent Solution: SOL-{NN}` line in each assumption file is the only cross-reference back to OST — no shared sidecar file.

### File format

Existing assumption-test files in this repo encode **one assumption plus its test plan plus its result** in a single file. The skill keeps that structure and adds two fields the map needs (`Importance` and `Evidence`) so the file alone is enough to render the sticky in the right quadrant.

```
# Assumption Test: {short title}

**ID**: ASSUMPTION-{NNN}
**Parent Solution**: SOL-{NN}
**Type**: Desirability | Viability | Feasibility | Usability | Ethical
**Importance**: High | Medium | Low
**Evidence**: Strong | Moderate | Weak
**Hypothesis**: {"If we X, then Y" statement — what the assumption asserts}
**Method**: {how the test will be run; populated when the assumption enters the "test first" quadrant}
**Success Criterion**: {what would make you believe the hypothesis; populated alongside Method}
**Result**: Pending | Confirmed | Rejected | Inconclusive
```

`Importance` and `Evidence` together place the sticky on the 2×2. `Method` and `Success Criterion` are scaffolded by the absorb skill when an assumption lands in the "test first" quadrant — before that, they may be empty.

`Type` follows Torres' four categories (desirability / viability / feasibility / usability) plus an optional ethical category. `Type` drives sticky color (see "Color convention" below).

## Board naming and location

**Board name:** `{project} — Assumption Map — SOL-{NN}-{solution-slug}`

`{project}` is derived from `basename "$(git rev-parse --show-toplevel)"`. Override by placing a single-line file at `.claude/project-name.txt` in the host repo. `SOL-{NN}-{solution-slug}` matches the parent solution's filename in `product/context/opportunity-solution-tree/solutions/`.

**Cardinality:** one board per candidate solution being de-risked. A solution lives on its own board so the team can scope the conversation tightly; multiple maps coexist in the host's Miro account, each tied to a different `SOL-{NN}`.

**Location:** if the host's Miro account uses team folders, place the board in the folder matching `{project}`. Otherwise leave at account root. The skill does not create folders.

**Lifecycle:** the board persists across the parent solution's full lifecycle (under consideration → committed → shipped or killed). Killed or shipped maps are NOT renamed or archived — they stay as live boards because the test history and the surfaced assumptions remain useful institutional memory ("we tried this before; here's what we learned"). Do not delete; do not rename on status change.

**Referencing the board in chat:** whenever this skill — or any response Claude writes about the board — refers to it, include the full URL from the sidecar's `board_url` field (e.g., `https://miro.com/app/board/{board_id}=`). Don't reference a board by name or ID alone; the URL is what makes it one click from Claude Code to the live board. This rule applies anywhere a Miro board is mentioned.

## Miro layout

A 2×2 grid with drawn axis lines, four axis-tip labels, a board title, a right-side color legend, and the assumption stickies. The board is *not* viewport-bound — stickies land inside their quadrant; the board scrolls. Layout validated end-to-end on the native toolchain via `product/_test/assumption-map/native-spike/`.

### Coordinate system

Origin at the grid's center. Each quadrant is 1200×800 with 80 px gutters between quadrants. Importance descends top-to-bottom; evidence strengthens **right-to-left** (strong evidence on the left, weak evidence on the right). The "test first" cluster is the **top-right** quadrant — high importance, weak evidence — by convention (Torres, *Continuous Discovery Habits*, p. 162).

| Region | Center (x, y) | Size (w × h) |
|---|---|---|
| Top-left quadrant (Watch — high importance, strong evidence) | (-640, -440) | 1200 × 800 |
| Top-right quadrant (**TEST FIRST** — high importance, weak evidence) | (640, -440) | 1200 × 800 |
| Bottom-left quadrant (Don't worry) | (-640, 440) | 1200 × 800 |
| Bottom-right quadrant (Investigate later) | (640, 440) | 1200 × 800 |

### Axes (drawn lines, story-map swim-lane technique)

Two thin black rectangles cross at the origin. No connectors; no rotation. Mirrors the release-horizon technique in `story-map/reference/create-story-map.md` §4.3.

| Axis | Center (x, y) | Size (w × h) | Style |
|---|---|---|---|
| Horizontal x-axis (evidence) | (0, 0) | 2480 × 12 | `fill=#222222`, `border_width=1`, `border_color=#222222` |
| Vertical y-axis (importance) | (0, 0) | 12 × 1680 | same |

Axis span = full grid extent: x ∈ [-1240, 1240], y ∈ [-840, 840]. See **Known DSL limitations** below for why `border_width=1` (matching color) instead of `0`.

### Axis-tip labels (all horizontal — no rotation needed)

Four `text` items, one at each cardinal tip. Bold via `<strong>`, `font_size 48`.

| Content | Position (x, y) |
|---|---|
| `<strong>high importance</strong>` | (0, -920) |
| `<strong>low importance</strong>` | (0, 920) |
| `<strong>strong evidence</strong>` | (-1340, -60) |
| `<strong>weak evidence</strong>` | (1340, -60) |

The evidence labels sit ~60 px **above** the horizontal x-axis line (not on it). At `font_size 48` the label's bottom edge ≈ y=-30, giving ~24 px clear air above the axis line's top edge at y=-6. Importance labels sit far outside the quadrants (y=±920) so no offset is needed.

### Board title

`text` item, `font_size 64`, bold via `<strong>`. Content: `<strong>{project} — Assumption Map — SOL-{NN} {solution-slug-title-case}</strong>`. Mirrors `story-map` and `opportunity-tree` titles but at 64 (not 96) — at 96 the title visually dominates the assumption map.

**Position:** left-aligned to the upper-left corner of board content (x=-1240, y=-840), 200 px above the topmost content row → **y = -1040**. Text item position is its center, so:

```
x_title = -1240 + w_title / 2
```

`w_title` ≈ 2300 px for a typical product title at `font_size 64`. **Use a snug `w`**: an over-wide bounding box leaves the rendered text visually centered inside it. With a snug `w`, `align=left` becomes a visual no-op and the box's left edge equals the text's left edge.

### Color legend (right side)

Six rows: small colored swatch + label. The legend is essential because, unlike OST nodes (which carry ref_id prefixes), sticky type is encoded *only* in color and needs decoding for workshop attendees.

**Swatches:** `shape` rectangles, 60×60, centered at (x=1800, y=row_y). Fill = the type's canonical hex (see table below). `border_width=1`, `border_color` matching `fill`.

**Labels:** `text` items, `font_size 36`, NOT bold, snug `w=500`. Text-item center x = **2110** (left edge ≈ 1860, ~30 px right of swatch's right edge at 1830).

**Rows** (top-aligned with quadrant top edge at y=-840; swatch top edge = y=-840 means swatch center y=-810; 120 px row pitch):

| Row | y (center) | Swatch fill (canonical hex) | Sticky color name | Label |
|---|---|---|---|---|
| 1 | -810 | `#fff9b1` | light_yellow | Desirability — will customers want this? |
| 2 | -690 | `#cce8fc` | light_blue | Usability — can customers use this? |
| 3 | -570 | `#d5f692` | light_green | Feasibility — can we build this? |
| 4 | -450 | `#fbd5d8` | light_pink | Viability — does it work for our business? |
| 5 | -330 | `#c9b6f5` | violet | Ethical — should we build this? |
| 6 | -210 | `#d0d0d0` | gray | Tested — result no longer Pending |

### Sticky placement inside a quadrant

Within a quadrant, stickies tile in a 4×4 grid (up to 16 per quadrant before overflow). Slot size 240×160 with 40 px gutters. Slots assigned row-major by assumption ID. If a quadrant fills, the skill warns the PM and offers to split the map (e.g. one map per outcome cluster).

Slot center math: quadrant center `(cx, cy)`; col `c ∈ {0,1,2,3}`; row `r ∈ {0,1,2,3}`:
```
slot_x = cx - 420 + 280 * c
slot_y = cy - 300 + 200 * r
```

### Color convention (sticky fill, by type)

Sticky `Type` → fill color (canonical hex on the right; sticky color name on the left is what `layout_create` expects for the `style.fill` property of a `sticky_note` item).

- **light_yellow** (`#fff9b1`) — Desirability assumption (will the customer want this?)
- **light_blue** (`#cce8fc`) — Usability assumption (can the customer use this?)
- **light_green** (`#d5f692`) — Feasibility assumption (can we build this?)
- **light_pink** (`#fbd5d8`) — Viability assumption (does this work for our business?)
- **violet** (`#c9b6f5`) — Ethical assumption (should we build this?)
- **gray** (`#d0d0d0`) — assumption with `Result: Confirmed | Rejected | Inconclusive` — already tested, kept on the map for context (overrides type color)

### Connectors

Optional: thin curved connectors from each sticky back to its parent solution sticky on the OST board, *only* if both boards are open in the same Miro project. The skill does not require this and will not error if the OST sticky isn't reachable. If added, connectors are native DSL `CONNECTOR` items in the `layout_create` / `layout_update` batch (`from`/`to` referencing the sticky and the OST solution item) — the layout DSL has a first-class `CONNECTOR` type.

## Known DSL limitations and canonical write forms

Validated against the official `mcp.miro.com` MCP during the native-toolchain spike (see `product/_test/assumption-map/native-spike/findings.md`). Treat the canonical write forms as load-bearing: the diff stability of refresh-mode `layout_update` depends on the write DSL matching what `layout_read` returns.

- **No `rotation` property** on any item type (TEXT, SHAPE, STICKY). The 4-axis-tip-label pattern above avoids needing rotation; do not introduce designs that require it.
- **`border_width=0` is rejected** by DSL validation ("must be greater than 0"). For visually borderless shapes, write `border_width=1` with `border_color` equal to `fill`. Visually identical at any zoom.
- **Defaults appear on read-back even when not written.** `layout_read` appends `border_opacity=1.0` to bordered SHAPEs, `shape=square align=center valign=middle` to STICKYs, and `color/font/size/align/valign` defaults to SHAPEs with empty content. **Write these defaults explicitly at create time** so the round-trip DSL is stable and `layout_update` `old_string` matches.
- **Transparent fill needs both props explicit.** Write `fill=#ffffff fill_opacity=0.0` together — Miro internally defaults `fill` to `#ffffff` and returns it on read, so writing only `fill_opacity=0.0` causes round-trip drift.
- **`layout_update` response serializes numerics inconsistently** (e.g. `fill_opacity=0` vs `0.0` from `layout_read`). Always re-read via `layout_read` before constructing the next `old_string` for `layout_update`. Never reuse an `old_string` across parallel updates — each write invalidates concurrent ones.

## Sidecar format

Each map gets its own standalone sidecar at `product/context/assumption-maps/SOL-{NN}-{slug}/miro-metadata.json`. No shared file with the OST or story map; cross-references are by `Parent Solution: SOL-{NN}` in the assumption files themselves.

```json
{
  "solution_ref": "SOL-09",
  "board_id": "uXjVOqr...",
  "board_url": "https://miro.com/app/board/uXjVOqr.../",
  "last_synced_at": "2026-04-29T...",
  "chrome": {
    "title_id": "...",
    "x_axis_line_id": "...",
    "y_axis_line_id": "...",
    "axis_tip_label_ids": {
      "high_importance": "...",
      "low_importance": "...",
      "weak_evidence": "...",
      "strong_evidence": "..."
    },
    "legend_swatch_ids": {
      "light_yellow": "...",
      "light_blue": "...",
      "light_green": "...",
      "light_pink": "...",
      "violet": "...",
      "gray": "..."
    },
    "legend_label_ids": {
      "light_yellow": "...",
      "...": "..."
    }
  },
  "stickies": {
    "ASSUMPTION-004": { "sticky_id": "...", "current_quadrant": "test_first" }
  }
}
```

The `current_quadrant` field per sticky is the absorb skill's anchor for detecting "moved between quadrants" events on the next pass. The `chrome` block records board-chrome item IDs so absorb mode can classify them as chrome (`unchanged` / `missing` only — never as data) and refresh mode can re-style them without re-creating.

## Modes

### 1. Create mode

Push repo → Miro for one solution.

**Inputs:** solution ID (e.g. `SOL-09`), and the set of assumption-test files whose `Parent Solution` matches it.

**Steps:**

0. **Pre-flight: materialize from synthesis if needed.** Check whether any `product/context/opportunity-solution-tree/assumptions/assumption-*.md` file has `Parent Solution: SOL-{NN}`. If none exist, read the iteration's `synthesis.md` (the iteration that shaped this solution — recorded in the solution file's frontmatter), find the matching `### SOL-candidate-*` block, and materialize each inline assumption as its own `assumption-{NNN}-{slug}.md` file (next-available `ASSUMPTION-NNN` ref_id). Use the synthesis-suggested `Importance` / `Evidence`; `Method` and `Success Criterion` start empty; `Result: Pending`. Report to the user how many were materialized before proceeding to step 1.
1. Read all `product/context/opportunity-solution-tree/assumptions/assumption-*.md` files; filter by `Parent Solution: SOL-{NN}`. Call `mcp__miro-official__layout_get_dsl` **once** here and reuse the spec (a prerequisite of `layout_create`).
2. Get the board: reuse an existing one keyed by `solution_ref` in `product/context/assumption-maps/SOL-{NN}-{slug}/miro-metadata.json` (refresh), or, for a new map, **mint an empty board with `mcp__miro-official__board_create`** (returns its URL/id). Board creation is a two-step sequence — `board_create` makes the board, `layout_create` (step 3) renders into it.
3. Place board chrome by rendering into the board's `miro_url` with `layout_create` in this order: title (upper-left), x-axis line, y-axis line, 4 axis-tip labels, 6 legend swatches, 6 legend labels. (`layout_create` renders into an existing board; it does not create one.) See "Miro layout" above for exact positions and the canonical write forms (explicit defaults, matching-color borders).
4. For each assumption: compute (quadrant, slot) from `Importance` and `Evidence`; create a sticky at the slot's coordinates with sticky color from `Type` (override to `gray` if `Result ≠ Pending`); write content as two `<p>` blocks — `{ID}` then `{abbreviated title from H1}` — mirroring the story-map sticky-content format.
5. Save the sidecar at `product/context/assumption-maps/SOL-{NN}-{slug}/miro-metadata.json` including the full `chrome` block (item IDs of every chrome item) and the `stickies` block.
6. Summarize to the user with the board URL and counts per quadrant. Flag if `test_first` is empty (suggests the team thinks they have nothing risky to validate — usually wrong; ask the PM to revisit importance/evidence ratings).

Reference: `reference/create-assumption-map.md` (to be written; expected to mirror `story-map/reference/create-story-map.md` in shape).

### 2. Refresh mode

Push repo → Miro, preserving the existing board.

1. Read the sidecar at `product/context/assumption-maps/SOL-{NN}-{slug}/miro-metadata.json`.
2. Diff current assumption files against recorded stickies.
3. For each diff (use `layout_update` per the canonical write forms above; re-read via `layout_read` before each update):
   - **Added** assumption → create a new sticky in the right quadrant; append to `stickies`.
   - **Importance/Evidence changed** → reposition into the new quadrant slot; update `current_quadrant`.
   - **Result became non-Pending** → recolor sticky to gray; do NOT move out of its quadrant (keeps tested-context visible).
   - **Removed** assumption → recolor sticky to gray and prepend "(Removed)" to content. Do NOT delete from Miro.
4. Save `last_synced_at`.

### 3. Absorb mode (two-pass: structural diff, then semantic interpretation)

Pull Miro → repo. The hero move for assumption-mapping workshops, where the team argues importance and evidence on the board and the AI then proposes which assumptions need test-design.

**Structural diff pass.** Using the sidecar as a map, classify every observed sticky:

- Known sticky, unchanged
- Known sticky, moved (new quadrant) → repo update candidate
- Known sticky, content changed (title rewritten) → flag for review
- New sticky (no sidecar record) → candidate new assumption
- Missing sticky (in sidecar, not on board) → warn, keep repo unchanged

**Semantic interpretation pass.** For each candidate change, propose:

- **Sticky moved into "test first"** → propose updating `Importance: High` and `Evidence: Weak` in the file; if `Method` and `Success Criterion` are still empty, scaffold them (with placeholders — "TODO: choose a test method") and ask the PM to fill them in.
- **Sticky moved out of "test first"** (importance dropped or evidence strengthened) → propose updating `Importance` / `Evidence`; ask whether the test plan should be archived or left in place.
- **New orphan sticky in any quadrant** → propose new assumption file; suggest `Type` from sticky color, `Importance` / `Evidence` from quadrant; ask for ID, hypothesis, and parent solution confirmation.
- **Sticky title rewritten** → propose updating the file's header and hypothesis.
- **Cluster of moves (3+ stickies repositioned together)** → ask if the team is re-rating an entire category (e.g. all desirability assumptions just got harder evidence); offer a batch update.

Reference: `reference/interpret-assumption-changes.md` (to be written; expected to mirror `story-map/reference/interpret-changes.md` in shape).

**Important:** absorb mode NEVER deletes repo files without explicit approval. A removed sticky is a warning, not a cascade.

## Open questions for the PM before building

Before creating an assumption map for the first time on a given solution:

1. **Scope.** Is this a per-solution map (one map for SOL-09) or a per-iteration roll-up (one map covering every assumption surfaced during this iteration)? Default: per-solution.
2. **Pre-populate from solution markdown?** Some teams write 5–10 candidate assumptions inline in the solution-shape doc; the skill can seed the map from those if `solution-shape.md` follows the convention (TBD; not currently used in this repo).
3. **Ethical-assumption category.** Torres' canonical model has four categories; many teams add a fifth for ethical/safety assumptions. Confirm the team uses five, not four.

## Error handling

- No Miro MCP available → tell the user which MCP to install and stop cleanly.
- Assumption file with no `Parent Solution` header → skip with warning, list skipped files at the end.
- Sidecar `assumption_maps` block missing for the target solution → offer to bootstrap by matching sticky content to assumption IDs.
- `Importance` or `Evidence` field absent on an existing assumption file → ask the PM to rate before render; do not guess.

## Related skills

- `story-map` — same four-piece pattern, grid topology (activity × NOW/NEXT/LATER).
- `opportunity-tree` — same four-piece pattern, tree topology. Assumption maps live under solutions branched in the OST; the OST is the source of `Parent Solution` references.
- `discovery-synthesis` — proposes candidate solutions with their initial assumptions inline in `synthesis.md`. Those assumptions materialize as `product/context/opportunity-solution-tree/assumptions/assumption-{NNN}-*.md` files when the PM commits the parent solution (`Status: Committed`) or when `/assumption-map create` runs against an uncommitted solution. See "Lifecycle and lazy materialization" above.

## Hardening checklist (for when the Miro MCP we want lands)

These need to be tested end-to-end before the skill claims production-readiness; they are the analogue of the same list pending for `story-map` and `opportunity-tree`:

- Coordinate math under quadrant overflow (>16 stickies per quadrant)
- Recolor + reposition behavior when both `Type` and `Importance/Evidence` change in the same refresh
- Absorb pass when a sticky is moved AND content-edited in the same workshop
- Round-trip stability — create → workshop edits → absorb → refresh produces the same board state without churn
- Sidecar conflict resolution if two PMs sync from different machines
