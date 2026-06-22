# Absorbing OST changes — diff format and detection rules

This is the canonical spec for `opportunity-tree` **absorb mode**. The skill reads a board that a PM has edited, compares it to the sidecar at `product/context/opportunity-solution-tree/miro-metadata.json`, and emits a structured diff describing what changed. The PM reviews; only on approval does the skill update repo files.

The rules below define what counts as a change, what the diff looks like, and what gets flagged for human review. Every absorb run produces output in the format in §3.

---

## 1. Inputs

- **Sidecar (baseline)** — `miro-metadata.json` from the last successful render (create or refresh). Authoritative for `ref_id ↔ miro_id` identity, `parent_ref` structure, and last-known content/position.
- **Board shapes (current)** — read via `layout_read` (official Miro MCP) with the `board_id` from the sidecar. It returns the full top-level item list on every call — each shape with id, content, position, size, and fill color. There is no incremental read: `layout_read` returns the full board every call, so absorb always works from a complete board snapshot (this is what §2.4's full-board-read requirement relies on). The workflow below is fetch-agnostic — any read mechanism that yields items keyed by id with content, position, size, and fill color works in place of `layout_read`.
- **Board connectors (current)** — read via `scripts/read-connectors.sh <board_id>`. The Miro layout DSL has no connector type, so absorb drops one level and hits Miro's REST API directly. Auth via the `MIRO_ACCESS_TOKEN` environment variable (see `docs/miro-setup.md`).

Sidecar nodes carry `ref_id`. Board shapes carry `miro_id`. The link is the `miro_id` recorded in the sidecar plus the ref_id segment parsed from the shape's content — both must agree, and disagreement is a flag (§4).

**Guiding principle.** The MD files in `product/context/opportunity-solution-tree/` are the source of truth. Absorb's only job is to keep MD files in sync with the board. Anything on the board that does not impact MD content (titles, parent-child structure) is noise and is silently ignored — never reported, never flagged, never counted. That includes: fill color, border color, size, position, font, text-align, HTML wrapper variations around the canonical content, whitespace normalization, and entity encoding (`&#39;` vs `'`).

## 1.5 Tree membership: reachability from the root shape

The board is both a structured OST and a brainstorming surface. The spec separates these by *reachability from the root shape* (`PRODUCT-CRUMBS` in the sidecar) via the connector graph. Three states are possible for any shape on the board:

| State | Sidecar entry? | Reachable from root? | Absorb treatment |
|---|---|---|---|
| **Active tree node** | yes | yes | Diff normally — content edits, parent moves, deletions, etc. (§2). |
| **Detached node** | yes | no | Preserve the spec work. Sidecar flips `attached: false` with `detached_on: <date>`. Repo file stays in place. No archive, no flag, no resolution prompt. Reattaches automatically if a connector path to root is restored (§2.7). |
| **Brainstorming sketch** | no | irrelevant (and usually no) | Silently ignored. No flag, no count, no prompt to adopt. Absorb behaves as if the shape isn't there. The PM may sketch, copy, drag, and discard freely without absorb noticing. |

Reachability is computed every absorb run from the current connector snapshot. A node is reachable if there is *any* connector path of any length leading to the root shape's `miro_id`. Direction is irrelevant — connectors are undirected edges (§2.6).

Implications:

- **Brainstorming is first-class.** PMs do not need to "park" or "label" a sketch. Anything not in the sidecar is invisible to absorb.
- **Detachment is reversible without ceremony.** Drawing a connector that re-attaches a detached node to the tree restores its active status. No re-adoption flow needed.
- **Deletion intent is signalled by deleting the shape itself**, not by deleting connectors. If the PM wants to fully delete a node (and archive its file), they delete the shape. If they want to park it for later, they delete connectors and leave the shape. The distinction is unambiguous from the board state.
- **Detached repo files are not orphaned.** The sidecar entry stays; the file path stays. Tools that link to the file (other repo docs, prototype specs, ticket descriptions) continue to work.
- **The board title is chrome, not a node.** The `text` item recorded as `items.title` in the sidecar (see `create-ost.md` §2a) is never a node candidate — it is not a `round_rectangle` shape and carries no ref_id pattern. Absorb classifies it only `unchanged` / `missing` and never runs it through §2's diff or the new-node path.

Sidecar shape (additions):

```json
{
  "ref_id": "SOL-08",
  "type": "solution",
  "miro_id": "3458764670883863934",
  "parent_ref": "OPP-17",          // last-known parent before detachment, preserved
  "x": 1440, "y": 3290,
  "attached": false,                // NEW; default true if omitted
  "detached_on": "2026-05-11"       // NEW; date first observed detached
}
```

Existing sidecars without these fields default to `attached: true`. Canonical `miro-metadata.json` does not need migration until something first detaches.

## 2. Detection rules — what counts as a change

### Identity
- Identity is `ref_id`. A shape is "the same node" iff its `miro_id` matches a sidecar entry **and** the ref_id parsed from its content matches. Either-or-neither is a flag, not silently absorbed.
- A shape with no matching `miro_id` in the sidecar is a **new node candidate** (§2.3).
- A sidecar node whose `miro_id` no longer appears on the board is a **deletion candidate** (§2.4).

### 2.1 Content changes — extraction and comparison

The shape's `content` field is normalized before comparison. Normalization steps (applied in order):

1. Strip outer `<p>...</p>` if it wraps the entire content.
2. Match the canonical pattern: an opening bold tag (`<strong>` or `<b>`), the ref_id text, a closing bold tag, a line break (`<br>` or `<br />`), then the title text. Extract `ref_id` and `title` from this match.
3. If the canonical pattern doesn't match: branch on identity.
   - **Shape's `miro_id` is in the sidecar** (existing node): **content-malformed flag** (§4). Existing nodes are required to carry their ref_id prefix; absence means manual breakage.
   - **Shape's `miro_id` is NOT in the sidecar** (new node candidate, §2.3): leniently extract the title — strip any HTML tags, treat the entire remaining text as the title. PMs add new nodes by typing a plain title in Miro; absorb assigns the ref_id.
4. HTML-decode the title (`&#39;` → `'`, `&amp;` → `&`, etc.). Trim leading/trailing whitespace. Collapse runs of internal whitespace to single spaces.

After normalization, compare the extracted `(ref_id, title)` pair against the sidecar / MD baseline. Branch on identity:

- **`miro_id` in sidecar, parsed ref_id matches**: existing node. Compare title. Title differs after normalization → `## Content` entry `{ref_id}: title "..." → "..."`. Title identical → silently absorbed.
- **`miro_id` in sidecar, parsed ref_id mismatches**: **identity-break flag** (§4) — the PM may have renamed the node, typo'd it, or pasted over it.
- **`miro_id` NOT in sidecar, parsed ref_id is already in the sidecar (used by a different `miro_id`)**: **stale-prefix flag** (§4) — the PM almost certainly copy-pasted an existing shape and didn't clear the `<strong>{ref_id}</strong>` prefix. The new shape is treated as a new-node candidate; absorb does not honor the parsed ref_id. Resolution loop (§6) offers to strip the leftover prefix and assign the next available ref_id.
- **`miro_id` NOT in sidecar, parsed ref_id is also new** (e.g., PM hand-typed "OPP-99" into a fresh shape): treat as new-node candidate (§2.3); the parsed ref_id is ignored — absorb assigns the next available number for the inferred column. Surface a non-blocking note in the diff so the PM sees it.

What is silently ignored (never appears in the diff):
- `<p>...</p>` wrapper added by Miro's inline editor on click-into-edit.
- `<br>` vs `<br />` (Miro returns self-closing form on read regardless of how content was written).
- Border color, fill color, size, position, font size, text-align changes.
- HTML entity differences in title text once decoded.
- Multiple internal whitespace characters once collapsed.

### 2.2 Structural changes
The connector graph defines parenthood. For every node, the parent is the *other endpoint* of the unique tree-edge connector touching it whose other endpoint is **closer to root in the connector graph** (one step shallower on any path back to `PRODUCT-CRUMBS`). For fixed-column types (root, outcome, solution, assumption_test) this collapses to "one column to the left." For opportunities, where columns are depth-dependent, the parent may be either an outcome (depth 1) or another opportunity (depth ≥ 2); see §2.8.

- **Re-parented:** node N's connector-derived parent ref ≠ sidecar `parent_ref`, **and** N is still reachable from the root (active per §1.5). Goes in `## Structural` as `Re-parented: {ref_id}: {old_parent_ref} → {new_parent_ref}`.
- **Moved subtree (implicit):** when N is re-parented, its descendants follow by virtue of their connectors to N being unchanged. Absorb does **not** report descendants as re-parented; the move on N is sufficient.
- **Detached (lost reachability to root):** see §2.4b. Not a re-parent; not a flag. Sidecar flips `attached: false`.

### 2.3 New nodes
A shape with no matching `miro_id` in the sidecar **and reachable from the root** (per §1.5). Unreachable new shapes are **brainstorming sketches** and are silently ignored (§1.5, third row of the table) — no flag, no entry, no count.

**Type inference — signal ladder.** Absorb determines the new shape's type by checking signals in this priority order; the first one that resolves wins:

1. **Bold prefix in shape content.** If the shape's content has a parseable `<strong>{TYPE}-{NN}</strong>` prefix and `{TYPE}` maps to a known type (`OUTCOME`, `OPP`, `SOL`, `ASSUMPTION`), use that type. This is authoritative for any shape that's been through the skill at least once — copy-paste preserves the prefix even when the `miro_id` is new. (When the parsed `{TYPE}-{NN}` ref_id is already in use by a different sidecar entry, fall through to the stale-prefix flag in §4.)
2. **Canonical fill color.** A shape with no parseable prefix but a canonical fill is typed by its fill: `#cce5ff` → opportunity, `#fff3cd` → solution, `#d4edda` → assumption_test, `#ffffff` → outcome (rare for new outcomes; usually treated as ambiguous and prompted). This is the narrow color-as-signal exception to §1's "color is silently ignored" guiding principle — fill color is consulted **only as a type fallback for new shapes that lack a prefix.** Existing typed nodes (sidecar entry or parseable prefix) still ignore color; recoloring a node does nothing.
3. **Connector neighborhood.** For a shape with neither a prefix nor a canonical fill (PM sketched a plain box and dragged a connector), infer type from the type of its tree-adjacent node, using the type graph in §2.6:
   - Adjacent to an outcome → opportunity (depth 1).
   - Adjacent to an opportunity → either a deeper opportunity or a solution; cannot distinguish without more signal. Emit a **type-ambiguous flag** (§4).
   - Adjacent to a solution → assumption_test.

If two signals disagree (e.g., prefix says `SOL-04` but fill is opportunity-blue), the prefix wins silently. Color drift is below the noise threshold; do not flag this case.

**Position validation.** Once type is inferred, absorb checks that the shape's x sits within `opportunity_pitch / 2` (default 160 px) of the expected x for its inferred type/depth. Mismatch → **column-mismatch flag** (§4). For opportunities specifically, depth is inferred from the unique parent connector first; the expected x is `outcome_ancestor.x + outcome_to_opportunity_gap + opportunity_pitch × (inferred_depth - 1)`.

**Parent inference.** The unique incoming tree-edge connector whose other endpoint is closer to root in the connector graph identifies the parent. Reachability to root is already proven (otherwise the shape wouldn't be a new-node candidate in the first place). For opportunities, this parent may be an outcome or another opportunity, per the type graph.

**Proposed ref_id.** Next available number for the inferred type (`OPP-{NN}`, `SOL-{NN}`, etc.). Numbering is global per type — opportunity numbering does not reset per tier.

Reported as: `New nodes: {temp_id} | type={type} | parent={parent_ref} | title="..." | proposed_ref={NN}`. For opportunities, also include `depth={N}`.

**On adoption.** Accept-mode rewrites the shape content to canonical `<strong>{ref_id}</strong><br />{title}`, writes the MD file, and adds a sidecar entry (`attached: true` implicit). For new opportunities, `opportunity_depth` is recorded; if it exceeds the sidecar's `max_opportunity_depth`, the sidecar's `max_opportunity_depth` is bumped and the solution column is re-laid-out on the next render.

### 2.4 Deletions and detachments

Two distinct outcomes for a sidecar node that no longer behaves like an active tree member. The board state — not the connector graph alone — decides which one applies:

| Board state of the sidecar node | Treatment | Section |
|---|---|---|
| Shape **gone** from board entirely | Real deletion — archive file, drop sidecar entry | §2.4a |
| Shape **still present** but no longer reachable from root | Detachment — sidecar flips `attached: false`, file stays | §2.4b |

**Detection requires a full board read.** This comes for free with `layout_read`, which always returns the complete top-level item list — there is no incremental read mode to opt out of, so the old `--diff-against` optimization concern is moot. Deletions and detachments surface via set-difference of sidecar `miro_id`s against the full item list, plus reachability recomputation from the current connector snapshot. Connector set-difference against the prior snapshot is a useful corroboration but not the primary signal.

#### 2.4a Real deletion — shape gone from board

A sidecar node whose `miro_id` is absent from the current board read. The PM has explicitly removed the shape; intent is unambiguous.

- Reported as: `Deleted nodes: {ref_id} (was under {parent_ref}; descendants in sidecar: [...])`.
- Absorb does NOT delete repo files. On approval, the file is moved to `product/context/opportunity-solution-tree/_archive/{ref_id}-{slug}.md` with frontmatter `deleted_on: {date}`, `deleted_from_board: {board_id}`. The archive exists so the PM can resurrect prior work (see §4 "Possible duplicate" flow).
- **Cascade — descendants whose shapes are also gone.** Each missing descendant is its own deletion entry (recursive). No nesting; each entry lists its own former children under `descendants in sidecar: [...]`.
- **Cascade — descendants whose shapes remain on the board.** These shapes lose their connector path to root when the ancestor's shape is removed (Miro auto-deletes the touching connectors). They are now **detached**, not deleted — handled by §2.4b. No flag, no resolution prompt. Their sidecar entries flip `attached: false`; their files stay.

#### 2.4b Detachment — shape present, reachability lost

A sidecar node whose `miro_id` is still on the board, but no longer has a connector path to the root shape (§1.5). The PM disconnected it intentionally (parking it, reorganizing, treating it as a brainstorm fragment) or as a side effect of deleting an ancestor (§2.4a cascade).

- **Not reported in `## Structural` and not flagged.** Detachment is a routine board state under the reachability model.
- Reported as a quiet line in `## Detachments` (new section, may be empty):
  - `Detached: {ref_id} (was under {parent_ref}; last reachable at {sidecar.last_synced})`.
- On accept: set `attached: false` and `detached_on: {today}` on the sidecar entry. **Do not** archive the file. **Do not** drop the sidecar entry. **Do not** delete the shape from the board.
- Preserves PM spec work. A solution or assumption test that took real effort to write stays linked to its repo file; reattachment (§2.7) restores it transparently.
- If the PM truly wants to discard a detached node, they delete the shape from the board — at which point §2.4a takes over.

### 2.5 Style and layout changes — silently ignored

Position, size, fill color, border color, font size, text-align, connector style, and connector thickness do **not** appear in the diff under any section. They are not flagged, not counted, not reported. Per the guiding principle in §1: anything that doesn't impact MD content or tree structure is noise.

A consequence: if the PM moves a whole subtree visually (drags 20 nodes around) but doesn't change parents or content, absorb produces an all-empty diff. That's correct behavior — there is nothing for absorb to do. The PM should not expect a "I saw you move things" acknowledgment.

### 2.6 Connectors that don't fit the tree

**Connectors are undirected edges.** The Miro REST API records `from_id` and `to_id`, but these reflect *the gesture* — which endpoint the user started dragging from — not tree direction. Absorb derives parent-child orientation from x-column position, not from `from_id`/`to_id`. Two endpoints in adjacent columns form a normal tree edge regardless of API direction.

A connector is a **tree edge** iff its two endpoints are adjacent in the OST **type graph**:

```
root → outcome → opportunity → opportunity* → solution → assumption_test
```

(`*` = zero-or-more. An opportunity may be a direct child of an outcome or of another opportunity — Torres's actual methodology nests opportunities multiple tiers deep before solutions attach.)

Adjacency rules derived from the graph:

- `root ↔ outcome` — tree edge.
- `outcome ↔ opportunity` — tree edge.
- `opportunity ↔ opportunity` — **tree edge** (self-loop in the type graph). The parent is the endpoint closer to root in the connector graph.
- `opportunity ↔ solution` — tree edge.
- `solution ↔ assumption_test` — tree edge.

Anything else is a non-tree edge. Type comes from the sidecar for already-known nodes, and from the type-inference ladder in §2.3 for new shapes.

A connector is a **non-tree edge** if any of the following hold:
- **Same-type edge for a non-self-edge type.** Today only `opportunity` permits self-edges. `SOL ↔ SOL`, `OUTCOME ↔ OUTCOME`, `ASSUMPTION ↔ ASSUMPTION` are reported in `## Structural` under `New connectors (non-tree)`. The PM is asked whether this means a merge, an alternative-framing relationship, or a noted dependency. (Pre-multi-tier `OPP ↔ OPP` flags are now tree edges and are not reported here.)
- **Skip-level edge** (e.g., `OUTCOME ↔ SOL` with no OPP between, or `OPP ↔ ASSUMPTION` skipping the solution): flagged **only when both endpoints have established types from the sidecar**. For a fresh shape, type is inferred from the connector graph, so the edge is adjacent by construction; any layout disagreement is a column-mismatch on the new shape (§2.3), not a skip-level on the connector. Resolution: ask whether to insert an intermediate node, re-classify one of the endpoints, or remove the connector.
- **Multiple-parent edge** (a node has two incoming tree edges from different parents): flagged. OST is a tree; a node has exactly one parent. The PM is asked which parent is correct, and the resolution loop (§6) deletes the rejected connector from the board.

**Solutions attached to non-leaf opportunities.** A solution connected to an opportunity that has child opportunities is a structural error and is **flagged** for PM resolution. Per Torres's model, solutions attach to leaf opportunities only; mid-tier attachment usually means the PM either wants to re-parent the solution under one of the leaf children, or wants to collapse the opportunity sub-tree. Both are PM decisions, not silent-accept territory. (This was previously silent-accept; reverted to flag-and-resolve to keep the Torres reading strict — re-evaluate if PMs find the prompts noisy.)

Note: a connector whose API `from_id`/`to_id` happen to run "right-to-left" is **not** a flag. It's the same edge as any other; the gesture direction is discarded.

### 2.7 Reattachment — detached node restored to the tree

A sidecar node with `attached: false` whose current reachability check now finds a path to root. The PM drew a new connector (or the deleted ancestor was restored) and the node is back in the tree.

- Reported in `## Structural` as: `Reattached: {ref_id} (was detached on {detached_on}; now under {new_parent_ref})`.
- On accept: remove `attached` and `detached_on` from the sidecar entry; set `parent_ref = new_parent_ref`. The file was preserved through detachment, so it's available immediately — no resurrection ceremony.
- If `new_parent_ref` differs from the original `parent_ref` recorded before detachment, this is also a re-parent. The Reattached entry is sufficient; do not also emit a Re-parented entry for the same node.

### 2.8 Opportunity tier changes

When an opportunity's `parent_ref` changes type (e.g., was a direct child of OUTCOME-04, now a child of OPP-12), its `opportunity_depth` changes too. Absorb:

- Emits a normal `Re-parented:` entry in `## Structural`. The depth shift is implicit in the parent change; do not surface it separately.
- On accept: recompute `opportunity_depth = parent.opportunity_depth + 1` (or `1` if the new parent is an outcome). Propagate to all descendants — every opportunity whose ancestor chain passes through the moved node has its `opportunity_depth` recomputed.
- If the recomputed depth on any node exceeds the sidecar's `max_opportunity_depth`, bump `max_opportunity_depth`. The next render will shift the solution column right; absorb does not reposition shapes itself, only updates the sidecar so the next refresh has correct math.
- If the move *reduces* the deepest branch — e.g., the only depth-3 opportunity was moved up to depth 2 — recompute `max_opportunity_depth` from scratch across all opportunity nodes and decrement if appropriate. The solution column may shift left on the next render.

The depth recomputation is silent in the diff. The PM sees one `Re-parented:` line; the depth math is bookkeeping.

## 3. Diff output format

Both `expected-diff.md` (written before a board edit) and `actual-diff.md` (emitted by absorb) use this exact structure. Sections are present even when empty, so a reader can assert "nothing happened in this category."

```markdown
# Absorb diff — {board_id} — {ISO-8601 timestamp}

## Structural
- Re-parented: {ref_id}: {old_parent_ref} → {new_parent_ref}
- Reattached: {ref_id} (was detached on {date}; now under {new_parent_ref})
- New nodes: {temp_id} | type={type} | parent={parent_ref} | title="..." | proposed_ref={NN} [| depth={N} when type=opportunity]
- Deleted nodes: {ref_id} (was under {parent_ref}; descendants in sidecar: [list or "none"])
- New connectors (non-tree): {miro_id_a} ↔ {miro_id_b} — {same-column | skip-level | reverse}

## Content
- {ref_id}: title "..." → "..."

## Detachments
- Detached: {ref_id} (was under {parent_ref}; last reachable at {sidecar.last_synced})

## Flags (need human review)
- {ref_id_or_miro_id}: {one-line reason}

## Summary
- Structural: {N}
- Content: {N}
- Detachments: {N}
- Flags: {N}
```

A run with no MD-impacting changes produces all-empty sections and a summary of zeroes — that itself is a useful signal. Style and layout changes are silently absent; absorb does not acknowledge them.

## 4. Flags — what gets surfaced for human review, never auto-absorbed

Flags exist only for ambiguities the skill cannot resolve safely. Style drift never produces a flag.

- **Identity break:** ref_id parsed from an *existing* shape's content (its `miro_id` is in the sidecar) does not match the `miro_id`'s sidecar entry (typo, manual edit, paste-over). Resolution prompt order: typo/mis-paste (default, revert prefix) → rename intent → paste-over.
  - **Sub-case — structural conflict:** the parsed ref_id is *already in use* by a different sidecar entry. The "rename intent" branch is no longer a simple rename; surface explicitly as a conflict and route the PM to delete-the-existing-target + edit-this-shape as separate operations. Validated by test 3.4.
- **Stale prefix:** a *new* shape (`miro_id` not in sidecar) carries a `<strong>{ref_id}</strong>` prefix where `{ref_id}` is already used by a different node in the sidecar. Almost always a copy-paste leftover. Resolution loop strips the prefix and proceeds as a normal new node.
- **Content malformed:** the canonical pattern in §2.1 step 3 cannot be matched at all (bold tag missing, no `<br>`, multiple `<br>`s, content reordered such that ref_id and title aren't separable).
- **Non-tree connector violation:** a connector is reverse-direction or skip-level.
- **Column mismatch:** a node appears at a column that doesn't match its inferred type from the connector graph (e.g., a fresh shape connected only to OUTCOME-04 — type=OPP — but visually placed at x=530 near the OUTCOME column). Absorb infers type from connectors, not from x-position or color; a position-vs-type mismatch is the *signal*, not silently corrected. This is the most common new-shape flag in practice — PMs sketch in roughly the right area without snapping precisely to a column.
- **Ref collision:** two new shapes propose the same `ref_id`.
- **Possible duplicate:** a title on a new shape is identical (after normalization) to a recently-deleted node's title. Ask the PM.
- **Type ambiguous:** a new shape's type cannot be resolved from prefix, canonical fill, or connector neighborhood — typically a plain box connected only to another opportunity (could be a deeper opportunity or a solution). Ask the PM which type it is.
- **Solution on non-leaf opportunity:** a solution is connected to an opportunity that has at least one child opportunity. Torres's model attaches solutions to leaves only. Ask the PM whether to re-parent the solution under a specific leaf child, collapse the opportunity sub-tree, or override (rare).

Flags block silent absorption of the affected node only. The rest of the diff is still presented.

## 5. Modes

- **Propose-only (default):** read the board, write `actual-diff.md`, do not modify repo files or the sidecar. Used by the test harness in `product/_test/ost-absorb/` and as the default surface for absorb mode generally.
- **Accept:** after PM review and resolution of any flags (§6), apply the diff. Write/edit repo files. Update the sidecar's `nodes` array, `last_synced`, and any layout fields that changed. Move real deletions (§2.4a) to `_archive/`. Flip `attached: false` / `detached_on` on detached nodes (§2.4b). Clear those fields on reattachments (§2.7). Full runbook: `accept-mode.md`.

The skill always runs propose-only first and asks before accepting. There is no single-shot absorb-and-write path. Accept always runs inside the same invocation as propose-only — see `accept-mode.md` §1 for the procedural shape.

## 6. Resolution loop — ask, then auto-fix the board where possible

Flags exist because absorb cannot resolve an ambiguity by itself. They are not the end of the story — they are the start of a short conversation. After absorb writes the propose-only diff, the skill walks each flag with the PM and, where the resolution is mechanical, applies the fix to the board itself. Repo files only change once flags are resolved.

Board writes use the **native toolchain** (CLAUDE.md §4): shape content / fill / position changes go through the official MCP's `mcp__miro-official__layout_update`; connector create / update / delete go through `.claude/skills/opportunity-tree/scripts/write-connectors.sh` (the layout DSL has no connector type). `layout_update` re-serializes the entire board to DSL on each call — story-map item 17 documents a parser bug triggered by literal `\n` in sticky content, but OST shapes use `<br />` line breaks and don't trip it.

### Resolution table

| Flag | Skill asks | Mechanical fix on board (after PM answers) |
|---|---|---|
| **Identity break** (ref_id in shape content disagrees with sidecar's `miro_id` mapping) | "Did you mean to rename `{old_ref}` to `{new_ref}`, or was this a typo?" | If typo: `layout_update` to restore the canonical `<strong>{old_ref}</strong><br />{title}` content. If rename: update the sidecar's ref_id and proceed; flag the cascade if anything else references the old ref_id. |
| **Content malformed** (existing node, canonical pattern unmatched) | Show the raw content. Ask: "What did you intend? \[Restore canonical / Take this as the new title / Treat as new node\]" | Restore: `layout_update` with the canonical pattern reassembled from sidecar. New title: rewrite content to canonical with the extracted title. New node: same as the new-node path. |
| **Stale prefix** (new shape with a copy-pasted `<strong>{ref_id}</strong>` from another node) | "This new shape still has `{ref_id}` in its content from copy-pasting. Propose stripping the prefix and assigning `{next_ref}` instead. Or did you mean to replace `{ref_id}` itself?" | Strip-and-assign (default): `layout_update` to set content to `<strong>{next_ref}</strong><br />{title}` (where `{title}` is the body text after the `<br />`). Replace: convert this into a paste-over and treat the new shape as a substitute for the old (rare; see identity-break path). |
| **Skip-level edge** (e.g., OUTCOME ↔ SOL) | "Should this be re-routed through an intermediate node, or did you mean to drop the SOL/OPP layer here?" | Re-route: `write-connectors.sh delete` on the offending connector and `write-connectors.sh create` for the two correct ones. Drop layer: leave the connector and reclassify one endpoint (rare; usually wrong). |
| **Multiple-parent edge** (two incoming tree connectors) | "Which parent is correct?" | `write-connectors.sh delete` on the rejected edge. |
| **Same-column edge** (OPP ↔ OPP, SOL ↔ SOL) | "Is this a merge, an alternative framing, or a noted dependency?" | Today: leave the connector and record the relationship in MD frontmatter. (Future: dedicated visual treatment.) |
| **Column mismatch** (node's x-column doesn't match its connector-inferred type) | "Which is right — the connector parent or the visual position?" | Fix the position: `layout_update` to move the shape to the correct column's x. Fix the parent: rewire the connector via `write-connectors.sh delete` + `create`. |
| **Ref collision** (two new shapes propose the same ref_id) | Auto-resolved by absorb (assigns the next available number to the second). PM is informed, not asked, unless one shape's title duplicates a recently-deleted ref_id (then it's "Possible duplicate"). | `layout_update` the content of the second shape to carry the assigned ref_id once the human accepts. |
| **Possible duplicate** (new shape's title matches a recently-deleted node) | "Is this resurrecting `{old_ref}` ({old_title}), or is it genuinely new?" | Resurrect: restore the archived MD file, reuse the old ref_id, `layout_update` content. Genuine new: assign the next available ref_id. |
| **Type ambiguous** (plain-box new shape connected only to an opportunity) | "Is `{temp_id}` a deeper opportunity under `{adjacent_ref}`, or a solution attached to it?" | Opportunity: `layout_update` to set fill `#cce5ff` and content to `<strong>OPP-{NN}</strong><br />{title}`. Solution: fill `#fff3cd`, content `<strong>SOL-{NN}</strong><br />{title}`. Position is corrected on the next refresh. |
| **Solution on non-leaf opportunity** (SOL connected to an OPP that has child OPPs) | "`{sol_ref}` is on `{opp_ref}`, which has child opportunities `{children}`. Re-parent under one of the children, collapse `{opp_ref}`'s sub-tree, or keep as-is (override)?" | Re-parent: `write-connectors.sh delete` on the mid-tier edge, `write-connectors.sh create` to the chosen leaf child. Collapse sub-tree: delete the child opportunities (cascading through the resolution loop). Override: leave as-is and record the override on the SOL's MD frontmatter so future absorbs don't re-flag. |

### Behavioral rules

- **Always ask before fixing.** The skill never silently rewrites the board, even when the fix looks obvious. Ambiguity that absorb couldn't resolve is by definition something the PM should see.
- **Flag placeholders for new shapes.** The resolution-table prompts above use `{sol_ref}`-style placeholders, but a new shape has no canonical ref_id yet. Substitute `proposed_ref={TYPE}-{NN}` (e.g., `proposed_ref=SOL-10`) when emitting flag text for a new shape; use the miro_id when even the proposed_ref isn't determined.
- **One flag at a time.** The skill walks flags sequentially, applying each fix before moving on. This keeps the board state consistent during the resolution loop.
- **Re-read after each fix.** Once a fix is applied, the skill re-reads the relevant part of the board (via `mcp__miro-official__layout_read` for shapes, `read-connectors.sh` for connectors) to confirm the fix took, and then proceeds. If the re-read produces a new flag, the loop continues.
- **No board edits in propose-only mode.** Resolution-loop fixes only run when the PM has invoked accept-mode (or an explicit "fix the board" subcommand).
- **Repo writes wait for all flags resolved.** Even if the structural and content sections are clean, accept-mode does not write repo files until every flag is closed (or explicitly skipped by the PM with "leave it for now").

### Why auto-fix the board

The PM's mental model is "the board is the canvas." If absorb only ever reads, every ambiguity becomes a manual cleanup task that lives on the PM's plate. Auto-fix during resolution lets the conversation end with both the board and the repo in a consistent, reviewed state — which is the whole point of round-trip absorb.

## 7. Open questions (revise as tests reveal answers)

- ~~Does color encode status?~~ **Closed 2026-05-08.** No. Color is purely visual. If status needs to be encoded (e.g., `Descoped`, `Validated`), it will live in MD frontmatter and optionally be reflected in the title prefix (`[descoped] {title}`), not in fill color. Color changes are silently ignored under all circumstances.
- How does absorb behave with non-OST stickies/text on the board (workshop notes, parking lot)? Current rule: shapes that are not `round_rectangle` are ignored entirely. Stickies and text frames don't enter the diff.
- How are connectors with intermediate waypoints handled? Current rule: only endpoints matter; waypoints ignored.
