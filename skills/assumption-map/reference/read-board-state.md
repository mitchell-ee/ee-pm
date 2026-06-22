# Reference: Read Board State — Structural Diff Pass

The `absorb` mode first-pass workflow for assumption maps. Read the live Miro board, classify every item against the sidecar, produce a structured diff. No interpretation here — see `interpret-assumption-changes.md` for the semantic pass.

Mirrors `story-map/reference/read-board-state.md` and `opportunity-tree/reference/interpret-changes.md` §1–2; assumption-map's topology is simpler (no connectors, no swim-lane horizons, no two-layer delivery/discovery split).

## Inputs

- `product/context/assumption-maps/SOL-{NN}-{slug}/miro-metadata.json` — sidecar with recorded item IDs (chrome + stickies blocks).
- Assumption files under `product/context/opportunity-solution-tree/assumptions/assumption-*.md` filtered by `Parent Solution: SOL-{NN}`.
- Live Miro board, read via `mcp__miro-official__layout_read`.

## Step 1: Load the sidecar

Build a lookup table from `miro-metadata.json`:

```
sidecar_index = {
  "<miro_item_id>": {
    "role": "title" | "x_axis_line" | "y_axis_line" |
            "axis_tip_label" | "legend_swatch" | "legend_label" |
            "sticky",
    "assumption_id": "ASSUMPTION-001",     // sticky role only
    "current_quadrant": "test_first" | "watch" | "dont_worry" | "investigate_later",
    "fill_color": "light_yellow" | "light_blue" | "light_green" |
                  "light_pink" | "violet" | "gray",
    "sticky_short_title": "...",           // for stickies
    "color_key": "light_yellow" | ...      // for legend_swatch / legend_label
  }
}
```

Stickies are compared on three axes: **observed_quadrant** (against `current_quadrant`), **parsed short title** (against `sticky_short_title`), and **fill color** (against `fill_color`). Like story-map, the short title is the content key — the abbreviation rendered on the sticky is not reverse-derivable from the file's H1 once the team starts editing on the board.

## Step 2: Fetch the live board

`mcp__miro-official__layout_read` with the `board_id` from the sidecar. Returns the full top-level item list — stickies, text, shapes — each with ID, position, content, and fill style. Assumption maps carry no connectors, so no connector read is needed.

The workflow below is fetch-agnostic: any read mechanism that yields items keyed by ID with position, content, and fill works.

## Step 3: Compute observed_quadrant for each sticky

The origin (0, 0) is the grid center; the x-axis line runs horizontally at y=0, the y-axis line vertically at x=0. Quadrant by **sign of x and y**:

| sign(x) | sign(y) | quadrant |
|---|---|---|
| < 0 | < 0 | `watch` (top-left) |
| > 0 | < 0 | `test_first` (top-right) |
| < 0 | > 0 | `dont_worry` (bottom-left) |
| > 0 | > 0 | `investigate_later` (bottom-right) |

**Sub-quadrant position is cosmetic.** SKILL.md describes a 4×4 slot grid for create-mode, but a PM dropping a sticky anywhere inside a quadrant is intentional — slot alignment is workshop affordance, not state. Two stickies whose (x, y) differs but whose `sign(x), sign(y)` matches are in the same quadrant; this is not a diff.

**Axis-boundary case.** If a sticky lands exactly on `x=0` or `y=0` (unlikely with freehand drag but possible with snap-to-axis on touch devices), treat 0 as belonging to the **negative side** (so `x=0, y=-100` → `watch`, not `test_first`). Flag the item with `on_axis: true` in the change record so the PM can nudge it off if the placement was unintentional. This rule activates only when a sticky's coordinate is *exactly* 0 — not "close to 0."

## Step 4: Normalize sticky content before comparing

Stickies are authored as two `<p>` blocks: `<p>{ID}</p><p>{short title}</p>`. The Miro inline editor reshapes any touched sticky into this same form (per `reference_miro_editor_side_effects`), so freshly created and human-touched stickies share one content form — there is no "canonical vs collapsed" split to reconcile.

