---
name: workshop-facilitator
description: Router skill that knows when to invoke the EE PM Workflow capability skills during a PM workshop. Loads into the main thread's context when the user frames the request as a workshop phase ("let's pick what to work on next", "we're about to run focused discovery", "the team moved things on the board, can you absorb that?") rather than a specific capability skill.
---

# Workshop Facilitator (router skill)

Drives the full EE PM Workflow loop — from a living product-level OST, through iteration selection, focused discovery, OST contribution, solution shaping, the story-map↔prototype loop, and engineering-ready stories. Doesn't do the artifact work itself; picks the right skill for the phase and hands off.

These are instructions loaded into the main thread's context. The main thread follows this routing guide; it does not run as a separate subagent. Worker spawns leave from the main thread directly.

## The loop (two modes of discovery, one iteration spine)

```
PRODUCT-LEVEL (continuous)
──────────────────────────
  Strategic discovery ──► OST inbox ──► opportunity-tree
  (ongoing interviews,                   (promote-from-inbox,
  signals, field visits)                 refresh on Miro
                                         → main thread spawns board-builder)

  OST grows. Persistent across iterations.

SELECTION (entry to an iteration)
──────────────────────────
  PM: "what should we pursue next?"
  ──► opportunity-tree (analyze mode) ──► ranked candidates
  PM picks one.

ITERATION (one cycle)
──────────────────────────
  1. iteration-setup --opportunity <slug>    scaffold + bind to OST opportunity
  2. interview-management                    (cold starts only; seeded runs skip)
                                             → hand off to discovery skill for synthesis
  3. (discovery skill owns synthesis)        returns synthesis.md path + inbox-candidates path
  4. opportunity-tree (promote-from-inbox)   land adjacent candidates into tree
  4. opportunity-tree (refresh)              push changes to Miro
                                             → main thread spawns board-builder (background)
  5. solution shaping                        facilitator-led conversation, not a skill
  6. story-management (Mode 4, seed)         v1 story set from solution brief + synthesis
                                             plan in-thread → PM approves breakdown →
                                             fan out story-writer per stub (parallel, bg)
  7. story-map (create)                  story-map v1 on Miro, rendered from v1 stories
                                             → main thread spawns board-builder (background)
     ⇅ magic-patterns (stretch; stub today) prototype pass
     story-map (absorb + refresh)        v2 reflecting prototype learnings
                                             absorb = two-call boundary (see Rules §3)
  8. story-management (Mode 4, align)        finalize against converged map + prototypes:
                                             epic-or-flat, prototype_refs, AC/priority
  9. backlog-management                      reconcile
  10. retrospective → evidence back to OST
                                             absorb (OST or story-map) = two-call boundary
```

## Worker spawns (main thread, following this skill)

| Worker | When | Backgrounded |
|---|---|---|
| `board-builder` (sonnet) | OST refresh, story-map create/refresh | yes |
| `absorb-interpreter` (opus) | Absorb mode — read board, compute propose-only diff | yes |
| `board-writer` (sonnet) | Accept side of absorb — apply PM-approved diff | no |

The main thread never calls `mcp__miro-official__*` directly while following this skill. All Miro reads and writes go through one of the three board workers. Synthesis is owned by the `discovery` router skill — workshop-facilitator hands off rather than spawning `synthesis-worker` here.

## Phase routing table

| User intent | Phase | Skill to invoke |
|---|---|---|
| "Set up the product context / personas / principles" | Framework setup | `framework-setup` |
| "What should we work on next?" / "Pick the next opportunity" | Selection | `opportunity-tree` (analyze mode) |
| "Promote the candidates from iteration X into the tree" | OST contribution | `opportunity-tree` (promote-from-inbox mode) |
| "Refresh the tree on Miro" | Update OST board | `opportunity-tree` (refresh mode) |
| "The team reshuffled the tree on the board, pull it back" | Absorb OST | `opportunity-tree` (absorb mode) |
| "Start an iteration on opportunity X" | Iteration setup (cold) | `iteration-setup --opportunity {slug}` |
| "Start a pre-seeded iteration" | Iteration setup (seeded) | `iteration-setup --from-seed {ref}` |
| "Conduct an interview" / "format this transcript" | Interview capture | `interview-management` |
| "Synthesize the interviews" / "what are the themes?" | Synthesis (dual output) | hand off to `discovery` skill |
| "Shape the solution" | Solution shaping | (facilitator conversation — not a skill) |
| "Build a story map for this iteration" | Create story map | `story-map` (create mode) |
| "Prototype these screens" | Prototyping | `magic-patterns` (stretch; stub today) |
| "The workshop just ended, absorb the board changes" | Absorb story map | `story-map` (absorb mode) |
| "Refresh the map — we added stories" | Update story map | `story-map` (refresh mode) |
| "Create initial stories from the brief + synthesis" | Story seeding | `story-management` (Mode 4) |
| "Extract / finalize / align stories to the converged solution + map" | Story finalization | `story-management` (Mode 4) |
| "Refine this story / improve the AC" | Story refinement | `story-management` (Mode 2/3) |
| "Add this to the backlog" / "what's in the backlog?" | Backlog | `backlog-management` |

## Seeded vs. empty start

Sometimes you want to pre-populate the early phases before a workshop — so the session opens at synthesis with interviews already in place — rather than building everything live with participants. When you start from a seeded iteration:

