---
name: framework-setup
description: Initialize product context by creating foundational product management files (personas, glossary, principles, journey maps)
version: 1.0.0
category: product-management
---

# Framework Setup Skill

This skill guides the PM through establishing core product context files through an interactive interview process.

## Modes

### Quick Start
Initialize minimal context to start building product (personas + glossary only)
- Time: 15-20 minutes
- Outputs: personas.md, glossary.md
- Best for: Getting started quickly, validating concept

### Standard Setup
Establish working product context with core artifacts
- Time: 30-45 minutes
- Outputs: personas.md, glossary.md, product-principles.md, journey-maps.md
- Best for: Most product initiatives

### Complete Setup
Full product context with all recommended artifacts
- Time: 60-90 minutes
- Outputs: All standard files + competitive-analysis.md, use-cases.md, constraints.md
- Best for: Complex products, regulated industries, competitive markets

## Workflow

### 1. Mode Selection
Ask the PM which mode to use based on project needs and available time.

### 2. Interactive Interview
For each artifact in the selected mode:

**Personas**
- Who will use this product?
- What are their goals and pain points?
- What is their context (technical skills, environment, constraints)?

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
Create each file in `product/context/` using responses from the interview.

Format each file with:
- Clear markdown structure
- Consistent heading hierarchy
- Bulleted lists where appropriate
- Examples where helpful

### 4. Summary and Next Steps
Provide the PM with:
- List of files created with absolute paths
- Suggested next steps (typically running the discovery-synthesis or interview-management skill)
- Note about what context is now available for other workflows

## Quality Checklist

Before completing:
- [ ] All files use consistent markdown formatting
- [ ] Each file has clear section headings
- [ ] Content is specific to the user's product (not generic)
- [ ] Glossary terms are used consistently across all files
- [ ] Persona details are concrete and actionable
- [ ] Files are created in `product/context/` directory
- [ ] No placeholder or lorem ipsum content
- [ ] Summary provided with absolute file paths

## Templates

Use templates from `/templates/product/` if they exist:
- `persona-template.md`
- `glossary-template.md`
- `product-principles-template.md`
- `journey-map-template.md`

If templates don't exist, create well-structured markdown files following standard product management formats.

## Notes

- This is an interactive process - ask one question at a time
- Build on the PM's answers with follow-up questions to get depth
- Keep the PM's domain expertise in mind - trust their judgment
- Use examples from their responses in the final files
- Don't rush - better to get rich context than complete quickly
