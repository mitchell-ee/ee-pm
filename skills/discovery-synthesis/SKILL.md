---
name: discovery-synthesis
description: Synthesize discovery research into actionable insights. Use when asked to "synthesize", "analyze interviews", "summarize discovery", or review interview materials from an iteration.
---

# Discovery Synthesis

Analyze interview files from an iteration's discovery to (1) **enrich** the chosen OST opportunity with sharper problem framing, (2) **propose** candidate solutions and their initial assumptions inline (exploratory — not separate files yet), and (3) **contribute** adjacent opportunity candidates back to the product-level OST inbox.

This skill is the bridge between iteration discovery and the product-level OST. Its primary customer is the iteration (sharper opportunity → candidate solutions → solution shaping). Its secondary customer is the OST (fresh candidates for the tree).

## Lazy materialization

Synthesis is exploratory. It writes candidate solutions and their initial assumptions **inline in `synthesis.md`** — it does not create separate solution or assumption files. Materialization happens downstream, driven by the PM:

1. **Solution MD file** materializes when the PM promotes a candidate to the OST (interactive or via OST absorb). Created with `Status: Proposed`.
2. **Assumption MD files** materialize when the PM flips a solution's `Status:` to `Committed` (commitment to pursue). The inline assumptions for that solution in `synthesis.md` are written out as separate `assumption-{NNN}-{slug}.md` files under `product/context/opportunity-solution-tree/assumptions/`, ready for `/assumption-map create from solution-NN`.
3. **Assumption-map sidecar dir** materializes on first `/assumption-map create` for that solution.

The synthesis doc keeps its inline copies as the historical record; the promoted files become the working artifacts. Unchosen candidate solutions stay inline forever — no orphan files for branches the team never pursued.

**Log the commitment to the iteration.** The solution and assumption files live at the **product/OST level** (they are reusable tree knowledge, not iteration-scoped), but the *decision* to commit belongs to the iteration. When step 2 fires, append an entry to `product/iterations/{slug}/decisions.md` recording: the chosen solution (ID + name), the rejected alternative(s) and why, the assumption IDs that were materialized (pre-existing + new), and which one or two carry the thinnest evidence (the "test first" candidates for the assumption map). This is the iteration's record that selection + materialization happened; without it the iteration has no trace of why this solution was pursued. The product-level files are the *what*; `decisions.md` is the *why*.

## When to Use

- User asks to synthesize iteration interviews.
- User wants to analyze interviews from an iteration.
- User mentions "synthesize", "analyze interviews", or "summarize discovery".

## Output contract

**Primary (enrichment):** deepen the iteration's chosen opportunity — JTBD framing, pain detail per persona, solution-shape hints, quoted evidence. Written to `product/iterations/{slug}/synthesis.md`.

**Embedded in primary (candidate solutions):** within the same `synthesis.md`, a `## Candidate solutions` section lists 1–3 candidate solutions for the chosen opportunity, each with a short description, pros/cons, and 3–8 initial assumptions inline. These are exploratory; they materialize as separate solution and assumption files only after the PM promotes / commits them (see "Lazy materialization" above).

**Secondary (contribution):** adjacent opportunity candidates that surfaced from interviews but don't belong to the chosen opportunity. Written to `product/context/opportunity-solution-tree/inbox/{iteration-slug}-candidates.md`.

The skill does **not** produce a "proposed features with priority/effort" list. Features are downstream of solution shaping, which happens after synthesis.

## Workflow

### 1. Record start time

Capture the current timestamp for timing metrics:
```bash
START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

### 2. Identify the iteration

- Check if the user specified an iteration name (e.g., `YYYY-MM-DD-{iteration-slug}`).
- If not specified, look in `product/iterations/` for the most recent iteration (by date prefix).
- Ask the user to clarify if there are multiple recent iterations.

### 3. Load the chosen opportunity

Read the iteration README to get the chosen OST opportunity. Read the opportunity file itself from `product/context/opportunity-solution-tree/opportunities/opportunity-{NN}-{slug}.md`. Synthesis should sharpen this opportunity, not re-invent it.

### 4. Verify discovery materials exist

Check that the iteration has interviews:
- `product/iterations/{iteration}/interviews/` — must have at least one interview file.

If no materials found, inform the user and stop.

### 5. Load product context

Read for product background:
- `product/context/product-strategy.md`
- `product/context/product-as-built.md`
- `product/context/personas.md`
- `product/context/glossary.md`
- `product/context/principles.md`

### 6. Gather discovery materials

Read all files in `product/iterations/{iteration}/interviews/` except template files, and any prior iterations' `synthesis.md` for cross-reference.

### 7. Analyze and synthesize

**Identify themes within the chosen opportunity**
- A theme is significant if mentioned in 3+ interviews (or when a single interview surfaces something especially vivid for a persona that hasn't been heard before).
- Group related feedback into coherent themes.
- Note frequency: "X of Y participants mentioned..."

**Extract JTBD framing**
- "When I... I want to... So I can..."
- Capture both functional and emotional needs; include desires, not only pains.

**Detail pains per persona**
- For each persona, what specifically hurts and why.
- Use role descriptions, not specific interviewee names.

**Solution-shape hints**
- Surface patterns in what interviewees tried to do when things went wrong — these hint at solution direction. Not prescribed features; directional pointers.

**Surface adjacent opportunities**
- When an interview surfaces a pain or need that does **not** belong to the chosen opportunity, capture it as a candidate for the OST inbox rather than forcing it into this iteration's synthesis.
- Candidates are not ranked; they are staged for the PM's `opportunity-tree promote-from-inbox` flow.

**Propose candidate solutions with initial assumptions**
- From the pain detail and solution-shape hints, propose 1–3 candidate solutions for the chosen opportunity. Each candidate names a directional shape, not a feature list.
- For each candidate, surface 3–8 initial assumptions across Torres' categories (desirability, viability, feasibility, usability, ethical) — the assumptions that would have to hold for that solution to work. Cite the interview evidence that motivated each.
- Do **not** rank importance/evidence here; the assumption-map workshop is where placement gets decided. Initial `Importance` / `Evidence` ratings get scaffolded from the synthesis evidence as defaults the PM can revise.
- If one candidate is clearly stronger from synthesis alone, mark it as a recommendation but list the others — the PM picks.

### 8. Format output — primary

Write `product/iterations/{iteration}/synthesis.md` using this structure:

```markdown
# Synthesis — {iteration name}

