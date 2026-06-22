---
name: story-management
description: Author and maintain user stories — write a single new story, refine an existing one, enhance acceptance criteria, or batch-create/align a whole story set from sources (solution brief + synthesis early, or a converged story map + prototypes late). Use when asked to "write a story", "create a story", "refine story", "improve AC", "add acceptance criteria", "create stories from the brief/synthesis", "extract stories", or "finalize/align stories to the map".
---

# Story Management

Create, refine, and enhance user stories with comprehensive acceptance criteria — one at a time or as a batch aligned to whatever sources the iteration provides.

## When to Use

- User asks to write or create a new story
- User wants to refine or improve an existing story
- User asks to enhance or add acceptance criteria
- User asks to create/extract/align a batch of stories from a solution brief, synthesis, a converged story map, or prototypes
- User mentions "story", "user story", "AC", or "acceptance criteria"

## Modes

### Mode 1: Write New Story

Create a new user story from scratch or from a feature description.

**Workflow:**

1. **Determine Story Number**
   Run: `./scripts/find-highest-story.sh`
   New story = highest + 1 (see [reference/story-numbering.md](reference/story-numbering.md))

2. **Identify Iteration**
   - Ask which iteration this story belongs to
   - Or use the most recent iteration in `product/iterations/`

3. **Select Template**
   Ask user preference:
   - **LLM Developer**: Streamlined, high-level AC
   - **Human Developer**: Detailed, explicit requirements

4. **Gather Story Details**
   - Who is the user? (Use general personas from `product/context/personas.md`)
   - What do they want to do?
   - Why? (business value, user benefit)
   - Which iteration and chosen solution does it trace to?
   - Does the iteration have an epic layer? If so, which epic does this story belong to?
   - Any prototype artifacts in `product/iterations/{slug}/prototypes/` this story should reference?

5. **Write Story**
   Use selected template from `templates/`
   - Follow "As a [persona], I want [action], so that [benefit]"
   - Include context and source (traceability to synthesis + story-map activity)
   - Populate optional frontmatter when applicable:
     - `epic:` (string slug, e.g., `epic-02-courier-handoff`) — only when the iteration has an epic layer (>8 stories)
     - `prototype_refs:` (array of paths or URLs) — point to mockups in `prototypes/` that visualize this story
   - Add design references inline in AC when helpful: "See `prototypes/{filename}.png`."

6. **Generate Acceptance Criteria**
   Use Given-When-Then format (see [reference/acceptance-criteria-format.md](reference/acceptance-criteria-format.md)):
   - Happy path scenarios
   - Error/failure scenarios
   - Edge cases
   - Non-functional requirements (performance, accessibility, security)

7. **Assign Priority**
   Use [reference/priority-scale.md](reference/priority-scale.md):
   - Critical, High, Medium, or Low

8. **Save Story**
   Save to: `product/iterations/{iteration}/stories/story-{number}-{slug}.md`

9. **Update Backlog**
   Add story to `product/context/backlog.md`

10. **Record Timing**
    Run: `./scripts/append-timing.sh "/story-write" "{iteration}" {duration} '{"story_id": "STORY-XXX"}'`

### Mode 2: Refine Existing Story

Improve an existing story's clarity, scope, or structure.

**Workflow:**

1. **Locate Story**
   - User provides story ID or path
   - Or search: `product/iterations/*/stories/story-*.md`

2. **Read Current Story**
   Understand the current state

3. **Identify Issues**
   - Unclear user benefit?
   - Vague acceptance criteria?
   - Missing scenarios?
   - Scope too large (should split)?

4. **Propose Changes**
   Present specific improvements before making changes

5. **Apply Refinements**
   - Clarify language
   - Improve acceptance criteria specificity
   - Add missing scenarios
   - Update estimates if scope changed

6. **Update Metadata**
   - Set "Last Updated" date
   - Keep "Created" date unchanged

7. **Record Timing**
    Run: `./scripts/append-timing.sh "/story-refine" "{iteration}" {duration} '{"story_id": "STORY-XXX"}'`

