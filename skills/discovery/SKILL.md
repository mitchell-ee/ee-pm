---
name: discovery
description: Router skill for generative and evaluative discovery. Loads into the main thread's context when the user frames the request as discovery work — running interviews, synthesizing findings, evolving the opportunity tree, or designing assumption tests — rather than calling a specific capability skill.
---

# Discovery (router skill)

Runs the Teresa Torres discovery loop: outcome → opportunities → assumption tests → evidence. Owns the product-level OST as a living artifact and the per-iteration discovery cycle that feeds it. Does not write stories — that is `story-shaping`'s job; discovery output flows across the seam as inbox candidates and a converged opportunity, not as backlog entries.

These are instructions loaded into the main thread's context. The main thread follows this routing guide; it does not run as a separate subagent. Worker spawns leave from the main thread directly.

## The loop

```
PRODUCT-LEVEL (continuous)
──────────────────────────
  Bootstrap (cold start)   opportunity-tree seed ─► create on Miro
                           → main thread settles shape, spawns
                             opportunity-writer per node (parallel),
                             then board-builder for the board

  Strategic interviews ─► OST inbox ─► opportunity-tree
  (signals, field work)                (promote-from-inbox, refresh)

ITERATION (one cycle, bound to one opportunity)
──────────────────────────
  0. iteration-setup               create iteration folder bound to chosen opportunity
  1. interview-management          conduct + format transcripts
  2. discovery-synthesis           dual output: synthesis.md + OST inbox candidates
                                   → main thread spawns synthesis-worker (background)
  3. opportunity-tree              promote-from-inbox → refresh on Miro
                                   → main thread spawns board-builder (background)
  4. assumption-map                prioritize riskiest assumptions; design "test first" cluster
                                   → main thread spawns board-builder (background)
  5. (test) evidence collected     fed back into opportunity-tree or assumption-map absorb
                                   absorb = two-call boundary (see Rules §3)
  ──► hand off chosen opportunity to story-shaping
```

## Worker spawns (main thread, following this skill)

| Worker | When | Backgrounded |
|---|---|---|
| `opportunity-writer` (sonnet) | Bootstrap — OST seed: expand one settled outcome/opportunity stub → one node file (fanned out one-per-node, parallel) | yes |
| `synthesis-worker` (opus) | Phase 2 — many transcripts → `synthesis.md` + inbox candidates | yes |
| `board-builder` (sonnet) | Phase 3 / 4 — build or refresh OST / assumption-map on Miro | yes |
| `absorb-interpreter` (opus) | Absorb mode — read board, compute propose-only diff | yes |
| `board-writer` (sonnet) | Accept side of absorb — apply PM-approved diff | no |

The main thread never calls `mcp__miro-official__*` directly while following this skill. All Miro reads and writes go through one of the three board workers. Inline `mcpServers: miro-official` is registered on those three workers, not on the main thread.

## Phase routing table

| User intent | Phase | Skill to invoke |
|---|---|---|
| "Build the OST from scratch" / "Create the initial opportunity tree" / "Seed outcomes and opportunities" | Bootstrap | `opportunity-tree` (seed mode), then create mode |
| "Start a new iteration on this opportunity" / "Spin up an iteration folder" | Setup | `iteration-setup` |
| "Conduct an interview" / "format this transcript" | Capture | `interview-management` |
| "Synthesize the interviews" / "what are the themes?" | Synthesis | `discovery-synthesis` |
| "What should we work on next?" / "Pick the next opportunity" | Selection | `opportunity-tree` (analyze mode) |
| "Promote candidates from this iteration into the tree" | OST contribution | `opportunity-tree` (promote-from-inbox mode) |
| "Refresh the tree on Miro" | Update OST board | `opportunity-tree` (refresh mode) |
| "The team reshuffled the tree on the board, pull it back" | Absorb OST | `opportunity-tree` (absorb mode) |
| "What's risky about this solution? What should we test first?" | Assumption testing | `assumption-map` (create / refresh) |
| "The team reorganized the assumption map, pull it back" | Absorb assumptions | `assumption-map` (absorb mode) |