Normalize before compare, in order:

1. **HTML-decode** entities: `&lt;` → `<`, `&gt;` → `>`, `&amp;` → `&`, `&#39;` → `'`. ASSUMPTION-002's "ETA model can ingest surge signal in <100ms" round-trips as `&lt;100ms` from `layout_read` and would otherwise flag as content change on every read.
2. **Strip the outer `<p>...</p>` wrapper** and split on the inner `</p><p>` boundary. The first segment is the ID line; the second is the short title.
3. **Trim whitespace** on both segments.
4. The result is the **parsed short title**. Compare against `sticky_short_title` in the sidecar.

**Single-`<p>` legacy form.** If a sticky's content has no `<p>` tags (created via REST PATCH without HTML wrapping), split on the first `\n` instead. Treat as equivalent to the two-`<p>` form for comparison; flag a `legacy_form: true` note so the next workshop touch normalizes it.

A sticky whose only difference is whitespace, entity-encoding, or `<p>`-wrapper presence is **not** a content change.

## Step 5: Color format — names for stickies, hex for shapes

`layout_read` returns color information asymmetrically:

- **Stickies:** `color={palette_name}` — `light_yellow`, `light_blue`, `light_green`, `light_pink`, `violet`, `gray`. Compare directly against `fill_color` in the sidecar.
- **SHAPE items (legend swatches, axis lines):** `fill={hex}` — `#fff9b1`, `#cce8fc`, `#d5f692`, `#fbd5d8`, `#c9b6f5`, `#d0d0d0`. If you need a name, lookup via the canonical hex table in `SKILL.md` §"Color legend (right side)".

This asymmetry is a Miro DSL quirk recorded in `reference_miro_dsl_gotchas`. For sticky comparison in absorb, only the palette-name form matters — the hex form is only relevant when verifying chrome integrity (legend swatches).

## Step 6: Classify each board item

For every observed item, classify into one of the states below.

### Board chrome (exempt from semantic classification)

An item whose sidecar role is `title`, `x_axis_line`, `y_axis_line`, `axis_tip_label`, `legend_swatch`, or `legend_label` is **chrome**. Classify as:

- **chrome_unchanged** — id present on board; position, content (where applicable), and color (where applicable) match.
- **chrome_drift** — id present but a chrome property (e.g. title text, axis-tip label content, swatch hex) differs. Warn but do not propose repo changes — chrome edits are usually PM accidents (clicking into a label and committing on tab-out adds a `<p>` wrap). Refresh-mode can resnap.
- **chrome_missing** — chrome id absent from the board. Warn; do not delete repo data. A missing axis line means the board is partially broken — surface prominently.

Chrome is never classified as `sticky_*` states.

### Sticky states

1. **unchanged** — id in sidecar; observed_quadrant matches `current_quadrant`; parsed short title matches `sticky_short_title`; fill color matches `fill_color`.
2. **moved_quadrant** — id in sidecar; observed_quadrant differs from `current_quadrant`. Everything else matches.
3. **content_changed** — id in sidecar; parsed short title differs from `sticky_short_title` (after Step 4 normalization). Position and color may or may not have changed.
4. **recolored** — id in sidecar; observed_quadrant and parsed short title match; fill color differs from `fill_color`. A recolor is one of two things — a **`Type` reclassification** (light_yellow → light_blue means Desirability → Usability) or a **`Result` arrival** (any color → gray means the assumption has been tested). Step 7 disambiguates.
5. **moved_and_changed** — any combination of moved_quadrant / content_changed / recolored on the same sticky. Report each axis in the change record so the semantic pass can handle them independently.
6. **orphan_sticky** — sticky on the board with no record in the sidecar. Candidate new assumption.

### Missing-from-board

