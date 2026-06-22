---
name: story-shaping
description: Router skill for the discovery-to-delivery seam. Loads into the main thread's context when the user frames the request as story work — extracting stories from a converged solution, building or absorbing a story map, refining acceptance criteria, or reconciling the backlog — rather than calling a specific capability skill. Standalone-usable for orgs that don't run discovery.
---

# Story Shaping (router skill)

Owns the seam between discovery output and delivery input. Takes a chosen opportunity + a converged solution shape and produces engineering-ready stories with acceptance criteria, organized on a story map and in the backlog. Designed to stand alone: PM teams that don't run discovery can enter here with a one-line solution intent and run the full loop.

These are instructions loaded into the main thread's context. The main thread follows this routing guide; it does not run as a separate subagent. Worker spawns leave from the main thread directly.

## The loop

```
ENTRY (from discovery, or cold)
──────────────────────────
  Inputs: chosen opportunity (slug) + solution shape
          OR a one-line solution intent (cold start)

SHAPING (one cycle)
──────────────────────────
  1. story-management (Mode 4, seed)   v1 story set from solution brief + synthesis
                                       (no map yet — stories are born here)
                                       plan in-thread → PM approves the breakdown →
                                       main thread fans out story-writer per stub
                                       (parallel, background) → assemble index in-thread
  2. story-map (create)            v1 map on Miro: activities × NOW/NEXT/LATER,
                                       rendered from the v1 stories
                                       → main thread spawns board-builder (background)
     ⇅ prototype pass                  (handoff to prototyping skill if needed)
     story-map (absorb + refresh)  v2 reflecting workshop edits
                                       absorb = two-call boundary (see Rules §3)
                                       refresh → main thread spawns board-builder (background)
  3. story-management (Mode 4, align)  finalize stories against converged map +
                                       prototypes: epic-or-flat, prototype_refs,
                                       re-derived AC/priority/traceability
  4. backlog-management                reconcile into the iteration backlog
  ──► hand off backlog to delivery
```

## Worker spawns (main thread, following this skill)

| Worker | When | Backgrounded |
|---|---|---|
| `story-writer` (sonnet) | Step 1 seed — expand each approved story stub into a full story file, **one worker per stub, fanned out in parallel** | yes |
| `board-builder` (sonnet) | Step 2 — create / refresh story map on Miro | yes |
| `absorb-interpreter` (opus) | Absorb mode — read board, compute propose-only diff | yes |
| `board-writer` (sonnet) | Accept side of absorb — apply PM-approved diff | no |

The main thread never calls `mcp__miro-official__*` directly while following this skill. All Miro reads and writes go through one of the three board workers (`board-builder`, `absorb-interpreter`, `board-writer`); inline `mcpServers: miro-official` is registered on those three workers, not on the main thread. `story-writer` holds no Miro MCP — story authoring never touches a board.

**`story-writer` is the one fan-out worker.** Stories are independent units, so seed expansion is a map: the main thread issues the per-stub spawns as a parallel batch (single message, multiple spawns) so they run concurrently, in waves of ~10 (the subagent concurrency cap). Every other worker is spawned singly — a board is one atomic artifact, and absorb is gated on one shared sidecar. See Rules §1 and §7.

## Phase routing table

| User intent | Phase | Skill to invoke |
|---|---|---|
| "Build a story map for this iteration" | Create story map | `story-map` (create mode) |
| "Refresh the map — we added stories" | Update story map | `story-map` (refresh mode) |
| "The workshop just ended, absorb the board changes" | Absorb story map | `story-map` (absorb mode) |
| "Create initial stories from the solution brief + synthesis" | Story seeding | `story-management` (Mode 4) |
| "Extract / finalize / align stories to the converged solution + map" | Story finalization | `story-management` (Mode 4) |
| "Write a story for X" / "create a new story" | Story drafting (cold) | `story-management` (Mode 1) |
| "Refine this story / improve the AC" | Story refinement | `story-management` (Mode 2/3) |
| "Add this to the backlog" / "what's in the backlog?" | Backlog | `backlog-management` |
| "Reorder the backlog" / "deprioritize X" | Backlog | `backlog-management` |

## Rules