## Rules

1. **Synthesis is dual-output.** `discovery-synthesis` always produces both `synthesis.md` and OST inbox candidates — never one without the other. The main thread delegates the run to `synthesis-worker` (backgrounded) rather than ingesting transcripts directly.
2. **OST contribution routes through inbox.** Synthesis does not write directly into the tree. The PM promotes inbox candidates via `opportunity-tree promote-from-inbox`.
3. **Absorb is a two-call boundary, not a single interactive run.** PM-approval pauses are natural turns of the main thread; the two-call shape preserves that explicitly. An absorb cycle splits across two invocations:
    - **Call 1 (propose):** the main thread (following this skill) spawns `absorb-interpreter` (backgrounded). It reads the board, writes a propose-only diff at the path passed in the invocation, and returns the diff path + flag count. The main thread relays that to the PM and stops.
    - *Interactive turn:* the PM walks the diff, resolves flags, and signals "go" with a structured `approvals` block.
    - **Call 2 (accept):** the main thread is re-invoked with the diff path + approvals; it spawns `board-writer` to apply the diff and runs the skill's accept-mode repo writes.
   Never run absorb in a single call. Never have `absorb-interpreter` mutate the board.
4. **Assumption mapping happens after a candidate solution exists,** not before. Inputs: chosen opportunity + candidate solution.
5. **Do not extract stories.** That is `story-shaping`. Hand off the chosen opportunity (slug + converged solution shape) and stop.
6. **Preconditions are caller-passed.** Iteration slug, chosen opportunity, board IDs, scope (`product-context` vs `iteration:<slug>`), and any human-in-the-loop choices must be resolved before following this skill. If a required precondition is missing, ask the PM the specific question rather than guessing defaults.
7. **Heavy units delegate to worker agents, backgrounded.** Transcript synthesis, board builds, absorb reads, and long-thread digests run as backgrounded worker subagents. The main thread's context stays thin — only routing, precondition checks, and worker-result relays.
8. **Seed splits interactive shape from delegated expansion.** Building an OST from scratch is not one inline job. The main thread settles the tree *shape* with the PM — which outcomes, which opportunities, nesting, persona, evidence (the judgment). It then fans out one `opportunity-writer` per node to author the MD files in parallel, and delegates the board render to `board-builder` (create mode). The main thread never authors node bodies or builds the board inline. Seed authors outcomes + opportunities only; solutions and assumption tests arrive later via `promote-from-inbox` and `assumption-map`.

## Handoff payload

Schema: `agents/README.md` § "Cross-agent handoff payload".

**Consumes** (from `workshop-facilitator` or interactive thread):
- `iteration_slug`, `scope`
- For synthesis: interview transcript paths (in `next_action` or derivable from the iteration slug)
- For OST/assumption-map work: `boards.ost_board_id` / `boards.assumption_map_board_id`

**Emits** (to `story-shaping` or back to `workshop-facilitator`):
- After synthesis: `artifacts.synthesis_path`, `artifacts.inbox_candidates_path`
- At hand-off to `story-shaping`: `artifacts.chosen_opportunity` (slug + ref_id), `artifacts.converged_solution` (one-liner + shape-notes path), `boards.ost_board_id`, optional `boards.assumption_map_board_id`
- Two-call absorb between Call 1 and Call 2: `pending_absorb.diff_path`

## What this skill does NOT route to

- Story writing or refinement — hand off to `story-shaping`.
- Prototyping — hand off to `prototyping` once a solution is shaped.
- Direct edits of synthesis / opportunity / assumption files — all writes go through capability skills, run by the main thread or by a worker subagent.
- Direct Miro tool calls — board reads and writes are delegated to `board-builder`, `absorb-interpreter`, or `board-writer`. The main thread has no `mcpServers`; the Miro MCP is registered inline only on those three workers.

## Related resources

- `CLAUDE.md` — project scope and principles.
- `agents/README.md` — agent-shape rationale and the discovery↔story-shaping seam.
- `product/context/opportunity-solution-tree/README.md` — OST orientation.
- `skills/README.md` — skill inventory.
