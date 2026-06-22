# Reference: Read Board State — Structural Diff Pass

This is the `absorb` mode first-pass workflow. Its job: read the current Miro board state, classify every item against the sidecar, and produce a structured diff. No interpretation happens here — see `interpret-changes.md` for the semantic interpretation pass.

The structural-vs-semantic split is consistent with prior art on tree-diff (graphtage, Diff/TS) — structural pass detects positional and content change without inferring intent.

## Inputs

- `product/iterations/{iteration-slug}/story-maps/miro-metadata.json` (sidecar with recorded item IDs)
- Story files under `product/iterations/{iteration-slug}/stories/`
- Activity files under `product/iterations/{iteration-slug}/story-maps/activities/` (each activity header's `.md` home, associated via the sidecar's `activity_ref`)
- Live Miro board, read via `layout_read` (official Miro MCP) — or any board-read mechanism that returns items keyed by ID with position, content, and fill color

## Step 1: Load the sidecar

Parse `miro-metadata.json`. Build a lookup table keyed by Miro item ID:

```
sidecar_index = {
  "<miro_item_id>": {
    "role": "title" | "persona_legend" | "shape_legend" |
            "swim_lane_label" | "activity_header" | "release_horizon" |
            "story" | "opportunity" | "assumption",
    "story_id": "STORY-001",            // for stories
    "activity_ref": "ACTIVITY-01",      // for activity headers → activities/*.md
    "kind": "opportunity" | "assumption", // for discovery-layer items
    "expected_activity": "...",         // for stories
    "expected_swim_lane": "NOW|NEXT|LATER",
    "expected_x": ...,
    "expected_y": ...,
    "expected_fill_color": "...",       // sidecar `fill_color`
    "expected_short_title": "...",      // for stories: sidecar `sticky_short_title`
    "content_hash": "..."               // for discovery-layer items only
  },
  ...
}
```

Stories are compared on three axes: position (activity column + swim lane), the parsed sticky short title (against `expected_short_title`), and fill color (against `expected_fill_color`). Story stickies carry no `content_hash` — the short title is the content key, because the abbreviation rendered on the sticky is not reverse-derivable from the story file. Discovery-layer items still use `content_hash`.

## Step 2: Fetch current board

Call `layout_read` (official Miro MCP) with the `board_id` from the sidecar. It returns the full top-level item list — stickies, text, shapes (rounded rectangles in particular), frames — each with ID, position, content, and fill color. Story maps carry no connectors, so no connector read is needed; if a future map adds them, `.claude/skills/opportunity-tree/scripts/read-connectors.sh` covers that gap.

The workflow below is fetch-agnostic: any read mechanism that yields items keyed by ID with position, content, and fill color works in place of `layout_read`.

## Step 3: Infer the live coordinate system

Do NOT assume canonical coordinates from `create-story-map.md` — humans may have repositioned activity headers, slice connectors, or whole columns during the workshop.

**Activity spans:** an activity owns the horizontal span from its
header's left edge to the next header's left edge — not a fixed column
(see `create-story-map.md` §3). Find all stickies whose ID is recorded
as `activity_header` in the sidecar, read their current x-positions, and
sort ascending. With `STICKY_W = 199`, `left_edge(header_i) = header_i.x
− STICKY_W/2`. Activity *i* owns the x-range `[left_edge(header_i),
left_edge(header_{i+1}))`; the **last** activity owns `[left_edge(header_last),
+∞)`. A story belongs to whichever activity's range contains its
**center x**.

- A story whose center x falls left of the first header's left edge →
  assign to activity 0 and emit a warning.
- If a header is **missing** from the board, its live x is unknown — fall
  back to that header's recorded `span_left` (its left edge) from the
  sidecar `activity_headers` record, so the range test still has a
  boundary. Emit the Step 3 fallback warning.
- **Right-of-rightmost hint.** An orphan whose center x falls more than
  one `subcolumn_pitch` to the right of `left_edge(header_last)` is
  attributed to the rightmost activity (per the range rule) but flagged
  with `right_of_rightmost: true` on the change record. This is a Task C
  hint: a cluster of right-of-rightmost orphans is the structural signal
  for a `BACKBONE_EXTENSION` proposal, distinct from "new stories under
  the existing rightmost column." Without the flag the structural table
  reads misleadingly ("at Disputes resolve / NOW" implies the column
  already extends there) and Task C has to re-derive the geometry.

This range test replaces the older nearest-header-x rule. It is
equivalent for a single-sub-column map (each story sits under its
header) and correct for a multi-sub-column activity, where a story two
sub-columns right of the header is still inside that activity's span and
must not be pulled into the next activity.

