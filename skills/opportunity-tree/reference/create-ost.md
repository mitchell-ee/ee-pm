# Creating an OST in Miro — layout algorithm

This is the canonical layout spec for the `opportunity-tree` skill's `create` and `refresh` modes. Every render must follow these rules so the skill produces consistent output across projects and over time.

The rules below are non-negotiable defaults. Override only when the host project sets explicit alternates in its `miro-metadata.json:layout` block.

---

## 1. Orientation

- **Left-to-right horizontal tree.** Root at column 0, outcomes one column right, opportunities further right, solutions next, assumption tests rightmost.
- The board expands vertically as needed. **Never** wrap, shrink, or rotate to fit a viewport.

## 2. Columns (x-coordinates)

OST has four **fixed-column** types and one **variable-column** type. Opportunities cascade rightward as they nest, mirroring Torres's "opportunity sub-trees" methodology — solutions attach to *leaf* opportunities, but a single outcome can decompose through multiple opportunity tiers before reaching a solution.

### Fixed-column types

| Level | Default x | Node size (w × h) | Fill color |
|---|---|---|---|
| root | 0 | 360 × 160 | `#ffd6cc` |
| outcome | 480 | 320 × 140 | `#ffffff` |
| solution | *derived* (see below) | 220 × 90 | `#fff3cd` |
| assumption_test | *derived* (= solution.x + 480) | 200 × 80 | `#d4edda` |

Descoped/rejected nodes use `gray` fill (any level).

The root node is **optional** — include it only when the project name adds clarity. Skip when the tree has only one outcome.

### Opportunity — variable column

Opportunities have no fixed x. Tier 1 (direct child of an outcome) sits at the canonical opportunity column; each additional tier cascades right by an `opportunity_pitch`:

```
opportunity.x = outcome.x + outcome_to_opportunity_gap + opportunity_pitch × (opportunity_depth - 1)
```

Where:

- `outcome_to_opportunity_gap` defaults to **480 px** — the same cross-type gap used between outcome→opportunity and between opportunity-leaf→solution. This anchors the depth-1 opportunity column at the canonical x=960.
- `opportunity_pitch` defaults to **320 px** — narrower than the 480 px cross-type gap. Opportunity tiers should read as "deeper, same kind," not "different category."
- `opportunity_depth = 1` for an opportunity that is a direct child of an outcome.
- `opportunity_depth = 2` for the grandchild (an opportunity whose parent is another opportunity).
- ...and so on. No hard cap; warn (not flag) at depth > 6 — that usually indicates the PM is conflating opportunities with sub-tasks.

Node size for opportunities: 260 × 110 at every depth. Fill color: `#cce5ff` at every depth. **Horizontal position is the only depth cue** — do not vary color, shape, or size by depth.

Solutions sit in a **global column** anchored on the deepest opportunity branch on the board. Solutions attached to shallower-tier leaf opportunities still align with solutions attached to the deepest leaves — they do not "snap in" right of their own parent.

```
solution.x = outcome.x + outcome_to_opportunity_gap + opportunity_pitch × (max_opportunity_depth - 1) + solution_offset
assumption_test.x = solution.x + 480
```

Where `solution_offset` defaults to **480 px** — the same cross-type gap as outcome→opportunity. For a single-tier tree (`max_opportunity_depth = 1`): solution.x = 480 + 480 + 0 + 480 = 1440, assumption_test.x = 1920. Canonical column positions are preserved. For a depth-2 tree: solution.x = 480 + 480 + 320 + 480 = 1760. The solution column moves right as `max_opportunity_depth` grows; existing single-tier boards are unaffected.

**Solutions attach only to leaf opportunities** (an opportunity is a leaf when no other opportunity declares it as `Parent Opportunity`). A solution attached to a non-leaf opportunity is a structural error and must be flagged for PM resolution — not silently accepted.

## 2a. Board title

Every OST board carries a title `text` item so the board is self-identifying — same role as the story-map title.

- Type: `text` item, bold, `font_size: 96`.
- Content: `<strong>{tree name} — Opportunity Solution Tree</strong>` — e.g. `<strong>{Product} — Opportunity Solution Tree</strong>`. The tree name is the product/initiative name, the same string the root node would carry.
- Position: **left-aligned with the root node** and **above the topmost node on the board**. The title's left edge sits at the root node's left edge — since a `text` item's `x` is its center, `x = root.x − root_width/2 + title_width/2` (with the default 360-wide root: `x = −180 + title_width/2`). `y = (smallest node top edge across the whole tree) − 200`. The root node is centered on the leaf-range midpoint, so it is usually *not* the topmost node; compute the top edge from every node, not just the root. When the root is omitted, left-align with the outcome column instead.
- Recorded in the sidecar as `items.title` (see §6).
- **Absorb treats the title as board chrome** — classified only `unchanged` / `missing`, never as a node. It is not part of the tree and never triggers the semantic pass.

