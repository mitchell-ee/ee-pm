# Story Numbering Rules

Story numbers are **globally unique** across ALL iterations and **never reset**.

## Format

`STORY-NNNN` where NNNN is a **zero-padded four-digit** number (e.g., STORY-0001, STORY-0045,
STORY-0123). Every ee-pm artifact type uses the same width — `OUTCOME-`, `OPP-`, `SOL-`,
`ASSUMPTION-`, `EPIC-`, `TASK-` — so an ID is recognizable by shape alone.

**Widened from three digits in 0.6.0**, for two reasons: ee-pm was inconsistent with itself
(`OPP-01` beside `STORY-012`), and four digits is what the context-mesh vocabulary specifies, so
a project using both plugins doesn't carry two ID conventions.

### Reading a domain-prefixed ID

In a context-mesh Hub an artifact may be written `payments:STORY-0001` — the prefix names the
domain that owns it. **Accept that form when reading; never emit it.** An ee-pm project is a
single product with no domains, so emitting a prefix would invent one. A regex that parses IDs
should treat the prefix as optional:

```
^([a-z0-9][a-z0-9-]*:)?STORY-\d{4}$
```

## Rules

1. **Sequential across iterations**: A story created today might follow one created months ago in a different iteration
2. **Never reset**: Story numbers only increase, never restart at 0001
3. **Globally unique**: No two stories ever share the same number
4. **Permanent**: Once assigned, a story number is never reused (even if story is deleted)

## Finding the Next Number

Before creating any stories, determine the next available number:

1. **Scan ALL iterations**: Check `product/iterations/*/stories/` across every iteration
2. **Find highest number**: Identify the maximum STORY-NNNN in use
3. **Cross-check backlog**: Verify against `product/backlog.md`
4. **Start at next**: New stories begin at (highest + 1)

### Using the Script

```bash
./scripts/find-highest-story.sh
```

Returns the highest story number found, or 0 if none exist.

## Example

```
product/iterations/
├── 2025-11-12-mvp/stories/
│   ├── story-0019-welcome-screen.md      # STORY-0019
│   ├── story-0020-q1-atmosphere.md       # STORY-0020
│   └── ...
│   └── story-0044-accessibility.md       # STORY-0044
├── 2025-12-02-admin-page/stories/
│   ├── story-0045-admin-overview.md      # STORY-0045 (continues from 044)
│   └── story-0046-export-csv.md          # STORY-0046
└── 2025-12-08-new-feature/stories/
    └── story-0047-dark-mode.md           # STORY-0047 (continues from 046)
```

## Why This Matters

- **Traceability**: Story IDs uniquely identify work items across the entire product history
- **Issue tracker sync**: IDs map 1:1 with Jira/GitHub issue numbers
- **Release tracking**: Releases reference story IDs without ambiguity
- **Cross-iteration references**: Stories can reference each other without confusion
