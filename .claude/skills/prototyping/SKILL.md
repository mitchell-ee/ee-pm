---
name: prototyping
description: Router skill for per-screen prototypes round-tripped between repo specs and an external prototyping surface (Claude Design primary; Magic Patterns stretch). Loads into the main thread's context when the user frames the request as prototyping work — briefing a tool, ingesting handoff output, refreshing a prototype after spec changes — rather than calling a specific capability skill.
---

# Prototyping (router skill)

Provides visual confirmation of stories. Takes per-screen specs from `product/iterations/<slug>/prototypes/` and runs them through an external prototyping surface, then ingests the surface's handoff back into the repo. Same four-piece pattern as the Miro skills (brief → external work → handoff → absorb), but on a non-MCP surface — the human moves bits between Claude Code and the prototyping surface manually.

These are instructions loaded into the main thread's context. The main thread follows this routing guide; it does not run as a separate subagent.

## Surfaces

- **Primary: Claude Design** (`claude-design` skill). Browser-driven on claude.ai/design. Ingests your design system as a linked reference (e.g. Equal Experts' Kuat). Handoff via CD's "Handoff to Claude Code" or zip download.
- **Stretch: Magic Patterns** (`magic-patterns` skill). Programmatic / API-driven specialty tool. Used only as second-path comparison to demonstrate the pattern generalizes across surfaces. Do not invoke unless explicitly asked for the comparison run.

## The loop

```
ENTRY
──────────────────────────
  Inputs: per-screen specs at product/iterations/<slug>/prototypes/<screen>.md
          and the chosen surface (CD by default)

PROTOTYPING (one cycle per surface)
──────────────────────────
  1. Brief the surface              skill writes the per-screen spec for handoff
  2. (External work)                human runs the surface; PM iterates on prototype
  3. Ingest handoff                 skill absorbs CD handoff / Magic Patterns export
                                    into product/iterations/<slug>/prototypes/<screen>/
  4. Refresh on spec change         re-brief surface with updated spec; re-ingest

EXIT (hand back to story-shaping)
──────────────────────────
  5. Fold into stories              hand back to story-management Mode 4 (align) with
                                    prototypes/ as a source — attaches prototype_refs,
                                    refines AC, and proposes NEW stories for flows the
                                    design surfaced that no story covers. Writes to
                                    stories/ directly; no board step required.
```

The prototype loop is a requirement-surfacing activity like story-mapping — its findings land in the canonical story files via step 5, not by detouring through a board sticky. Refresh the story map from the files afterward only if the board still needs to be current.

## Worker spawns

None. The prototyping surfaces are non-MCP and human-mediated; the `claude-design` and `magic-patterns` skills run inline in the main thread's context. There is no Miro round-trip and no transcript-scale ingestion that warrants backgrounded workers.

## Phase routing table

| User intent | Phase | Skill to invoke |
|---|---|---|
| "Prototype these screens" / "brief Claude Design for X" | Brief (primary) | `claude-design` |
| "Refresh the prototype after the spec changed" | Refresh (primary) | `claude-design` |
| "Import the Claude Design handoff back into the repo" | Ingest (primary) | `claude-design` |
| "Fold the prototype back into the stories" / "did the design surface new stories?" | Fold into stories (exit) | `story-management` (Mode 4, align) |
| "Run the same prototype through Magic Patterns for comparison" | Stretch comparison | `magic-patterns` |

## Rules

1. **Claude Design is the primary surface.** Default there unless the user explicitly asks for Magic Patterns.
2. **Always reference your design system for any UI decision.** Load your design system's rules/tokens directory (or a design-guidelines doc) before authoring per-screen specs or making color/typography/spacing choices — e.g. if using Equal Experts' Kuat, `node_modules/@equal-experts/kuat-core/agent-docs/`. CD ingests the design system at project creation; Claude Code uses the locally available rules.
3. **Specs live in the repo,** prototypes are external. The repo is the source of truth for intent; the surface is the source of truth for visual output until ingested.
4. **Ingest before re-briefing.** If the surface has produced output that hasn't been absorbed, ingest first so the next brief reflects the converged state.
5. **Magic Patterns only on explicit request.** It exists as comparison evidence for the "lowest-level capable tool" point; it is not part of the default loop.
6. **Preconditions are caller-passed.** Iteration slug, target screen list, chosen surface, and any human-in-the-loop choices must be resolved before following this skill. If a required precondition is missing, ask the PM the specific question rather than guessing defaults.
7. **Surface skills run inline; no worker delegation.** `claude-design` and `magic-patterns` are skills invoked directly by the main thread — there is no equivalent of `board-builder` here, because the surfaces are human-mediated rather than MCP-driven.

## Handoff payload

Schema: `.claude/agents/README.md` § "Cross-agent handoff payload".

**Consumes** (from `story-shaping` or interactive thread):
- `iteration_slug`, `scope`
- `artifacts.prototype_specs_dir` (or specific per-screen spec paths in `next_action`)
- Choice of surface (`claude-design` default; `magic-patterns` only on explicit request)

**Emits** (back to `story-shaping` or caller):
- `artifacts.ingested_handoff_dirs` — one entry per screen ingested

No `boards.*` fields apply (non-MCP surface).

## What this skill does NOT route to

- Story writing or AC refinement — hand off to `story-shaping`.
- Discovery work — hand off to `discovery`.
- Programmatic interaction with the prototyping surface beyond what the skill does. Browser handoff is human-mediated.
- Improvised UI when the design system's coverage is unclear — ask before deviating from the design system.

## Related resources

- `CLAUDE.md` — your design system's rules entrypoints and component-selection order (e.g. Equal Experts' Kuat).
- `.claude/agents/README.md` — why prototyping is its own router (and the fallback collapse path if legibility forces three).
- `.claude/skills/claude-design/SKILL.md` — primary surface.
- `.claude/skills/magic-patterns/SKILL.md` — stretch comparison surface.
- your design system's rules/tokens directory — e.g. if using Equal Experts' Kuat, `node_modules/@equal-experts/kuat-core/agent-docs/README.md` (the Kuat bundle index).
