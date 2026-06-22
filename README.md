# Visual Collaboration with AI — Workflow

A repeatable, portable set of skills and agents for **LLM-assisted, human-led visual collaboration** in product management. It lets a PM and an LLM work together on the visual artifacts of discovery and delivery — opportunity solution trees, assumption maps, story maps, and prototypes — with the human leading and the LLM doing the heavy, mechanical, and synthesis-shaped work.

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
│  Holds: Agent tool · Skill tool · Read/Write/Bash · NO MCP     │
└──────────────┬──────────────────────────────┬─────────────────┘
               │ load a router skill          │ spawn a worker agent
               ▼                              ▼
┌──────────────────────────────┐   ┌──────────────────────────────┐
│  Phase-router SKILLS         │   │  Worker AGENTS (leaves)      │
│  .claude/skills/             │   │  .claude/agents/             │
│   workshop-facilitator       │   │   board-builder       (MCP)  │
│   discovery                  │   │   absorb-interpreter  (MCP)  │
│   story-shaping              │   │   board-writer        (MCP)  │
│   prototyping                │   │   synthesis-worker           │
│                              │   │   story-writer               │
│  Route intent → invoke a     │   │  Single-purpose, model-      │
│  capability skill + tell the │   │  matched, no nested spawn.   │
│  main thread which worker    │   │  Miro MCP scoped to the 3    │
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

Routing lives in the main thread (as a loaded skill) because subagents can't spawn other subagents. See `.claude/agents/README.md` for the full worker inventory, model-matching rationale, and the two-call approval split.

## Getting started

1. **Pick your LLM coding environment.** The skills and agents are written for an environment that supports a skill/agent model and tool delegation. The conventions and prompts are the portable core — adapt the harness-specific glue (agent frontmatter, MCP registration) to your tool.
2. **Connect Miro.** See [`docs/miro-setup.md`](docs/miro-setup.md) — the board workers use the official hosted Miro MCP (OAuth at connect), plus thin REST scripts for connectors.
3. **Bring your design system.** The prototyping skills reference a design system for any UI decision. They ship with Equal Experts' Kuat as a worked example; point them at your own design-system rules and your own Claude Design linked project.
4. **Scaffold a project.** Use `framework-setup` once, then `iteration-setup` per iteration. Your PM artifacts live under `product/` (empty scaffold included).

## Repo layout

```
.claude/
├── skills/        router skills + capability skills
└── agents/        worker agents (+ README with the architecture detail)
docs/
└── miro-setup.md  connect the hosted Miro MCP
product/           your PM artifacts (empty scaffold)
CLAUDE.md          project instructions for the LLM
```

## What's portable, what you swap

- **Portable as-is:** the skills, worker agents, conventions, the absorb/diff logic, the connector REST scripts.
- **You provide:** your LLM environment, your Miro account + OAuth, your design system (rules + Claude Design project).

No custom MCP server, no library or SDK. Small scripts are bundled inside skills only where determinism requires them.
