---
name: opportunity-tree
description: Create, refresh, or absorb a Teresa Torres Opportunity Solution Tree (OST) on Miro. Use when a PM asks to visualize outcomes, opportunities, solutions, and assumption tests from Continuous Discovery Habits.
tags: [product-management, visualization, miro, discovery, torres]
---

# Opportunity Tree Skill

Round-trip workflow between a **product-level** repo-resident OST and a Miro board. The OST is not iteration-bound — it's the product's persistent map of outcomes, opportunities, candidate solutions, and assumption tests, seeded with strategic/known problems and enriched over time as evidence arrives from strategic discovery and per-iteration discovery.

Structure (left-to-right). Opportunities nest — a single outcome can decompose through multiple tiers of opportunities before a solution attaches:

```
                       ┌── Opportunity ── Opportunity ── Solution ── Assumption Test
                       │                └─ Opportunity ── Solution
              Outcome ─┤
                       └── Opportunity ── Solution
  Root ─┐
        ├── Outcome ── Opportunity ── Solution
        │
        └── Outcome ── ...
```

Six modes: **seed**, **create**, **refresh**, **absorb**, **analyze**, **promote-from-inbox** (`seed` authors the source MD files for a cold-start tree from scratch; `create` renders existing files to a board; `absorb` is the structural round-trip from Miro; `promote-from-inbox` is the file-side flow that moves candidates staged by iteration synthesis into the canonical tree).

## Required tools

- Official Miro MCP at `mcp.miro.com`: `mcp__miro-official__layout_create` (build the board + nodes), `mcp__miro-official__layout_read` (round-trip read for absorb), `mcp__miro-official__layout_update` (refresh-mode node moves / content / fill), `mcp__miro-official__context_get` (board metadata).
- `${CLAUDE_PLUGIN_ROOT}/scripts/write-connectors.sh` (create / update / delete) and `${CLAUDE_PLUGIN_ROOT}/scripts/read-connectors.sh` for tree edges — the layout DSL has **no connector type**, so connectors go through these thin REST helpers. Auth via the `MIRO_ACCESS_TOKEN` environment variable (see `docs/miro-setup.md`).
- Filesystem access to `product/context/opportunity-solution-tree/` and its sidecar `miro-metadata.json`.

**Execution context:** this skill runs *inside* a board worker agent (`board-builder` for create / refresh, `absorb-interpreter` + `board-writer` for absorb), which is where the official Miro MCP is registered. The main thread never calls `mcp__miro-official__*` directly — the router (`discovery`) spawns the worker, the worker loads this skill. The `seed`, `analyze`, and `promote-from-inbox` modes are file-side only (no board mutation) and run without a board worker — `seed` fans out `opportunity-writer` workers; the others run in the main thread. See the canonical write forms in `reference/create-ost.md` and `reference/interpret-changes.md` so create output is diff-stable against `layout_read`.

## When to use this skill

Invoke when the user asks to:

- **Build** the product's OST from outcomes and a starting set of known opportunities.
- **Refresh** the board after opportunities, solutions, or tests changed in the repo (including after iteration synthesis contributed to the tree).
- **Absorb** a workshop-modified OST board back into repo files — new opportunities discovered, solutions repositioned under different opportunities, assumption tests added.
- **Analyze** the current tree and recommend which opportunity to pursue next (selection mode; powers the iteration-entry moment).
- **Promote from inbox** — interactively move candidate opportunities staged by `discovery-synthesis` (in `inbox/`) into the canonical tree under an outcome.

## Repo conventions

OST data lives at **product-level**, under `product/context/opportunity-solution-tree/`:

```
product/context/opportunity-solution-tree/
  README.md                   # orientation — what this tree is, how it grows
  outcomes/
    outcome-{NN}-{slug}.md
  opportunities/
    opportunity-{NN}-{slug}.md
  solutions/
    solution-{NN}-{slug}.md
  assumptions/
    assumption-{NNN}-{slug}.md
  inbox/                      # staging for per-iteration synthesis output
    {iteration-slug}-candidates.md
  miro-metadata.json          # sidecar, same pattern as story-map
```

The tree is **not** per-iteration. Iteration discovery contributes evidence and candidates (written to `inbox/`) and the `promote-from-inbox` mode absorbs them into the canonical tree.

### File formats

