---
description: Architecture notes for the EE PM Workflow worker agents — not a spawnable agent. Documents the worker inventory, model-matching rationale, and the two-call approval split.
---

# Agents

Agents are personas + tool allowlists + system prompts that the main Claude thread can delegate to. Skills are stateless capabilities; agents are *who is invoking them and why*. This README documents the agent shape for the EE PM Workflow.

## Design rule

**Skills are organized by capability. Agents are organized by how a PM adopts them.** This workflow applies the four-piece visual-collaboration pattern across surfaces (Miro, Claude Design); the agents organize the same skills by *PM phase*, because that is how a PM will pick up the work on Monday.

Story-writing is intentionally **not** bundled inside discovery. A large slice of the EE ICP audience does little or no discovery — for them, story-writing is the job. Naming an agent for work the viewer doesn't do causes them to skip past the part that's actually relevant. The discovery/story-shaping seam is where Torres draws her line, and it matches audience reality.

## Phases

All four are **router skills** — they load into the main thread's context to route phases and spawn worker agents for heavy work. See "Router-skill + worker-agent architecture" below for the worker inventory and model-matching rationale.

**Why this shape:** subagents cannot spawn other subagents — the `Agent` tool is stripped from any subagent context regardless of frontmatter (`claude.com/docs/en/sub-agents.md`: *"Subagents cannot spawn other subagents, so `Agent(agent_type)` has no effect in subagent definitions."*). Routing therefore lives in the main thread as a loaded skill, so `Agent`-spawn calls always originate from the main thread.

| Phase router (skill) | Owns these skills | Purpose |
|---|---|---|
| `workshop-facilitator` | router only — invokes the others during a live workshop | Live workshop loop: intake → map → discuss → absorb → handoff. Persistent facilitator pattern in the main thread. |
| `discovery` | `interview-management`, `discovery-synthesis`, `opportunity-tree`, `assumption-map` | Generative + evaluative discovery. Outcome → opportunities → assumption tests → evidence. |
| `story-shaping` | `story-management`, `story-map`, `backlog-management` | Discovery-to-delivery seam. Stories (created from the brief + synthesis, then finalized against the converged map), AC, the story map as a shaping surface, and the backlog. Standalone-usable for orgs that don't run discovery. |
| `prototyping` | `claude-design`, `magic-patterns` | Per-screen specs round-tripped to Claude Design (primary) or Magic Patterns (stretch comparison). Visual confirmation of stories. |

`framework-setup` and `iteration-setup` are bare skills — invoked once at project/iteration start by the main thread. They don't need an agent wrapper.

## Why four, not three

The earlier sketch folded story-shaping into discovery. Rejected because:

1. **Audience mismatch.** Story-shop PMs would not open `agents/discovery.md`.
2. **Torres orthodoxy.** Story-writing consumes discovery output but produces delivery input — it's a boundary, not an interior of either side.
3. **Surface ambiguity for `story-map`.** The story map is both a workshop surface and a delivery-shaping artifact. Owning it from `story-shaping` (and letting `workshop-facilitator` invoke it) keeps a single owner.

## Why not collapse to three

If legibility pressure forces three, fold `prototyping` into `workshop-facilitator` (treat Claude Design as a workshop surface) — *not* the discovery/story-shaping merge. The discovery↔story split is the seam the audience actually feels.

## Router-skill + worker-agent architecture

The four phase routers above are **router skills** that load into the main thread's context. Each owns a loop, picks the right capability skill, and delegates every unit of heavy work to a **worker agent** chosen for the unit. The PM's main thread loads a router skill via `Skill`; following that skill, the main thread spawns worker agents (backgrounded where possible). Two layers, each with a single concern:

| Layer | Role | Holds | Talks to |
|---|---|---|---|
| Main thread (executing a router skill) | Routes by phase, confirms preconditions, approves diffs, spawns workers | `Agent` tool + `Skill` tool, no MCP | Skills + worker agents |
| Worker agent | Executes one unit of work | Skill it needs + scoped MCP only when applicable | Returns final message only |

Canonical diagram + rationale: see this repo's README for the architecture diagram.

### Worker agent inventory

Workers live flat in `agents/` (agent discovery is non-recursive). Each is single-purpose, model-matched, and never spawns its own workers (no `Agent` tool).