**Iteration**: {slug}
**Chosen opportunity**: [OPP-{NN} — {title}](../../context/opportunity-solution-tree/opportunities/opportunity-{NN}-{slug}.md)
**Interviews**: {N total, persona breakdown}
**Date**: {YYYY-MM-DD}

## Executive summary
{2–3 sentences on what sharpened, what surprised}

## Sharpened opportunity framing
{1–2 paragraphs re-stating the opportunity with the nuance interviews added}

## JTBD per persona
### {Persona A}
- When {situation}, I want to {motivation}, so I can {outcome}.
- Supporting: {interview reference}

### {Persona B}
...

## Pain detail
| Persona | Pain | Frequency | Vividness |
|---|---|---|---|
| {persona} | {pain} | {X/Y interviews} | {quote snippet} |

## Solution-shape hints
- {directional pattern, with evidence}
- {directional pattern, with evidence}

## Candidate solutions
Exploratory — these materialize as files only when promoted (solution → OST) and committed (`Status: Committed` → assumption files).

### SOL-candidate-{A} — {short title}
**Shape**: {1–2 sentences describing the directional solution}
**Pros**: {bullets}
**Cons / risks**: {bullets}

**Initial assumptions** (materialize as `assumption-{NNN}-*.md` on commit):
- {Type — Desirability | Viability | Feasibility | Usability | Ethical} — *{hypothesis}*. Suggested Importance: {High/Med/Low}, Evidence: {Strong/Mod/Weak}. Source: {interview ref}.
- ...

### SOL-candidate-{B} — {short title}
...

## Cross-references
- Previous synthesis / evidence that this confirms or contradicts: {links}

## Open questions
- {ambiguities for the PM to resolve in solution shaping}
```

### 9. Format output — secondary

Write `product/context/opportunity-solution-tree/inbox/{iteration-slug}-candidates.md` using the inbox format documented in `opportunity-tree` SKILL. One section per candidate, each with suggested parent outcome, persona, evidence, and a note on why it doesn't fit the chosen opportunity.

If no adjacent opportunities surfaced, write a file with an explicit "no candidates this iteration" note so there's a record.

### 10. Report results

Tell the user:
- Synthesis primary output path and summary (themes, pain points per persona).
- Candidate solutions count + recommended next pick (still PM's call).
- Inbox candidate output path and count.
- Suggested next step: review candidate solutions, promote one or more to the OST (creates `solution-{NN}-*.md` with `Status: Proposed`), then commit to pursue one (flip to `Status: Committed`) — that flip materializes the inline assumptions for that solution as `assumption-{NNN}-*.md` files under `product/context/opportunity-solution-tree/assumptions/`, ready for `/assumption-map create from solution-{NN}`. Then `opportunity-tree promote-from-inbox` to land adjacent candidates; then `story-map`.

## Quality checklist

- [ ] Each theme references at least 3 interviews (or justifies why 1–2 is enough)
- [ ] Pain detail uses role descriptions, not interviewee names
- [ ] JTBD framing present per persona
- [ ] No prescriptive features; only directional solution-shape hints
- [ ] 1–3 candidate solutions proposed inline, each with 3–8 initial assumptions and interview-evidence citations
- [ ] Adjacent opportunities written to the OST inbox (or explicit "none" record)
- [ ] Chosen opportunity reference is present in synthesis.md
- [ ] Open questions captured for the PM
- [ ] No separate solution/assumption files created at this step — those materialize on PM promotion/commit

## Success criteria

- Synthesis sharpens the chosen opportunity enough that solution shaping can begin.
- Candidates in the OST inbox are actionable — promotable without needing another round of interpretation.
- No features proposed; scope is insight, not delivery.