### Mode 3: Enhance Acceptance Criteria

Add or improve acceptance criteria for an existing story.

**Workflow:**

1. **Read Story**
   Understand the user story and current AC

2. **Analyze Gaps**
   Check for missing:
   - Happy path scenarios
   - Error conditions
   - Edge cases
   - Validation requirements
   - Non-functional requirements

3. **Generate Additional AC**
   Use Given-When-Then format:
   ```
   **Scenario: [Name]**
   - **Given** [precondition]
   - **When** [action]
   - **Then** [expected outcome]
   - **And** [additional outcome]
   ```

4. **Add Non-Functional Requirements**
   - Performance (response time, load handling)
   - Accessibility (WCAG compliance, keyboard navigation)
   - Security (input validation, authorization)
   - Usability (error messages, feedback)

5. **Update Story File**
   Append new AC to existing criteria

6. **Record Timing**
    Run: `./scripts/append-timing.sh "/story-ac" "{iteration}" {duration} '{"story_id": "STORY-XXX"}'`

### Mode 4: Align Stories to Sources (batch create + update)

Create or update a whole story set so it stays aligned to whatever sources the iteration currently provides. This is the batch counterpart to Mode 1 and the one mode the `story-shaping` loop calls twice:

- **Early (seed):** create the initial story set from the **solution brief + synthesis** *before* a story map exists. This is the v1 set the story map will render.
- **Late (finalize):** re-run after the story-map↔prototype loop converges, aligning the set to the **converged story map + prototypes** — re-deriving AC, priorities, traceability, attaching `prototype_refs`, tripping the epic-or-flat decision, **and creating any new stories the prototype surfaced** (see below). Prototype output is a *story-creating* source here, not only a refine-and-ref source.

The same mode handles both; the only difference is which sources it's pointed at. Story authoring off synthesis is explicitly allowed here (a previous extraction-only skill refused it) — early seeding is the whole point.

**Two valid on-ramps, one canonical destination.** New stories can be born two ways, and both write to the same `stories/` files: (1) `story-map absorb`, when the Miro board is the live surface and a human added a sticky during a workshop; (2) this mode, directly from synthesis or prototype output, when the board is *not* the working surface. The board-first reverse-sync that the OST and assumption-map skills use is correct for *their* case (human edits on the board) — it is not the only path to a story. The story files are the canonical requirement set; the map is a view that `story-map refresh` (push repo→board) brings current from the files afterward, if the PM still wants the board updated. Prototyping does **not** have to detour through a board sticky to create a story.

**Seed fans out; finalize stays in-thread.** The two on-ramps differ in volume and context needs, so they run differently:

- **Seed (cold bulk authoring)** splits into three phases — **plan** (in-thread), **fan-out expansion** (parallel `story-writer` workers), **assemble** (in-thread). The plan decides *what* stories exist and *why*; the workers expand each stub into a full file in isolated contexts so the main thread never ingests the full prose of every story; the assemble phase builds the index from one-line receipts. This keeps the breakdown rationale queryable in the main thread (`_seed-plan.md` + the stub list) while shedding the AC prose that would otherwise blow the context window. The phase tags on the steps below say which phase each step belongs to.
- **Finalize / align (late re-run)** runs the whole workflow **in-thread, no fan-out.** It is a reconcile-and-refine pass over existing files — lower volume, and it needs cross-story context to keep the set consistent, attach `prototype_refs`, and trip the epic decision against the full set. Fanning it out would lose exactly the cross-story view it depends on. Run steps 1–15 inline.

The phase tags below (**[plan]** / **[fan-out]** / **[assemble]**) apply to the **seed** path. For finalize, ignore the tags and run every step in-thread.

**Workflow:**

1. **Record start time**
   ```bash
   START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   ```

2. **Identify the iteration**
   Use the user-specified slug or the most recent iteration in `product/iterations/`.

