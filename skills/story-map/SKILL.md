---
name: story-map
description: Create a Jeff Patton story map in Miro from repo story files, read human changes back, and interpret their meaning. Use when a PM asks to build, refresh, or absorb a story map.
tags: [product-management, visualization, miro, workshop]
---

# Story Mapping Skill

Round-trip workflow between repo-resident user stories and a Miro story map. Backbone activities run across the top in temporal order; NOW / NEXT / LATER release slices run vertically; stories sit at the intersections.

The map is **Patton-narrative-scoped**: one map per iteration, representing the iteration's full end-to-end narrative — even when multiple actors are involved. Per Patton, the backbone reads as the system's flow through time (e.g. *Restaurant prepares → Courier picks up → Courier delivers → Order completes*), and actor handoffs sit on the same map so they're visible. Persona is an emoji-prefix attribute on stories and on backbone activity headers — one emoji per persona, so handoffs read along the spine — not a separate map or a swim-lane axis.

## When to use this skill

- **Create** a story map from existing stories (`create` mode).
- **Refresh** an existing story map after stories changed in the repo (`refresh` mode).
- **Read** a Miro board back and update the repo to match human changes from a workshop (`absorb` mode).

If unsure which mode, ask: "Are we pushing repo → board, pulling board → repo, or interpreting what changed on the board?"

## Required tools

- Official Miro MCP at `mcp.miro.com`: `mcp__miro-official__layout_get_dsl` (load the DSL grammar **once** per run, then reuse — a prerequisite of `layout_create`), `mcp__miro-official__layout_create` (build the board + items), `mcp__miro-official__layout_read` (round-trip read for absorb), `mcp__miro-official__layout_update` (refresh-mode mutations), `mcp__miro-official__context_get` (board metadata). Story maps carry no connectors, so none is needed (release horizons are thin rectangles, not edges) — though the DSL does have a first-class `CONNECTOR` type available if a future map variant wants one.
- Filesystem access to the iteration's `stories/` and `story-maps/activities/` directories, the product-level persona legend at `product/context/personas.md`, and the iteration's sidecar at `product/iterations/{iteration-slug}/story-maps/miro-metadata.json`.

**Execution context:** this skill runs *inside* a board worker agent (`board-builder` for create / refresh, `absorb-interpreter` + `board-writer` for absorb), which is where the official Miro MCP is registered. The main thread never calls `mcp__miro-official__*` directly — the router (`story-shaping`) spawns the worker, the worker loads this skill. The official MCP renders stickies, shapes (including rounded rectangles), and text — the primitives this spec uses. See the canonical write forms in `reference/create-story-map.md` and `reference/read-board-state.md` (explicit defaults, matching-color borders) so create output is diff-stable against `layout_read`.

## Board naming and location

**Board name:** `{project} — Story Map — {iteration-slug}`

`{project}` is derived from `basename "$(git rev-parse --show-toplevel)"`. Override by placing a single-line file at `.claude/project-name.txt` in the host repo. `{iteration-slug}` is the iteration folder name (e.g. `YYYY-MM-DD-{iteration-slug}`).

**Cardinality:** exactly one story-map board per iteration. If the iteration has genuinely independent narratives that don't share a backbone, create a second iteration — don't split the map.

**Location:** if the host's Miro account uses team folders, place the board in `{project}` (or a sub-folder if the host has one per iteration). The skill does not create folders.

**Lifecycle:** when an iteration moves to `_archive/`, rename the board to `{project} — Archived — Story Map — {iteration-slug}`. Do not delete.

**Referencing the board in chat:** whenever this skill — or any response Claude writes about the board — refers to it, include the full URL from the sidecar's `board_url` field (e.g., `https://miro.com/app/board/{board_id}=`). Don't reference a board by name or ID alone; the URL is what makes it one click from Claude Code to the live board. This rule applies anywhere a Miro board is mentioned.

## Objects on the map (visual vocabulary)

Two layers, distinguishable by shape:

- **Stickies = delivery layer.** Things the team commits to build.
- **Rounded rectangles = discovery layer.** Things being investigated. Same fill colors as OST and assumption-map so the visual language is one vocabulary across all three boards.

