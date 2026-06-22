# Reference: Interpret Changes — Semantic Interpretation Pass

This is the second pass of `absorb` mode — what distinguishes this skill from a simple two-way sync. Its job: take the structural diff from `read-board-state.md` and reason about what the human changes *mean* at the product level, then propose repo changes the PM can approve or reject.

The structural-vs-semantic split has lineage in tree-diff theory (graphtage, Diff/TS); this file owns the semantic side.

**Core principle: propose, never auto-apply.** This skill proposes; the PM decides.

## When to invoke

Called from `absorb` mode whenever `read-board-state.md` produces any of:

- **orphan_sticky** (delivery-layer sticky with no sidecar record)
- **candidate_story** (Story ID present but not in sidecar)
- **content_changed** items (board edit on a known sticky)
- **moved** items that cross an activity column
- **orphan_assumption** (new discovery-layer item — `orphan_opportunity`
  is dormant per the 2026-05-14 decision; see Task E)
- **discovery_moved** or **discovery_content_changed** items (assumptions)
- Clusters of changes in the same region of the board
- **`missing` cluster that includes an activity header** — a deleted
  column (see Task H below)

## Interpretation tasks

### Task A — Orphan sticky → new story?

For each `orphan_sticky` in the delivery layer:

- **Content intent.** Does the content look like a user-story title, an activity, a note, or something else?
- **Location.** Which activity column and swim lane is it in? The column implies the activity; the emoji prefix implies the persona. The swim lane constrains priority but does **not** determine it — see the priority note below.
- **Color.** Did the human use the type-color scheme? Cyan suggests infrastructure; violet suggests a spike; light_blue suggests quality.

**Priority is ambiguous from a board read.** A sticky in the NOW lane is Critical *or* High — the lane does not disambiguate. Follow the same rule `read-board-state.md` Step 6 applies to moved stories: default a NOW landing to **High** and flag it for the PM to confirm or raise to Critical. NEXT → Medium, LATER → Low, same flag. Do not assert Critical from lane position alone.

Produce a proposed story draft:

```
PROPOSED NEW STORY
  Suggested ID:  STORY-015 (next available)
  Activity:      Courier picks up
  Priority:      High (NOW lane — Critical/High ambiguous on a board read;
                 defaulted to High per read-board-state.md Step 6, flag for
                 PM to confirm or raise)
  Type:          Regular (because light_yellow sticky)
  Personas:      courier (from 🛵 emoji prefix)
  Draft title:   "Courier confirms ETA before pickup"

  Rationale: A new light_yellow sticky appeared in the Courier picks up
  column in the NOW swim lane, prefixed with the courier emoji. Reads as a
  standard user story for the courier persona. Confidence: high.
```

Ask the user: **accept / edit / reject**. On accept, create `story-{NNN}-{slug}.md` from the template and add the sticky to the sidecar.

### Task B — Cross-column move → rescoping?

When a story moves from activity column X to column Y, the human is re-scoping what activity the story supports. This is more than a priority change.

Propose:

```
PROPOSED RESCOPE
  STORY-007 "Handoff PIN displays on courier app at arrival"
    Moved from:  Courier picks up
    Moved to:    Courier delivers

  Rationale: The story is about PIN handoff at the eater's door, not at the
  restaurant. The human likely caught a misclassification.

  Suggested action: update the story's activity context — its
  acceptance-criteria framing and any activity-bearing Labels. The skill
  records the column move; it does NOT auto-rewrite the Labels line.
  Prompt the PM for the new Labels value.
```

**Labels are not deterministically computable from a column move.** An
iteration's label slugs are theme-based (`handoff-evidence`,
`pickup-evidence`), not a mechanical function of column names — there is
no activity → label-slug map to apply. Present the Labels change as
**PM-supplied**: show the current Labels line, state the column move, and
ask the PM what the new Labels value should be. Do not propose a
before/after Labels diff the skill cannot actually derive.

Ask: **accept / edit / reject**. On accept, apply the PM-supplied Labels value (if any), update the activity context, and add a `## Sync History` note at the bottom of the story.

### Task C — Cluster of changes → backbone promotion?

When multiple orphans cluster in the same region (same column, same swim lane, or a contiguous area), the human may be signaling a structural change to the map itself.

Patterns to look for:

- **New column of stickies** to the right or left of the existing backbone → a new activity should be promoted.
- **Many moves across NOW/NEXT in the same direction** → the release slicing is being rethought.
- **Multiple orphans with a shared theme** in one column → a new sub-theme worth naming.

Propose the structural change:

```
PROPOSED BACKBONE EXTENSION
  4 new stickies appeared to the right of the "Disputes resolve" column:

    - "🎧 CX exports chain artifacts to PDF"
    - "🎧 CX shares evidence with restaurant ops"
    - "🎧 Restaurant ops acknowledges dispute"
    - "🎧 Eater notified of resolution"

  Rationale: These form a coherent activity after dispute resolution — a
  post-resolution communication step. Propose adding "Post-resolution
  follow-through" as a 6th backbone column.

  If accepted:
    1. Create story files STORY-015 through STORY-018
    2. Create story-maps/activities/activity-06-post-resolution-follow-through.md
       (ID: ACTIVITY-06, Order: 6, Personas: cx — seeded from the 🎧 prefix
       on the new column's header sticky) — the new activity's .md home
    3. Update sidecar with a new activity_header entry carrying its activity_ref
    4. Next refresh renders the new column header on the board
```

