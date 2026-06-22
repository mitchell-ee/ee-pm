# Reference: Interpret Assumption Changes — Semantic Interpretation Pass

The second pass of `absorb` mode for assumption maps. Take the structural diff from `read-board-state.md` and reason about what the human changes *mean*: which file fields to update, which fields need PM input, which changes are observable facts safe to sync without asking.

Mirrors `story-map/reference/interpret-changes.md` and `opportunity-tree/reference/interpret-changes.md`. Assumption maps' semantic surface is narrower (no parent-relationship reshuffling, no cross-column rescoping) but distinctively two-dimensional — quadrant moves derive *two* file fields (`Importance` AND `Evidence`), and color carries dual meaning (Type vs Result).

**Core principle: propose, never auto-apply.** This file proposes; the PM decides.

## When to invoke

Called from absorb mode whenever `read-board-state.md` produces any of:

- **moved_quadrant** (sticky crossed an axis)
- **content_changed** (short title rewritten)
- **recolored** (fill color changed; includes the gray-arrival "result came in" case)
- **moved_and_changed** (any combination of the above on one sticky)
- **orphan_sticky** (no sidecar record — candidate new assumption)
- **missing** clusters that suggest deliberate removal (phase-3 territory)

## Interpretation tasks

### Task A — Quadrant move → Importance/Evidence rerating

When a sticky's `observed_quadrant` differs from sidecar `current_quadrant`, the PM has rerated the assumption on one or both axes. Derive the file updates from the *new* quadrant:

| Quadrant | Importance | Evidence |
|---|---|---|
| `watch` (top-left) | High | Strong |
| `test_first` (top-right) | High | Weak |
| `dont_worry` (bottom-left) | Low | Strong |
| `investigate_later` (bottom-right) | Low | Weak |

Propose the file edit and the sidecar update:

```
PROPOSED QUADRANT MOVE
  ASSUMPTION-006 "Marketing can position wider ETAs as reliability win"
    From: investigate_later (Low / Weak)
    To:   test_first        (High / Weak)

  Proposed edit (assumption-006-marketing-spin.md):
    Importance: Low  →  High
    Evidence:   Weak →  Weak  (unchanged — flagged for transparency)

  Proposed sidecar edit:
    stickies.ASSUMPTION-006.current_quadrant: investigate_later → test_first
```

**Flag unchanged axes for transparency.** If the move was diagonal (both Importance AND Evidence change), report both deltas. If the move was orthogonal (e.g. across the y-axis only — Importance flips but Evidence is unchanged), explicitly mark the unchanged axis. The PM should see both columns of the derivation, even when one is a no-op.

**Special case: move INTO `test_first`.** If the sticky lands in test_first AND the assumption file's `Method:` / `Success Criterion:` fields are empty, surface a PM follow-up:

> ASSUMPTION-006 just landed in test_first. Method and Success Criterion are still empty. Want to design the test now, or leave for later?

Do NOT auto-scaffold `Method` / `Success Criterion` with placeholders. The "test first" quadrant is consequential — entering it should prompt the PM, not generate work.

**Special case: move OUT of `test_first`.** Either Importance dropped or Evidence strengthened — the team decided this no longer needs urgent testing. If the file has populated `Method:` / `Success Criterion:`, ask whether the test plan should be archived or kept in place:

> ASSUMPTION-XX just left test_first. The test plan (Method + Success Criterion) is still filled. Archive it (move into a notes section) or leave as-is in case it returns?

### Task B — Recolor → Type or Result

A `recolored` sticky is structurally the same diff but semantically branches on which colors were involved.

**Color → gray (Result arrival).** The assumption was tested. Propose `Result: Pending → ?` but BLOCK on PM input — color alone cannot say which outcome:

```
PROPOSED RESULT UPDATE
  ASSUMPTION-001 "Customers trust a wider ETA band"
    Sticky recolored: light_yellow → gray
    Implication: result has come in (gray = Result ≠ Pending)

  Proposed sidecar edit (safe — observable):
    stickies.ASSUMPTION-001.fill_color: light_yellow → gray

  Proposed file edit (BLOCKED on PM):
    Result: Pending → {Confirmed | Rejected | Inconclusive}

  Question: ASSUMPTION-001 went gray on the board — looks like a result
  came in. Which one: Confirmed, Rejected, or Inconclusive? Want to
  record the evidence link too?
```

`Type` in the file is **not** changed on graying. Gray is a *display override* indicating tested-status, not a type reclassification. The Desirability assumption is still a Desirability assumption — the workshop just learned the answer.

**Gray → color (Result undo).** Rare; the PM is reverting a tested assumption back to pending status. Propose `Result: Pending` and ask whether the prior outcome should be archived in the file as historical context.

**Color → different color (Type reclassification).** Both colors are in the canonical palette and neither is gray. Map the new color to a Type via `SKILL.md` §"Color convention":

- `light_yellow` → Desirability
- `light_blue` → Usability
- `light_green` → Feasibility
- `light_pink` → Viability
- `violet` → Ethical

```
PROPOSED TYPE UPDATE
  ASSUMPTION-XX "{short title}"
    Sticky recolored: light_yellow → light_pink
    Type mapping:     Desirability  → Viability

  Proposed sidecar edit:
    stickies.ASSUMPTION-XX.fill_color: light_yellow → light_pink

  Proposed file edit:
    Type: Desirability → Viability
```

This is deterministic — proposed without PM clarification, accepted as a single approval.

**Unknown color (not in canonical 6-color palette).** PM picked a custom hex. Warn and flag; do not auto-map. Ask: "ASSUMPTION-XX recolored to a non-canonical hex `#aabbcc`. Should we adopt this as a new type, or was it a stray click?"

### Task C — Content change → Hypothesis review

When a sticky's parsed short title differs from `sticky_short_title`, the PM has rewritten the assumption's framing. The file's H1 should follow. The file's `Hypothesis:` field should be reviewed — a title shift often reflects a hypothesis shift, but not always.

```
PROPOSED CONTENT UPDATE
  ASSUMPTION-003 short title rewritten:
    From: "Pickers understand the wider ETA band UI"
    To:   "Picker app surfaces ETA band correctly to staff"

  Proposed sidecar edit:
    stickies.ASSUMPTION-003.sticky_short_title: → "Picker app surfaces ETA band correctly to staff"

  Proposed file edit (assumption-003-pickers-understand-band.md):
    # Assumption Test: Pickers understand the wider ETA band UI
    →
    # Assumption Test: Picker app surfaces ETA band correctly to staff

  PM follow-up question:
    The title shift changes scope from comprehension to UI display.
    The Hypothesis field still reflects the old framing
    ("Pickers correctly read '25-40 min' as a range, not a deadline").
    Want to rewrite the Hypothesis, or is it still load-bearing as
    a secondary claim?
```

**File slug is durable identity.** Do not propose renaming `assumption-003-pickers-understand-band.md` even when the title in the file changes radically. The slug is the filesystem identity — stable across edits, referenced from the OST and possibly from the story map. The title-in-file evolves; the slug doesn't.

**Never auto-rewrite Hypothesis, Method, or Success Criterion.** These fields encode the team's research design and assertions. A retitle is a strong signal that they need review, but the actual rewrite is human work. Surface the question; let the PM type.

### Task D — Orphan sticky → new assumption

For each `orphan_sticky` (sticky on the board with no sidecar record):

- **Content intent.** Parse the sticky content. If it follows the `<p>{ID}</p><p>{short title}</p>` convention with an `ASSUMPTION-` prefix already, the PM was thinking ahead — they wrote a candidate ID inline. Honor it if it doesn't collide with an existing assumption file.
- **Quadrant.** Maps to `Importance` / `Evidence` via Task A's table.
- **Color.** Maps to `Type` via Task B's color table. If gray, the PM is recording a previously-tested assumption — propose `Result:` non-Pending alongside.

Propose:

```
PROPOSED NEW ASSUMPTION
  Suggested ID:    ASSUMPTION-009 (next available — current max is 008)
  Quadrant:        test_first
  Type:            Desirability (light_yellow)
  Importance:      High (top-half quadrant)
  Evidence:        Weak (right-half quadrant)
  Result:          Pending
  Draft title:     "Customers will tolerate a 5-minute ETA buffer"
  Parent Solution: SOL-01 (derived from board's solution_ref)

  Rationale: A new light_yellow sticky appeared in the test_first quadrant
  with content suggesting a desirability claim about ETA buffers. Reads as
  a high-importance / weak-evidence assumption the team just surfaced.
  Confidence: high.

  PM follow-up: Hypothesis field is empty in the proposed file. The sticky
  short title gives the WHAT but not the HOW we'd test it. Fill the
  Hypothesis ("If we ___, then ___") and Method when accepting?
```

Ask: **accept / edit / reject**. On accept, create `product/context/opportunity-solution-tree/assumptions/assumption-{NNN}-{slug}.md` from the SKILL.md file template and add the sticky to the sidecar's `stickies` block.

### Task E — Missing sticky → deletion warning (phase-3)

A `missing` state is a recorded sticky the read couldn't find on the board. Two interpretations:

- **Deliberate delete.** The team decided the assumption is no longer relevant — e.g. it was actually duplicate, or the parent solution moved on.
- **Accidental delete.** Someone hit delete instead of deselect.

Surface as a warning; do NOT cascade-delete the assumption file. Ask:

> ASSUMPTION-XX is no longer on the board but its file is still in the repo. Was the deletion intentional? Options:
>   1. Yes — mark the file's Status as Removed and keep it as record.
>   2. Yes — delete the file (rare; only if it was a duplicate that got merged into another assumption).
>   3. No, accidental — refresh-mode will recreate the sticky on the next build.

Default to option 1 if the PM is undecided. The assumption file carries research history; deletions are recoverable.

### Task F — Cluster: 3+ stickies rerated together

If three or more stickies move quadrant in the same absorb pass, the team is likely re-rating an entire category — e.g. "we systematically overestimated our evidence for all the desirability assumptions." Surface the pattern:

> 4 stickies moved between quadrants in this pass. 3 of them (ASSUMPTION-001, -004, -006) are all Desirability assumptions, all moved into the same quadrant (test_first). Looks like the team is re-rating the Desirability category. Apply the moves individually, or apply as a batch with a single rationale entry in each file's history section?

Batch-apply is cosmetic — the underlying edits are still per-file — but the framing helps the PM see the workshop story.

## Output format

The semantic interpretation pass produces a `actual-diff.md` document per the harness contract. Format:

```markdown
# Absorb diff — {test name or timestamp}

## Structural diff (pass 1)

- {state}: {item_id} {assumption_id} — {summary of what changed}

## Semantic interpretation (pass 2)

**{Assumption ID} — {state label}**

Proposed sidecar change (safe):

```diff
- {field}: {old}
+ {field}: {new}
```

Proposed file change to `tests/{slug}.md`:

```diff
- {line}
+ {line}
```

PM follow-up surfaced (if any):
> {question to PM}

## What is NOT proposed
- {explicit no-ops, e.g. "Type unchanged on graying", "Hypothesis not auto-rewritten"}
```

Clean reads emit the no-op shape from `read-board-state.md` Step 9 — no semantic section needed.

## Cross-skill seams

The skill never writes outside its own surface (`product/context/assumption-maps/`). If absorb surfaces signals relevant to neighboring skills, route them:

- **A new sticky on the assumption map that reads more like an opportunity than an assumption** → flag for `opportunity-tree` inbox. Do not write to OST.
- **A retitle that suggests the parent solution has changed scope** → surface the question, but the solution-shape edit happens in the OST, not here.
- **A `Result: Confirmed` arrival that demolishes the parent solution's case** → flag for OST review (solution may need re-evaluation), but again — the OST owns its own state.

These hooks are paper today; cross-skill sync between the assumption map, OST, and story map is a later release.
