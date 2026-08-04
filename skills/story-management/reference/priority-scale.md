# Priority Scale

Four-level priority scale for user stories and backlog items. **This is the single definition** —
`backlog-management`, `story-map`, and the story templates all reference it rather than restating
it.

## Priority Levels

| Priority | Description | Examples |
|----------|-------------|----------|
| **P0** | Core functionality that blocks release. Without these, the product cannot ship. | Login, core workflow, data persistence |
| **P1** | Important features with strong business value. Should be built if time allows. | Key user workflows, performance improvements |
| **P2** | Nice-to-have features with lower urgency. Adds polish but not essential. | UI enhancements, convenience features |
| **P3** | Deferred items that may not be built. Consider for future iterations. | Edge cases, advanced features |

## MoSCoW Mapping

When converting from MoSCoW prioritization:

| MoSCoW Term | Maps To | Notes |
|-------------|---------|-------|
| Must Have | P0 | Non-negotiable for release |
| Should Have | P1 | Important but not blocking |
| Nice to Have | P2 | Adds value, lower priority |
| Could Have | P3 | May be deferred indefinitely |
| Won't Have | N/A | Not a priority level - explicit scope exclusion |

## Won't Have (Out of Scope)

"Won't Have" is **not a priority level**. It represents explicit scope exclusions documented within stories as acceptance criteria:

```markdown
## Acceptance Criteria

### Won't Have (Out of Scope)
- Admin users cannot delete other admin accounts
- No bulk export to PDF (only CSV supported)
- Multi-language support is not included
```

Use "Won't Have" sections to:
- Clarify boundaries to prevent scope creep
- Document conscious decisions about what's excluded
- Set expectations for stakeholders

## Story Map Swim Lanes

When creating Miro story maps, priorities map to swim lanes:

| Swim Lane | Priorities | Meaning |
|-----------|------------|---------|
| NOW | P0, P1 | Build in current/next iteration |
| NEXT | P2 | Build after NOW items complete |
| LATER | P3 | Backlog for future consideration |

**The mapping is lossy in reverse.** NOW collapses P0 and P1, so a board read cannot tell which a
NOW story is. See `${CLAUDE_PLUGIN_ROOT}/skills/story-map/reference/read-board-state.md` for how absorb resolves this: a story
already at P0 or P1 keeps its priority, and one promoted into NOW from NEXT/LATER defaults to
**P1** with a flag for the PM to raise it to P0.

## Legacy scale

Projects created before this scale used **Critical / High / Medium / Low**, mapping
Critical→P0, High→P1, Medium→P2, Low→P3. `setup` §7 migrates them
(`${CLAUDE_PLUGIN_ROOT}/skills/setup/migrations/0.7.0-priority-p0p3.sh`); `read-board-state.md`'s sticky parser tolerates the old
words on boards built before the change.

## Usage Guidelines

1. **New stories** should have priority assigned at creation
2. **Priorities can change** as business context evolves
3. **P0 items** require explicit justification (why is this blocking?)
4. **P3 priority** doesn't mean "bad idea" - just lower urgency
5. **Backlog grooming** should regularly reassess priorities
