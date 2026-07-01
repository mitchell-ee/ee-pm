# EE PM Workflow

A repeatable, portable set of skills and agents for **AI-assisted, human-led product management** across discovery and delivery. It lets a PM and an LLM work together end to end — interviews and synthesis, opportunity solution trees, assumption maps, story maps and stories, backlog, prototypes, and live workshop facilitation — with the human leading and the LLM doing the heavy, mechanical, and synthesis-shaped work. Several of these artifacts are visual surfaces (Miro boards, Claude Design prototypes) the PM and LLM round-trip together.

This is **not a product or a packaged tool.** It's a set of conventions, prompts, and small scripts you adopt into your own LLM coding environment. The design goal is portability: bring your own LLM, your own Miro account, your own design system.

## What it does

The workflow centers on a repeatable four-piece pattern, instantiated across surfaces:

1. **Build** a visual artifact (a Miro board, a Claude Design prototype) from plain-text repo state.
2. **Collaborate** — humans rearrange, add, and edit directly on the visual surface.
3. **Read back** the human changes as a structural diff against a saved sidecar.
4. **Interpret** what the changes *mean* and propose repo updates — the human approves, then the changes are written back.

The same shape covers three Miro artifacts (opportunity solution tree, assumption map, story map) and the Claude Design prototyping loop.

## The four PM phases

Work is organized by **how a PM adopts it**, not by tool. Each phase is a *router skill* that loads into your LLM's main thread and delegates heavy work to *worker agents*:

| Phase | Skill | Covers |
|---|---|---|
| Workshop | `workshop-facilitator` | Live workshop loop: intake → map → discuss → absorb → handoff |
| Discovery | `discovery` | Interviews, synthesis, opportunity trees, assumption maps |
| Story shaping | `story-shaping` | Stories, acceptance criteria, story maps, backlog |
| Prototyping | `prototyping` | Per-screen specs round-tripped to Claude Design (or Magic Patterns) |

`framework-setup` and `iteration-setup` are one-shot setup skills.

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│  Main thread (PM ↔ LLM)                                        │
│  Uses: Agent tool · Skill tool · Read/Write/Bash (no Miro MCP) │
└──────────────┬──────────────────────────────┬─────────────────┘
               │ load a router skill          │ spawn a worker agent
               ▼                              ▼
┌──────────────────────────────┐   ┌──────────────────────────────┐
│  Phase-router SKILLS         │   │  Worker AGENTS (leaves)      │
│  skills/                     │   │  agents/                     │
│   workshop-facilitator       │   │   board-builder       (MCP)  │
│   discovery                  │   │   absorb-interpreter  (MCP)  │
│   story-shaping              │   │   board-writer        (MCP)  │
│   prototyping                │   │   synthesis-worker           │
│                              │   │   story-writer               │
│  Route intent → invoke a     │   │  Single-purpose, model-      │
│  capability skill + tell the │   │  matched, no nested spawn.   │
│  main thread which worker    │   │  Miro MCP used by the 3      │
│  to spawn                    │   │  board workers only.         │
└──────────────┬───────────────┘   └──────────────────────────────┘
               │ invoke a capability skill
               ▼
┌──────────────────────────────────────────────────────────────┐
│  Capability SKILLS                                            │
│  story-map · opportunity-tree · assumption-map ·             │
│  story-management · claude-design · magic-patterns · …       │
└──────────────────────────────────────────────────────────────┘
```

Routing lives in the main thread (as a loaded skill) because subagents can't spawn other subagents. See `agents/README.md` for the full worker inventory, model-matching rationale, and the two-call approval split.

## Getting started

This repo is a **Claude Code plugin** (`ee-pm`). Skills install namespaced as `/ee-pm:<skill>`.

1. **Install the plugin.** Point your Claude Code at this repo — `claude --plugin-dir /path/to/ee-pm` for local use, or install it from a marketplace. (The skills and conventions are the portable core; if you use a different LLM coding environment, adapt the harness glue — agent frontmatter, MCP registration — to your tool.)
2. **Scaffold your project.** Run `/ee-pm:setup` once. It creates the `product/` artifact tree and adds the workflow conventions to your project's `CLAUDE.md`. It's non-destructive and safe to run in an existing repo — it reports what it'll do and never overwrites your files.
3. **Connect Miro.** See [`docs/miro-setup.md`](docs/miro-setup.md) — the board workers use the official hosted Miro MCP (OAuth at connect), plus thin REST scripts for connectors.
4. **Bring your design system.** The prototyping skills reference a design system for any UI decision. They ship with Equal Experts' Kuat as a worked example; point them at your own design-system rules and your own Claude Design linked project.
5. **Work iteratively.** Run `/ee-pm:framework-setup` once to establish product context, then `/ee-pm:iteration-setup` per iteration. Your PM artifacts live under `product/`.

## Plugin layout

```
.claude-plugin/
└── plugin.json    plugin manifest (name: ee-pm)
skills/            router skills + capability skills (incl. setup)
agents/            worker agents (+ README with the architecture detail)
scripts/           shared Miro REST helpers (connectors, board copy)
docs/
├── miro-setup.md           connect the hosted Miro MCP
└── adding-a-board-type.md  extend the workflow with a new Miro artifact
```

`/ee-pm:setup` generates `product/` and the conventions block in `CLAUDE.md` **in your project**, not here.

## Extending

To add a fourth Miro board type (beyond opportunity tree, assumption map, and story map) that follows the same build → collaborate → read-back → interpret loop, see [`docs/adding-a-board-type.md`](docs/adding-a-board-type.md).

## What's portable, what you swap

- **Portable as-is:** the skills, worker agents, conventions, the absorb/diff logic, the connector REST scripts.
- **You provide:** your LLM environment, your Miro account + OAuth, your design system (rules + Claude Design project).

No custom MCP server, no library or SDK. Small scripts are bundled inside skills only where determinism requires them.