**outcome-{NN}-{slug}.md**
```
# Outcome: {title}

**ID**: OUTCOME-{NN}
**Metric**: {specific metric being moved}
**Target**: {delta}
**Timeframe**: {by when}

## Framing
{short paragraph describing why this outcome was chosen and which side of the
product/platform it serves}
```

**opportunity-{NN}-{slug}.md**
```
# Opportunity: {title}

**ID**: OPP-{NN}
**Parent Outcome**: OUTCOME-{NN}        # for a depth-1 opportunity (direct child of an outcome)
**Parent Opportunity**: OPP-{NN}        # for a deeper opportunity (child of another opportunity). Exactly one of Parent Outcome or Parent Opportunity is set.
**Evidence Strength**: Strong | Moderate | Weak
**Persona**: {persona}
**Status**: Open | Exploring | Descoped

## Description
{2–4 sentences describing the customer need, pain, or desire}

## Supporting Evidence
- {quote from interview, research, signal, or usage data; link to source}
- {quote}

## Iterations that enriched this
- {iteration-slug}: {one-line note}
```

**solution-{NN}-{slug}.md**
```
# Solution: {title}

**ID**: SOL-{NN}
**Parent Opportunity**: OPP-{NN}
**Status**: Proposed | Testing | Committed | Shipped | Rejected
**Shaped by iteration**: {iteration-slug}   # set when the solution was promoted from a synthesis

## Description
{1–3 sentences}

## Tests
- ASSUMPTION-{NNN}: {one-line description}   # populated after the Status: Committed flip materializes assumption files
```

**Status lifecycle and the commitment trigger.** A solution lands on the OST at `Status: Proposed` (created when the PM promotes a candidate from synthesis or branches via OST absorb). Flipping to `Status: Committed` is the team's commitment to pursue. **That flip is also the materialization trigger for assumption files**: read the inline assumptions for this solution in `{shaped-by-iteration}/synthesis.md` (`### SOL-candidate-*` block) and write each one as `product/context/opportunity-solution-tree/assumptions/assumption-{NNN}-{slug}.md`, then list them under `## Tests` here. After materialization, the next `/assumption-map create from SOL-{NN}` renders the 2×2 cleanly. Other transitions (`Testing` → `Shipped` / `Rejected`) do not materialize new files; see `assumption-map` SKILL for downstream behavior.

**assumption-{NNN}-{slug}.md** (in `assumptions/`)
```
# Assumption Test: {title}

**ID**: ASSUMPTION-{NNN}
**Parent Solution**: SOL-{NN}
**Hypothesis**: {"If we X, then Y" statement}
**Method**: {how the test is run}
**Success Criterion**: {what would make you believe the hypothesis}
**Result**: Pending | Confirmed | Rejected | Inconclusive
```

**inbox/{iteration-slug}-candidates.md** (written by `discovery-synthesis`)
```
# Candidate opportunities surfaced by {iteration-slug}

Each entry below is an adjacent opportunity that emerged from interviews but
did not belong to the iteration's chosen opportunity. Promote into the tree
via `opportunity-tree promote-from-inbox`.

## Candidate 1 — {proposed title}
**Suggested parent outcome:** OUTCOME-{NN}
**Persona:** {persona}
**Evidence strength:** Strong | Moderate | Weak
**Evidence:**
- {quote, source}
- {quote, source}
**Notes:** {why this doesn't belong to the chosen opportunity}

## Candidate 2 — ...
```

## Board naming and location

Every project gets exactly one OST board — the OST is product-level, not iteration-bound.

**Board name:** `{project} — Product OST`

`{project}` is derived from `basename "$(git rev-parse --show-toplevel)"`. Override by placing a single-line file at `.claude/project-name.txt` in the host repo if a different display name is wanted.

**Cardinality:** singleton. Refresh in place; never duplicate. The board ID is recorded in the sidecar `miro-metadata.json` at `product/context/opportunity-solution-tree/`.

**Location:** if the host's Miro account uses team folders, place the board in the folder matching `{project}`. Otherwise leave at account root. The skill does not create folders — it expects the PM to set folder structure once per project.