3. **Determine sources**
   - If the invocation names sources ("create stories from the solution brief and synthesis", "finalize stories against the converged map"), use them.
   - Otherwise ask the user which to use (AskUserQuestion), offering the candidates that exist for the iteration:
     - Chosen solution: `product/context/opportunity-solution-tree/solutions/solution-{NN}-{slug}.md`
     - `product/iterations/{slug}/synthesis.md`
     - Linked OST opportunity (for traceability)
     - Converged story map under `product/iterations/{slug}/story-maps/`
     - Prototype artifacts under `product/iterations/{slug}/prototypes/`
     - Any ambient docs the user points at
   - **Do not require a converged map or prototypes.** When they're absent (early seed), proceed from the brief + synthesis. When present (late finalize), use them to refine, to attach `prototype_refs`, **and to create new stories for flows the prototype surfaced that no story covers** (see step 7a). A prototype's handoff README / CD-notes are a first-class story source — like synthesis, they can mint new stories, not just refine existing ones.

4. **Select story template** (AskUserQuestion)

   | Template | Description |
   |----------|-------------|
   | LLM Developer | Streamlined stories with high-level acceptance criteria. Best for LLM-assisted development. |
   | Human Developer | Detailed stories with explicit UI components, data requirements, and implementation guidance. |

5. **Select granularity** (AskUserQuestion)

   | Granularity | Description |
   |-------------|-------------|
   | Fine | More, smaller stories. Each screen element, interaction, or discrete capability becomes a separate story. |
   | Standard | Balanced approach. Logical user-facing capabilities become stories. |
   | Coarse | Fewer, larger stories. Related functionality grouped together. |

6. **Determine story numbering**
   ```bash
   ./scripts/find-highest-story.sh
   ```
   Story numbers are **globally unique across all iterations** and never reset. New stories start at the next sequential number.

7. **[plan] Draft the story set as stubs, then reconcile create-vs-update**
   For each capability implied by the sources, decide the story — but in **seed**, stop at a *stub*, not a full file. The full body is written later by the fan-out workers; deciding the set is the judgment this phase keeps.
   - **No matching story exists** → create a stub for it.
   - **A matching story exists** → (finalize path only) update it to align (re-derive AC, priority, traceability) rather than duplicating. **Never silently overwrite** — propose the diff before applying (consistent with Mode 2's "propose changes before making them"). In seed there are no existing stories to reconcile against — every capability is a new stub.
   - Apply the granularity setting **to the stub list** — granularity decides how many stubs, not how verbose each one is.
   - Use "As a [persona], I want [action], so that [benefit]" framing for the stub's `intent` — general personas matching `product/context/personas.md`.
   - Maintain traceability: every stub records its solution + opportunity + source theme (and a story-map activity once a map exists) in `source_refs`.

   Each stub carries exactly the fields the `story-writer` invocation contract names (`.claude/agents/story-writer.md`): `story_id`, `slug`, `title`, `personas`, `activity`, `priority`, `type`, `epic`, `intent`, `source_refs`. A stub is cheap — one to two lines of intent plus metadata — which is why the whole stub list fits in the main thread without bloat.

7a. **[plan] Detect flows the prototype surfaced that no story covers** (only when `prototypes/` is among the sources)
   A prototype almost always builds or gestures at flows beyond what the seed stories named — and its handoff often *flags* them explicitly as out of scope. Read the prototype's handoff README and `cd-metadata.json` (and CD-notes if present), then:
   - Identify each screen / state / flow the design surfaced — including ones the design **declined to build but called out** (e.g. "the dispute / problem-report exit is shown only as an exit; it needs its own design pass").
   - For each, check whether an existing story covers it. A flow the prototype treats as a first-class screen, or explicitly defers, that has **no matching story and no acceptance criteria** is a candidate **new** story.
   - **Propose, don't auto-create.** This is a semantic judgment (like absorb's board read), not a mechanical diff — surface each candidate to the PM with its source quote and the assumption/AC it relates to, and create only on approval. Assign the next sequential `STORY-{NNN}` (step 6) once approved.
   - Flows the prototype built that *are* within an existing story's scope → refine that story's AC and attach `prototype_refs` (steps 9 and 11), not a new story.

