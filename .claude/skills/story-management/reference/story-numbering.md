# Story Numbering Rules

Story numbers are **globally unique** across ALL iterations and **never reset**.

## Format

`STORY-XXX` where XXX is a zero-padded three-digit number (e.g., STORY-001, STORY-045, STORY-123)

## Rules

1. **Sequential across iterations**: A story created today might follow one created months ago in a different iteration
2. **Never reset**: Story numbers only increase, never restart at 001
3. **Globally unique**: No two stories ever share the same number
4. **Permanent**: Once assigned, a story number is never reused (even if story is deleted)

## Finding the Next Number

Before creating any stories, determine the next available number:

1. **Scan ALL iterations**: Check `product/iterations/*/stories/` across every iteration
2. **Find highest number**: Identify the maximum STORY-XXX in use
3. **Cross-check backlog**: Verify against `product/context/backlog.md`
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
│   ├── story-019-welcome-screen.md      # STORY-019
│   ├── story-020-q1-atmosphere.md       # STORY-020
│   └── ...
│   └── story-044-accessibility.md       # STORY-044
├── 2025-12-02-admin-page/stories/
│   ├── story-045-admin-overview.md      # STORY-045 (continues from 044)
│   └── story-046-export-csv.md          # STORY-046
└── 2025-12-08-new-feature/stories/
    └── story-047-dark-mode.md           # STORY-047 (continues from 046)
```

## Why This Matters

- **Traceability**: Story IDs uniquely identify work items across the entire product history
- **Issue tracker sync**: IDs map 1:1 with Jira/GitHub issue numbers
- **Release tracking**: Releases reference story IDs without ambiguity
- **Cross-iteration references**: Stories can reference each other without confusion