**Referencing the board in chat:** whenever this skill — or any response Claude writes about the board — refers to it, include the full URL from `miro-metadata.json:board_url` (e.g., `https://miro.com/app/board/{board_id}=`). Don't reference a board by name or ID alone; the URL is what makes it one click from Claude Code to the live board. This rule applies anywhere a Miro board is mentioned, not just in OST contexts.

## Miro layout

> **Every render must follow `reference/create-ost.md` exactly.** That file is the canonical spec for orientation, columns, node content format, the per-column pitch rule, centering, and the sidecar contract. This section summarizes the rules; the reference is authoritative when in conflict.

An OST renders as a **left-to-right horizontal tree** in Miro. The board is not constrained to a viewport — PMs scroll around during discussion, so the layout expands vertically as needed rather than wrapping or shrinking. Horizontal node shapes (wider than tall) pack the title text on fewer lines and use the canvas more efficiently than a top-down tree.

**Node shape:** rounded-corner rectangles (Miro `shape: round_rectangle`), not sticky notes. Connectors are **curved** (`shape: curved`), not straight or elbowed.

**Node content format (mandatory):** every node carries a bold ref_id line above the title, using inline HTML in the shape's `content` field:

```
<strong>{REF-ID}</strong><br>{title}
```

For example: `<strong>OPP-01</strong><br>ETA trust — the promise time drifts`. This convention applies to every node type (root, outcome, opportunity, solution, assumption test) and every mode (create, refresh, absorb, promote-from-inbox). Miro's shape `content` field accepts inline HTML; `<strong>` and `<br>` are the only tags needed.

**Board title:** every board carries a bold `text` item — `<strong>{tree name} — Opportunity Solution Tree</strong>`, `font_size: 96` — at the root column (x=0), placed above the topmost node. It is board chrome: recorded in the sidecar as `items.title`, classified only `unchanged` / `missing` by absorb, never treated as a tree node. See `reference/create-ost.md` §2a.

**Levels (left → right):**

- **Root** — single project-level node (e.g., `PRODUCT-CRUMBS`) anchoring the tree at column 0. Larger (~360×160), peach fill (`#ffd6cc`) so it reads as a parent layer over the white background. Vertically centered on the leaf-range midpoint. Optional — skip when the tree has only one outcome.
- **Outcomes** — one column to the right of root (~320×140). Each outcome is vertically centered on the span of its child opportunities. Multiple outcomes stack vertically, separated by an outcome gutter so subtrees don't crowd.
- **Opportunities** — one or more nested tiers between outcome and solution (~260×110, blue `#cce5ff` at every tier). Tier 1 (direct child of an outcome) sits at the canonical opportunity column (x=960 with defaults: `outcome.x + outcome_to_opportunity_gap`, where the gap is 480 px). Each additional tier cascades right by `opportunity_pitch` (default 320 px) — depth-2 at x=1280, depth-3 at x=1600. Horizontal position is the only depth cue — color, shape, and size are uniform across tiers. Vertically positioned so each is centered on its own subtree.
- **Solutions** — next column (~220×90). Solutions attach **only to leaf opportunities** (an opportunity is a leaf when no other opportunity declares it as `Parent Opportunity`). All solutions in a tree align in a single column — the column position is derived from the deepest opportunity branch, not from each solution's own parent depth. Solutions sit at their own leaf-slot y (one solution per slot at the within-group pitch). The parent opportunity is centered on its solutions' y-range.
- **Assumption tests** — rightmost column (~200×80). Aligned vertically with their parent solution.

**Coordinate rule (see `reference/create-ost.md`):** the within/between rule applies **at every column** (opportunity, solution, assumption), not just at outcome boundaries:

- **Within-group pitch (same direct parent):** default **140 px** — about 30 px gap between adjacent opportunity nodes. Tight enough to stay compact, loose enough to read.
- **Cross-group pitch (different direct parent):** default **280 px** — exactly **2× the within-group pitch**. This is the cap, not a multiplier: enough to read group boundaries, not so much that the diagram sprawls. Same value at every column boundary, regardless of which level (cross-OPP at the SOL column = cross-OUTCOME at the OPP column).

**Centering and propagation:** each parent is positioned at the y-center of its children. When a parent's children are spread (e.g., a 2-solution opportunity), the parent occupies more vertical space than 140 px and the cross-pitch may be subtree-driven rather than rule-driven at higher columns — that's expected. Solve column-by-column from the rightmost leaves leftward, taking the maximum of (rule-required pitch) and (subtree-spread pitch) at each column.