**Swim lanes:** find the release-horizon lines (sidecar `release_horizons[]`, each with a `line_id` and `y`) and read their current y. A sticky with y between `activity_headers.y` and the NOW/NEXT horizon's y is in NOW; between the NOW/NEXT horizon and the NEXT/LATER horizon → NEXT; between the NEXT/LATER horizon and the LATER/end horizon → LATER.

**Discovery-layer shapes** are classified by **shape + fill color, anywhere on the map** — not by a band region. A rounded rectangle with a green fill is an assumption wherever it sits. There is no "discovery band" location rule: assumptions are placed *next to the story they question*, not in a strip above the backbone. For each discovery-layer shape, compute its **`nearest_story`**: the story sticky whose center is closest to the shape's center. (Opportunities on the story map are dormant — see Step 4 state 8 — so the only discovery shape absorb classifies today is the assumption.)

> **Fill color on the read side is hex, not a palette name.** The PM
> *places* an assumption by picking the Miro palette color named
> `light_green` — but `layout_read` returns palette names only for
> **stickies** (`color=light_yellow`); for **shapes** it returns a hex
> fill (`fill=#adf0c7`). The assumption classifier must therefore match
> a **green hex range** on shape fills, not a literal `light_green`
> string. Treat any rounded rectangle whose fill hex reads as green
> (green channel dominant, distinct from the gray/yellow/blue shape
> fills used for horizons, the persona legend, and release lines) as an
> assumption. "Miro color name `light_green`" is the *placement
> instruction given to the PM* (`create-story-map.md` §4.5); it is not a
> string the read-back classifier can equality-check.

## Step 4: Classify each board item

For every observed item, classify into one of the states below. Before
classifying stickies, normalize their content with the parser in this
step's first subsection.

**Board chrome is exempt.** An item whose sidecar role is `title`,
`persona_legend`, `shape_legend`, `swim_lane_label`, or `release_horizon`
is not a delivery or discovery item — classify it only as `unchanged`
(id present on the board) or `missing` (id absent). The delivery- and
discovery-layer states below apply to stories and discovery shapes only.
This is what keeps the §4.7 shape-legend samples — a `light_yellow`
sticky, a `dark_blue` sticky, and a `light_green` rounded rectangle —
from being misread as `orphan_sticky` / `orphan_assumption`: they are
recorded in the sidecar with role `shape_legend`, so they never reach
the orphan states.

### Sticky-content parser

Stickies are authored as two `<p>` blocks —
`<p>{emoji_prefix} STORY-{NNN}</p><p>{short title}</p>` — which is the
same HTML shape Miro's inline editor produces when a human touches a
sticky (see `reference_miro_editor_side_effects`). So freshly rendered
and human-touched stickies share one content form; there is no
"canonical vs collapsed" split to reconcile. Two legacy variants still
turn up and the parser tolerates them: stickies rendered before the
`<p>` convention (literal `\n` between the two lines), and stickies
rendered before the priority block was dropped (a bare `{Priority}`
word inlined at the end).

Normalization steps, in order:

1. Strip `<p>…</p>` wrappers — treat each `</p><p>` boundary and any
   literal `\n` as a line break; HTML-decode entities (`&#x1f6f5;` →
   🛵, `&#39;` → `'`, etc.).
2. Split into tokens. The **emoji prefix** is the leading run of
   emoji codepoints, regardless of intervening whitespace — `🎧Restaurant`
   parses identically to `🎧 Restaurant` (a missing space after the emoji
   is a common human-typed form on Miro and must not break parsing).
   Multi-persona prefixes are still recognized whether the emojis are
   space-separated or run together. The **id** is the first
   `STORY-\d+` token. Everything after the id token is the
   **short-title remainder**.
3. **Strip a trailing priority token.** If the remainder ends with a
   bare `Critical` / `High` / `Medium` / `Low` word (a legacy
   priority block), drop it. Priority is not part of the sticky
   content model — it lives in the story file and is reflected only
   by swim lane. Collapse internal runs of whitespace to single
   spaces and trim.
4. The result is the **parsed short title**. Compare it against the
   sidecar's `expected_short_title`.

This parser is the single content key for story stickies — there is no
`content_hash` for stickies. A sticky whose only board-side difference
is a legacy form reshaped to the `<p>` form (same emoji, same id, same
parsed short title) is **not** a content change.

### Known limitation — `layout_update` and sticky newlines

The official MCP's `layout_update` re-serializes the *whole* board to
DSL before diffing. A sticky whose content carries a literal `\n`
serializes to a multi-line DSL entry that the MCP's own parser then
rejects (`Internal error parsing current DSL: … invalid syntax`) —
and because it is a whole-board parse, **one bad sticky fails every
`layout_update` call on that board**, not just the one touching that
sticky. The `<p>`-block authoring form above avoids this: it
round-trips through the DSL as a single clean line. When absorb (or
any tool) must update a board that still has legacy `\n` stickies,
fall back to REST PATCH on the individual items
(`PATCH /v2/boards/{id}/sticky_notes/{item_id}`) rather than
`layout_update`. Re-canonicalizing those stickies to the `<p>` form
clears the limitation permanently.