| Worker | Model | Owns | MCP scope |
|---|---|---|---|
| `story-writer` | Sonnet | Expand **one** approved story stub → one full story `.md` file. Fanned out one-per-stub in parallel during seed. | none |
| `opportunity-writer` | Sonnet | Expand **one** approved tree-node stub (outcome or opportunity) → one node `.md` file. Fanned out one-per-node in parallel during OST seed. The OST analogue of `story-writer`. | none |
| `board-builder` | Sonnet | Build / refresh a Miro board from a sidecar | Miro MCP (project `.mcp.json`) |
| `absorb-interpreter` | Opus | Read a board, compute a propose-only diff, return diff path + flag count | Miro MCP (project `.mcp.json`) |
| `board-writer` | Sonnet | Apply a PM-approved diff back to a Miro board | Miro MCP (project `.mcp.json`) |
| `synthesis-worker` | Opus | Many interview transcripts → `synthesis.md` + OST inbox candidates | none |

**`story-writer` and `opportunity-writer` are the two fan-out workers — the only workers spawned multiply in parallel.** Both author independent files from settled stubs: a *map*. Story emission expands one stub per story; OST seed expands one node (outcome or opportunity) per file. In each case the main thread (following its router — `story-shaping` for stories, `discovery` for OST seed) spawns N workers as a parallel batch (single message, waves of ~10). Every other worker is spawned singly, for one of two reasons: it is gated on a single shared artifact (the board workers — one board, one sidecar, can't be parallelized without racing), or its value *is* seeing everything in one context (`synthesis-worker` is a *reduce* — splitting per-transcript would destroy the cross-cutting synthesis). The split that motivates both fan-out workers is plan-vs-prose: the main thread keeps the breakdown/tree plan (queryable "why"); the workers hold and shed the per-file prose (the file on disk is the record).

**Miro MCP registration:** by default the Miro MCP is registered at the **project level** in the project's `.mcp.json` (written by `/ee-pm:setup` §5). Only these three board workers actually *use* it — their `tools:` allowlists carry the explicit `mcp__miro-official__*` entries; the main thread and router skills never call the Miro tools directly, delegating every Miro touch to one of the three workers. The agents stay fully plugin-managed (no project-local copies) and auto-update with the plugin.

Each board worker also ships an inline `mcpServers:` block **commented out** in its frontmatter. That block is an optional advanced optimization: copy the agent into a project's `.claude/agents/` and uncomment it to load the Miro MCP *only inside that worker* (off the main thread, saving context tokens). It's off by default because Claude Code ignores `mcpServers` frontmatter on plugin-provided agents for security — it only takes effect on a project-local copy — and the local copy then stops auto-updating and needs bare-named spawns + a restart. See `docs/miro-setup.md` → "Optional: agent-scoped MCP" for the full trade-off.

### Model-matching rationale

Models are matched per worker to the cognitive load of the work. Router skills inherit the main thread's model — the cost knob is at the worker layer:

- **Opus** for judgment-heavy workers: `absorb-interpreter` (semantic diffing) and `synthesis-worker` (theme extraction across many transcripts).
- **Sonnet** for mechanical worker execution: `board-builder` and `board-writer` (deterministic skill execution), and `story-writer` / `opportunity-writer` (expanding a settled stub into a well-formed file — the judgment was spent in the main thread's plan phase, so the worker's job is mechanical).

A uniform model would either over-spend on mechanical board writes or under-resource semantic absorb interpretation. Per-worker matching avoids both.

### The two-call approval split

A worker agent cannot pause mid-run for PM approval — its only output is a final message. The router skill itself runs in the main thread, so it *can* pause for PM input between calls — that's the natural turn of the main thread. So absorb (the one phase that requires PM approval mid-loop) splits into two router-skill turns:

1. **Call 1 (propose):** main thread (following the router skill) spawns `absorb-interpreter` (background). It reads the board, writes a propose-only diff, returns the diff path + flag count. The main thread relays to the PM and stops.
2. *Main thread, between turns:* PM walks the diff, resolves flags, signals "go" with a structured `approvals` block.
3. **Call 2 (accept):** the router skill is re-entered with the diff path + approvals; the main thread spawns `board-writer` to apply the diff and run the skill's accept-mode repo writes.

This pattern is documented identically in `discovery` SKILL.md, `story-shaping` SKILL.md, and `workshop-facilitator` SKILL.md Rule §3. `prototyping` does not own absorb (its surface is human-mediated), so it does not run this split.

### When to invoke a skill bare vs. through a router skill

- **Bare skill, main thread**: one-shot, low-token, no Miro touch — `framework-setup`, `iteration-setup`. Invoke directly via `Skill`; no router-skill wrapper needed.
- **Router skill**: anything that runs a multi-skill loop, touches Miro, or needs the structured handoff payload. All four router skills above qualify when running their full loop.
- **Worker agent, spawned by the main thread (typically while executing a router skill)**: every unit of heavy work — board reads/writes, multi-transcript synthesis, long-thread digests. The router skill owns precondition checks and result relay.

## Cross-phase handoff payload

When one router skill hands off to another (e.g. `discovery` → `story-shaping`, or `workshop-facilitator` → `discovery` for synthesis), router context lives in the main thread, but worker final messages are the only outputs crossing the subagent boundary on each spawn. The receiving router skill cannot re-derive iteration state, board IDs, or upstream artifact paths by introspection — they must be carried explicitly across the seam.

The convention: when transitioning routers, the main thread carries a YAML-shaped `handoff:` block. The new router treats it as authoritative and does not re-confirm. When spawning a worker, the main thread also includes any relevant `handoff:` fields in the invocation prompt. Workers can include an updated `handoff:` block in their final message reflecting any new artifacts produced.

### Schema

```yaml
handoff:
  from: <router-name>           # workshop-facilitator | discovery | story-shaping | prototyping
  to: <router-name>
  iteration_slug: YYYY-MM-DD-{iteration-slug}    # required when iteration-bound; omit for product-context work
  scope: iteration | product-context              # which corner of the repo writes target

  # State produced upstream that the receiver needs.
  # Include only fields relevant to this seam — see "Per-seam contents" below.
  artifacts:
    synthesis_path:           product/iterations/<slug>/synthesis.md
    inbox_candidates_path:    product/context/opportunity-solution-tree/inbox/<slug>.md
    chosen_opportunity:
      slug:    {opportunity-slug}
      ref_id:  O-12
    converged_solution:
      one_liner:        <short intent>
      shape_notes_path: product/iterations/<slug>/solution.md
    story_map_path:           product/iterations/<slug>/story-map.md
    prototype_specs_dir:      product/iterations/<slug>/prototypes/
    ingested_handoff_dirs:    [product/iterations/<slug>/prototypes/<screen>/]

  # Miro identifiers — board IDs survive across calls and must be threaded through,
  # not re-discovered from sidecars on each invocation.
  boards:
    ost_board_id:           <board-id>
    story_map_board_id:     ...
    assumption_map_board_id: ...

  # Two-call absorb (intra-agent re-invocation). Present only when the orchestrator
  # is re-entering after the interactive thread approved a propose-only diff.
  pending_absorb:
    skill:        story-map | opportunity-tree | assumption-map
    diff_path:    product/iterations/<slug>/_absorb/<skill>/<timestamp>.diff.md
    approvals:    <structured approvals block, present on Call 2 only>

  # What the receiver should do first. Free text the receiver routes against
  # its phase table; not a skill name, so the receiver retains routing authority.
  next_action: "extract stories from the converged map and refine AC"
```

### Per-seam contents

| Seam | Required `artifacts` fields | Required `boards` fields |
|---|---|---|
| `workshop-facilitator` → `discovery` (synthesis) | (interview paths in `next_action` or implicit via iteration slug) | `ost_board_id` if OST refresh follows |
| `discovery` → `workshop-facilitator` (return from synthesis) | `synthesis_path`, `inbox_candidates_path` | — |
| `discovery` → `story-shaping` | `chosen_opportunity`, `converged_solution` | `ost_board_id` (for back-reference); `assumption_map_board_id` if relevant |
| `story-shaping` → `prototyping` | `prototype_specs_dir` | — |
| `prototyping` → `story-shaping` (return) | `ingested_handoff_dirs` | — |
| `workshop-facilitator` → `story-shaping` / `prototyping` | whichever upstream artifacts the next phase needs | whichever boards the next phase touches |
| Same router, Call 2 of absorb | `pending_absorb` (with `approvals`) | the relevant board ID |

### Rules

1. **Caller fills the payload; receiver does not re-confirm.** A receiver that finds a required field missing returns `precondition-unresolved` immediately (per each router skill's Rule §6) — it does not prompt for the missing value.
2. **Board IDs are authoritative when present.** The receiver must not re-look up board IDs from sidecars when the payload provides them. This avoids the canonical-vs-throwaway-board class of bugs.
3. **Workers do not see the full payload.** The main thread (following a router skill) consumes the `handoff:` block and passes only the fields the worker needs (e.g. `board-builder` gets the board ID and the source spec path, not the upstream synthesis path).
4. **The returned payload is additive.** A receiver returning control should emit an updated `handoff:` block that retains the inputs and adds whatever it produced.

## Build order

The agents do not all need to ship at once. `workshop-facilitator` exists. The other three are documented here as the target shape; they get built when you want to run a real iteration end-to-end.
