---
name: iteration-setup
description: Set up a new product iteration — directory structure, iteration README, and PM interview to define goals and scope. Supports seeding from an existing iteration so a new iteration starts with pre-populated interviews.
---

# Iteration Setup Skill

Creates a new iteration folder under `product/iterations/` with the standard subdirectories, optionally bound to an opportunity in the product-level OST, optionally seeded from an existing iteration, and captures iteration goals via a short PM interview.

The OST is **product-level** (`product/context/opportunity-solution-tree/`), not per-iteration. An iteration pursues one opportunity (or a tight cluster) from the tree, enriches it, and may surface adjacent opportunities that land in the OST inbox.

## When to use

- Starting new discovery work against a chosen opportunity from the OST.
- Starting a pre-seeded iteration — seed from an existing iteration so interviews are already in place and the work begins at synthesis.
- Archiving a completed iteration and beginning the next one.

## Naming convention

Iteration folders use `YYYY-MM-DD-{initiative-slug}` format. The slug often matches or echoes the chosen opportunity's slug.

Examples:
- `YYYY-MM-DD-{iteration-slug}` (canonical iteration)
- `2026-05-01-courier-stacking`

## Workflow

### 1. Decide the chosen opportunity (optional but recommended)

If the PM ran `opportunity-tree analyze` and picked an opportunity, capture the opportunity slug (e.g., `opp-NN-{iteration-slug}`). The iteration README will reference it, and the iteration slug can echo it.

Accept a `--opportunity <slug>` flag so the PM can launch directly:
```
iteration-setup --opportunity opp-NN-{iteration-slug}
```

If no opportunity is given, ask: "Which OST opportunity does this iteration pursue? (Pick from `product/context/opportunity-solution-tree/opportunities/`, or mark as 'to be defined' if exploratory.)"

### 2. Decide the iteration slug

Construct as `$(date +%Y-%m-%d)-{initiative-kebab}`. Echo the opportunity slug where it makes sense.

### 3. Decide whether to seed

Two modes:

- **Cold start** — no seed. Interviews will be conducted fresh via `interview-management`.
- **Seeded** — clone `interviews/` from an existing iteration. Used to pre-populate a workshop so work begins at synthesis.

### 4. Create the directory structure

Invoke `scripts/create-iteration-dirs.sh`:

```
./scripts/create-iteration-dirs.sh <iteration-slug>
./scripts/create-iteration-dirs.sh <iteration-slug> --from-seed <seed-iteration-path>
```

The script creates:

```
product/iterations/{slug}/
├── README.md                 # (created in step 6)
├── decisions.md              # chosen opportunity + solution + why (filled during iteration)
├── interviews/               # seeded or cold; one file per person
├── synthesis.md              # populated by discovery-synthesis (primary output)
├── prototypes/               # mockups / screens produced during the story-map↔prototype loop
├── epics/                    # populated when solution is large (>8 stories); otherwise stays empty
├── stories/                  # populated by story-management (Mode 4 batch + single-story modes)
├── story-maps/               # populated by story-map skill (Miro sidecar lives here)
└── retrospective.md          # placeholder for post-iteration learnings
```

**Note:** the iteration no longer contains an `opportunity-tree/` subfolder. The OST is product-level.

### 5. Conduct the PM iteration-planning interview

Use the `interview-management` skill to run a short interview capturing:

1. **Chosen opportunity** — which OST opportunity is being pursued (copy from `--opportunity` if passed).
2. **Iteration goal** — what outcome claim this iteration makes.
3. **Scope boundary** — what's explicitly in and out.
4. **User journeys** — which standalone end-to-end flows this iteration covers. One iteration may have 1..N journeys (they may share stories but get separate story maps). Capture a slug for each (e.g. `courier-pickup-verification`, `eater-pin-confirmation`). Default: one journey, slug echoes the iteration slug.
5. **Success criterion** — how the team knows the iteration is done.
6. **Known constraints** — time, dependencies, blockers.

### 6. Write the iteration README

Generate `product/iterations/{slug}/README.md`:

```markdown
# Iteration: {initiative name}

**Slug**: {slug}
**Started**: {YYYY-MM-DD}
**Status**: active | completed | archived
**Seeded from**: {reference iteration slug, or "cold start"}
**Chosen opportunity**: [OPP-{NN} — {title}](../../context/opportunity-solution-tree/opportunities/opportunity-{NN}-{slug}.md)

## Problem frame
{one paragraph — the specific angle this iteration pursues on the chosen opportunity}

## Goal
{outcome claim in 1–2 sentences}

## Scope
**In**: {what's in scope}
**Out**: {what's out}

## Journeys
- `{journey-slug-A}` — {one-line description}
- `{journey-slug-B}` — {one-line description}

## Success criterion
{measurable outcome}

## Constraints
- {constraint 1}
- {constraint 2}

## Key decisions
(filled in during iteration — also see decisions.md)
```

### 7. Register in the iterations index

Append a one-line entry to `product/iterations/README.md`:

```
- [{slug}](./{slug}/) — {one-line description} ({status})
```

## Integration with other skills

- `framework-setup` — run once per scenario to populate `product/context/` before the first iteration.
- `opportunity-tree` (analyze mode) — typically runs **before** `iteration-setup`, returning the chosen opportunity.
- `interview-management` — used inside this skill for the iteration-planning interview, and separately for user interviews during discovery.
- `discovery-synthesis` — next skill invoked after interviews are in place. Produces dual output: enrichment into the iteration's `synthesis.md`, and candidate opportunities into the OST `inbox/`.

## Quality checklist

Before completing:

- [ ] Iteration directory exists with all subdirectories (no `opportunity-tree/` folder)
- [ ] Slug follows `YYYY-MM-DD-{initiative}` convention
- [ ] README references a chosen OST opportunity (or explicitly marks as "to be defined")
- [ ] README has goal, scope, success criterion
- [ ] Listed in `product/iterations/README.md`
- [ ] If seeded, interview files present in `interviews/`

## Output

Report to the PM:

- Path to the new iteration directory
- Chosen opportunity reference (if any)
- Seed source (if any)
- One-line summary of the goal
- Suggested next skill (`discovery-synthesis` for seeded runs; `interview-management` for cold starts)
