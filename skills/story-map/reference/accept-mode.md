# Accept-mode runbook — applying an absorb diff to repo + board

This is the canonical spec for `story-map` **accept mode**.
Propose-only (`read-board-state.md` Step 6 + `interpret-changes.md`)
reads the board and emits a diff of structural-only proposals, semantic
proposals, warnings, and informational notices. Accept mode walks any
flags with the PM, writes the resolved diff into repo files and the
sidecar, then runs a closing **board label-normalization pass** that
writes the canonical identity label (`STORY-NNN` token + persona emoji)
onto any sticky whose board content doesn't already carry it.

The label pass is **content-only**: it never moves, recolors, or
resizes a sticky. A workshop arranges the board for human collaboration
— that arrangement is left exactly as the PM left it. Accept only makes
sure each sticky *displays* the identity the sidecar now assigns it
(critically, a brand-new story's freshly minted `STORY-NNN`).

Accept always runs inside the same invocation as propose-only. There is
no standalone accept-from-prior-diff entrypoint; the diff lives in
conversation context (and optionally `actual-diff.md` for audit), not as
a load-bearing artifact.

For the detection rules and diff format, see `read-board-state.md`
(structural pass) and `interpret-changes.md` (semantic pass). For Miro
layout, see `create-story-map.md`. This file covers only the
propose→accept transition.

---

## 1. Procedural shape

One skill invocation, three phases:

```
read board → propose-only diff → flag-walk loop → PM "accept" → repo + sidecar writes → board label normalization
                                       ↑                              ↑                          ↑
                                 no mutations              file writes here          identity labels written
```

- **Phase 1 — propose-only.** Read the board via `layout_read`, compute
  the structural diff (`read-board-state.md`) and semantic proposals
  (`interpret-changes.md`), write `actual-diff.md`. No mutations of any
  kind.
- **Phase 2 — flag-walk loop.** For each flagged proposal, ask the PM
  the resolution prompt in §6, record the answer. Story-mapping's flags
  are **value-supply** prompts (confirm a defaulted Priority, supply a
  Labels value) — not board-fix prompts. No board or repo write happens
  in the loop. Loop until the flag set is empty or the PM defers a flag
  with "leave it for now."
- **Phase 3 — write.** Once flags are clear (or explicitly deferred),
  confirm with the PM ("apply the rest of the diff to repo files?"),
  then write MD files and update the sidecar (§3.1–3.5), and finally run
  the board label-normalization pass (§3.6). The **only** board writes
  accept ever makes are in §3.6, and they are content-only — never
  position, fill, or size. The sidecar is finalized (§3.5) **before**
  the label pass runs, because the sidecar is the source of truth for
  the identity labels the pass writes.

The PM may abort between any phase. Phase 1 produced no side effects;
phase 3's writes are not transactional across stories (see §4).

**Key contrast with `opportunity-tree` accept mode.** Story maps carry
**no connectors** — release horizons are rectangles, parenthood is
positional. So accept mode has no connector reads, no connector writes,
and no detachment/reattachment handling. The flag-walk loop is also
lighter: there is no stale-prefix board-fix step, because a story map's
delivery items are stickies whose identity is the `STORY-NNN` token in
their content, assigned by accept itself — not a prefix a human
copy-pastes.

## 2. Phase 2 — flag-walk loop

Walk flags in the order they appear in `actual-diff.md`. For each:

1. Surface the flag's one-line reason to the PM with the relevant prompt
   from §6's resolution table.
2. Record the PM's answer in memory (and in `actual-diff.md` for audit).
   No board or repo write happens here.
3. Mark the flag resolved. Move to the next.

If the PM says "leave it for now" for a flag, record it as **deferred**
in the diff. A deferred flag does not block phase 3 — the relevant
proposal simply isn't applied this round, and the same flag resurfaces
on the next absorb. For a deferred NEW_STORY Priority flag, the safe
default still applies (the proposal carries **High** per
`read-board-state.md` Step 6); "leave it for now" means the PM accepts
that default rather than that the story is skipped.

**No phase-3 writes happen during the loop.** The loop only collects PM
answers.

## 3. Phase 3 — repo and sidecar writes

After the loop, confirm with the PM, then walk the diff sections.
Ordering within phase 3 is **structural-only proposals → semantic
proposals → informational notices → sidecar finalize → board label
normalization**. A story that
appears in more than one section (e.g. a `moved_and_changed` sticky with
a Priority proposal, a Type proposal, and a CONTENT_UPDATE) is touched
once per field on the same file — order within that file doesn't affect
correctness because the fields are disjoint header lines.
Sidecar finalize runs once at the end; only the on-disk sidecar write is
atomic.

A story file lives at
`product/iterations/{iteration-slug}/stories/story-{NNN}-{slug}.md`. The
sidecar lives at
`product/iterations/{iteration-slug}/story-maps/miro-metadata.json`.
Activity files live at
`product/iterations/{iteration-slug}/story-maps/activities/activity-{NN}-{slug}.md`;
the persona legend is the `## Legend` table in
`product/context/personas.md` (the iteration README holds no map
structure).

### 3.1 Structural-only proposals — Priority and Type header edits

These come from `read-board-state.md` Step 6 — a swim-lane move maps to
`Priority`, a recolor maps to `Type`. Both are deterministic; neither
needs the semantic pass; neither touches the board (the PM already moved
or recolored the sticky — the board is already canonical).

**`PROPOSED PRIORITY UPDATE` — `{story_id}: Priority {old} → {new}`:**
- Read the story file. Replace the `**Priority**: {old}` header line
  with `**Priority**: {new}`.
- Update the sidecar story entry's `swim_lane` to the new lane and
  `priority` to `{new}`.
- A NOW landing whose new priority is ambiguous (moved in from NEXT or
  LATER) arrives here already flagged and resolved — the value written
  is whatever the PM confirmed in the §2 loop (default **High**).

**`PROPOSED TYPE UPDATE` — `{story_id}: fill {old} → {new}`:**
- Read the story file. Add or replace the `**Type**: {Type}` header
  line, where `{Type}` is the deterministic mapping of the new fill
  color (`read-board-state.md` Step 6 color table). Insert it after the
  `**Priority**` line if no `**Type**` line exists.
- Update the sidecar story entry's `fill_color` to the new color.

### 3.2 Semantic proposals — content updates and new stories

**`CONTENT_UPDATE` — `{story_id}: title "..." → "..."` (Task D):**
- Update the sidecar story entry's `sticky_short_title` to the new
  parsed short title. (The short title is the content key for the
  structural pass — it is not reverse-derivable from the file, so the
  sidecar must carry it; see `read-board-state.md` Step 1.) **This is
  the only write CONTENT_UPDATE makes in the thin slice.**
- **The story file is not touched.** The board sticky carries the
  *short* title; the story file's `# Story: {title}` H1 is the *full*
  title (e.g. sticky "Handoff PIN displays at arrival" vs file H1
  "Handoff PIN displays on courier app at arrival"). The two are
  distinct fields — the full H1 is **not** mechanically derivable from
  an abbreviated board edit, and absorb must never silently overwrite a
  PM-authored full H1 with a board short string. This matches the
  phase-1 test 1.1 precedent: CONTENT_UPDATE accept updates the working
  sidecar only.
- The §3.6 pass writes the new short title onto the board sticky in its
  canonical two-`<p>` form.

> Deferred (later cohort): a `STORY FILE REVIEW` flag that, when the
> board short title changes, asks the PM whether the story file H1 /
> body needs a corresponding edit — and applies the PM-supplied full
> title. The thin slice proves only the mechanical sidecar write.

**`NEW_STORY` — Task A, one per accepted `orphan_sticky`:**
- **Re-derive the Story ID at write time.** Scan the live sidecar for
  the highest existing `STORY-NNN`, increment. Do not trust the
  `Suggested ID` from the diff text — it was advisory. Apply in stable
  order (sorted by the orphan's Miro item id if multiple new stories).
- Slugify the draft title into a filename: lowercase, hyphenated,
  ASCII-only, truncate to ~40 chars at a word boundary.
- Write `story-{NNN}-{slug}.md` from `templates/story.md`. Fill in:
  - `**Story ID**: {NNN}`
  - `**Priority**: {value}` — the value the PM confirmed in the §2 loop
    (default **High** for a NOW landing, per `read-board-state.md`
    Step 6).
  - `**Type**: {Type}` — the deterministic mapping of the orphan's fill
    color. Per `templates/story.md`, **omit this line entirely when the
    mapping is `Regular`** (the default); write it only for a
    non-Regular type.
  - `**Personas**: {persona-slug}` — resolved from the emoji prefix via
    the `product/context/personas.md` `## Legend` table.
  - `**Status**: Draft`
  - `**Labels**: {iteration-slug}` — area labels are theme-based and not
    mechanically derivable; leave them for the PM.
  - The `# {draft title}` H1.
  - Acceptance criteria and body left as TODO placeholders for the PM.
- **Assign the canonical content** for the board sticky: the two-`<p>`
  form `<p>{emoji} STORY-{NNN}</p><p>{short title}</p>`. The orphan was
  created by the PM with no `STORY-` id; this is where accept mints its
  identity. The actual board write happens in the §3.6 label-normalization
  pass — §3.2 only records the canonical content the pass will write.
  The pass writes content only; the orphan stays at the position, fill,
  and size the PM gave it. Track this sticky's Miro id in an in-memory
  self-edit set so a post-write re-read doesn't re-flag it as a content
  change.
- Add a sidecar `stories[]` entry: `{id, story_id, activity, swim_lane,
  x, y, fill_color, personas, priority, sticky_short_title}` where `x` /
  `y` come from the **phase-1 board read** (accept makes no positional
  moves).
- Append a row to `stories/stories-index.md` for the new story.

### 3.3 Warnings — the no-cascade guarantee

A `missing` change record (a story in the sidecar with no sticky on the
board) produces a **warning only**. Accept mode does **not**:
- delete or archive the story file,
- drop the sidecar entry,
- mutate the board.

This is the no-cascade guarantee from `read-board-state.md` Step 4 state
12 and `SKILL.md` ("absorb mode NEVER deletes repo files without
explicit approval. A sticky removed from the board is a warning, not a
cascade"). The missing story stays in the repo and the sidecar; the same
warning resurfaces on the next absorb. A PM who genuinely wants the
story removed does that through a separate, explicit deletion — never as
an absorb side effect. This holds in accept mode exactly as in
propose-only mode.

> Deferred (later cohort): a `## Removed` diff section that, on explicit
> PM approval, grays out the sticky and prepends "(Removed)" per
> `SKILL.md` refresh-mode rules. Even then it never deletes the file.
> The thin slice proves only that `missing` is inert in accept mode.

### 3.4 Informational notices — sidecar-only

An `ASSUMPTION_CAPTURED` notice (a `light_green` rounded rectangle with
no sidecar record) carries no accept/edit/reject. On a sidecar refresh
accept mode records the assumption under `items.assumptions` with its
`nearest_story` and content — "seen, surfaced" — so it isn't
re-surfaced. No story file is written; no forward happens (cross-board
linkage is deferred per the 2026-05-14 decision). This is part of the
normal sidecar finalize, not a PM-approved write.

> Deferred (later cohort): the thin slice in §6 does not exercise
> `ASSUMPTION_CAPTURED`. Listed here so the contract is complete.

### 3.5 Sidecar finalization

- `last_synced_at`: set to **`now()` at end of phase 3**, after all repo
  writes succeed, as a UTC `Z`-form timestamp. Future absorb runs diff
  the board against this timestamp's sidecar state.
- Write the sidecar back to
  `product/iterations/{iteration-slug}/story-maps/miro-metadata.json`
  atomically: write to a sibling `.tmp` file, then `rename`. This single
  write is the only atomic boundary in phase 3.

### 3.6 Board label-normalization pass

After the sidecar is finalized (§3.5), accept mode runs a closing pass
that writes the canonical **identity label** onto any sticky whose board
content doesn't already carry it. This is the **only** place accept
writes to the board, and it is **content-only**.

**Why the pass exists.** When the PM creates an orphan sticky, it has no
`STORY-NNN` token — accept mints the id in §3.2, and the board sticky
must then *display* that id so the next absorb run can identify the
story by its content key. The pass is what puts the minted label on the
board.

**What the pass writes**, driven by the just-finalized sidecar — for
every `stories[]` entry, compare the board sticky's content to the
canonical two-`<p>` form `<p>{emoji} STORY-NNN</p><p>{short title}</p>`
(emoji from the persona, `STORY-NNN` and short title from the sidecar
entry). If they differ, write the canonical content. If they already
match, write nothing. In practice the only sticky that needs a write
each run is the §3.2 new story — every other sticky already carries its
canonical label.

**What the pass must not do — it never moves, recolors, or resizes
anything.** A workshop arranges the board for human collaboration: a
sticky parked off-grid, a deliberate cluster, extra whitespace — those
are signal, not drift, and accept leaves them untouched. Position, fill,
and size are the PM's; absorb has already read their *meaning* into the
sidecar (lane → Priority, color → Type) and that is the whole of what
accept does with them. The pass also never touches an item with no
sidecar entry (a `missing` story, an un-accepted orphan or assumption).

The pass is **idempotent** — on an already-labelled board it writes
nothing. An accept with zero accepted proposals runs the pass and is a
no-op.

**Failure is self-healing.** The pass is not transactional, but the only
write it makes is the new-story content write — if it fails, the new
story file and sidecar entry are already on disk but the board sticky
still lacks its `STORY-NNN` token. Surface to the PM ("repo and sidecar
updated; board label write failed — re-run accept to finish"). The next
absorb re-detects the still-unlabelled sticky as a `candidate_story` /
`orphan_sticky`, the same `STORY-NNN` is re-derived (it is the highest
on disk), and the pass retries. No repo damage, converges on re-run.

## 3a. Underspecified-state rule — ask, don't invent

If the skill encounters a state during phase 1, 2, or 3 that **no rule
in this file, `read-board-state.md`, or `interpret-changes.md` covers**,
the skill must stop and ask the PM how to proceed. Examples:

- A story MD file exists on disk for a `STORY-NNN` that has no sidecar
  entry (drift between repo and sidecar).
- Two sidecar story entries share a `miro_id` or a `story_id` (data
  corruption — `SKILL.md` error handling: "refuse to sync").
- An orphan sticky's emoji prefix matches no persona in the
  `product/context/personas.md` `## Legend` table.
- A `recolored` sticky's fill color is not in the `create-story-map.md`
  type-color table.

The skill **never** silently picks a default in these cases. The cost of
a wrong silent choice (overwriting prior work; assigning a `STORY-NNN`
already in use on disk) is high enough that interrupting the PM is
always cheaper. Frame the prompt as a flag the PM sees alongside any
other flagged ambiguities.

Distinction from §6 documented flags: documented flags are *predictable*
ambiguities the spec already anticipated (the NOW-priority flag). This
rule covers *unanticipated* states — bugs, drift, or scenarios the spec
hasn't yet handled. Unanticipated flags should be recorded post-test as
either new documented flags or new rules.

## 4. Error handling and abort semantics

**Mid-loop PM abort (phase 2):** no board or repo writes occurred —
phase 2 only collects answers. Surface to PM: "No changes applied.
Re-running absorb produces a fresh diff." Fully self-healing.

**Mid-phase-3 abort or process failure:** writes are not transactional
across stories. Some MD files may be written, some not; the sidecar is
only written at the very end (§3.5 atomic rename). On abort:
- Sidecar still reflects pre-run state (it wasn't written yet) — safe.
- MD files may have partial updates.
- Next absorb re-detects the actual board state vs the still-old sidecar
  and surfaces the remaining work. Stories that did get processed will
  be in sync with the board; the unwritten ones reappear in the next
  diff.

**MD file already exists at new-story write path** (slug collision):
append `-2`, `-3`, etc. to the slug until unique. The `STORY-NNN` id is
the citation key; the filename is incidental.

**Board label-normalization pass fails during phase 3** (`layout_update`
/ REST PATCH error): the repo files and sidecar are already written and
finalized — only the new story's `STORY-NNN` label didn't make it onto
the board sticky. Surface to PM: "Repo and sidecar updated; board label
write failed — re-run accept to finish." Self-healing: the next absorb
re-detects the unlabelled sticky as an orphan, the same `STORY-NNN` is
re-derived (it is now the highest on disk), and the pass retries. Do
**not** roll back the sidecar — its state is correct and is what the
re-run converges against.

**Sidecar write fails** (disk error, race): MD files from phase 3 are
already on disk. Surface clearly: "Repo updated, sidecar write failed.
Re-run accept after resolving {error}." The next absorb run diffs the
board against the *old* sidecar — phase 3's MD writes appear briefly out
of sync (e.g. a new story file with a `STORY-NNN` the sidecar doesn't
know), but the next absorb treats the corresponding sticky as a
candidate, proposes the same id (or next available), and converges.

## 5. Test harness expectations

Accept-mode tests live in `product/_test/story-map/phase-5-accept/`
(continuing the numbering — phases 1–4 are propose-only cohorts). The
cohort:

1. Uses **one** throwaway Miro board, built fresh from the canonical repo
   state via the normal create flow (`board_create` for an empty board, then
   `layout_create` to render the map into it), recorded in `board_id.txt`.
   Tests run as per-test edits on that board, mirroring phase-1's per-test
   protocol — accept mode mutates one story file per test, so batching would
   entangle the expected-after states.
2. Points the skill at a `working-repo/` copy of the iteration
   directory, made at phase setup. Tests write there, **never** the real
   `product/iterations/{iteration-slug}/`. The `working-repo/` and its
   sidecar mutate forward across the cohort — later tests start from the
   state earlier tests left behind.
3. Records `expected-after.md` per test — the MD file + sidecar diff
   accept *should* produce.
4. Runs the skill in accept mode against a scripted PM-answer transcript
   (`answers.md`) for any flag prompts.
5. Compares the on-disk `working-repo/` MD files and sidecar after
   accept against `expected-after.md`, writes `verdict.md`.

**Repo-root override.** Tests must not write to
`product/iterations/{iteration-slug}/`. The skill accepts a
`--repo-root <path>` argument that redirects all MD reads and writes
(stories, `stories-index.md`, `story-maps/activities/`, the iteration
README, and the sidecar) to the given path. Production callers do not pass this flag; it exists for
test isolation only.

## 6. Thin-slice scope for first bring-up

Initial accept-mode validation covers these diff entry types, in order.
Each maps directly to a proposal type phases 1–4 already proved in
propose-only mode:

1. **CONTENT_UPDATE (no flag)** — Task D. Update the sidecar
   `sticky_short_title` only; the story file is not touched (§3.2). The
   §3.6 pass is a no-op here — the PM already typed the new short title
   on the board and the sticky still carries its `STORY-NNN` label, so
   the board content is already canonical. (Proved propose-side by
   phase-1 test 1.1, phase-4 test 4.1.)
2. **Structural Priority update (no flag)** — a swim-lane move into NEXT
   or LATER, where the reverse mapping is unambiguous. Update the
   `**Priority**` line + sidecar `swim_lane` / `priority`. (Proved
   propose-side by phase-1 test 1.2, phase-4 tests 4.1 / 4.2 / 4.3.)
3. **Structural Type update (no flag)** — a recolor. Update / insert the
   `**Type**` line + sidecar `fill_color`. (Proved propose-side by
   phase-1 test 1.4, phase-4 test 4.2.)
4. **NEW_STORY (Priority flag)** — Task A. Flag-walk the NOW-ambiguity
   Priority (PM confirms High or raises to Critical), re-derive the
   `STORY-NNN`, write the story file, rewrite the board sticky to
   canonical form, add the sidecar entry, append to `stories-index.md`.
   (Proved propose-side by phase-2 test 2.1, phase-4 tests 4.1 / 4.3.)
5. **Missing item (warning, no write)** — confirm the no-cascade
   guarantee holds in accept mode: a `missing` story produces a warning
   and zero repo / sidecar / board writes. (Proved propose-side by
   phase-3 tests 3.1 / 3.2 / 3.3, phase-4 test 4.1.)

Deferred to a later cohort, each with a richer prompt or a multi-file
write:
- **RESCOPE** (Task B, cross-column move) — needs the PM-supplied Labels
  value and a `## Sync History` note; the Labels rewrite is not
  mechanically computable (`interpret-changes.md` Task B).
- **BACKBONE_EXTENSION** (Task C, cluster) — writes multiple story
  files *and* a new `story-maps/activities/activity-{NN}-{slug}.md`
  *and* a sidecar `activity_header` entry (with its `activity_ref`) in
  one accept.
- **`moved_and_changed` compound accept** — applying a Priority, a Type,
  and a CONTENT_UPDATE proposal to one story file in a single accept
  (phase-4 test 4.2's propose-side output).
- **`ASSUMPTION_CAPTURED` sidecar write** — recording an assumption
  under `items.assumptions` (§3.4).
- **`## Removed` gray-out** — the explicit-approval deprecation path
  (§3.3 deferred note).

**Every thin-slice test also verifies the §3.6 board label-normalization
pass.** The pass is content-only — it writes the canonical `STORY-NNN`
label onto a sticky that lacks it and touches nothing else. So each
test's `expected-after.md` records two things about the board: (a) the
sticky positions, fills, and sizes are **byte-identical to the PM's
edit** — accept moved nothing; (b) for test 4 (new story) only, the
orphan sticky's content is rewritten to canonical
`<p>{emoji} STORY-NNN</p><p>{short title}</p>`. Tests 1–3 and 5 expect
**zero** board writes (their stickies already carry canonical labels).
`verdict.md` compares a post-accept `layout_read` against this.

These are designed after the thin slice proves the I/O pattern: that
accept mode reads `working-repo/`, applies the four write-producing
proposal types, leaves `missing` inert, finalizes the sidecar
atomically, and writes the new story's identity label to the board
without disturbing the PM's arrangement.
