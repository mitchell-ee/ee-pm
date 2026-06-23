# Adding a board type

This workflow already ships three Miro "board types" — `opportunity-tree`, `assumption-map`, and `story-map` — that all follow one round-trip pattern:

**build → collaborate → read-back → interpret**

A PM and the LLM build a visual artifact on Miro from plain-text repo state, humans rearrange it directly on the board, the skill reads the changes back as a structural diff against a saved sidecar, and then interprets what the changes *mean* and proposes repo updates the PM approves.

Adding a fourth board type means writing **one new skill directory** and updating a handful of **registration points** that enumerate the board types. No new infrastructure is required — the worker agents, the Miro MCP layer, and the connector REST scripts are generic and already handle any board type.

This guide assumes your artifact maps onto the same round-trip. If it doesn't (e.g. it's write-only, or it lives on a non-Miro surface), it's not a "board type" in this sense — look at the `claude-design` / `magic-patterns` prototyping skills instead.

---

## 1. The two design decisions to make first

Everything else is mechanical once these are settled.

### a. Storage scope and cardinality

Where does the artifact's repo-side state live, and how many of these boards exist? The three existing types each chose differently:

| Board type | Scope | Sidecar path |
|---|---|---|
| `opportunity-tree` | singleton, product-level | `product/context/opportunity-solution-tree/miro-metadata.json` |
| `assumption-map` | one per solution | `product/context/assumption-maps/SOL-{NN}-{slug}/miro-metadata.json` |
| `story-map` | one per iteration | `product/iterations/{iteration-slug}/story-maps/miro-metadata.json` |

Pick the scope that matches the artifact's lifecycle. Product-level artifacts go under `product/context/<your-type>/`; per-iteration artifacts go under `product/iterations/{slug}/<your-type>/`. The choice dictates the sidecar path and how the router resolves "which board" before spawning a worker.

### b. Identity inference for absorb

This is the genuinely hard part. When a human rearranges the board and you read it back, you have to distinguish an **intentional edit** from a **render artifact**, and infer structure (parentage, grouping, quadrant) that Miro's API doesn't hand you directly.

Two lessons from the existing skills, both load-bearing:

- **Infer structure from position, not from the connector API.** Miro's connector `from_id`/`to_id` reflects which end the human dragged from, *not* tree direction. `opportunity-tree` infers parentage from each node's **x-column position** instead. Whatever your topology, decide what observable board property is the source of truth for structure.
- **The sidecar is what makes the diff possible.** Without a baseline of each item's rendered state (position, color, content, role), absorb can't tell a moved sticky from a sticky that was always there. Decide exactly what per-item state your sidecar records (see §4).

Write these two decisions down in your `SKILL.md` before you write the layout math — they shape everything downstream.

---

## 2. Create the skill directory

A board type *is* a capability skill. Mirror the existing three:

```
skills/<board-type>/
├── SKILL.md                      # the spec (see §3)
├── reference/
│   ├── create-<board>.md         # BUILD — deterministic layout algorithm
│   ├── read-board-state.md       # READ-BACK + structural diff (the "what changed" pass)
│   ├── interpret-changes.md      # INTERPRET — what the diff means; propose repo edits
│   └── accept-mode.md            # PM-approval write-back loop (if absorb writes to the repo/board)
└── templates/                    # only if the board spawns per-item MD files
    └── <item>.md                 #   (e.g. story-map ships templates/story.md)
```

The four reference files map onto the four pieces of the round-trip. What varies per board type is only the topology, the layout math, and the per-item state — the loop itself is the invariant.

Reuse, don't reinvent: copy the closest existing skill (`opportunity-tree` if your board uses connectors; `story-map` or `assumption-map` if it doesn't) and adapt it. The existing reference docs already encode the hard-won Miro DSL gotchas.

### Which reference files you actually need

- **`create-<board>.md`** — always. This is where the real work is (see §5).
- **`read-board-state.md`** — always, for absorb. `opportunity-tree` folds its read pass into `interpret-changes.md`; the others keep it separate. Separate is clearer.
- **`interpret-changes.md`** — always, for absorb's semantic pass.
- **`accept-mode.md`** — only if absorb writes changes back (board updates + repo MD writes). If your board is read-only after creation, skip it.
- **`templates/`** — only if the board materializes per-item markdown files in the repo (stories, etc.).

---

## 3. Write SKILL.md

Match the skeleton the existing board skills share. Sections, in order:

1. **Frontmatter** — `name`, `description` (intent-based; the description is how the skill gets matched, so write it for the trigger phrases a PM would use).
2. **Preamble** — one sentence: the round-trip between repo and Miro for this artifact.
3. **Topology diagram** — what the artifact looks like (tree / 2×2 grid / activity×release grid / yours).
4. **Modes** — name each: typically `create`, `refresh`, `absorb`, plus any board-specific mode. One line each.
5. **Required tools** — the Miro MCP calls (`layout_create` / `layout_read` / `layout_update` / `context_get`), the connector scripts if used (`${CLAUDE_PLUGIN_ROOT}/scripts/...`), and the `product/` paths it reads/writes.
6. **When to use** — bulleted intent triggers.
7. **Repo conventions** — the directory layout and the markdown file format(s) the board is built *from*, with example frontmatter.
8. **Board naming and location** — naming convention, cardinality, folder placement, and the rule that every board URL goes in chat (not just name/ID).
9. **Miro layout** — coordinate system, shapes, colors, text format, connectors (if any). Reference the canonical write forms.
10. **Modes (detailed)** — step-by-step per mode: create (read repo → build → save sidecar → emit URL), refresh (diff repo vs sidecar → update changed items), absorb (structural diff + semantic interpretation → propose, never delete without approval).
11. **Sidecar format** — the JSON schema (see §4).
12. **Related skills** — cross-references up/downstream.