| Object | Miro form | Fill color | Notes |
|---|---|---|---|
| Activity header (backbone) | Sticky | Miro `dark_blue` | Top row, temporal order. One per backbone step; each header maps to an `activities/activity-{NN}-{slug}.md` file (see "Activity files"). The owning persona(s) from the activity file's `Personas:` field render as an emoji prefix on the header (`🛵 Courier picks up`), so the backbone reads as a sequence of actors and handoffs are visible along the spine. Sub-activity rows (Patton "tasks") are not rendered — add activity files if finer granularity is needed. |
| Story | Sticky | type-color (see below) | Body cards. Persona indicated via emoji prefix on content (one emoji per persona for multi-actor stories). |
| Release horizon | Thin rectangle (`total_width × 12`, `#222222`) | n/a | Horizontal line separating NOW / NEXT / LATER, spanning the full map width. Three per map (NOW/NEXT, NEXT/LATER, LATER end). |
| Swim-lane label | Text, bold, `font_size 72` | n/a | One per slice (NOW, NEXT, LATER), placed to the left of the map and vertically centered in the lane. NOW label is the left-edge bounds landmark. |
| **Opportunity** (Torres-unified: problem / pain / need / desire) | Rounded rectangle | n/a | **Dormant** (2026-05-14 decision). An opportunity relates to an *outcome* (the OST's job), not an *activity* — nothing renders, classifies, or forwards opportunities on the story map today. Kept as a spec placeholder for the future cross-board linkage release. |
| **Assumption** | Rounded rectangle | Miro `light_green` | Things we're treating as true but haven't verified. Placed **beside the story it questions**, not in a band. Absorb detects and surfaces these as informational `ASSUMPTION_CAPTURED` notices — no forward, no linkage today. Disambiguated from a `light_green` Refactor sticky by **shape**. |
| Persona legend | Rectangle shape with HTML content | `#f5f5f5` | One shape (not a frame, not stacked text items) right of the map, text at `size 24`. HTML `<p>` per persona, `<strong>`-wrapped emoji + slug. Right-edge bounds landmark. |
| Shape legend | Heading text + 3 copyable sample shapes | sample fills | Below the persona legend. Real copyable samples — a `light_yellow` story sticky, a `dark_blue` activity sticky, a `light_green` assumption rounded rectangle — each labelled in its own content. Off-map chrome; recorded in the sidecar so absorb doesn't misread the samples as orphans. |
| Iteration title | Text, bold, `font_size 96` | n/a | Top of the board, above the activity headers. Content is `{iteration title} — Story Map`. Top-edge bounds landmark. |

**Story type colors** (sticky fill):

- **light_yellow** — regular user stories
- **cyan** — infrastructure / technical
- **violet** — spike / research
- **light_blue** — quality / testing / compliance
- **light_orange** — risk / defect-prone
- **red** — bug / defect
- **light_green** — refactor / tech debt
- **gray** — documentation or removed

Activity headers always **dark_blue**. Persona legend is a `#f5f5f5` rectangle shape (HTML content), not a frame.

**Persona indication:** stories and activity headers carry an emoji prefix drawn from the product-level persona legend (`product/context/personas.md` `## Legend`). Example: `🍳 Restaurant confirms item count at pack-ready`. The legend on the board maps emoji → persona name.

A story or activity may name **more than one persona** (the `Personas:` field is comma-separated). Render one emoji per persona, space-separated, in the order written — primary actor first. This is how Patton's handoffs show up: a multi-persona story is a moment two actors act together (e.g. `🛵 🍽️ STORY-008 / Eater enters handoff PIN`, the courier-to-eater PIN exchange), and a multi-persona activity header marks a co-owned backbone step. Where adjacent activity headers carry different emoji, the reader sees the baton pass along the spine. Keep the visual to ~3 emoji; an activity that genuinely needs more is usually a hidden handoff that wants splitting into separate activity files — surface that to the PM rather than rendering a crowded header.

**Map bounds (for absorb mode):** the canonical map area is defined by four landmark items — title (top), LATER end horizon line (bottom), NOW swim-lane label (left), persona legend (right). Absorb mode reads this rectangle and treats anything outside as off-map. The mechanism is landmark-relative, so if a PM drags a landmark, the bounds shift with it.

## Modes

### 1. Create mode

Push repo → Miro. Follow `reference/create-story-map.md` end-to-end.

**Inputs:** iteration slug. All stories under `product/iterations/{iteration-slug}/stories/`, the backbone from `story-maps/activities/*.md` (one file per activity, ordered by `Order`), the persona legend from `product/context/personas.md` `## Legend`, plus an optional `assumptions.md` file (or whatever the iteration uses). An `opportunities.md` file, if present, is ignored — opportunities on the story map are dormant.

**Outputs:**
- A new Miro board named per the convention above with the iteration title (top-edge landmark), activity headers, story stickies (persona-prefixed), assumption rounded rectangles placed beside their related stories, NOW/NEXT/LATER release horizons + swim-lane labels, and a persona legend rectangle (right-edge landmark).
- `story-maps/activities/activity-{NN}-{slug}.md` files, if the iteration has none yet — activity files are a prerequisite the same way stories are, so create mode drafts them from the stories' inferred activities (with PM approval) before rendering.
- `product/iterations/{iteration-slug}/story-maps/miro-metadata.json` sidecar recording every Miro item ID.
- A summary to the user with the board URL.

### 2. Refresh mode

Push repo → Miro, preserving the existing board.

**Inputs:** iteration slug.

1. Read `product/iterations/{iteration-slug}/story-maps/miro-metadata.json`.
2. Diff repo state against sidecar.
3. For each diff:
   - **Added** story → create a new sticky and append its ID to the sidecar.
   - **Removed** story → update the sticky color to gray and prepend "(Removed)" to the content. Do NOT delete from Miro.
   - **Changed** priority → reposition to the new swim lane.
   - **Changed** title / type / persona → update content or color.
   - **Added** assumption → create a `light_green` rounded rectangle beside its related story. (Opportunities are dormant — not rendered.)
   - **Added / renamed** activity (a new `activities/*.md` file, or a title change in an existing one) → create or re-content the dark_blue header sticky, recompute spans, and update the sidecar entry keyed by `activity_ref`.
4. Save `last_synced_at` in the sidecar.

Refresh also **re-canonicalizes** any sticky a human has touched on the board: the Miro inline editor collapses two-line sticky content to a single `<p>` line on first click-into-edit (see `reference/read-board-state.md` "Sticky-content parser"). Re-rendering the sticky content from the story file restores the canonical `{emoji} STORY-NNN\n{short title}` form. Run refresh after an absorb if the board has visually drifted.

### 3. Absorb mode (two-pass: structural diff, then semantic interpretation)

Pull Miro → repo. This is the green-field capability at the center of the round-trip. Two passes, run in order.

**Inputs:** iteration slug. Operates against the sidecar at `story-maps/miro-metadata.json`. New stories surfaced by absorb get added to the iteration's `stories/` directory after PM approval. New assumptions surfaced by absorb are **detected and surfaced** as informational `ASSUMPTION_CAPTURED` notices recorded in the sidecar — not forwarded, not absorbed, no repo write (2026-05-14 decision; cross-board linkage is a later release).

- **Structural diff pass** — see `reference/read-board-state.md`. Classifies every board item against the sidecar; produces a structured list of moves, adds, removes, content changes. No interpretation.
- **Semantic interpretation pass** — see `reference/interpret-changes.md`. Takes the structural diff and reasons about what the human edits *mean* (new story, rescope, backbone promotion, deprecation), and surfaces captured assumptions informationally. Always proposes; the PM decides.

This two-pass split maps to established practice in tree-diff theory — see graphtage and Diff/TS for prior art on the structural-vs-semantic distinction.

**High-level flow:**

1. **Fetch** board state via `mcp__miro-official__layout_read` (see `reference/read-board-state.md`).
2. **Structural diff pass:** using the sidecar as a map, classify every observed board item as:
   - Known item, unchanged
   - Known item, moved (new swim lane / new activity column) → repo update
   - Known item, content changed → flag for review (repo keeps source-of-truth, but note the change)
   - Known item, recolored (new fill color) → story `Type` reclassification, deterministic structural proposal
   - New sticky with no sidecar record → candidate new story
   - New rounded rectangle with Miro `light_green` fill → orphan assumption (classified by shape + color, anywhere on the map) → surfaced informationally
   - Missing item (in sidecar, not on board) → warn, keep repo unchanged
3. **Semantic interpretation pass:** for each candidate, run the interpretation prompt in `reference/interpret-changes.md` to decide:
   - New story? Suggest ID, activity, priority, draft title, persona prefix.
   - New activity column? Propose a new `activities/activity-{NN}-{slug}.md` (backbone extension — parallel to a new story).
   - Re-slicing of releases? Propose the new slice boundaries.
   - New assumption? Surface it as an informational `ASSUMPTION_CAPTURED` notice with its `nearest_story` — no forward, no proposal, no repo write (cross-board linkage deferred).
4. **Propose, don't apply.** Present every proposed repo change to the user for approval. On approval, write new story markdown files, update existing ones, and update the sidecar.

**Important:** absorb mode NEVER deletes repo files without explicit approval. A sticky removed from the board is a warning, not a cascade.

## Story file format

Each story lives at `product/iterations/{iteration-slug}/stories/story-{NNN}-{slug}.md`.

Header metadata (parsed by this skill):

```
**Story ID**: {NNN}
**Epic**: EPIC-{NNN} - {epic title}
**Priority**: Critical | High | Medium | Low
**Type**: Regular | Infrastructure | Spike | Quality | Risk | Bug | Refactor | Doc (optional; defaults to Regular)
**Status**: Draft | Ready | In Progress | Built | Done
**Personas**: {persona-slug} (optionally comma-separated for stories that span actors)
**Labels**: {iteration-slug}, {area}
```

`Type` drives the sticky fill color (see `reference/create-story-map.md` Step 1's color table). It is optional — absent means Regular. Absorb mode's `recolored` state proposes adding or updating this line when a human changes a sticky's color on the board.

The skill renders persona as an emoji prefix — one emoji per persona named in the comma-separated `Personas:` field, in the order written. Persona-emoji mapping is recorded in the product-level legend (`product/context/personas.md` `## Legend`) and reproduced on the board's persona legend rectangle.

Body follows with user story, acceptance criteria, design references, etc. See `templates/story.md`.

## Activity files

The backbone is stored as first-class activity files — one `.md` per backbone activity, mirroring the OST's one-object-one-file rule. The iteration README holds no map structure; like the OST and assumption-map READMEs, it is orientation prose only.

**Location:** `product/iterations/{iteration-slug}/story-maps/activities/activity-{NN}-{slug}.md`

Co-located under `story-maps/` (not the iteration root) because the backbone is a property of the map, not the whole iteration — the sidecar lives there for the same reason.

**Header block** (parsed by this skill; mirrors the OST node-file style):

```
# Activity: Restaurant prepares order

**ID**: ACTIVITY-01
**Order**: 1
**Personas**: restaurant
**Description**: Optional prose about this lifecycle step.
```

`ID` and `Order` are required; `Personas` (which persona(s) own this lifecycle step) and `Description` are optional. `Order` drives left-to-right column placement. `Personas` resolves to an emoji prefix on the header (one emoji per persona, comma-separated → space-separated), so a co-owned step shows both actors and the backbone reads as a sequence of owners — this is how Patton's handoffs become visible on the spine. The activity's display text — what renders on the dark_blue header sticky — is that emoji prefix followed by the `#` title after the `Activity:` prefix (the prefix is omitted if the file has no `Personas:` field). The skill enumerates `activities/*.md` sorted by `Order` to lay out the columns; if none exist, it warns and offers to draft them from the stories' inferred activities.

## Persona legend

The persona legend (slug · emoji · display name) is product-level, not per-iteration. The skill reads the `## Legend` table in `product/context/personas.md`:

```
## Legend

| slug | emoji | name |
|---|---|---|
| restaurant | 🍳 | Restaurant pack-out staff |
| courier | 🛵 | Delivery courier |
| eater | 🍽️ | Person receiving the order |
| cx | 🎧 | Customer experience / dispute handler |
```

Persona is a **story attribute** (the `Personas:` field on each story `.md`), not a board object — there are no persona `.md` files. The skill reads the legend at create/refresh time to build the persona legend rectangle and resolve emoji prefixes. If a story names a persona missing from the legend, warn and offer to append a row to `product/context/personas.md` — new personas surfacing mid-story-mapping are possible but rare.

## Sidecar format

One sidecar per iteration at `product/iterations/{iteration-slug}/story-maps/miro-metadata.json`. The sidecar is a **pure index** — board identity, layout constants, bounds, and per-object entries that reference `.md` files by ref-id, same shape as the OST and assumption-map sidecars. It stores Miro item IDs for every board element: title, activity headers (each with its `activity_ref` → `activities/*.md`, plus rendered `span_left` / `span_width`), release horizons, swim-lane labels, persona legend, shape legend, each story sticky (`story_id` → `stories/*.md`, plus rendered position / lane / color and the `sticky_short_title`, a render-time choice that is not reverse-derivable), and each assumption (with its `nearest_story`). The `opportunities` array stays empty — opportunities are dormant. Also captures the layout band table, the `subcolumn_pitch` / `rows_per_lane` grid constants, and the landmark-relative `bounds` block so absorb mode can read the canonical map area without hard-coded coordinates.

No authoritative *content* is duplicated into the sidecar: backbone order and activity names live in the activity files; the persona legend lives in `product/context/personas.md`. (Earlier sidecars carried standalone `backbone` / `personas` blocks — those are gone; anything position- or render-shaped in the sidecar is derived state, re-derivable from board geometry on absorb.)

## Activity × release layout (canonical)

See `reference/create-story-map.md` for the full coordinate specification. Summary:

- Iteration title (bold, font_size 96) at the top (y=-1230), content `{iteration title} — Story Map`. Top-edge bounds landmark.
- Activity headers (dark_blue stickies) at y=-600. Each activity owns a horizontal **span**, not a fixed column — the span runs from its header's left edge to the next header's left edge (last activity owns everything to its right). Header is left-aligned to its span. Span width = sub-columns needed × 600 px; the whole map is centered around x=0. Stories under an activity fill a grid within the span (down a sub-column to the lane's row limit — NOW 5, NEXT/LATER 3 — then wrap right).
- NOW / NEXT / LATER stories below, separated by three release horizons (thin `total_width × 12 #222222` rectangles at y=675, 1653, 2631).
- Swim-lane label per slice (bold text, font_size 72) at `x = map_left - 350`, vertically centered in each lane. NOW label is the left-edge bounds landmark.
- Persona legend (`#f5f5f5` rectangle, HTML content, text `size 24`) right of the map. Right-edge bounds landmark. Shape legend (copyable sample shapes) stacked below it.
- Assumptions (`light_green` rounded rectangles) are placed beside the story each one questions — no separate band. Classified on absorb by shape + color, anywhere on the map.

## Error handling

- No Miro MCP available → tell the user which MCP to install and stop cleanly.
- Story file with no Story ID header → skip with warning, list skipped files at end.
- Story with no `Personas:` field → warn and ask the PM to assign at least one persona before render.
- No `story-maps/activities/` files → warn and offer to draft them from the stories' inferred activities.
- `product/context/personas.md` with no `## Legend` table → warn and stop; offer to draft one from the stories' personas.
- Story names a persona missing from the legend → warn and offer to append a row to `product/context/personas.md`.
- Sidecar missing but board referenced → offer to rebuild the sidecar by matching sticky content to story IDs.
- Two stories with the same ID → refuse to sync, ask the user to resolve.

## Related skills

- `opportunity-tree` — same round-trip pattern, tree topology. Story-map ↔ OST linkage is **deferred** (2026-05-14 decision) — opportunities on the story map are dormant; the OST owns opportunities.
- `assumption-map` — Torres assumption-mapping. Assumptions surfaced on a story map are **captured and surfaced informationally** for the PM to route by hand; absorb does not forward them to the assumption-map or OST today (cross-board linkage is a later release).