1. **Confirm seed source.** Usually an existing iteration under `product/iterations/YYYY-MM-DD-{iteration-slug}`. Clone with `iteration-setup --from-seed <path>` into a new dated slug.
2. **Skip `framework-setup` and `interview-management`.** `product/context/`, the product-level OST, and the cloned interviews are already in place.
3. **Open the OST on Miro first.** Start by showing the living OST. `opportunity-tree` (refresh mode) if needed to project the current tree onto a board.
4. **Run the selection moment.** `opportunity-tree analyze` — run the selection analysis.
5. **Begin the iteration by handing off to the `discovery` skill for synthesis.** `discovery` returns the synthesis + inbox-candidate paths.
6. **Proceed through the rest of the loop.**

When starting empty, run from the selection moment if the OST is populated; from `framework-setup` if `context/` is empty.

## Workshop loop (live session)

A typical live workshop touches one or more of these segments:

1. **Before the workshop (T-minus)** — facilitator pre-produces the board. For a story-map session: `story-map` create mode (the main thread spawns `board-builder`). For an OST review: `opportunity-tree` refresh mode (same delegation).
2. **During the workshop** — humans work the board. Main thread idle.
3. **After the workshop (T-plus)** — facilitator says "absorb the board." Absorb is a two-call boundary (see Rules §3): Call 1 spawns `absorb-interpreter` to produce a propose-only diff; PM walks it; Call 2 spawns `board-writer` to apply the approved diff.
4. **Between workshops** — `refresh` mode pushes repo-side edits back to the same board.

## Rules

1. **Synthesis is owned by the `discovery` skill.** Do not spawn `synthesis-worker` from here. When the loop reaches synthesis, hand off to `discovery` with the iteration slug + interview paths and consume the returned `synthesis.md` + inbox-candidate paths.
2. **Never invoke two capability skills at once.** Finish the current skill's mode, show results, then move on.
3. **Absorb is a two-call boundary, not a single interactive run.** PM-approval pauses are natural turns of the main thread; the two-call shape preserves that explicitly. An absorb cycle (OST or story-map) splits across two invocations:
    - **Call 1 (propose):** the main thread (following this skill) spawns `absorb-interpreter` (backgrounded). It reads the board, writes a propose-only diff at the path passed in the invocation, and returns the diff path + flag count. The main thread relays that to the PM and stops.
    - *Interactive turn:* the PM walks the diff, resolves flags, and signals "go" with a structured `approvals` block.
    - **Call 2 (accept):** the main thread is re-invoked with the diff path + approvals; it spawns `board-writer` to apply the diff and runs the skill's accept-mode repo writes.
   Never run absorb in a single call. Never have `absorb-interpreter` mutate the board.
4. **Prefer skills over free-form reasoning.** If a skill exists for the request, route to it.
5. **Respect the seed/live boundary.** Do not run `framework-setup` or `interview-management` during a seeded iteration unless the user explicitly asks.
6. **Story extraction happens after the story-map↔prototype loop has converged,** not directly off synthesis. Inputs: chosen solution + converged story map + prototype artifacts.
7. **OST contribution is routed through inbox,** not direct writes from synthesis. The PM promotes inbox candidates via `opportunity-tree promote-from-inbox`.
8. **Preconditions are caller-passed.** Iteration slug, seed source (if seeded), board IDs, scope, and any human-in-the-loop choices must be resolved before following this skill. If a required precondition is missing, ask the PM the specific question rather than guessing defaults.
9. **Heavy units delegate to worker agents, backgrounded.** Board builds, absorb reads, and long-thread digests run as backgrounded worker subagents. Synthesis is delegated by handing off to `discovery`, not by spawning a worker here. The main thread's context stays thin — only routing, precondition checks, and worker-result relays.

## Handoff payload

Schema: `agents/README.md` § "Cross-agent handoff payload".

As the live workshop router, this skill is usually the *initiator* of cross-agent handoffs and the *receiver* on return. It threads board IDs and iteration state across phases so the next router doesn't re-derive them.

**Emits** (to `discovery`, `story-shaping`, `prototyping`):
- Always: `iteration_slug`, `scope`, `next_action`
- To `discovery` for synthesis: interview transcript paths (in `next_action`), `boards.ost_board_id` if OST refresh will follow
- To `story-shaping`: whatever `discovery` returned (`chosen_opportunity`, `converged_solution`) plus `boards.story_map_board_id` if it exists
- To `prototyping`: `artifacts.prototype_specs_dir`

**Consumes** (on return from any router):
- The returned `handoff:` block, additively merged into the main thread's threaded state
- From `discovery` return: `artifacts.synthesis_path`, `artifacts.inbox_candidates_path`
- From `story-shaping` return: converged story-map path, `boards.story_map_board_id`
- From `prototyping` return: `artifacts.ingested_handoff_dirs`

## What this skill does NOT route to

- Designing Miro boards from scratch without a skill.
- Direct edits of repo story / opportunity / synthesis files — all writes go through the relevant capability skill, run by the main thread or by a worker subagent.
- Direct Miro tool calls — board reads and writes are delegated to `board-builder`, `absorb-interpreter`, or `board-writer`. The main thread has no `mcpServers`; the Miro MCP is registered inline only on those three workers.

## Related resources

- `CLAUDE.md` — project-level instructions and scope.
- `product/README.md` — product tree orientation.
- `product/context/opportunity-solution-tree/README.md` — OST orientation.
- `skills/README.md` — skill inventory and adaptation notes.
