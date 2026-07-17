# Accept-mode runbook — applying an absorb diff to repo + board

This is the canonical spec for `opportunity-tree` **accept mode**. Propose-only (`interpret-changes.md` §5) reads the board and emits a diff. Accept mode walks any flags with the PM (§6), applies mechanical fixes to the board, then writes the resolved diff into repo files and the sidecar.

Accept always runs inside the same invocation as propose-only. There is no standalone accept-from-prior-diff entrypoint; the diff lives in conversation context (and optionally `actual-diff.md` for audit), not as a load-bearing artifact.

For the underlying detection rules and diff format, see `interpret-changes.md` §1–§4. For Miro layout, see `create-ost.md`. This file covers only the propose→accept transition.

---

## 1. Procedural shape

One skill invocation, three phases:

```
read board → propose-only diff → flag-walk loop → PM "accept" → repo + sidecar writes
                                       ↑                              ↑
                                board mutations only            file writes here
```

- **Phase 1 — propose-only.** Read shapes + connectors, compute the diff per `interpret-changes.md` §1–§4, write `actual-diff.md`. No mutations of any kind.
- **Phase 2 — flag-walk loop.** For each entry in `## Flags`, ask the PM the prompt in §6's resolution table, apply the chosen mechanical fix to the board via `miro_*` calls, re-read just the affected shape(s) to confirm. Loop until the flag set is empty or the PM defers a flag with "leave it for now."
- **Phase 3 — write.** Once flags are clear (or explicitly deferred), confirm with the PM ("apply the rest of the diff to repo files?"), then write MD files, update the sidecar, and archive any real deletions.

The PM may abort between any phase. Phase 1 produced no side effects; phase 2's board edits are committed already (and visible on the board); phase 3 writes are not transactional across nodes (see §4 abort and partial-state rules).

## 2. Phase 2 — flag-walk loop

Walk flags in the order they appear in `actual-diff.md`. For each:

1. Read the flag's one-line reason and surface to the PM with the relevant prompt from `interpret-changes.md` §6's resolution table.
2. On the PM's answer, call the corresponding board-write operation from `interpret-changes.md` §6 — all via `mcp__miro-official__layout_update`: shape content/fill/position by editing the item's DSL line, connectors by adding, editing, or removing the `CONNECTOR` line. For multi-step fixes (remove + add connector pair), apply both before re-reading.
3. **Scoped re-read.** Call `mcp__miro-official__layout_read` and filter the result to the affected shape ids to confirm the canonical state. `layout_read` always returns the full board (per `interpret-changes.md` §2.4), so "scoped" here means filtering the response, not narrowing the request; the loop only needs to inspect the shapes it just touched.
4. **In-memory self-edit set.** Track the set of `miro_id`s the skill mutated this invocation. The scoped re-read's "modified" signal is expected for these ids; do not re-flag. This is a pure in-memory concern — `last_synced` plays no role inside the loop.
5. If the re-read produces a *new* flag (rare — usually a typo in the fix), surface that and continue the loop.
6. Mark the flag resolved. Move to the next.

**Stale-prefix → new-node hand-off.** When a stale-prefix flag's fix strips the prefix from a new shape, the node remains in `## Structural — New nodes` and is processed by §3.2 in phase 3. The board fix in phase 2 only rewrites the shape content; the node's classification doesn't change.

*Known wastefulness.* Phase 2's strip-and-assign writes a next-available ref_id to the board at fix time, but §3.2 re-derives ref_ids fresh against the live sidecar in `temp_id` order. If a sibling new-node with a lower `temp_id` claims the value phase 2 picked, phase 3 will overwrite the board content a second time. Final state is consistent; the extra write is harmless but visible. Two refinements are tracked but out of thin-slice scope: (a) phase 2 writes a temporary marker (`NEW-{n}`) and phase 3 assigns the real ref_id; (b) phase 2 coordinates with phase-3 `temp_id` ordering so the value it writes is the one phase 3 will honor.

If the PM says "leave it for now" for a flag, record it as **deferred** in the diff. Deferred flags do not block phase 3 — the relevant node simply doesn't get its sidecar/MD entry updated this round, and the same flag will resurface on the next absorb.

**No phase-3 writes happen during the loop**, even for fully-resolved flags. The loop only edits the board.

## 3. Phase 3 — repo and sidecar writes

After the loop, confirm with the PM, then walk the diff sections. Ordering within phase 3 is **Content → Structural → Detachments → sidecar finalize**. A node that appears in both Content and Structural (re-parented + title edited) is touched twice on different fields, so order doesn't affect correctness. Detachments are last because they're cheap sidecar-only flips. Sidecar finalize runs once at the end; only the on-disk sidecar write is atomic.

**No phase-3 connector writes.** For new nodes, the connector to the parent already exists on the board — that's how parenthood was inferred during propose-only. Phase 3 mutates shapes (for new-node prefix rewrites) and repo files; it never creates or deletes connectors.

### 3.1 `## Content` — title edits on existing nodes

For each entry `{ref_id}: title "..." → "..."`:

- Read the existing MD file at `product/context/opportunity-solution-tree/{type}s/{type}-{NN}-{slug}.md`.
- Update the `# Type: {title}` H1.
- Save under the **existing filename** — do not rename even if the new title would produce a different slug. Rationale: repo-internal hyperlinks (other context docs, prototype specs, ticket descriptions, archive cross-references) cite by path. Ref_id is the stable identity; slug drift in the filename is acceptable and expected over a node's lifetime.

### 3.2 `## Structural` — re-parents, new nodes, deletions, reattachments

**Re-parented `{ref_id}: {old} → {new}`:**
- Pick the right parent field based on the new parent's type: `**Parent Outcome**` for an outcome parent, `**Parent Opportunity**` for an opportunity parent, `**Parent Solution**` for a solution parent. Only one is set at a time per `SKILL.md` §"File formats."
- Update the sidecar entry's `parent_ref` to `{new}`.
- For opportunity re-parents that cross tiers, recompute `opportunity_depth` for the moved node and propagate to descendants per `interpret-changes.md` §2.8. Bump or decrement `max_opportunity_depth` if appropriate.

**Reattached `{ref_id}`:**
- Remove `attached` and `detached_on` from the sidecar entry.
- Pick the right parent field based on the new parent's type (same rule as Re-parented above). Set `parent_ref` to the new connector-derived parent.
- No MD content changes — the file body was preserved through detachment.
- If the reattached node is an opportunity whose new parent's depth differs from its pre-detachment parent's depth, recompute `opportunity_depth` and propagate to descendants per §2.8, same as Re-parented.

**New nodes `{temp_id} | type={type} | parent={parent_ref} | title="..." | proposed_ref={NN}`:**
- **Re-derive ref_id at write time.** Scan the live sidecar for the highest existing `{TYPE}-NN`, increment. Do not trust `proposed_ref` from the diff text — it was advisory. Apply in stable order (sorted by `temp_id` if multiple new nodes of the same type).
- Slugify the title into a filename: lowercase, hyphenated, ASCII-only, truncate to ~40 chars at a word boundary.
- Write `{type}-{NN}-{slug}.md` using the template in `SKILL.md` §"File formats". Pick the right parent field based on parent type (same rule as Re-parented). Fill in ref_id, parent, title; leave evidence/persona/status as TODO placeholders for the PM to fill in.
- Add a sidecar entry: `{ref_id, type, miro_id, parent_ref, x, y}` where `x` and `y` come from the **latest board read Claude holds at sidecar finalize**. If phase 2 wrote to this shape (e.g., a column-mismatch fix moved it from x=1366 to x=960), that's the scoped re-read after the last flag-walk write. If phase 2 did not touch this shape, no re-read happened and the phase-1 board read is itself the latest state — use those coordinates directly. The sidecar must record where the shape sits **now**, never a stale pre-fix coordinate. `attached: true` is implicit by omission. For opportunities, also `opportunity_depth`.
- **Rewrite the board shape** via `mcp__miro-official__layout_update` to set content to canonical `<strong>{ref_id}</strong><br />{title}`. This is the one phase-3 board write — required because the PM may have typed the title with no prefix, and the canonical form must be on the board for future absorb runs to identify the node. Add this shape's miro_id to the in-memory self-edit set so the post-write re-read (if any) doesn't re-flag.
- For new opportunities whose depth exceeds the sidecar's `max_opportunity_depth`, bump `max_opportunity_depth`. Next refresh will re-flow the solution column.

**Deleted nodes `{ref_id} (was under {parent_ref}; descendants in sidecar: [...])`:**
- Move the MD file to `product/context/opportunity-solution-tree/_archive/{ref_id}-{slug}.md`.
- **Add** YAML frontmatter at the top of the archived file: `deleted_on: {YYYY-MM-DD}` and `deleted_from_board: {board_id}`. Note: live MD files don't have frontmatter (per `SKILL.md` §"File formats"); this block is introduced *on archive* and exists only in `_archive/`.
- Drop the sidecar entry.
- Do NOT recursively archive descendants whose shapes are also gone — each deleted node is its own diff entry per §2.4a cascade rule. Walk them in order.
- Descendants whose shapes remain on the board are handled by §3.3 below (Detachments).

### 3.3 `## Detachments` — sidecar flip only

For each `Detached: {ref_id}`:
- Set `attached: false` and `detached_on: {today}` on the sidecar entry.
- **Do not** archive the file. **Do not** drop the sidecar entry. **Do not** mutate the board.

### 3.4 Sidecar finalization