## 3. Node shape and content (mandatory)

- Shape: `round_rectangle`. Never sticky notes.
- Content: every node carries a bold ref_id line above the title, using inline HTML in the shape's `content` field:

  ```
  <strong>{REF-ID}</strong><br>{title}
  ```

  Example: `<strong>OPP-01</strong><br>ETA trust — the promise time drifts`

- This applies to **every node type** (root, outcome, opportunity, solution, assumption test) and **every mode** (create, refresh, absorb, promote-from-inbox). Miro's `content` field accepts inline HTML; `<strong>` and `<br>` are the only tags needed.

## 4. Y-coordinates — the per-column pitch rule

The rule below applies **at every column** (each opportunity tier, solution, assumption), not just at outcome boundaries. Each opportunity depth (1, 2, 3, ...) is its own column for pitch-rule purposes — siblings at depth 2 with the same depth-1 parent are "within group" at 140 px; siblings at depth 2 with different depth-1 parents are "cross group" at 280 px.

### Definitions

- **Within-group pitch** = 140 px. Used between consecutive nodes in a column when they share the **same direct parent**.
- **Cross-group pitch** = 280 px. Used between consecutive nodes in a column when they have **different direct parents**. This is exactly **2× the within-group pitch** — the upper bound, not a multiplier.

The 2× ratio is intentional: enough to read group boundaries, not so much that the diagram sprawls. Don't make it bigger. Don't make it smaller.

### Algorithm

Layout is solved column-by-column, from the rightmost column leftward. At each column:

1. **List the column's nodes in tree-order** (in-order traversal of the parent tree).
2. **Compute minimum required pitch** between each consecutive pair:
   - Same direct parent → 140 px (within-group)
   - Different direct parent → 280 px (cross-group)
3. **Assign y-coordinates** so each consecutive pair satisfies its minimum.
4. **At the next column leftward**, each parent's y is the **mean of its children's y-coordinates** (centering).
5. **Reconcile across columns:** at any column, take the **maximum** of (rule-required pitch) and (subtree-spread pitch from the column to its right). This means a parent column may need to spread further than 140/280 to accommodate wider subtrees below.
6. **Iterate if needed:** if a column's centering pushes a parent into violation of its own column's pitch rule, propagate the constraint back down (push the conflicting subtree further) and recompute. Two passes usually converge.

### Why per-column, not just leaf-driven

A leaf-only rule produces non-uniform spacing within parent columns when subtrees vary in size. Applying the rule at every column makes group boundaries readable at every level — opportunities under the same outcome look like a group, solutions under the same opportunity look like a group, and so on.

### Worked example ({Product} OST, render 4)

Solution column (9 solutions, ordered):

| Ref | Parent | y | Pitch from previous | Reason |
|---|---|---|---|---|
| SOL-01 | OPP-01 | 0 | — | start |
| SOL-02 | OPP-01 | 140 | +140 | same parent (OPP-01) |
| SOL-03 | OPP-02 | 420 | +280 | different parent |
| SOL-09 | OPP-02 | 560 | +140 | same parent (OPP-02) |
| SOL-04 | OPP-05 | 1050 | +490 | different parent — but OPP column needs ≥280 from OPP-04, which forces SOL-04 down past the SOL rule's 280 minimum |
| SOL-05 | OPP-08 | 1610 | +560 | subtree-driven: OPP-7 needs ≥280 from OPP-8 |
| SOL-06 | OPP-10 | 1890 | +280 | different parent |
| SOL-07 | OPP-13 | 2450 | +560 | subtree-driven from OPP column |
| SOL-08 | OPP-17 | 3290 | +840 | subtree-driven |

The 280 minimum at the SOL column is the floor; subtree-spread can push pairs further apart. The 140 minimum within the same parent is also a floor — if there's room to spread, the parent's children stay tight at 140.

## 5. Connectors

Tree edges are native DSL `CONNECTOR` items, created in the **same** `layout_create` batch as the nodes (connectors are emitted last so they can reference node aliases defined above them). No REST script, no second credential.

- Type: **curved**, thin, no arrowheads — `shape=curved start_cap=none end_cap=none` (tree edges are structural, not directional). Use a light stroke, e.g. `stroke_color=#888888`.
- Intent: parent-right → child-left. Leave `start_snap` / `end_snap` off (they default to `auto`), so Miro routes each edge to the closest side. This is acceptable — in a horizontal tree, the closest sides usually are right-of-parent and left-of-child.
- One `CONNECTOR` per parent-child edge. No skip-level connectors.

