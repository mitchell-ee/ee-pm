<!-- BEGIN ee-pm v{{VERSION}} -->
# EE PM Workflow — workflow conventions

This project uses the **EE PM Workflow** plugin (`ee-pm`) — a portable workflow for AI-assisted, human-led product management across discovery and delivery. The conventions below tell the LLM how to work within it. The skills and worker agents are provided by the plugin and invoked as `/ee-pm:<skill>`.

## Guiding principles

1. **Portability first.** Any PM should be able to follow this approach with the LLM of their choice. Anything specific to one LLM harness should be replaceable; conventions, prompts, and small scripts are the primary artifacts.
2. **Minimize custom code.** Prefer skills, prompts, and conventions. Small scripts bundled inside skills are acceptable when determinism or speed requires them. Do not introduce library-scale code (typed models, packaged SDKs, custom MCP servers).
3. **Skill-first orchestration.** Each artifact type gets its own capability skill. Router skills organize capability skills by PM phase and know when to invoke which — see the four-router shape (`workshop-facilitator`, `discovery`, `story-shaping`, `prototyping`).
4. **Miro via the official MCP.** Board interactions go through the official Miro MCP at `mcp.miro.com` (`mcp__miro-official__*`) — its layout DSL covers everything the workflow needs: `layout_get_dsl` / `layout_create` / `layout_read` / `layout_update` build and read frames, stickies, shapes, text, cards, docs, tables, **and connectors** (the DSL has a first-class `CONNECTOR` type). One credential (the MCP's OAuth-at-connect), no REST scripts and no second token. Do not design around a custom sync server.

## Phase routers and worker agents

Phases are organized by **how a PM adopts the work**. Each phase is a **router skill** that loads into the main thread's context; heavy units of work delegate to **worker agents**. Subagents cannot spawn other subagents, so routing has to live in the main thread.

Router skills:
- `workshop-facilitator` — live workshop router
- `discovery` — interviews, synthesis, opportunity tree, assumption map
- `story-shaping` — story management (create + finalize), story map, backlog
- `prototyping` — Claude Design (primary), Magic Patterns (stretch)

Worker agents: `board-builder`, `absorb-interpreter`, `board-writer`, `synthesis-worker`, `story-writer`.

## Schema version — check before operating on `product/`

The marker at the top of this block (`<!-- BEGIN ee-pm v{{VERSION}} -->`) records the **schema
version this project's artifacts are written in**.

**Every ee-pm skill checks it before reading or writing anything under `product/`:**

1. Read the version from the marker above. No version on the marker means the project predates
   the convention — treat it as `0.5.0`.
2. Compare to the plugin's `version` in `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.
   That file ships **with the plugin**, not in this project — resolve it under
   `${CLAUDE_PLUGIN_ROOT}` (the plugin's install directory), never against the project root.
3. **If the project's version is older, stop.** Say which version the project is on and which the
   plugin is, and tell the PM to run `/ee-pm:setup` to migrate. Do not read or write `product/`
   artifacts in the meantime.

This exists because a plugin cannot run anything when it is updated. Without the check, an
updated plugin writes new-convention data into a project full of old-convention data and the
mismatch surfaces later as corrupted artifacts — a stale Miro sidecar reads as "every node is
new", which silently proposes recreating a board that already exists. Stopping loudly is the
whole point; a skill that quietly operates on stale data is the failure this prevents.

`/ee-pm:setup` is exempt — migrating is its job. Skills that touch nothing under `product/` are
also exempt.

## Artifact storage convention

PM artifacts live under `product/`:
- **`product/{artifact}`** — durable cross-iteration context, directly under `product/`: `personas/{slug}.md` (one file each), `assumptions/`, `opportunity-solution-tree/`, `assumption-maps/`, `backlog.md`, `design-principles.md`, `glossary.md`. Create what your practice produces; none is required.
- `product/iterations/{YYYY-MM-DD-iteration-slug}/` — per-iteration work (interviews, synthesis, stories, story-maps, prototypes, decisions).

There is **no `product/context/` layer** — durable context sits directly under `product/`. (It existed through 0.5.x; `/ee-pm:setup` migrates the old layout.)

Each Miro artifact keeps its own sidecar (`miro-metadata.json`) recording the board ID and the shape/connector IDs the absorb pass diffs against. Sidecars are per artifact, never nested.

## Design system (optional)

**If this project has a design system**, the prototyping skills (`prototyping`, `claude-design`) reference it for UI decisions — color, typography, spacing, layout, component selection — rather than improvising. Record where it lives:

- **Local rules (spec authoring):** path to the design system's rules/tokens directory or a design-guidelines doc.
- **Claude Design:** the linked design-system project in claude.ai/design, if one is published. Publishing a repo-resident design system is `/design-sync`'s job, not this plugin's.

If a UI need isn't covered by the loaded rules, ask before improvising.

**If this project has no design system**, the prototyping skills still work — specs describe intent, and UI choices are made in the prototyping surface. Creating a design system is out of scope for this plugin.

## Working style

- Plan before implementation; work iteratively, one section at a time.
- When designing green-field capability (structural-diff reverse sync, semantic interpretation, board layout), propose the approach in markdown before committing to coordinate math or large code blocks.
- Prefer reusing working skill content verbatim over rewriting for style.
<!-- END ee-pm -->
