<!-- BEGIN ee-pm -->
# EE PM Workflow — workflow conventions

This project uses the **EE PM Workflow** plugin (`ee-pm`) — a portable workflow for AI-assisted, human-led product management across discovery and delivery. The conventions below tell the LLM how to work within it. The skills and worker agents are provided by the plugin and invoked as `/ee-pm:<skill>`.

## Guiding principles

1. **Portability first.** Any PM should be able to follow this approach with the LLM of their choice. Anything specific to one LLM harness should be replaceable; conventions, prompts, and small scripts are the primary artifacts.
2. **Minimize custom code.** Prefer skills, prompts, and conventions. Small scripts bundled inside skills are acceptable when determinism or speed requires them. Do not introduce library-scale code (typed models, packaged SDKs, custom MCP servers).
3. **Skill-first orchestration.** Each artifact type gets its own capability skill. Router skills organize capability skills by PM phase and know when to invoke which — see the four-router shape (`workshop-facilitator`, `discovery`, `story-shaping`, `prototyping`).
4. **Miro via the native toolchain: official MCP + REST scripts.** Board interactions go through the official Miro MCP at `mcp.miro.com` (`mcp__miro-official__*`) for everything its layout DSL covers — `layout_create` / `layout_read` / `layout_update` build and read frames, stickies, shapes, text, cards, docs, and tables. The DSL has no connector type, so connector create/read/update goes through thin REST scripts (`read-connectors.sh`, `write-connectors.sh`) plus `miro-copy-board.sh` for board copies; these ship with the plugin (referenced as `${CLAUDE_PLUGIN_ROOT}/scripts/`) and are shared by the board skills. Do not design around a custom sync server.

## Phase routers and worker agents

Phases are organized by **how a PM adopts the work**. Each phase is a **router skill** that loads into the main thread's context; heavy units of work delegate to **worker agents**. Subagents cannot spawn other subagents, so routing has to live in the main thread.

Router skills:
- `workshop-facilitator` — live workshop router
- `discovery` — interviews, synthesis, opportunity tree, assumption map
- `story-shaping` — story management (create + finalize), story map, backlog
- `prototyping` — Claude Design (primary), Magic Patterns (stretch)

Worker agents: `board-builder`, `absorb-interpreter`, `board-writer`, `synthesis-worker`, `story-writer`.

## Artifact storage convention

PM artifacts live under `product/`:
- `product/context/` — durable cross-iteration artifacts (personas, backlog, opportunity-solution-tree, assumption-maps).
- `product/iterations/{YYYY-MM-DD-iteration-slug}/` — per-iteration work (interviews, synthesis, stories, story-maps, prototypes, decisions).

Each Miro artifact keeps its own sidecar (`miro-metadata.json`) recording the board ID and the shape/connector IDs the absorb pass diffs against. Sidecars are per artifact, never nested.

## Design system

The prototyping skills (`prototyping`, `claude-design`) reference a design system for **any** UI decision — color, typography, spacing, layout, component selection. This is a deliberate guardrail: the LLM should never improvise UI when the design system covers it.

The skills ship with **Equal Experts' Kuat** as a concrete worked example, but the design system is **swappable**. To use your own:
- **Local rules (spec authoring):** point the skills at your design system's rules/tokens directory or a design-guidelines doc.
- **Claude Design (browser):** link *your* design system's project in claude.ai/design, the same way the example links the "Kuat Design System" project.

If a UI need isn't covered by your loaded design-system rules, ask before improvising.

## Working style

- Plan before implementation; work iteratively, one section at a time.
- When designing green-field capability (structural-diff reverse sync, semantic interpretation, board layout), propose the approach in markdown before committing to coordinate math or large code blocks.
- Prefer reusing working skill content verbatim over rewriting for style.
<!-- END ee-pm -->