1. **Stories are created before the map, then finalized after it.** Initial story creation (`story-management` Mode 4, seed) runs *first*, off the solution brief + synthesis — authoring stories off synthesis is explicitly allowed, and the v1 story map renders from that set. **Seed splits plan from emission:** the main thread runs the plan phase (decides the breakdown, writes stubs + `_seed-plan.md`, gets PM approval on the breakdown), then fans out one `story-writer` per stub in parallel to expand each into a full file, then assembles the index from the receipts. The breakdown rationale stays queryable in the main thread (`_seed-plan.md` + stubs) while the per-story AC prose lives in the workers and on disk, not in the main context. Story authoring re-runs (`story-management` Mode 4, align) after the story-map↔prototype loop converges, this time against the converged map + (optional) prototype artifacts to finalize AC, priority, traceability, epics, and `prototype_refs` — the **align re-run stays in-thread (no fan-out)**: it is a reconcile pass that needs cross-story context.
2. **The story map is both a workshop surface and a delivery-shaping artifact.** This skill owns it; `workshop-facilitator` invokes it during live sessions.
3. **Absorb is a two-call boundary, not a single interactive run.** PM-approval pauses are natural turns of the main thread; the two-call shape preserves that explicitly. An absorb cycle splits across two invocations:
    - **Call 1 (propose):** the main thread (following this skill) spawns `absorb-interpreter` (backgrounded). It reads the board, writes a propose-only diff at the path passed in the invocation, and returns the diff path + flag count. The main thread relays that to the PM and stops.
    - *Interactive turn:* the PM walks the diff, resolves flags, and signals "go" with a structured `approvals` block.
    - **Call 2 (accept):** the main thread is re-invoked with the diff path + approvals; it spawns `board-writer` to apply the diff and runs the skill's accept-mode repo writes.
   Never run absorb in a single call. Never have `absorb-interpreter` mutate the board.
4. **Cold-start path is supported.** If there is no upstream discovery, accept a one-line solution intent and proceed straight to `story-map` create. Do not require synthesis.
5. **Hand off to prototyping when visual confirmation is needed,** then resume on the absorbed map.
6. **Preconditions are caller-passed.** Iteration slug, board IDs, scope, chosen opportunity (or cold-start intent), and any human-in-the-loop choices must be resolved before following this skill. If a required precondition is missing, ask the PM the specific question rather than guessing defaults.
7. **Heavy units delegate to worker agents, backgrounded.** Seed story expansion, board builds, absorb reads, and long-thread digests run as backgrounded worker subagents. The main thread's context stays thin — only routing, precondition checks, plan judgment, and worker-result relays. Seed expansion is the one **fan-out** (one `story-writer` per stub, parallel batch in a single message, waves of ~10); every other delegation is a single worker. The split exists to keep the main thread holding the *plan* (the queryable "why") without the *prose* (the per-story AC, which the file on disk already records).

## Handoff payload

Schema: `.claude/agents/README.md` § "Cross-agent handoff payload".

**Consumes** (from `discovery`, `workshop-facilitator`, or interactive thread):
- `iteration_slug`, `scope`
- `artifacts.chosen_opportunity` + `artifacts.converged_solution` (or, on cold start, a one-line solution intent in `next_action`)
- `boards.story_map_board_id` (for refresh / absorb modes)

**Emits** (to `prototyping` or back to caller):
- At hand-off to `prototyping`: `artifacts.prototype_specs_dir`
- After absorb: `boards.story_map_board_id`, the converged story-map path
- Two-call absorb between Call 1 and Call 2: `pending_absorb.diff_path`

## What this skill does NOT route to

- Discovery — hand off to `discovery` if interviews / synthesis / opportunity work is needed first.
- Prototyping — hand off to `prototyping` for per-screen specs and round-tripping.
- Direct edits of story / backlog files — all writes go through capability skills, run by the main thread or by a worker subagent.
- Direct Miro tool calls — board reads and writes are delegated to `board-builder`, `absorb-interpreter`, or `board-writer`. The main thread has no `mcpServers`; the Miro MCP is registered inline only on those three workers.

## Related resources

- `CLAUDE.md` — project scope and principles.
- `.claude/agents/README.md` — why story-shaping is split from discovery.
- `.claude/skills/README.md` — skill inventory.
