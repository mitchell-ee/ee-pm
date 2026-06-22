---
name: interview-management
description: Conduct user/stakeholder interviews and format transcripts into structured insights
version: 1.0.0
category: product-management
---

# Interview Management Skill

This skill helps the PM conduct structured interviews and transform raw transcripts into actionable product insights.

## Modes

### Conduct Interview
Guide the PM through a live interview with a structured question framework
- Real-time question suggestions based on interview type
- Follow-up prompts based on responses
- Time management and pacing guidance

### Format Transcript
Transform raw interview transcripts into structured, searchable insights
- Extract key quotes
- Identify themes and patterns
- Tag insights by category
- Link to personas and journey maps

## Workflow: Conduct Interview

### 1. Interview Setup
Ask the PM:
- What type of interview? (discovery, validation, usability, stakeholder)
- Who is being interviewed? (role, relationship to product)
- What is the primary goal?
- How much time is available?

### 2. Opening Questions
Provide warm-up questions to establish context:
- Background and role
- Current workflow or process
- Relationship to the problem space

### 3. Core Interview Questions
Based on interview type, suggest:

**Discovery Interview**
- What challenges do you face with [topic]?
- Walk me through the last time you [did task]
- What would an ideal solution look like?
- What have you tried before?

**Validation Interview**
- How does this solution address your needs?
- What concerns do you have?
- What's missing?
- How does this compare to alternatives?

**Usability Interview**
- Show me how you would [complete task]
- What did you expect to happen there?
- What's confusing about this?
- What would you change?

**Stakeholder Interview**
- What success metrics matter to you?
- What constraints should we be aware of?
- What risks concern you?
- How will this impact your team?

### 4. Follow-Up Prompts
After each response, suggest follow-ups:
- "Can you tell me more about..."
- "What happened next?"
- "Why is that important?"
- "How often does that occur?"

### 5. Closing
- Summarize key themes heard
- Ask for clarification on any ambiguous points
- Thank participant
- Confirm any follow-up actions

## Workflow: Format Transcript

### 1. Input
Ask the PM for:
- Raw transcript (paste or file path)
- Interview metadata (participant role, date, type)
- Any specific areas of focus

### 2. Analysis
Extract and organize:

**Key Quotes**
Direct quotes that capture important insights or user voice
```markdown
> "I waste 20 minutes every day just trying to find the right report"
> — Sarah, Operations Manager, 2025-12-10
```

**Themes**
Patterns across responses:
- Pain points
- Desired outcomes
- Workarounds currently used
- Emotional responses

**Insights**
Actionable learnings:
- What this means for the product
- What assumptions are validated/invalidated
- What new questions emerge

### 3. Categorization
Tag insights by:
- Related persona
- Journey stage
- Feature area
- Priority (high/medium/low signal)

### 4. Output Format
Create structured markdown file in `/knowledge/interviews/`:

```markdown
# Interview: [Participant Role] - [Date]

## Metadata
- **Participant:** [Role/Title]
- **Date:** YYYY-MM-DD
- **Interviewer:** {interviewer}
- **Type:** Discovery/Validation/Usability/Stakeholder
- **Duration:** [Minutes]

## Summary
[2-3 sentence overview of key findings]

## Key Quotes
> "Quote text"
> — Context/timestamp

## Themes
### [Theme Name]
- Finding 1
- Finding 2

## Insights
### [Insight Title]
**What we learned:** [Description]
**Implications:** [What this means for product]
**Related to:** [Persona name, journey stage, feature]
**Priority:** High/Medium/Low

## Questions Raised
- [ ] Question 1
- [ ] Question 2

## Follow-Up Actions
- [ ] Action item 1
- [ ] Action item 2

## Raw Notes
[Optional: Full transcript or detailed notes]
```

### 5. Integration
Suggest connections to existing product context:
- Link quotes to personas
- Map findings to journey stages
- Flag insights that challenge existing assumptions
- Identify gaps in current understanding

## Quality Checklist

### For Conducted Interviews
- [ ] Opening questions establish rapport and context
- [ ] Core questions are open-ended (not yes/no)
- [ ] Follow-ups dig deeper on interesting responses
- [ ] Time managed appropriately (not rushed or dragging)
- [ ] Closing summarizes and confirms understanding

### For Formatted Transcripts
- [ ] Metadata is complete and accurate
- [ ] Key quotes are verbatim and attributed
- [ ] Themes are specific (not generic)
- [ ] Insights are actionable
- [ ] Categories/tags are consistent with existing framework
- [ ] File saved in `/knowledge/interviews/` with clear naming
- [ ] Connections to personas/journeys are explicit
- [ ] New questions are captured for future research

## Templates

Use templates from `/templates/product/` if available:
- `interview-guide-template.md`
- `interview-transcript-template.md`

## Notes

- Listen more than talk - aim for 80/20 participant/interviewer ratio
- Avoid leading questions - let participant's mental model emerge
- Capture exact words when possible - user language matters
- Note non-verbal cues in usability sessions
- Document what wasn't said - gaps are insights too
- Connect findings to existing product context
- One interview is a data point, not a pattern - look for themes across multiple interviews