When the new header carries more than one persona emoji, list all of them
in the proposed `Personas:` field, in board order. The activity name comes
from the header text with the emoji prefix stripped (see
`read-board-state.md` "Activity-header content parser").

Ask: **accept / edit / reject** for the backbone extension and each story.

### Task C-bis — Persona-ownership change on an existing activity

A known activity header whose **emoji prefix** changed (added, removed, or
reordered) while its activity name held steady is not a backbone rename —
the PM re-marked who owns that step (e.g. a step that was courier-only is
now a courier-to-eater handoff). Propose updating the activity file's
`Personas:` field, not its `#` title:

```
PROPOSED ACTIVITY OWNERSHIP UPDATE
  ACTIVITY-03 "Handoff at door"
    current Personas:  courier
    board edit:        courier, eater   (header now reads 🛵 🍽️ Handoff at door)

  Rationale: The step gained a second owner — the eater now acts at the
  handoff (PIN entry). Suggested action: update Personas to "courier, eater".
```

Ask: **accept / edit / reject**. This path makes Patton's handoffs editable
on the board: dragging a persona's emoji onto a header is how a PM says "this
actor now participates here."

### Task D — Content edit on existing story

The repo is source of truth for story content. Default: keep repo content, log the board edit for human review.

If the edit looks like a meaningful improvement (clarity, factual fix, persona addition), propose updating the repo:

```
PROPOSED CONTENT UPDATE
  STORY-009 current title:  "SMS PIN fallback to eater's phone on handoff"
  Board edit:               "SMS PIN fallback after 30s of no in-app entry"

  Rationale: The board version is more specific — fallback trigger is now
  explicit. Likely a workshop refinement. Suggested action: update title;
  acceptance criteria in the repo unchanged.
```

Ask: **accept / edit / reject**.

### Task E — Orphan opportunity → OST inbox *(DEFERRED — dormant per 2026-05-14 decision)*