- `last_synced`: set to **`now()` at end of phase 3**, after all repo writes succeed. Rationale: future `--diff-against` runs against the *new* `last_synced` skip any phase-2 board mutations the skill itself made (those mutations' `modified_at` is ≤ `now()`), so subsequent absorbs aren't perpetually re-reading skill-touched shapes. The in-loop self-edit set in §2 handles within-invocation re-reads; `last_synced` handles between-invocation reads. They are separate concerns.
- Write the sidecar back to `product/context/opportunity-solution-tree/miro-metadata.json` atomically: write to a sibling `.tmp` file, then `rename`. This single write is the only atomic boundary in phase 3.

## 3a. Underspecified-state rule — ask, don't invent

If the skill encounters a state during phase 1, 2, or 3 that **no rule in this file or `interpret-changes.md` covers**, the skill must stop and ask the PM how to proceed. Examples of states this applies to:

- An MD file exists on disk for a ref_id that has no sidecar entry (drift between repo and sidecar).
- A connector references a `from_id` or `to_id` that doesn't exist in the current shape read (corrupted graph).
- Two sidecar entries share a `miro_id` (data corruption).
- A node's `parent_ref` points to a ref_id that's neither in the sidecar nor in the archived deletions.

The skill **never** silently picks a default in these cases. The cost of a wrong silent choice (writing an MD file that overwrites prior work; assigning a ref_id that's already in use on disk; etc.) is high enough that interrupting the PM is always cheaper. Frame the prompt as a flag in `## Flags (need human review)` so the PM sees it alongside any other flagged ambiguities.

Distinction from §4 documented flags: documented flags are *predictable* ambiguities the spec already anticipated. This rule covers *unanticipated* states — bugs, drift, or scenarios the spec hasn't yet handled. Both surface through the same flag mechanism; the difference is whether the resolution table has a row for them. Unanticipated flags should be recorded post-test as either new documented flags or new rules.

## 4. Error handling and abort semantics

**Mid-loop PM abort (phase 2):** board mutations applied so far are committed and visible on the board. No repo writes occurred. Surface to PM: "Board partially updated. Re-running absorb will re-read current board state and produce a fresh diff." Self-healing — the next absorb run picks up the new state.

**Mid-phase-3 abort or process failure:** writes are not transactional across nodes. Some MD files may be written, some not; the sidecar is only written at the very end (§3.4 atomic rename). On abort:
- Sidecar still reflects pre-run state (it wasn't written yet) — safe.
- MD files may have partial updates (some titles edited, some new files written, some not).
- Next absorb re-detects the actual board state vs the still-old sidecar and surfaces the remaining work. The previously-written MD files will be in sync with the board for the nodes that did get processed; the unwritten ones will reappear in the next diff.

**MD file already exists at new-node write path** (slug collision): append `-2`, `-3`, etc. to the slug until unique. Sidecar `slug` field is the citation key; the filename is incidental.

**Board-write failure during phase 2 or phase 3** (`layout_update` non-2xx / MCP error): surface to PM, skip the affected node's phase-3 entry, leave it as a flag for the next run. Don't write a sidecar entry whose board state isn't canonical.

**Sidecar write fails** (disk error, race): MD files from phase 3 are already on disk. Surface clearly: "Repo updated, sidecar write failed. Re-run accept after resolving {error}." The next absorb run will diff the board against the *old* sidecar — phase 3's MD writes will appear briefly out of sync (e.g., a new MD file with a ref_id the sidecar doesn't know about), but the next absorb will treat the corresponding shape as a new-node candidate, propose the same ref_id (or next available), and converge.

## 5. Test harness expectations

Accept-mode tests live in `product/_test/ost-absorb/phase-5-accept/` (continuing the existing numbering — phase-1..4 are propose-only cohorts). Each test:

1. Sets up its own throwaway Miro board, built fresh from the canonical repo state via the normal create flow (`board_create` for an empty board, then `layout_create` to render the tree into it). Tests do not chain off prior propose-only test boards — schema and state assumptions are too entangled (phase-1..3 working sidecars predate the multi-tier schema; reuse would require migration).
2. Records `expected-after.md` — the MD files + sidecar diff that accept *should* produce.
3. Runs the skill in accept mode against a scripted PM-answer transcript for any flag prompts.
4. Compares the on-disk MD files and sidecar after accept against `expected-after.md`.

The harness drives "accept" via scripted inputs because the conversational flow doesn't expose a non-interactive accept entrypoint. The scripted-answers file lives next to `target.md` as `answers.md`.

**Repo-root override.** Tests must not write to `product/context/opportunity-solution-tree/`. The skill accepts a `--repo-root <path>` argument that redirects all MD reads and writes (including `_archive/` and the sidecar) to the given path. Production callers do not pass this flag; it exists for test isolation only.

## 6. Thin-slice scope for first bring-up

Initial accept-mode validation covers these diff entry types, in order:

1. **Content edit (no flag)** — write MD title change, finalize sidecar.
2. **Real deletion (no flag)** — archive MD + drop sidecar entry.
3. **New node, prefix-typed (no flag)** — re-derive ref_id, rewrite shape content, write MD, add sidecar entry.
4. **Detachment (no flag)** — sidecar flip only.
5. **Stale-prefix flag** — most common copy-paste leftover; PM confirms "strip and assign next ref_id," skill rewrites shape content, then proceeds as new-node.

Deferred to a later cohort: type-ambiguous, solution-on-non-leaf, multiple-parent, ref-collision, possible-duplicate, identity-break, content-malformed, skip-level, column-mismatch. These have richer prompts and are designed after the thin slice proves the I/O pattern.
