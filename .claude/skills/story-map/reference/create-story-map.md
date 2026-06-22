# Reference: Create Story Map on Miro

This is the `create` mode workflow for the `story-map` skill. Follow it end-to-end when the user asks to create a new story map.

The map is Patton-narrative-scoped (one map per iteration, multi-actor narrative on one backbone) and uses the cross-board visual vocabulary defined in `SKILL.md`: stickies = delivery layer, rounded rectangles = discovery layer (same fill colors as OST and assumption-map).

## Input files

Read from `product/iterations/{iteration-slug}/` (plus the product-level persona legend):

1. **`README.md`** — provides the iteration title (top `# ...` heading) only. The README holds no map structure — it is orientation prose, like the OST and assumption-map READMEs.
2. **`story-maps/activities/activity-{NN}-{slug}.md`** — the backbone. One file per activity with an `ID` (e.g. `ACTIVITY-01`) and `Order` header; the `#` title (after the `Activity:` prefix) is the header text rendered on the dark_blue sticky. See `SKILL.md` "Activity files".
3. **`product/context/personas.md`** — the `## Legend` table (slug · emoji · name) used to build the persona legend rectangle and resolve emoji prefixes.
4. **`stories/story-{NNN}-{slug}.md`** — all story files. Each contains header metadata:
   - `Story ID`, `Priority`, `Status`, `Personas`, `Labels`, optional `Type`
5. **Optional** `assumptions.md` (or whatever the iteration uses) — surfaces assumption items to render as `light_green` rounded rectangles placed *beside the story each assumption questions* (per the 2026-05-14 decision — no separate discovery band). If absent, skip. Opportunities on the story map are **dormant**: even if a source file exists, nothing renders today (opportunities relate to outcomes, which the OST owns, not to activities).

## Step 1: Parse structural sources

### Personas (from `product/context/personas.md` `## Legend`)

Build a map: `persona-slug → {emoji, name}`. Legend row order preserved for legend display. If a story names a persona with no legend row, warn and offer to append one before rendering.

### Backbone (from `story-maps/activities/*.md`)

Enumerate the activity files and sort by `Order`. Each file's `#` title (after the `Activity:` prefix) is the activity name — these become the column headers, left-to-right. Record each file's `ID` as the activity's `activity_ref` for the sidecar. If the iteration has no `activities/` files yet, warn and offer to draft them from the stories' inferred activities — write the files first (PM approves), then proceed; activity files are a prerequisite the same way stories are.

### Stories

For each story file:
- Parse header metadata.
- Classify by `Type` field if present; otherwise infer from title / labels:
  - **Regular** (default): standard user-facing feature → light_yellow
  - **Infrastructure**: schema, API, deploy → cyan
  - **Spike**: research, prototype, investigate → violet
  - **Quality**: WCAG, performance, security, testing → light_blue
  - **Risk**: defect-prone, untrusted area → light_orange
  - **Bug**: defect → red
  - **Refactor**: tech debt, cleanup → light_green
  - **Doc**: guides, runbooks → gray
- Resolve `Personas` field to emoji prefix(es) via the persona map.
- Assign activity column by analyzing story content + labels against the backbone names. If ambiguous, fall back to alphabetical assignment within the closest matching activity and emit a warning.
- Assign swim lane by priority:
  - Critical / High → NOW
  - Medium → NEXT
  - Low → LATER

## Step 2: Create the Miro board

This skill runs inside a board worker (`board-builder`), which holds the official
Miro MCP. Create the board and its items with `mcp__miro-official__layout_create`;
the call returns the new `board_id` and the item IDs. (If a board already exists for
this iteration — sidecar present with a `board_id` — this is a `refresh`, not a
create: read the board with `layout_read` and mutate with `layout_update` instead.)

`layout_create` takes a `board_name` plus the list of items to render. Name the
board:

```
board_name: "{project} — Story Map — {iteration-slug}"
```

Capture the returned `board_id` and every item's returned ID for the sidecar
(see Step 5). All subsequent reads/updates use `board_id`. The item examples in
Step 4 show one item at a time for clarity; in practice pass them together in the
`layout_create` item list, in the Step 4 order.

## Step 3: Layout coordinates

**Y-axis bands** (top to bottom):