> **Deferred.** Opportunities on the story map are dormant: nothing
> renders, classifies, or forwards them today. The story map is not an
> opportunity-capture surface — an opportunity relates to an *outcome*
> (OST's job), not an *activity* (a story-map column). This section is
> kept in the spec for the future cross-board linkage release, which
> reactivates it. Until then, `read-board-state.md` does not emit
> `orphan_opportunity`, so this task never runs.

*(Original forwarding behavior, deferred:)* For each `orphan_opportunity`
(rounded rectangle, opportunity fill color), propose forwarding the
candidate to the OST inbox:

the OST inbox (`product/context/opportunity-solution-tree/inbox/`) via
the `opportunity-tree` skill, recording the Miro ID in the story-map
sidecar so the shape isn't re-proposed.

### Task F — Orphan assumption → informational `ASSUMPTION_CAPTURED` notice

For each `orphan_assumption` (rounded rectangle, Miro fill color
`light_green`, anywhere on the map — classified by shape + color, not by
band membership):

Per the 2026-05-14 decision, **there is no story-map ↔ OST linkage
today.** The story map is a legitimate place assumptions surface during
mapping, but absorb does NOT forward them anywhere, does NOT propose a
repo change, and does NOT write to the repo. It **detects** the
assumption, records which story it sits beside (`nearest_story`), and
**surfaces** it as an informational notice for the PM to route by hand.

```
ASSUMPTION_CAPTURED (informational — no action taken)
  Content:         "Couriers will tap a one-tap transit flag mid-route"
  Sits beside:     STORY-012 "Courier flags transit disturbance"
  Activity column: Courier delivers

  This assumption surfaced on the story map during mapping. It has been
  recorded in the story-map sidecar under items.assumptions with its
  nearest_story so it isn't re-surfaced on the next absorb. It has NOT
  been forwarded to the OST or the assumption-map skill — cross-board
  linkage is a later release. Route it by hand if you want it tested.
```

This is **not** a proposal — there is no accept/edit/reject. It is an
informational line in the output. The only state change is the
story-map sidecar recording the Miro ID + `nearest_story` under
`items.assumptions` (tracked as "seen, surfaced"), part of the normal
sidecar refresh, not a PM-approved write.

*(When the future linkage release ships, Task F regains a forwarding
proposal — to the OST assumption-test tier if a specific solution is
implied by `nearest_story`, otherwise to the `assumption-map` skill. Kept
as a deferred note, same as Task E.)*

### Task G — Discovery-layer move or content change

If a tracked assumption was repositioned (now sits beside a different
story) or its content was edited, surface it as an informational
`ASSUMPTION_CAPTURED` update — same no-forward, no-proposal,
no-repo-write rule as Task F. The sidecar's `nearest_story` and content
fields refresh to match the board; nothing else changes. (Opportunity
moves are dormant — see Task E.)

### Task H — Deprecation / contraction (deleted activity column)

Task C's inverse. When a `missing` cluster from `read-board-state.md`
**includes an activity header**, the PM has deleted a column from the
backbone, not just a few stories. Today absorb degrades to warnings only
under the no-cascade guarantee — correct, but it leaves an
`activities/*.md` file claiming a column that no longer exists and the
column's stories orphaned in the repo with no surfacing.

**Trigger.** A `missing` cluster where at least one missing item has
`role: activity_header` in the sidecar. Co-missing stories from the same
column (sidecar `activity == header.activity`) are bundled into the same
Task H proposal.

Propose the structural change (PM-approved; **never** automatic):

```
PROPOSED BACKBONE CONTRACTION
  The "Disputes resolve" column is no longer on the board:
    - Missing activity header: "Disputes resolve" (sidecar id 3458764671405697781)
    - Co-missing stories from that column: STORY-006, STORY-014

  Rationale: The column header and 2 of its 2 stories were removed
  together. Reads as an intentional deletion of the activity from the
  backbone, not an accidental wipe.

  If accepted:
    1. Move story-maps/activities/activity-05-disputes-resolve.md to
       story-maps/activities/_archive/ with frontmatter
       deleted_on: {YYYY-MM-DD}, deleted_from_board: {board_id}
    2. Move story-006-*.md and story-014-*.md to product/iterations/
       {iteration}/stories/_archive/ with the same frontmatter
    3. Drop the sidecar entries for the header and the co-missing stories
    4. Next refresh renders the map with one fewer column
```

**Stories that survived the column deletion.** If some stories from the
deleted column are still on the board (their sidecar entries `unchanged`
or `moved`), they are **not** archived. Surface them in the proposal as
"stories that need a new column assignment" and ask the PM which
remaining column (or new column) they belong under. Apply the PM's
answer as a per-story re-attribution; the sidecar `activity` updates to
the new column, the story MD's `**Activity**:` line is rewritten, and
the structural pass on the next absorb will read it as `unchanged` in
its new column.

**Partial deletions are not Task H.** A `missing` cluster of stories
without the header missing is not a column deletion — it is just stories
gone (warnings, no proposal). Task H requires the header itself to be
missing.

Ask: **accept / edit / reject** for the contraction, and **accept /
re-attribute / leave-orphan** per surviving story.

## Prompt skeleton for the LLM interpretation call

When the skill asks the LLM to run this interpretation, structure the call like:

```
You are interpreting changes a human made to a Miro story map during a workshop.
Repo stores the source-of-truth story content; sidecar stores prior board state.
Your job is to propose repo changes the PM can approve.

Prior sidecar state:
{sidecar JSON excerpt for the changed region}

Structural diff from read-board-state:
{diff JSON for this interpretation task}

Relevant story files (for context):
{content of nearby stories in the same activity column and swim lane}

Persona legend (product/context/personas.md ## Legend) and backbone
activity files (story-maps/activities/*.md, sorted by Order):
{verbatim}

For each proposed change, output:
  - Type: NEW_STORY | RESCOPE | BACKBONE_EXTENSION |
          BACKBONE_CONTRACTION | CONTENT_UPDATE | DISCOVERY_UPDATE
  - Target (story id, "new", or upstream skill name)
  - Proposed action
  - Rationale (one sentence)
  - Confidence: high | medium | low

Separately, for each orphan or moved assumption, output an informational
ASSUMPTION_CAPTURED notice (content, nearest_story, activity column). This
is NOT a proposal — it carries no accept/edit/reject and triggers no repo
write. Opportunity types (OPPORTUNITY_FORWARD, ASSUMPTION_FORWARD) are
dormant per the 2026-05-14 decision and are not emitted today.
```

Always return concrete, reviewable proposals. Never apply without the PM's approval.

## Output contract

After running all interpretation tasks, output a single batched proposal document. Proposals and informational notices are listed separately:

```
SEMANTIC INTERPRETATION — {board_name} — {timestamp}

{N} proposals for PM review.

  1. NEW_STORY (high)
     {body}
  2. BACKBONE_EXTENSION (high)
     {body}
  3. RESCOPE (medium)
     {body}
  ...

{M} informational notices (no action required):

  - ASSUMPTION_CAPTURED — "{content}" beside STORY-012
  ...

Reply with: "accept 1,3" or "accept all" or "reject 2" or edit-per-item.
(Informational notices take no reply — they are surfaced, not proposed.)
```

The PM's response drives the final repo writes. This skill never writes outside `product/iterations/{iteration-slug}/`. Cross-board forwards to other skills (`opportunity-tree`, `assumption-map`) are deferred per the 2026-05-14 decision — captured assumptions are surfaced for the PM to route by hand, not forwarded. When the linkage release ships, those forwards return as separate skill invocations after PM approval.