A connector references its endpoints by the node aliases in the same batch (`from=root to=o1`), or, on a later `layout_update`, by the nodes' full Miro item URLs.

## 6. Sidecar contract

After every render, write the full layout to `product/context/opportunity-solution-tree/miro-metadata.json`. Required keys:

```json
{
  "board_id": "...",
  "board_url": "https://miro.com/app/board/{board_id}=",
  "team": "...",
  "space": "...",
  "last_synced": "ISO-8601",
  "created_by_skill": "opportunity-tree",
  "layout": {
    "style": "horizontal-left-to-right-tree",
    "node_shape": "round_rectangle",
    "node_content_format": "<strong>{REF-ID}</strong><br>{title}",
    "x_levels": {
      "root": 0,
      "outcome": 480,
      "opportunity_tier_1": 960,
      "solution": 1440,
      "assumption_test": 1920
    },
    "outcome_to_opportunity_gap": 480,
    "opportunity_pitch": 320,
    "max_opportunity_depth": 1,
    "solution_offset": 480,
    "node_sizes": { "root": [360, 160], "outcome": [320, 140], "opportunity": [260, 110], "solution": [220, 90], "assumption_test": [200, 80] },
    "within_group_pitch": 140,
    "cross_group_pitch": 280,
    "cross_group_center_pitch_ratio": 2.0,
    "rule_scope": "applied at every column (each opportunity tier counts as its own column)",
    "colors": { ... }
  },
  "items": {
    "title": { "miro_id": "...", "type": "text", "font_size": 96, "bold": true, "x": 0, "y": -360 }
  },
  "nodes": [
    { "ref_id": "OUTCOME-01", "type": "outcome", "miro_id": "...", "parent_ref": "PRODUCT-CRUMBS", "x": 480, "y": 0 },
    { "ref_id": "OPP-01", "type": "opportunity", "miro_id": "...", "parent_ref": "OUTCOME-01", "x": 960, "y": 0, "opportunity_depth": 1 },
    { "ref_id": "OPP-12", "type": "opportunity", "miro_id": "...", "parent_ref": "OPP-01", "x": 1280, "y": 0, "opportunity_depth": 2 },
    { "ref_id": "SOL-01", "type": "solution", "miro_id": "...", "parent_ref": "OPP-12", "x": 1760, "y": 0 }
  ]
}
```

Key changes from the pre-multi-tier schema:

- `x_levels.opportunity` is replaced by `x_levels.opportunity_tier_1` (the depth-1 anchor, always at `outcome.x + outcome_to_opportunity_gap`). Deeper tiers are per-node — computed from `opportunity_depth` at render time, not stored as columns.
- `solution` and `assumption_test` x are *derived* from `outcome.x + outcome_to_opportunity_gap + opportunity_pitch × (max_opportunity_depth - 1) + solution_offset` (and `+ 480` for tests). They are written to `x_levels` for fast lookup but recomputed on every render. For `max_opportunity_depth = 1` the formula collapses to the canonical 1440 / 1920.
- `max_opportunity_depth` is the deepest `opportunity_depth` observed across all opportunity nodes. Required so the solution column position is reconstructible from the sidecar alone.
- Every `type: "opportunity"` node carries `opportunity_depth: N` (1 = direct child of outcome).
- Solutions only attach to **leaf opportunities** (no other opportunity declares them as `Parent Opportunity`). Solutions on non-leaf opportunities are a structural error — flag for PM resolution.
- `items.title` records the board-title `text` item (§2a) — board chrome, not a tree node. Sidecars written before the title convention have no `items` block; the renderer adds the title on the next render and back-fills `items.title`.

Whenever the skill or any response references the board, include `board_url` so it's one click from Claude Code to the live board.

### Backward compatibility

Sidecars written before the multi-tier rewrite have:
- `x_levels.opportunity: 960` and no `outcome_to_opportunity_gap` / `opportunity_pitch` / `max_opportunity_depth` / `solution_offset` keys.
- No `opportunity_depth` field on opportunity nodes.

Such sidecars remain readable. The renderer treats them as `opportunity_depth: 1` for every opportunity. Because the new defaults reproduce the canonical 960 / 1440 / 1920 columns exactly for a single-tier tree, no shape movement is required on read. On the next render the sidecar is re-emitted in the new schema. No standalone migration script is needed.

## 7. Implementation notes (official Miro MCP)