| y | Band |
|---|---|
| -1230 | Iteration title (text, font_size 96, bold) |
| -600 | Activity headers (`dark_blue` stickies) |
| -400 … 400 | NOW stories (5 rows per sub-column) |
| 37 | **NOW** swim-lane label (vertical center of NOW lane) |
| 675 | NOW / NEXT release horizon (thin rectangle) |
| 889 … 1389 | NEXT stories (3 rows per sub-column) |
| 1164 | **NEXT** swim-lane label |
| 1653 | NEXT / LATER release horizon |
| 1867 … 2367 | LATER stories (3 rows per sub-column) |
| 2142 | **LATER** swim-lane label |
| 2631 | LATER end horizon |

**X-axis — activity spans** (each activity owns a horizontal span, not a fixed column):

An activity owns all horizontal space from its header's left edge to the
next header's left edge; the last activity owns everything to its right.
Stories under an activity are **not** confined to one column — they fill
a grid within the activity's span.

Layout constants: `SUBCOL_PITCH = 600`, `STICKY_W = 199`. Rows per lane:
**NOW = 5, NEXT = 3, LATER = 3** (from the y-band table — NOW spans
-400…400, NEXT 889…1389, LATER 1867…2367, all at 200 px vertical pitch).

Compute, per activity `a` (in backbone order):

- `subcols[a] = max(1, max over lanes L of ceil(stories[a][L] / rows[L]))`
- `width[a]   = subcols[a] × SUBCOL_PITCH`

Then place activities left to right, centered around x=0:

- `total_width = Σ width[a]`
- `map_left    = −total_width / 2`
- `span_left[a] = map_left + Σ width[0..a−1]`  (left edge of activity a's span)

The activity header is **left-aligned** to its span: header center x =
`span_left[a] + STICKY_W/2`, so the header's left edge sits exactly on
`span_left[a]`.

**Story card placement within an activity × lane:** stories fill the
lane's grid in stable order — down a sub-column to the lane's row limit,
then wrap into the next sub-column. For story `j` (0-indexed) in
activity `a`, lane `L`:

- `subcol = j // rows[L]`, `row = j % rows[L]`
- `x = span_left[a] + STICKY_W/2 + subcol × SUBCOL_PITCH`
- `y = lane_top[L] + row × 200`  (`lane_top`: NOW −400, NEXT 889, LATER 1867)

With a small map — every activity's busiest lane fitting in one
sub-column — `subcols[a]` is 1 for all activities and the layout is one
600 px column per activity, centered around x=0. The multi-sub-column
behavior only engages when a lane overflows its row limit.

**Swim-lane labels** (NOW / NEXT / LATER):

- One bold text item per lane, single word, font_size 72, content wrapped in `<strong>`.
- Placed to the left of the map at `x = map_left - 350`.
- Vertical position is the **center of the lane**: `y = (top_of_lane + bottom_of_lane) / 2`. With lane edges at activity-header y (-600) and the release horizons, that gives the values in the band table above.

**Persona legend:** a single `rectangle` shape with HTML-formatted content (no overlay text). Positioned right of the map at `x = map_left + total_width + 400` (clear of the rightmost activity span). Height computed from line count (see §4.6).

**Shape legend:** a small column of copyable sample shapes, stacked below the persona legend (see §4.7).

## Step 4: Create the board items

Create items in this order (so absorb-mode reads back a coherent structure):

1. Iteration title (text)
2. Activity headers (dark_blue stickies)
3. Release horizons (thin rectangles) + swim-lane labels (bold text)
4. Story stickies
5. Assumptions — `light_green` rounded rectangles beside the related story (opportunities dormant)
6. Persona legend (rectangle shape with HTML content)
7. Shape legend (sample copyable shapes + heading)

### 4.1 Iteration title

```
layout_create TEXT item:
  content: "<strong>{iteration title from README} — Story Map</strong>"
  x: -575
  y: -1230
  width: 1600
  font_size: 96
```

The on-board title appends "— Story Map" to the iteration title so the
board reads as a story map at a glance (the board *name* already carries
it). The title is the top-edge landmark for the canonical map bounds
(see §5).

### 4.2 Activity headers

For each activity *i* in the backbone:

```
layout_create STICKY item:
  content: "{activity_emoji_prefix} {activity name}"
  x: {span_left[i] + STICKY_W/2}   # left-aligned to the activity's span
  y: -600
  color: "dark_blue"
  shape: square
  align: center
  valign: middle
```

`activity_emoji_prefix` resolves the activity file's `Personas:` field through the
persona map, one emoji per persona, space-separated, in the order written (primary
actor first) — e.g. `🛵` for a courier-owned step, `🛵 🍽️` for a co-owned handoff
step. If the activity file has no `Personas:` field, omit the prefix and the leading
space; the header is just `{activity name}`. Cap at ~3 emoji; if an activity names
more, warn the PM that the step is probably a hidden handoff worth splitting into
separate activity files rather than rendering a crowded header. Because adjacent
headers then carry different emoji sets, the backbone reads as a sequence of actors
and the handoffs are visible along the spine (Patton's narrative flow).

`shape align valign` are written explicitly because `layout_read` returns them as
defaults on every sticky; writing them at create time keeps the round-trip DSL
stable for `layout_update` (per `read-board-state.md` "Known limitation").

Record each returned `item_id` in the sidecar under `activity_headers`,
along with the activity's `activity_ref` (its file's `ID`, e.g.
`ACTIVITY-01`) and its `span_left` and `span_width` (see §3 and Step 5) —
absorb's header-to-file association and column inference depend on them.

**Note on sub-activities:** Patton allows a finer-grained "task" row between activity and stories. We don't render those in v1; if the iteration backbone needs that granularity, add activity files instead. Revisit if a workshop turns up a real need.

### 4.3 Release horizons + swim-lane labels

The map has no Miro connector primitives between slices — horizons are thin rectangles, and each lane carries a single bold-text label centered vertically in the lane. This avoids the click-target and z-order problems of anchor-and-connector pairs.

**Release horizons** — one thin rectangle per slice boundary (NOW/NEXT, NEXT/LATER, LATER end), spanning the map width:

```
layout_create SHAPE item:
  shape: rectangle
  x: 0
  y: {horizon_y}
  width: {total_width}
  height: 12
  fill: "#222222"
  border_width: 1
  border_color: "#222222"
```

`border_width=0` is rejected by the DSL ("must be greater than 0"); for a visually
borderless line write `border_width=1` with `border_color` equal to `fill` (per
`read-board-state.md` and the assumption-map canonical write forms). Visually
identical at any zoom.

Horizon width is the full map width (`total_width` from §3), centered at
x=0. Horizon `y` values: **675** (NOW/NEXT), **1653** (NEXT/LATER),
**2631** (LATER end — this is the bottom-edge landmark for canonical map
bounds).

**Swim-lane labels** — one bold text per lane (NOW, NEXT, LATER), placed to the left of the map and centered vertically in the lane:

```
layout_create TEXT item:
  content: "<strong>{NOW|NEXT|LATER}</strong>"
  x: {map_left - 350}
  y: {lane_center_y}
  font_size: 72
```

`lane_center_y` values for the canonical 5-activity map: **NOW** = 37, **NEXT** = 1164, **LATER** = 2142. Derive generally as `(top_of_lane + bottom_of_lane) / 2` where the top of a lane is the previous horizon's `y` (or the activity-header band -600 for NOW) and the bottom is the lane's own horizon `y`.

The NOW swim-lane label is the **left-edge landmark** for canonical map bounds.

### 4.4 Story stickies

For each story, in activity × swim-lane order. Within an activity × lane,
stories fill the grid in stable order (down a sub-column to the lane's
row limit, then wrap into the next sub-column) — `x` and `y` come from
the §3 grid formula:

```
layout_create STICKY item:
  content: "<p>{emoji_prefix} STORY-{NNN}</p><p>{abbreviated_title}</p>"
  x: {span_left[a] + STICKY_W/2 + subcol × SUBCOL_PITCH}
  y: {lane_top[L] + row × 200}
  color: "{color_by_type}"
  shape: square
  align: center
  valign: middle
```

`emoji_prefix` is space-separated if the story has multiple personas (e.g. `🛵 🍽️`). Abbreviate title to ~40 chars; full title lives in the repo. Record `item_id`, `story_id`, `column`, `swim_lane`, `fill_color`, and the rendered `sticky_short_title` in the sidecar.

**Author sticky content as two `<p>` blocks: `<p>{emoji_prefix} STORY-{NNN}</p><p>{abbreviated_title}</p>`.** This is the same HTML shape Miro's inline editor produces the first time a human touches a sticky, so a freshly rendered sticky and a human-touched one are byte-identical — there is no "canonical vs collapsed" split for absorb to reconcile. It also sidesteps a `layout_update` bug: literal `\n` in sticky content makes the official MCP's whole-board DSL re-serialization unparseable, failing *every* `layout_update` on that board. The `<p>` form round-trips through the DSL as a single clean line. See `read-board-state.md` "Known limitation — `layout_update` and sticky newlines."

Priority is *not* rendered on the sticky. Priority stays story-file-authoritative; on the board it is reflected only by which swim lane the sticky sits in (Critical/High → NOW, Medium → NEXT, Low → LATER). Earlier versions rendered a third `{Priority}` block — it was display-only, lossy in reverse (NOW collapses Critical and High), and Miro's inline editor drops or inlines it the first time a human touches the sticky. Dropping it removes a whole class of false-positive content diffs in absorb mode. See `read-board-state.md` "Sticky-content parser" for how absorb tolerates legacy stickies that still carry the block.

### 4.5 Assumptions — beside the related story

Per the 2026-05-14 decision, there is **no separate discovery band**. An
assumption is placed next to the story it questions — that placement
*is* the linkage, and a band would sever it.

Only render if the iteration has an assumptions source file. For each
assumption, find the story it `relates_to` and position the rounded
rectangle immediately to the right of that story's sticky (offset the
sticky x by ~260 px, same y). If no related story is declared, skip the
assumption rather than guessing a position.