Default x positions: root=0, outcome=480. Opportunity x is `480 + 480 + 320 × (opportunity_depth - 1)` — depth-1 at 960, depth-2 at 1280, depth-3 at 1600. Solution x is `480 + 480 + 320 × (max_opportunity_depth - 1) + 480`; assumption_test x is `solution.x + 480`. For a single-tier tree (every opportunity at depth 1): solution=1440, assumption_test=1920 (canonical columns preserved). The solution column shifts right as opportunity branches deepen — depth-2 → solution=1760. The board auto-expands vertically. No wrapping, no shrinking. Full algorithm and sidecar schema in `reference/create-ost.md`.

**Color convention (fill):** root peach (`#ffd6cc`), outcomes white, opportunities blue (`#cce5ff`), solutions yellow (`#fff3cd`), assumption tests light green (`#d4edda`), rejected/descoped gray. Text color kept default.

**Connectors:** curved, thin, no arrowheads (tree edges are structural, not directional). Created via `${CLAUDE_PLUGIN_ROOT}/scripts/write-connectors.sh` (the layout DSL has no connector type). The intent is parent-right → child-left. `write-connectors.sh` sets only the from/to item IDs, not snap endpoints, so Miro auto-routes each edge to the closest side of each shape — which reads correctly in a horizontal tree, because the closest sides are usually right-of-parent and left-of-child. One connector per parent-child edge, no skip-level edges.

## Modes

### 1. Seed mode

Authors the **source MD files** for a tree from scratch — the cold-start that every other mode presumes already exists. Seed produces files only; it never touches Miro. When the PM asks to "build the OST from scratch" or "create the initial opportunity tree," run seed first, then hand to create mode for the board.

Seed is Torres-canonical: a fresh tree is **outcomes + an initial opportunity set**. Solutions and assumption tests are *not* authored in seed — they arrive later through iteration discovery (`promote-from-inbox`, `assumption-map`). Seeding solutions up front pre-commits to answers before the discovery that should produce them.