### Delivery layer (stickies)

1. **unchanged** — id in sidecar; position still in expected activity/lane; parsed short title matches `expected_short_title`; fill color matches `expected_fill_color`.
2. **moved** — id in sidecar, but current column or swim lane differs from expected.
3. **content_changed** — id in sidecar, parsed short title differs from `expected_short_title`. (A legacy form reshaped to the `<p>` form alone is **not** a content change — see the parser above.)
4. **recolored** — id in sidecar; position and parsed short title match; observed fill color differs from `expected_fill_color`. A recolor is a story `Type` reclassification — see Step 6 for the proposal.
5. **moved_and_changed** — any combination of moved / content_changed / recolored on the same sticky. Report each axis in the change record.
6. **orphan_sticky** — sticky on the board with no record in the sidecar. Color and position suggest interpretation: candidate new story (if in a delivery-layer swim lane) or **candidate new activity** (a `dark_blue` sticky in the activity-header row). Known activity headers are matched to their `activities/*.md` file via the sidecar's `activity_ref`; a header sticky with no `activity_ref` is the structural signal for a new activity — the semantic pass proposes creating an `activities/activity-{NN}-{slug}.md` (Task C), parallel to how a new story sticky proposes a story file.
7. **candidate_story** — sticky with no sidecar record but whose content includes a `STORY-\d+` pattern.

### Activity-header content parser

Activity headers render as `{emoji_prefix} {activity name}` — the emoji
prefix is the owning persona(s) from the activity file's `Personas:`
field (one emoji per persona, space-separated). When header text
matters — a known header whose name was edited, or an orphan header
proposing a new activity — split it the same way story stickies are
split:

1. Strip `<p>…</p>` wrappers and HTML-decode entities.
2. The **emoji prefix** is the leading run of emoji codepoints
   (space-separated or run together, same tolerance as the story
   parser). Map each emoji back to a persona slug via the legend; the
   ordered list is the header's `Personas:`. Everything after the
   prefix is the **activity name**.
3. Compare the parsed activity name against the sidecar's activity
   record / the `activities/*.md` `#` title. A header whose only
   board-side difference is an added/removed/reordered emoji prefix is
   **not** an activity rename — it's a persona-ownership change on the
   step. Surface it as such (propose updating the activity file's
   `Personas:` field), not as a backbone rename.

For an **orphan header** (new activity, no `activity_ref`), the parsed
emoji prefix seeds the proposed `activities/*.md` file's `Personas:`
field; the parsed activity name seeds its `#` title (Task C).

### Discovery layer (rounded rectangles)

8. **orphan_opportunity** — *dormant.* Per the 2026-05-14 decision,
   opportunities on the story map are out of scope: absorb does not
   classify, surface, or forward opportunity-colored shapes today. The
   state is kept named so a future cross-board-linkage release can
   reactivate it. If a rounded rectangle appears that is clearly an
   opportunity (and not an assumption), leave it unclassified and note it
   in `warnings` — do not fail.
9. **orphan_assumption** — a rounded rectangle with a **green hex fill**
   (see Step 3's fill-color note — `layout_read` returns hex for shapes,
   not the `light_green` palette name) and no sidecar record, **anywhere
   on the map**. Record its parsed content and its `nearest_story`
   (Step 3). This is the only discovery state absorb actively produces
   today.
10. **discovery_moved** — a known (sidecar-recorded) assumption whose
    `nearest_story` now differs from the recorded one — it was dragged
    beside a different story.
11. **discovery_content_changed** — a known assumption whose content hash
    differs from the sidecar's.

Green is also the story-`Type` "Refactor" sticky color — the
disambiguator is **shape**: a green *sticky* (palette name `light_green`)
is a Refactor story, a green *rounded rectangle* (green hex fill) is an
assumption. Classify on shape first, then color.

### Missing-from-board (any role)

12. **missing** — recorded item not found on the live board. Report as a warning; do NOT delete repo data.

## Step 5: Emit a structural diff

Produce a structured object the user (and `interpret-changes.md`) can read:

```json
{
  "board_id": "...",
  "fetched_at": "2026-05-11T19:30:00Z",
  "summary": {
    "total_items_observed": 42,
    "unchanged": 35,
    "moved": 2,
    "content_changed": 1,
    "recolored": 1,
    "orphan_sticky": 1,
    "orphan_assumption": 1,
    "discovery_moved": 0,
    "discovery_content_changed": 0,
    "missing": 0
  },
  "changes": [
    {
      "state": "moved",
      "item_id": "...",
      "story_id": "STORY-007",
      "from": {"activity": "Courier picks up", "swim_lane": "NEXT"},
      "to":   {"activity": "Courier delivers", "swim_lane": "NOW"}
    },
    {
      "state": "content_changed",
      "item_id": "...",
      "story_id": "STORY-009",
      "from_short_title": "SMS PIN fallback to eater's phone",
      "to_short_title": "SMS PIN fallback after 30s of no in-app entry"
    },
    {
      "state": "recolored",
      "item_id": "...",
      "story_id": "STORY-005",
      "from_fill_color": "light_yellow",
      "to_fill_color": "cyan",
      "implied_type": {"from": "Regular", "to": "Infrastructure"}
    },
    {
      "state": "orphan_sticky",
      "item_id": "...",
      "content": "🛵 Courier confirms ETA before pickup",
      "position": {"x": -300, "y": 200, "activity_column": "Courier picks up", "swim_lane": "NOW"},
      "fill_color": "light_yellow"
    },
    {
      "state": "orphan_assumption",
      "item_id": "...",
      "content": "Couriers will tap a one-tap transit flag mid-route",
      "nearest_story": "STORY-012",
      "fill_color": "#adf0c7",
      "note": "shape fill is hex from layout_read — green range → assumption"
    }
  ],
  "warnings": []
}
```

`nearest_story` for a discovery-layer shape is the story sticky whose
center is closest to the shape's center — it records which story the
assumption was placed beside. The interpretation pass surfaces it so the
PM can see the assumption-to-story relationship; per the 2026-05-14
decision absorb does not forward it anywhere.

## Step 6: Present the diff to the user

Display in a compact table:

```
Board changes since last sync (2026-05-10 18:42):

  DELIVERY LAYER
    MOVED (1):
      STORY-007  Courier picks up / NEXT  →  Courier delivers / NOW
    CONTENT CHANGED (1):
      STORY-009  parsed short title differs — board has edited text
    RECOLORED (1):
      STORY-005  light_yellow → cyan  (Type: Regular → Infrastructure)
    ORPHAN STICKIES (1):
      [light_yellow] "🛵 Courier confirms ETA before pickup"
        at Courier picks up / NOW — looks like a new story
    MISSING (0)

  DISCOVERY LAYER
    NEW ASSUMPTIONS (1):
      "Couriers will tap a one-tap transit flag mid-route"
        beside STORY-012 — captured for the PM to route by hand
```

Then ask: "Apply structural changes (moves, recolors) to the repo? Run semantic interpretation on the orphans?"

On approval for structural-only changes: update the affected story markdown headers (`Priority` for swim-lane moves, `Type` for recolors) and update sidecar `expected_*` fields. Do NOT auto-apply content changes or discovery-layer changes — those always route through `interpret-changes.md`.

**Swim lane → priority is lossy.** The forward mapping collapses two priorities into NOW: Critical→NOW, High→NOW, Medium→NEXT, Low→LATER. Reversing it, NEXT→Medium and LATER→Low are unambiguous, but NOW could be either Critical or High. Resolve a story that landed in NOW this way:
- If the story's current `Priority` is already Critical or High, leave it unchanged — a move within or into NOW carries no signal to change it.
- If it moved into NOW from NEXT or LATER (so its priority was Medium or Low), default the new priority to **High** and flag it in the diff summary, so the PM can promote it to Critical if that's what they meant.

**Recolor → Type is deterministic.** A `recolored` sticky is a story-`Type` reclassification. Map the new fill color to a `Type` via the `create-story-map.md` color table — `light_yellow`→Regular, `cyan`→Infrastructure, `violet`→Spike, `light_blue`→Quality, `light_orange`→Risk, `red`→Bug, `light_green`→Refactor, `gray`→Doc — and propose the story-file edit:

```
PROPOSED TYPE UPDATE (structural)
  STORY-005  "Courier flags pickup issue with chip-list reason"
    Fill color changed:  light_yellow  →  cyan
    Type mapping:        cyan → Infrastructure

  Proposed edit (story-005-courier-flag-pickup-issue.md):
    Add/replace header line:  **Type**: Infrastructure
    (insert after the **Priority** line if no Type line exists)

  On accept, also update sidecar STORY-005 entry:
    fill_color: light_yellow → cyan
```

The mapping is deterministic, so this is a structural-only proposal — it does not need the semantic pass. If the observed color is not in the table, emit a warning and route the sticky to `interpret-changes.md` instead. A `moved_and_changed` sticky that includes a recolor axis produces this proposal alongside the others.

For orphans and content edits, hand off to `interpret-changes.md`.