**Assumption** (rounded rectangle, Miro fill color `light_green`, ~200 × 80 — matches OST assumption_test):

```
layout_create SHAPE item:
  shape: round_rectangle
  content: "{assumption title}"
  x: {related_story_x + 260}
  y: {related_story_y}
  width: 200
  height: 80
  fill: "#d5f692"        # light_green — shapes take a hex fill, not a palette name
  border_color: "#34a853"
  border_width: 1
```

Shapes take a **hex** `fill` (not a palette name); `#d5f692` is the canonical
`light_green` hex, matching OST and assumption-map. `layout_read` returns shape
fills as hex, so absorb's assumption classifier matches a green hex range, not the
string `light_green` (see `read-board-state.md` Step 3 fill-color note).

Record `item_id`, `kind: "assumption"`, `nearest_story`, and source-file
reference in the sidecar under `items.assumptions`.

**Opportunities are dormant.** Even if an `opportunities.md` source file
exists, nothing renders today — an opportunity relates to an *outcome*
(the OST's job), not an *activity*. The `opportunities` sidecar array
stays empty. This is kept as a spec placeholder for the future
cross-board linkage release.

> **Color-name note:** `light_green` is also a story-`Type` sticky color
> (Refactor). The disambiguator is **shape** — a sticky is a story, a
> rounded rectangle is an assumption. Absorb classifies on shape first.

### 4.6 Persona legend

A single rectangle shape with HTML-formatted content. We use a shape (not a text item or a frame) because:

- Text items have no fill, so they can't carry the white card background the design calls for.
- Frames are anchored top-left in the Miro API (not center), and they pull the viewport on link-open. A shape avoids both issues.

Content is one `<p>` per persona, with the emoji and slug emphasized:

```
layout_create SHAPE item:
  shape: rectangle
  content: "<p><strong>{emoji} {persona-slug}</strong> — {persona name}</p>{...one per persona}"
  x: {map_left + total_width + 400}
  y: -400
  width: 480
  height: {persona_count * 60 + 30}
  font_size: 24
  fill: "#f5f5f5"
  border_color: "#cccccc"
  border_width: 1
```

`font_size: 24` sets the legend text size — readable, and well below the
swim-lane labels (72). The shape API default is 14, which is too small
to read on a workshop board. The width and per-line height are heuristic
— there is no autofit in the Miro shape API, so size the box to
comfortably fit the longest persona line at `size: 24`. Adjust width if a
persona name is unusually long.

The persona legend is the **right-edge landmark** for canonical map bounds.

### 4.7 Shape legend

A small column of **real, copyable sample shapes** stacked below the
persona legend, so a PM can copy the right shape mid-workshop instead of
building one from scratch. Each sample carries its label as its **own
content** — no separate text item beside it.

Place a `"Shapes"` heading text, then three samples stacked below it, all
sharing the persona legend's `x`. **Pitch matters:** the two samples are
`square` stickies, which Miro renders at a fixed ~199 × 228 px footprint
regardless of the nominal box — so consecutive sample *centers* must be at
least ~240 px apart or the stickies overlap. The thin assumption shape
(80 px tall) needs less clearance but keep the same rhythm for a clean
column. Offsets below are from `shapes_heading_y`:

```
# Shapes heading
layout_create TEXT item:
  content: "<strong>Shapes</strong>"
  x: {persona_legend_x}
  y: {persona_legend_y + persona_legend_height/2 + 80}
  font_size: 36

# Sample story sticky — clears the heading + half a sticky height
layout_create STICKY item:
  content: "Story"
  x: {persona_legend_x}
  y: {shapes_heading_y + 170}
  color: "light_yellow"
  shape: square
  align: center
  valign: middle

# Sample activity header — 240 px below the story sticky (no overlap)
layout_create STICKY item:
  content: "Activity"
  x: {persona_legend_x}
  y: {shapes_heading_y + 410}
  color: "dark_blue"
  shape: square
  align: center
  valign: middle

# Sample assumption — 240 px below the activity sticky
layout_create SHAPE item:
  shape: round_rectangle
  content: "Assumption"
  x: {persona_legend_x}
  y: {shapes_heading_y + 650}
  width: 200
  height: 80
  fill: "#d5f692"        # light_green hex
  border_color: "#34a853"
  border_width: 1
```

The samples now occupy a ~650 px column below the heading. If the persona
legend is unusually tall, the heading already clears it (the `+80` offset
in the heading `y`), so the only stacking constraint is the 240 px
sticky-to-sticky pitch within this column.

Record all four items (heading + three samples) in the sidecar under
`items.shape_legend` with role `shape_legend`. **This matters for
absorb:** the sample story/activity stickies and the sample assumption
rounded rectangle would otherwise be misclassified as `orphan_sticky` /
`orphan_assumption`. Because they are recorded in the sidecar, absorb
treats them as board chrome — see `read-board-state.md` Step 4.

The shape legend sits outside the canonical map-bounds rectangle (below
and right of the persona legend), so it is off-map chrome by the §5
bounds rule regardless.

## Step 5: Save sidecar

Write `product/iterations/{iteration-slug}/story-maps/miro-metadata.json`:

```json
{
  "board_id": "{board_id}",
  "board_name": "{board_name}",
  "board_url": "https://miro.com/app/board/{board_id}=",
  "iteration": "{iteration-slug}",
  "created_at": "{ISO8601 Z}",
  "last_synced_at": "{ISO8601 Z}",
  "sync_direction": "markdown_to_miro",
  "layout": {
    "subcolumn_pitch": 600,
    "rows_per_lane": {"NOW": 5, "NEXT": 3, "LATER": 3},
    "y_bands": {
      "title": -1230,
      "activity_headers": -600,
      "now_top": -400,
      "now_bottom": 400,
      "now_horizon": 675,
      "next_top": 889,
      "next_bottom": 1389,
      "next_horizon": 1653,
      "later_top": 1867,
      "later_bottom": 2367,
      "later_horizon": 2631
    },
    "swim_lane_label_x": -1550,
    "swim_lane_label_centers": {
      "NOW": 37,
      "NEXT": 1164,
      "LATER": 2142
    },
    "horizon_line": {
      "width": 2800,
      "height": 12,
      "color": "#222222"
    },
    "bounds": {
      "mechanism": "landmark-relative",
      "top":    {"landmark": "title",                "rule": "below_bottom_edge"},
      "bottom": {"landmark": "later_horizon_line",   "rule": "above_top_edge"},
      "left":   {"landmark": "swim_lane_label_NOW",  "rule": "right_of_right_edge"},
      "right":  {"landmark": "persona_legend",       "rule": "left_of_left_edge"},
      "note": "Absorb mode reads the canonical map area as the rectangle bounded by these four landmark items. Items outside this rectangle are off-map. If users drag a landmark, the bounds shift with it."
    }
  },
  "items": {
    "title": {"id": "{id}", "type": "text", "font_size": 96, "bold": true},
    "persona_legend": {"id": "{id}", "type": "shape", "shape": "rectangle", "fill": "#f5f5f5", "html": true, "size": 24},
    "shape_legend": [
      {"id": "{id}", "role": "shape_legend", "kind": "heading", "type": "text"},
      {"id": "{id}", "role": "shape_legend", "kind": "sample_story",    "type": "sticky", "fill_color": "light_yellow"},
      {"id": "{id}", "role": "shape_legend", "kind": "sample_activity", "type": "sticky", "fill_color": "dark_blue"},
      {"id": "{id}", "role": "shape_legend", "kind": "sample_assumption", "type": "shape", "shape": "round_rectangle", "fill_color": "light_green"}
    ],
    "swim_lane_labels": [
      {"slice": "NOW",   "id": "{id}", "x": -1550, "y": 37},
      {"slice": "NEXT",  "id": "{id}", "x": -1550, "y": 1164},
      {"slice": "LATER", "id": "{id}", "x": -1550, "y": 2142}
    ],
    "activity_headers": [
      {"id": "{id}", "activity_ref": "ACTIVITY-01", "activity": "{name}", "column_index": 0, "x": -1200, "y": -600, "span_left": -1299.5, "span_width": 600}
    ],
    "release_horizons": [
      {"slice_above": "NOW",   "slice_below": "NEXT",  "line_id": "{id}", "y": 675},
      {"slice_above": "NEXT",  "slice_below": "LATER", "line_id": "{id}", "y": 1653},
      {"slice_above": "LATER", "slice_below": "end",   "line_id": "{id}", "y": 2631}
    ],
    "stories": [
      {
        "id": "{id}",
        "story_id": "STORY-001",
        "activity": "{name}",
        "swim_lane": "NOW",
        "x": -1200,
        "y": -400,
        "fill_color": "light_yellow",
        "sticky_short_title": "{abbreviated_title as rendered on the sticky}"
      }
    ],
    "opportunities": [],
    "assumptions": [
      {"id": "{id}", "source": "assumptions.md#asn-03", "nearest_story": "STORY-012", "x": {x}, "y": {y}, "content_hash": "{sha1}"}
    ]
  }
}
```

`opportunities` stays empty — opportunities on the story map are dormant
(2026-05-14 decision). `assumptions` records `nearest_story` (the story
the rounded rectangle sits beside), not a band position.

The sidecar is a **pure index**: every entry references its `.md` home by
ref-id (`activity_ref` → `activities/*.md`, `story_id` → `stories/*.md`),
and no authoritative content is duplicated — there is no standalone
`backbone` or `personas` block (backbone order lives in the activity
files; the persona legend lives in `product/context/personas.md`).
Everything position-shaped in the sidecar is rendered state, re-derived
from board geometry on absorb.

Each `activity_headers` record carries `activity_ref` plus `span_left`
and `span_width` — the activity's horizontal span (§3). Absorb's column
inference is a range test over these spans; recording them explicitly
also lets absorb fall back cleanly when a header is missing from the
board. `shape_legend`
records the four copyable sample items (§4.7) as board chrome so absorb
does not misclassify them as orphans. `subcolumn_pitch` (was
`column_pitch`) and `rows_per_lane` capture the §3 grid constants.

For stories, the sidecar records `sticky_short_title` — the abbreviated title string as rendered on the sticky. The short title is *not* reverse-derivable from the story file (the abbreviation is a render-time choice), so it is stored explicitly; absorb-mode's structural pass compares the parsed board title against it. For assumptions, `content_hash` is a SHA-1 of the rendered content string; absorb-mode uses it to detect content changes without re-fetching.

## Step 6: Final output

After completion, tell the user:

```
Story map created.

Board: {board_url}

Summary:
- {N} stories across {M} activities
- NOW: {a} | NEXT: {b} | LATER: {c}
- Assumptions: {asn_count} (placed beside related stories)
- Personas: {persona_count}

Sidecar: product/iterations/{iteration-slug}/story-maps/miro-metadata.json
```

## Error handling

- Miro MCP unavailable → tell the user which MCP to install, stop cleanly.
- No `story-maps/activities/` files → warn, offer to draft them from the stories' inferred activities.
- `product/context/personas.md` missing a `## Legend` table → warn, offer to draft from the stories' personas.
- Story file with no `Story ID` header → skip with warning, list skipped files at end.
- Story with no `Personas:` field → warn and prompt to assign before render.
- Activity name on story can't be matched to backbone → place in best-guess column, list mismatches at end.
- Two stories with same ID → refuse to sync, ask user to resolve.

## Best practices

1. **Create items in dependency order:** activity headers and slice anchors before stories and connectors that reference them.
2. **Batch within a section:** all stickies in a column together, then move on — easier to debug if a call fails midway.
3. **Save sidecar progressively:** write after each major section completes, not only at end. If creation fails mid-flight, partial sidecar still reflects what landed on the board.
4. **Provide progress updates to the user** between sections (e.g. "activity headers placed", "story stickies placed").
5. **Validate inputs upfront:** parse the activity files and the persona legend and verify stories before issuing the first MCP call.
