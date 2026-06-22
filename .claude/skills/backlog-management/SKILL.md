---
name: backlog-management
description: Manage product backlog including adding stories, removing stories, viewing/filtering backlog, and updating story priorities
---

# Backlog Management Skill

## Purpose

This skill manages the product backlog stored in `product/context/backlog.md`. It supports adding new stories, removing obsolete stories, viewing/filtering the backlog, and updating story priorities. Stories carry optional `epic:` frontmatter — the backlog surfaces this as a filter and as a group-by-epic render toggle (no structural change to the backlog file itself).

## Modes

### Mode 1: Add Story

Add a new story to the backlog.

**Workflow:**
1. Read current backlog: `product/context/backlog.md`
2. Validate story has required fields:
   - Story ID (STORY-XXX format)
   - Title
   - Description
   - Priority (P0, P1, P2, P3)
   - Status (typically "Backlog" for new stories)
3. Check for duplicate story IDs
4. Insert story in correct priority order within the appropriate status section
5. Update backlog file
6. Confirm story added with ID and priority

**Input Requirements:**
- Story ID or generate next available ID
- Story title and description
- Priority level
- Optional: Epic, tags, dependencies

### Mode 2: Remove Story

Remove a story from the backlog.

**Workflow:**
1. Read current backlog: `product/context/backlog.md`
2. Find story by ID or title
3. Confirm story details before removal
4. Remove story from backlog
5. Update backlog file
6. Confirm story removed with reason (completed, deprecated, duplicate)

**Input Requirements:**
- Story ID or unique title match
- Reason for removal

### Mode 3: View/Filter Backlog

View backlog with optional filtering.

**Workflow:**
1. Read current backlog: `product/context/backlog.md`
2. Apply filters if specified:
   - By priority (P0, P1, P2, P3 — or Critical/High/Medium/Low if the backlog uses named priorities)
   - By status (Backlog, In Progress, Blocked)
   - By epic (reads the `epic:` frontmatter field on each story)
   - By iteration
   - By tag
3. Support a **group-by-epic** toggle: when enabled, render stories clustered under their epic headings; stories without an epic are rendered under "(no epic)".
4. Format output as readable list
5. Show summary statistics (total stories per priority/status, and per epic when grouped)

**Input Requirements:**
- Optional filter criteria
- Optional sort order

### Mode 4: Update Priority

Change priority of existing story.

**Workflow:**
1. Read current backlog: `product/context/backlog.md`
2. Find story by ID
3. Confirm current priority
4. Update to new priority
5. Move story to correct position in priority order
6. Update backlog file
7. Confirm priority change

**Input Requirements:**
- Story ID
- New priority level (P0, P1, P2, P3)
- Optional: Reason for priority change

## Quality Checklist

### Story Addition
- [ ] Story ID follows STORY-XXX format
- [ ] No duplicate story IDs
- [ ] Priority is valid (P0, P1, P2, P3)
- [ ] Story title is clear and concise
- [ ] Story description includes acceptance criteria or sufficient detail
- [ ] Story inserted in correct priority order
- [ ] Backlog markdown formatting maintained

### Story Removal
- [ ] Story found in backlog
- [ ] Reason for removal documented
- [ ] No broken dependencies (check if other stories depend on this)
- [ ] Backlog markdown formatting maintained

### Backlog View/Filter
- [ ] Filters applied correctly
- [ ] All matching stories returned
- [ ] Summary statistics accurate
- [ ] Output formatted for readability

### Priority Update
- [ ] Story found in backlog
- [ ] New priority is valid
- [ ] Story moved to correct position
- [ ] Priority change reason captured if significant
- [ ] Backlog markdown formatting maintained

## File Structure

**Primary File:**
- `product/context/backlog.md` - Master backlog file (cross-iteration product state)

**Related Files:**
- `product/iterations/{slug}/stories/story-*.md` - Source story files (authoritative for `epic:` and `prototype_refs:` fields)
- `product/iterations/{slug}/epics/epic-*.md` - Epic definitions, referenced by `epic:` frontmatter

## Best Practices

- Always maintain backlog in priority order within status sections
- Use story IDs consistently across all PM artifacts
- Document priority changes for P0/P1 stories
- Archive completed stories to release notes, not backlog
- Keep backlog focused on actionable, well-defined stories
- Review and groom backlog regularly to remove stale stories