---

## 4. Define the sidecar

`miro-metadata.json` is the anchor of the round-trip. It records, at minimum:

- **Board identity:** `board_id`, `board_url`, `board_name`, `last_synced_at`.
- **Layout constants:** any pitch/column/spacing defaults the layout math uses (so refresh reproduces the same coordinates).
- **Per-item records**, keyed by Miro item ID, each carrying:
  - `ref_id` — links the board item back to its repo markdown file (e.g. `OPP-01`, `STORY-003`).
  - role classification — tells absorb what kind of change to expect for this item.
  - rendered baseline — position, color, content, and any board-specific state your diff compares against (`current_quadrant` for assumption-map, etc.).
- **Board chrome:** IDs of titles, axes, legends, horizons — marked as chrome so absorb doesn't flag them as data changes.

One sidecar per artifact, never nested. If your board references another (e.g. a cross-board connector to the OST), record the other board by ID — don't share a sidecar.

---

## 5. The hard part: create-<board>.md determinism

The build algorithm must produce a board that `layout_read` can re-parse and match **exactly** against the sidecar on the next refresh. If the round-trip isn't deterministic, every refresh looks like a change and absorb floods the PM with false diffs.

This is where the genuine effort goes. Budget accordingly — the registration edits in §6 are trivial by comparison. Things that bite (all documented in the existing skills' reference files):

- Miro's layout DSL has **no connector type** — connectors go through the REST scripts, not `layout_create`.
- The DSL re-serializes the whole board on each `layout_update`; certain content (literal `\n` in stickies) can trip the parser — use `<br />` line breaks.
- Read-back applies defaults and wraps content in `<p>` — your diff has to normalize for that, not flag it.

Steal the canonical write forms from `skills/opportunity-tree/reference/create-ost.md` (connector-using) or `skills/story-map/reference/create-story-map.md` (no connectors).

---

## 6. Register the new board type

The worker agents and index enumerate the board types explicitly. A new skill is invisible to them until you update these. Current enum string in all three agents: `opportunity-tree | story-map | assumption-map`.

**Must update:**

1. **`agents/board-builder.md`** — the `artifact:` enum line, the frontmatter `description` board-skill list, and the "Picked the skill (`opportunity-tree`, `story-map`, etc.)" line.
2. **`agents/absorb-interpreter.md`** — the `artifact:` enum line, the description list, and the "Loads the named skill's absorb-mode reference" line (name which reference file your skill uses).
3. **`agents/board-writer.md`** — the `artifact:` enum line, the description list, and the "Loads the named skill's accept-mode reference" line (only if you wrote an `accept-mode.md`).
4. **`skills/README.md`** — add a row to the capability-skills table (§ around line 22), add the skill to the relevant router's row in the phase table (§ around line 10), and update **"The Miro three-piece pattern"** heading + text to four.
5. **A router skill** — wire the new board into the phase that owns it: `skills/discovery/SKILL.md` (OST, assumption-map), `skills/story-shaping/SKILL.md` (story-map), or `skills/workshop-facilitator/SKILL.md` (any). Routers route by *intent*, so this is adding a trigger and the worker-spawn wiring, not editing a hardcoded list.

**Optional (prose, not load-bearing):**

- Root `README.md` — the "three Miro artifacts" line.
- `skills/setup/templates/claude-md-block.md` — only if the new board is a product-level artifact worth naming in the conventions block that `/vcw:setup` writes into a user's `CLAUDE.md`. The template names the routers and the storage convention but does **not** enumerate board types, so adding a type does not require users to re-run `/vcw:setup`.

---

## 7. Validate

- `claude plugin validate .` — confirms the new SKILL.md frontmatter parses.
- Manually run the round-trip on a real board: **create** → make a hand edit on Miro → **absorb** → confirm the structural diff matches your edit and the interpretation is sane → **accept** (if applicable) → **refresh** and confirm it reports no spurious changes (the determinism check from §5).
- Grep for any remaining `three` / "three board" references you missed.

---

## Checklist

- [ ] Decided storage scope + cardinality (§1a)
- [ ] Decided identity-inference rule for absorb (§1b)
- [ ] Created `skills/<board-type>/SKILL.md` (§3)
- [ ] Created `reference/create-<board>.md` (§5)
- [ ] Created `reference/read-board-state.md` + `interpret-changes.md`
- [ ] Created `reference/accept-mode.md` (if absorb writes back)
- [ ] Defined the sidecar schema (§4)
- [ ] Updated `agents/board-builder.md`, `agents/absorb-interpreter.md`, `agents/board-writer.md` enums + descriptions (§6)
- [ ] Updated `skills/README.md` table + pattern section (§6)
- [ ] Wired into a router skill (§6)
- [ ] Ran `claude plugin validate .` and a full live round-trip (§7)