7. **missing** — recorded sticky id not found on the live board. Report as warning; do NOT delete repo data. Phase-3 (identity-destroying) defines the propose-only behavior for confirmed deletions.

## Step 7: Disambiguate recolors

A `recolored` state is **structurally** the same — fill color changed — but **semantically** it's one of:

- **Color → gray:** the sticky was retested. Propose updating the file's `Result` field (Pending → {Confirmed | Rejected | Inconclusive}) — actual outcome is non-derivable from color alone, PM picks. `Type` in the file stays unchanged (gray is a display override).
- **Gray → color:** the sticky's result was undone or relabeled. Rare; propose `Result: Pending` and ask the PM whether the prior outcome should be archived.
- **Color → different color (neither is gray):** Type reclassification. Map the new color to a Type via the SKILL.md §"Color convention" table — `light_yellow` → Desirability, `light_blue` → Usability, `light_green` → Feasibility, `light_pink` → Viability, `violet` → Ethical. Propose updating the file's `Type` field.
- **Unknown color** (not in the canonical 6-color palette — e.g. PM picked a custom shade): warn and flag for the PM; do not auto-map.

Sidecar `fill_color` updates are safe regardless — color is an observable fact.

## Step 8: Emit the structural diff

Produce a structured object:

```json
{
  "board_id": "<board-id>",
  "fetched_at": "2026-05-18T14:30:00Z",
  "summary": {
    "total_items_observed": 27,
    "stickies": {
      "unchanged": 7,
      "moved_quadrant": 1,
      "content_changed": 0,
      "recolored": 0,
      "moved_and_changed": 0,
      "orphan_sticky": 0,
      "missing": 0
    },
    "chrome": {
      "unchanged": 19,
      "drift": 0,
      "missing": 0
    }
  },
  "changes": [
    {
      "state": "moved_quadrant",
      "item_id": "3458764672162294121",
      "assumption_id": "ASSUMPTION-006",
      "from": "investigate_later",
      "to": "test_first",
      "observed_position": {"x": 362.39, "y": -317.49}
    }
  ],
  "warnings": []
}
```

## Step 9: Present the diff

Display in a compact table:

```
Board changes since last sync (2026-05-18 14:30):

  STICKIES
    MOVED QUADRANT (1):
      ASSUMPTION-006  investigate_later → test_first
                     (low/strong → high/weak)
    UNCHANGED (7)

  CHROME (19 unchanged)
```

Or, on a clean read:

```
No changes detected.

Board: <board-id>
Stickies checked: 8
Chrome items checked: 19
```

The **no-op output** drops the "Last synced" line (redundant with the sidecar) and omits the "slot-cosmetic position is ignored" note unless at least one sticky's (x, y) actually drifted from its canonical slot while staying in the same quadrant. Counts are kept — they confirm the read was complete and nothing went missing silently.

Then ask: "Apply structural changes (quadrant moves, color updates) to the repo? Run semantic interpretation on the orphans?"

For orphan stickies, content changes, and recolors, hand off to `interpret-assumption-changes.md`.

## Known DSL limitations carried in from create-mode

These don't affect absorb's structural pass but constrain refresh-mode and inform the propose-only output:

- No `rotation` on any item — axis-tip labels are horizontal-only.
- `border_width=0` rejected; canonical write uses `border_width=1 border_color={fill}`.
- Defaults appear on read-back even when not written (`border_opacity=1.0`, `shape=square align=center valign=middle` on stickies).
- Transparent fill needs both `fill=#ffffff fill_opacity=0.0` explicit.
- `layout_update` re-serializes the *whole* board to DSL — a sticky with a literal `\n` in content kills every `layout_update` on the board. Fall back to REST PATCH (`PATCH /v2/boards/{id}/sticky_notes/{item_id}`) for problem stickies; re-canonicalize to the `<p>...</p><p>...</p>` form to clear the limitation permanently.

See `.claude/skills/assumption-map/SKILL.md` §"Known DSL limitations and canonical write forms" for the authoritative list.