This reference runs inside a board worker (`board-builder` for create / refresh,
`absorb-interpreter` + `board-writer` for absorb), which holds the official Miro
MCP. The main thread never calls `mcp__miro-official__*` directly. Everything —
nodes and edges — goes through the MCP's layout DSL; there is a single credential
(the MCP's OAuth-at-connect), no separate connector token.

- **Load the DSL grammar first.** Call `mcp__miro-official__layout_get_dsl` **once**
  at the start of the run and reuse the returned spec — it is a documented
  prerequisite of `layout_create` and defines the item types, the `CONNECTOR`
  syntax, and the valid colors/shapes. DSL comments start with `#` (not `//`).
- **Create the board first (create mode only).** Board creation is a two-step
  sequence: `mcp__miro-official__board_create` mints an empty named board and
  returns its URL/id; `layout_create` then renders items into that **existing**
  board (it takes the board's `miro_url` + DSL; it does not create a board). For a
  refresh, skip `board_create` and use the existing `board_id`. Record the new
  board's id/URL in the sidecar's `board_url`.
- **Create nodes** with `mcp__miro-official__layout_create` — one SHAPE item per
  node (`round_rectangle`), `content` carrying the HTML format above
  (`<strong>{REF-ID}</strong><br />{title}`). Shapes take a **hex** `fill` (not a
  palette name) — use the §"Color convention" hex values. Write the canonical
  forms so the round-trip is diff-stable against `layout_read`: `border_width=1`
  with a matching `border_color` for a borderless look (`border_width=0` is
  rejected), and write any defaults `layout_read` returns (e.g. `border_opacity`)
  explicitly. `layout_create` returns each item's ID — record it as the node's
  `miro_id` in the sidecar.
- **Create edges** as native DSL `CONNECTOR` items in the **same** `layout_create`
  batch as the nodes (they must come after the node lines so aliases resolve):
  `cN CONNECTOR from={parent_alias} to={child_alias} shape=curved stroke_color=#888888 start_cap=none end_cap=none`.
  One connector per parent-child edge. `layout_create` returns each connector's ID
  — record it in the sidecar the same way as node IDs.
- **Reposition / re-content nodes** (refresh, absorb-accept) with
  `mcp__miro-official__layout_update`. Unlike the old community `bulk_update` (which
  silently dropped `content` on shapes), `layout_update` carries content correctly.
  It re-serializes the whole board to DSL on each call, so always `layout_read`
  before constructing the next `old_string`, and never reuse an `old_string` across
  parallel updates. OST node content uses `<br />` line breaks (not literal `\n`),
  so it does not trip the sticky-newline parser bug documented in story-map.
- **Rewire / remove edges** (refresh, absorb-accept) with `mcp__miro-official__layout_update`
  too: `layout_read` first (it emits each edge as a `CONNECTOR` line whose `from`/`to`
  are the endpoint item URLs), then find/replace that line — edit the endpoints to
  rewire, or replace it with empty to delete. Deleting a node cascades to its
  connectors automatically.
- Always emit the board URL (`https://miro.com/app/board/{board_id}=`) in chat after a render.

## 8. Worked example — literal DSL

A known-good `layout_create` DSL string, confirmed valid against the live MCP. It
renders a root outcome with two child opportunities and native tree connectors —
the same pattern scales to a full OST. Match this shape; don't reconstruct the
grammar from memory. Note the `#` comments, the `<strong>…</strong><br>…` content,
the `round_rectangle` fills, `align=center valign=middle`, and the `CONNECTOR`
lines emitted last with `start_cap=none end_cap=none` (no arrowheads):

```
# Nodes first — each SHAPE aliased so connectors below can reference it.
root SHAPE x=0 y=0 w=200 h=90 type=round_rectangle fill=#F5D95B align=center valign=middle "<strong>OUTCOME-01</strong><br>Eater trust and retention"
o1 SHAPE x=350 y=-120 w=200 h=90 type=round_rectangle fill=#8FD14F align=center valign=middle "<strong>OPP-01</strong><br>ETA trust — the promise time drifts"
o2 SHAPE x=350 y=120 w=200 h=90 type=round_rectangle fill=#8FD14F align=center valign=middle "<strong>OPP-02</strong><br>Order correctness and fair dispute resolution"

# Connectors last — reference the aliases above; curved, thin, no arrowheads.
c1 CONNECTOR from=root to=o1 shape=curved stroke_color=#888888 start_cap=none end_cap=none
c2 CONNECTOR from=root to=o2 shape=curved stroke_color=#888888 start_cap=none end_cap=none
```

On read-back, `layout_read` returns each of these with full Miro item URLs as ids
(and `from`/`to` as URLs), directly feedable into `layout_update` for rewiring.
