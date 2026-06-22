# Priority Scale

Four-level priority scale for user stories and backlog items.

## Priority Levels

| Priority | Description | Examples |
|----------|-------------|----------|
| **Critical** | Core functionality that blocks release. Without these, the product cannot ship. | Login, core workflow, data persistence |
| **High** | Important features with strong business value. Should be built if time allows. | Key user workflows, performance improvements |
| **Medium** | Nice-to-have features with lower urgency. Adds polish but not essential. | UI enhancements, convenience features |
| **Low** | Deferred items that may not be built. Consider for future iterations. | Edge cases, advanced features |

## MoSCoW Mapping

When converting from MoSCoW prioritization:

| MoSCoW Term | Maps To | Notes |
|-------------|---------|-------|
| Must Have | Critical | Non-negotiable for release |
| Should Have | High | Important but not blocking |
| Nice to Have | Medium | Adds value, lower priority |
| Could Have | Low | May be deferred indefinitely |
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
| NOW | Critical, High | Build in current/next iteration |
| NEXT | Medium | Build after NOW items complete |
| LATER | Low | Backlog for future consideration |

## Usage Guidelines

1. **New stories** should have priority assigned at creation
2. **Priorities can change** as business context evolves
3. **Critical items** require explicit justification (why is this blocking?)
4. **Low priority** doesn't mean "bad idea" - just lower urgency
5. **Backlog grooming** should regularly reassess priorities