Seed follows a **plan → fan-out → assemble** shape (the OST analogue of `story-shaping`'s seed). The plan phase is interactive and stays in the main thread; the expansion fans out:

1. **Plan (main thread, interactive).** Settle the tree shape *with the PM*: which outcomes (with metric + target), which opportunities under each, how they nest, persona and evidence strength per opportunity. Assign canonical `OUTCOME-{NN}` / `OPP-{NN}` ref_ids and slugs. This is the judgment; it is not delegated. Confirm the set before fan-out. Answer the three "Open questions for the PM before building" below as part of this phase.
2. **Fan-out (delegated, parallel).** For each settled node, the main thread spawns one `opportunity-writer` worker with the stub fully resolved in the prompt (see that agent's invocation contract). Workers run in parallel waves (~10 at a time), each writing one node file atomically and returning a one-line receipt. The node prose never returns to the main thread — only the receipts. The main thread never authors node bodies inline.
3. **Assemble (main thread).** Collect receipts, verify the file set is complete and parent refs resolve, then hand off to **create mode** (via `board-builder`) to render the board. Seed itself writes no sidecar — the sidecar is born when create renders the board.

If a worker returns `split_suspected` or `precondition-unresolved`, the main thread re-plans that one stub and re-spawns; the rest of the fan-out is unaffected.

### 2. Create mode

Read all outcome / opportunity / solution / test files — **they must already exist** (if starting from scratch, run seed mode first to author them). Build topology in memory. Create the Miro board; add outcomes, then opportunities with connectors, then solutions, then tests. Save the sidecar `miro-metadata.json` and emit the board URL in chat.

**Follow `reference/create-ost.md` for the full layout algorithm** — orientation, columns, node content format (mandatory bold ref_id), the per-column within/cross pitch rule, centering and propagation, sidecar contract. Every render must conform; the rules in that file are non-negotiable defaults.

### 3. Refresh mode

Diff repo against sidecar. Add new nodes, update moved/edited ones, gray-out removed ones. Do NOT delete from Miro without approval.

When recomputing positions for any new or moved node, re-run the full layout algorithm in `reference/create-ost.md` — same per-column pitch rule, same centering, same content format. Don't patch positions ad-hoc; the rule must hold globally after every refresh.

### 4. Absorb mode (two-pass: structural diff, then semantic interpretation)

**Structural diff pass** — read board; classify nodes against sidecar; detect:

- **Re-parenting** — a solution moved under a different opportunity. Signature OST move during discovery.
- **New branches** — orphan stickies that look like new opportunities or solutions.
- **Color changes** — may indicate status shifts.
- **New connectors** — dependency or alternative-framing signals.

**Semantic interpretation pass:**

- **Re-parented solution** → propose updating `Parent Opportunity`; ask whether the old opportunity should list this solution as "Alternative framing considered."
- **Orphan opportunity-shaped sticky** → propose new opportunity file with draft content; ask for persona and evidence strength.
- **Connector between two opportunities** → ask if the human is merging them or marking a relationship.

See `reference/interpret-changes.md` (to be written).

### 5. Analyze mode

Powers the iteration-entry **selection moment**. Reads:

- all outcomes and opportunities
- evidence strength and freshness per opportunity
- persona coverage across opportunities
- any notes in `inbox/` that haven't been promoted yet
- recent iteration synthesis files (`product/iterations/*/synthesis.md`) for signal about which areas have fresh evidence

Returns **2–3 ranked candidate opportunities** for "what to pursue next." For each candidate, surface:

- **Why this one:** evidence strength, freshness, persona coverage, outcome fit
- **Estimated risk/effort:** high-level, derived from candidate-solution count and assumption-test status
- **Adjacent opportunities:** other opportunities it might cluster with

The PM decides. The skill's output is advisory — it does not commit a choice or open an iteration.

Output format: a markdown summary shown in chat, plus optionally written to `product/context/opportunity-solution-tree/analyze-{YYYY-MM-DD}.md` when the PM asks for a durable record.

### 6. Promote-from-inbox mode

Reads `product/context/opportunity-solution-tree/inbox/*-candidates.md` and walks the PM through each candidate interactively. For each candidate, offer three resolutions; default is **new opportunity**:

**(a) New opportunity** — the candidate becomes its own node in the tree:

- Propose filename (`opportunity-{NN}-{slug}.md`), parent outcome, persona, evidence strength
- Confirm or edit with the PM
- Write the opportunity file
- Mark the candidate as promoted in the inbox file (strikethrough + date)

**(b) Enrichment to an existing opportunity** — the candidate is evidence for an opportunity the tree already carries, not a new node. The PM picks the existing OPP-NN. Then:

- Append the candidate's evidence bullets to that opportunity's MD file under an `## Evidence` section (create the section if absent). Each appended bullet is prefixed with the iteration slug for provenance (e.g., `- [YYYY-MM-DD-{iteration-slug}] E02: "$10 off..."`).
- Append a line to that opportunity's `## Iterations that enriched this` section (create if absent) recording the iteration slug and date.
- Mark the candidate in the inbox file as `~~enrichment~~ → OPP-NN ({YYYY-MM-DD})` — visually distinct from `~~promoted~~` so the inbox is auditable.
- **No Miro mutation.** The OST board is unchanged; the tree's structure didn't grow, only an existing node's evidence did.

**(c) Reject or defer** — the candidate doesn't belong in the tree (yet). Mark in the inbox as `~~deferred~~ ({YYYY-MM-DD}): {reason}`. The candidate stays in the inbox file as historical context; no other side effects.

Once all candidates are handled, offer to run `refresh` mode to push any **new** opportunities (resolution (a)) to the Miro board. Skip the refresh if no resolution (a) was chosen — enrichments and deferrals don't change the board.

## Open questions for the PM before building

Before creating the OST Miro artifact for the first time:

1. How many outcomes to render? (Torres recommends one tree per outcome; this skill renders all outcomes side-by-side on one board so the PM can traverse the whole product's thinking in one place.)
2. Include assumption tests in the first render, or add later?
3. Include greyed-out rejected/descoped nodes, or hide them?

## Related skills

- `story-map` — shares the sidecar pattern and the two-pass absorb approach (structural diff + semantic interpretation).
- `discovery-synthesis` — writes to `inbox/` as part of its secondary output contract; `promote-from-inbox` mode absorbs that into the canonical tree.
- `iteration-setup` — accepts `--opportunity <slug>` so an iteration opens bound to an OST opportunity.