8. **[plan] Epic-or-flat decision**
   After drafting the stub set, count the stubs.
   - **≤8 stories**: emit as flat stories. Do **not** create an epic.
   - **>8 stories**: introduce an epic layer.

   **Rationale to carry into the iteration's decision record:** epics are a **reporting/visibility layer for leadership outside the delivery team**, used when the iteration is large enough that progress needs mid-grain narration. With AI-assisted delivery, small iterations don't need them; large ones do.

   When the threshold trips:
   - Group stories into 2–4 cohesive epics (each epic is a user-facing capability cluster, not an engineering sub-system).
   - Write epic files to `product/iterations/{slug}/epics/epic-{NN}-{slug}.md`:

   ```markdown
   # Epic: {title}

   **ID**: EPIC-{NN}
   **Iteration**: {iteration-slug}
   **Chosen solution**: SOL-{NN}

   ## Summary
   {2–3 sentences — what this cluster delivers for which persona}

   ## Stories
   - STORY-{NNN}: {title}
   - STORY-{NNN}: {title}

   ## Success criterion
   {how leadership will know this epic delivered value — user-visible, not implementation}
   ```

   - Reference the epic from each stub via `epic: epic-{NN}-{slug}`.

8b. **[plan] Write the plan note, then get PM approval before fan-out** (seed path)
    The plan phase ends by making its judgment durable and gated:
    - Write `product/iterations/{iteration}/stories/_seed-plan.md` — the breakdown rationale: why this many stories, why these splits, which capabilities map to which stub, the epic-or-flat call and why. This is the queryable "why" the main thread keeps after the prose is shed; it is committed alongside the stories, not scratch.
    - Present the stub list + rationale to the PM and **get approval (AskUserQuestion: approve / edit / reject the breakdown)**. This is the one approval gate for seed — it sits on the breakdown, where the judgment is. Once approved, the workers run unattended; there is no per-story gate.
    - On "edit", revise stubs/`_seed-plan.md` and re-present. On "reject", stop.

9–12. **[fan-out] Expand each approved stub into a full story file — in parallel**
    This is the per-story expansion (acceptance criteria, priority/size, prototype refs, save) that used to run inline and bloat the context. In **seed**, the main thread (following the `story-shaping` router) **spawns one `story-writer` worker per stub**, backgrounded, in waves of ~10 — issuing the batch as parallel spawns in a single message so they actually run concurrently rather than serializing.

    Each worker receives one fully-resolved stub (the invocation contract in `.claude/agents/story-writer.md`) plus the shared `template` / `granularity` / `iteration` run parameters, loads `story-management` **Mode 1**, and:
    - generates Given-When-Then acceptance criteria — happy path, error/failure, edge, non-functional (performance, accessibility, security); referencing prototype screens inline when `prototype_refs` are present (see [reference/acceptance-criteria-format.md](reference/acceptance-criteria-format.md));
    - assigns priority (from the stub) and size (via the sizing guidelines below);
    - writes the story file atomically to `product/iterations/{iteration}/stories/story-{NNN}-{slug}.md` with the frontmatter below;
    - returns a **one-line receipt** (status, id, final title, path, persona/activity/priority/size, `ac_count`, `split_suspected`, notes) — never the story body.

    Frontmatter each worker writes (minimum):
    ```yaml
    ---
    id: STORY-{NNN}
    title: {title}
    iteration: {iteration-slug}
    solution: SOL-{NN}
    opportunity: OPP-{NN}
    epic: epic-{NN}-{slug}      # optional — only when >8 stories
    prototype_refs:              # optional — only when prototypes exist
      - prototypes/{file}.png
    priority: Critical | High | Medium | Low
    size: XS | S | M | L | XL
    ---
    ```

    The main thread collects the receipts. A receipt with `split_suspected: true` is surfaced to the PM as a re-planning candidate (the stub was too coarse) — the worker wrote a single best-effort story; splitting it is a plan decision, not a worker decision. A `precondition-unresolved` or `failed` receipt is re-spawned after the stub is fixed.

    **(finalize path:** run steps 9–12 in-thread per story, reconciling against existing files — no fan-out.)

