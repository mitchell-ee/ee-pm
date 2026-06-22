---
name: magic-patterns
description: STRETCH — second-path prototyping comparison against `claude-design`. Demonstrates the same prototyping pattern works on a programmatic / API-driven specialty surface. Primary prototyping surface is `claude-design`; do not invoke this unless the user explicitly asks for a Magic Patterns comparison run.
tags: [prototyping, magic-patterns, ui, stretch, comparison]
---

# Magic Patterns Skill — STRETCH (second-path comparison)

This skill exists to provide a programmatic / API-driven counter-example to `claude-design` — evidence that the same prototyping pattern generalizes beyond the foundation LLM platform to a specialty tool.

## Status

Stub. The Magic Patterns integration is a stretch capability and is not yet implemented here.

## Why this is stretch, not primary

`claude-design` is the primary prototyping path — the foundation LLM platform covers prototyping with no separate specialty subscription. Magic Patterns is the *honest comparison case*: a programmatic / API-driven specialty tool that does similar work via a paid integration.

If both paths land:

- You can show "we tried both" — same per-screen spec, two prototyping surfaces.
- The lowest-level-capable-tool point has explicit evidence rather than a verbal claim.

If only `claude-design` lands:

- Cite Magic Patterns verbally as the alternative path; the comparison stays narrative.
- The lowest-level-capable-tool point still holds, just without side-by-side artifacts.

## What's needed when this is ported

When implementing this skill, add:

- A `brief` mode that consumes the same per-screen spec format used by `claude-design` (so the comparison is fair — same input, different surface).
- An `import` mode that lands output in a sibling directory: `product/iterations/{cycle}/prototypes-mp/{screen}/`. Keeps the comparison side-by-side and avoids overwriting `claude-design` outputs.
- The same **post-import handback** `claude-design` carries: after ingest, point the PM at `story-management` Mode 4 (align) with the prototype dir as a source, so flows the design surfaced that no story covers become new stories (written to `stories/`, no board step). Mirror this verbatim from `claude-design`'s "Next step after import" so both surfaces fold back into the canonical story files identically.
- A direct reference to `claude-design`'s SKILL.md so the comparison framing is explicit on both sides.

## Do not invoke until ported

The `workshop-facilitator` agent should refuse Magic Patterns prototyping requests until this file is replaced, with message: "Magic Patterns is a stretch second-path comparison and isn't ported yet. Use `claude-design` for primary prototyping; ask the user if a Magic Patterns comparison run is needed."

## Related skills

- `claude-design` — primary prototyping surface; same four-piece pattern, browser-driven instead of API-driven.
