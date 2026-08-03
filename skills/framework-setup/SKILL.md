---
name: framework-setup
description: Initialize product context by creating foundational product management files (personas, glossary, principles, journey maps)
category: product-management
---

# Framework Setup Skill

This skill guides the PM through establishing core product context files through an interactive interview process.

## Modes

### Quick Start
Initialize minimal context to start building product (personas + glossary only)
- Time: 15-20 minutes
- Outputs: `product/personas/{slug}.md` (one per persona), `product/glossary.md`
- Best for: Getting started quickly, validating concept

### Standard Setup
Establish working product context with core artifacts
- Time: 30-45 minutes
- Outputs: the Quick Start files + `product/design-principles.md`, `product/journey-maps/{slug}.md`
- Best for: Most product initiatives

### Complete Setup
Full product context with all recommended artifacts
- Time: 60-90 minutes
- Outputs: all Standard files + `product/competitive-analysis.md`, `product/use-cases.md`, `product/constraints.md`
- Best for: Complex products, regulated industries, competitive markets

**A mode names the questions asked, not files guaranteed to appear.** If the interview
produces nothing real for an artifact, do not create it — see §3.

## Workflow

### 1. Mode Selection
Ask the PM which mode to use based on project needs and available time.

### 2. Interactive Interview
For each artifact in the selected mode:

**Personas**
- Who will use this product?
- What are their goals and pain points?
- What is their context (technical skills, environment, constraints)?

One file per persona at `product/personas/{slug}.md`, with frontmatter:

```yaml
---
type: Persona
slug: repeat-buyer      # kebab-case; the identity other files reference
name: Repeat buyer      # display name
emoji: 🔁               # optional — story-map board rendering only
---
```

The `slug` is what a story's `Personas:` field names and what every other skill resolves
against, so pick it deliberately and don't rename it casually. `emoji` is optional; a
persona without one simply renders no prefix. **There is no persona index or legend file** —
any legend is derived by reading these files (see `story-map`).

**Glossary**
- What domain-specific terms matter?
- What terms might be ambiguous?
- What acronyms or jargon will the team use?

**Product Principles** (Standard and Complete only)
- What are the core beliefs guiding product decisions?
- What tradeoffs will the team make consistently?
- What won't this product do?

**Journey Maps** (Standard and Complete only)
- What are the key user workflows?
- What are the critical moments in each workflow?
- Where do users experience friction today?

**Competitive Analysis** (Complete only)
- Who are the competitors or alternatives?
- What do they do well?
- What gaps exist in the market?

**Use Cases** (Complete only)
- What are the primary scenarios?
- What are edge cases that must be handled?
- What scenarios are explicitly out of scope?

**Constraints** (Complete only)
- What technical constraints exist?
- What business constraints apply?
- What regulatory or compliance requirements matter?

### 3. File Creation
Create each file directly under `product/` using responses from the interview — `personas/`
and `journey-maps/` take one file per subject; the rest are single files.

**Never create a file that says nothing.** If the interview produced no real content for an
artifact, skip it and say so in the summary. An empty or placeholder file is worse than an
absent one: it reads as answered when it isn't, and anything indexing `product/` will claim
context exists that doesn't. Skipping is not failure — the PM can run this skill again later
and the mode is a list of questions, not a quota.

Format each file with:
- Clear markdown structure
- Consistent heading hierarchy
- Bulleted lists where appropriate
- Examples where helpful

### 4. Register with context-mesh (only if it is installed)

**Skip this whole step unless `context-index.md` exists at the root of the tree containing
`product/`.** That file is what makes this a context-mesh domain. Absent, ee-pm stands alone
and nothing here applies — do not create the index, do not mention the mesh in the summary,
and do not treat its absence as a problem to fix. (`/ee-context-mesh:setup-mesh` is what
creates an index; that is its job, not this skill's.)

If it does exist:

**a. Add the files just created to the index's canonical-context table.** One row each —
path, what it is about, and when to load it. Add rows only for files that actually got
written in §3; a row pointing at a file that does not exist, or at one that exists and says
nothing, is worse than no row, because routing reads the index and will believe it.

**b. Emit the backlog workflow.** Do this whether or not `product/backlog.md` exists yet — it
is created lazily by `story-management` / `backlog-management` when the first story lands, and
the mesh needs a routing target *before* that, not after. This is the one exception to §3's
"never create a file that says nothing", and it holds because the workflow file is not a
claim that context exists — it is a pointer saying where work goes, which is true from the
moment the practice is set up.

ee-pm's backlog is a repo-native queue — `product/backlog.md` *is* the record of work, not a
pointer at Jira — so the mesh has no way to know it exists unless it is declared. Write
`process/workflows/backlog.md`:

```yaml
---
type: Workflow
name: backlog
system: repo
external_ref: product/backlog.md
creates: Story
via: ee-pm:story-management
owned-by: <team>
---
```

and add it to the index's Workflows table. `system: repo` is legitimate, not a degenerate
case: what the mesh requires is a *declared owner* for the queue, and a repo-native file with
an `external_ref` naming a repo-relative path has one. Without this, a `Todo` ingested from a
conversation has no legal `routed-to` target in this domain and cannot be placed at all.

**c. Do not emit a second workflow for anything else.** Iterations, OSTs, and assumption maps
are artifacts, not queues; only a place work is *routed to* is a `Workflow`.

Ask the PM before writing to `context-index.md` — it is a shared file that other domains and
skills read.

### 5. Summary and Next Steps
Provide the PM with:
- List of files created with absolute paths
- Which artifacts were skipped, and why (see §3) — so a thin run reads as deliberate
- Suggested next steps (typically running the discovery-synthesis or interview-management skill)
- Note about what context is now available for other workflows

## Quality Checklist

Before completing:
- [ ] All files use consistent markdown formatting
- [ ] Each file has clear section headings
- [ ] Content is specific to the user's product (not generic)
- [ ] Glossary terms are used consistently across all files
- [ ] Persona details are concrete and actionable
- [ ] Every persona file has `type`, `slug`, and `name` frontmatter; slugs are unique
- [ ] Files are created directly under `product/` (no `product/context/` layer)
- [ ] No placeholder or lorem ipsum content — and no file created for an artifact the
      interview produced nothing for
- [ ] Summary provided with absolute file paths

## Templates

This skill ships no artifact templates — `product/` documents are written directly, following the
structures specified in this file (personas carry the frontmatter in §Personas; the rest follow
standard product-management formats).

## Notes

- This is an interactive process - ask one question at a time
- Build on the PM's answers with follow-up questions to get depth
- Keep the PM's domain expertise in mind - trust their judgment
- Use examples from their responses in the final files
- Don't rush - better to get rich context than complete quickly