13. **[assemble] Maintain the stories index and backlog** (in-thread, from the receipts)
    - Create/update `product/iterations/{iteration}/stories/stories-index.md` from the worker receipts (id, title, priority, epic, size, `ac_count`) plus a priority-distribution summary — one writer building the index, not N workers racing on it. Do not re-read the story bodies; the receipts carry what the index needs.
    - Update `product/context/backlog.md` — ID, title, priority, iteration, and epic (if any) for each story.

14. **[assemble] Record timing**
    ```bash
    ./scripts/append-timing.sh "/story-align" "{iteration}" {duration} '{"stories_created": N, "stories_updated": U, "epics_created": E, "story_ids": [...], "template": "llm-dev", "granularity": "standard"}'
    ```

15. **[assemble] Report results**
    - Stories created vs updated, epic count (0 if flat), priority distribution, total effort estimate, duration.
    - For seed, build the report from the worker receipts (not by re-reading the bodies) and note any `split_suspected` flags the PM should revisit.
    - Which stories carry prototype references.
    - Next steps: render/refresh the story map (`story-map`), review with engineering, load to tracker.

## Acceptance Criteria Format

See [reference/acceptance-criteria-format.md](reference/acceptance-criteria-format.md) for detailed guidelines.

**Key principles:**
- All scenarios use Given-When-Then format
- Criteria are specific, measurable, testable
- No ambiguous terms ("should", "usually", "properly")
- Include both functional and non-functional requirements
- When prototype artifacts are attached (via `prototype_refs:`), reference the specific screens inline in the AC, e.g., "Then the user sees the confirmation state (see `prototypes/{iteration-slug}-screen-NN-handoff.png`)"

## Optional frontmatter fields

Two fields sit alongside the required ones. They are both optional; stories without them remain valid.

- **`epic:`** — a string slug identifying the epic grouping (e.g., `epic-02-courier-handoff`). Set only when the iteration has an epic layer (Mode 4 introduces one when a chosen solution decomposes into >8 stories). Epic files live at `product/iterations/{slug}/epics/epic-{NN}-{slug}.md`.
- **`prototype_refs:`** — an array of relative paths or URLs to prototype artifacts that visualize the story. Typical paths are under `product/iterations/{slug}/prototypes/`. Populated by Mode 4 when prototypes exist; may be edited via Mode 2 (refine).

## Story sizing guidelines

| Size | Duration | Complexity |
|------|----------|------------|
| XS | < 1 day | Minimal, clear implementation |
| S | 1-2 days | Some complexity, mostly clear |
| M | 3-5 days | Moderate, may need design discussion |
| L | 1-2 weeks | High complexity, architecture decisions |
| XL | > 2 weeks | Very high - should be split |

## Quality Checklist

Before finalizing any story:
- [ ] Story follows "As a... I want... So that..." format
- [ ] Persona is general (not specific stakeholder name)
- [ ] Benefit is clear and measurable
- [ ] All AC use Given-When-Then format
- [ ] Happy path covered
- [ ] Error conditions covered
- [ ] Edge cases identified
- [ ] Non-functional requirements specified
- [ ] Priority assigned with justification
- [ ] Size estimate provided
- [ ] Backlog updated (for new stories)
- [ ] Traceability to solution + opportunity + source theme (+ story-map activity once a map exists)

For batch runs (Mode 4), additionally:
- [ ] Story numbers verified globally unique
- [ ] Epic-or-flat rule applied correctly (threshold 8); when epics created, each story has `epic:` frontmatter and epic files exist
- [ ] When prototypes exist, stories carry `prototype_refs:` pointing to files that actually exist
- [ ] Updates proposed as a diff before applying (no silent overwrites)
- [ ] Stories index maintained

## Success Criteria

- Story is clear enough for development to begin
- Acceptance criteria are testable
- No implementation details prescribed (unless business constraint)
- Story traces to user need or synthesis
