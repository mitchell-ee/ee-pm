# Skills

The skill pack for the Visual Collaboration with AI workflow. Each skill is self-contained. **Router skills** load into the main thread and organize the others by PM phase; **capability skills** do one artifact type each. The router skills know which capability skill to invoke at which phase — see `.claude/agents/README.md` for the full shape.

## Router skills

| Skill | Phase | Owns |
|---|---|---|
| `workshop-facilitator` | Live workshop | Intake → map → discuss → absorb → handoff loop |
| `discovery` | Discovery | `interview-management`, `discovery-synthesis`, `opportunity-tree`, `assumption-map` |
| `story-shaping` | Story shaping | `story-management`, `story-map`, `backlog-management` |
| `prototyping` | Prototyping | `claude-design`, `magic-patterns` |

## Capability skills

| Skill | Does |
|---|---|
| `framework-setup` | One-shot: establish `product/context/` for a new project |
| `iteration-setup` | One-shot per iteration: scaffold `product/iterations/{YYYY-MM-DD-slug}/` |
| `interview-management` | Capture and manage discovery interview transcripts |
| `discovery-synthesis` | Synthesize interviews into themes + opportunity/solution candidates |
| `opportunity-tree` | Build / read / absorb a Teresa Torres opportunity solution tree on Miro |
| `assumption-map` | Build / read / absorb a Torres assumption map (importance × evidence 2×2) on Miro |
| `story-map` | Build / read / absorb a Jeff Patton story map on Miro |
| `story-management` | Create, finalize, and batch-shape user stories with acceptance criteria |
| `backlog-management` | Maintain the cross-iteration backlog |
| `claude-design` | Round-trip per-screen prototype specs to a Claude Design project (primary prototyping surface) |
| `magic-patterns` | Second-path prototyping comparison (stretch) |

## The Miro three-piece pattern

`opportunity-tree`, `assumption-map`, and `story-map` all follow the same build → collaborate → read-back → interpret loop, and share the connector REST scripts bundled under `opportunity-tree/scripts/`. `opportunity-tree` is therefore a required sibling of the other two board skills. See `docs/miro-setup.md` for the Miro auth paths.
