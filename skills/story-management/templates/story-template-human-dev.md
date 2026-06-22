---
name: Human Developer
description: Detailed stories with explicit UI components, data requirements, business rules, and implementation guidance. Best for human developers who need comprehensive specifications.
---

# User Story: [Story Title]

**Story ID**: [Number]
**Iteration**: [iteration-name]
**Priority**: [Critical/High/Medium/Low]
**Status**: [Draft/Ready/Built]
**Labels**: [iteration-name], [persona-name], [feature-area], [human-dev]

## User Story
As a [general persona - e.g., "Conference Attendee", "Conference Organizer"],
I want to [action],
So that [benefit/outcome].

## Context
[Why this matters - business driver, user need, or pain point being addressed. Include relevant background.]

## Source
**Discovery Cycle**: [e.g., 2025-11-12-mvp]
**Synthesis Reference**: [Path to synthesis document(s)]
**User Need**: [The JTBD this addresses]
**Supporting Evidence**: [Role descriptions from synthesis, not specific names]

## Design Reference
*(Include this section if design artifacts exist)*

**Screenshots**:
- [Path to relevant screenshot, e.g., `product/design/2025-11-12-mvp/screenshots/01-welcome-screen.png`]
- [Additional screenshots as needed]

**Design Notes**:
[Detailed description of UI layout, components, interactions, states, and visual design. Be specific about what should appear where.]

## Detailed Requirements

### UI Components
[List specific UI elements and their behavior]
- [Component 1]: [Description and behavior]
- [Component 2]: [Description and behavior]

### User Flow
[Step-by-step description of how users interact with this feature]
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Data Requirements
[What data needs to be captured, stored, or displayed]
- [Data field 1]: [Type, validation, required/optional]
- [Data field 2]: [Type, validation, required/optional]

### Business Rules
[Any specific logic, validation, or conditional behavior]
- [Rule 1]
- [Rule 2]

## Acceptance Criteria

### Functional Scenarios

**Scenario 1: [Primary Happy Path]**
- **Given** [initial context/precondition with specific details]
- **When** [user action occurs with specific details]
- **Then** [expected outcome with specific details]
- **And** [additional outcome if needed]

**Scenario 2: [Alternative Path]**
- **Given** [initial context]
- **When** [different action or condition]
- **Then** [expected behavior]

**Scenario 3: [Validation/Error Case]**
- **Given** [context with invalid input or error condition]
- **When** [action that triggers validation/error]
- **Then** [specific error message or handling]
- **And** [user feedback and recovery path]

**Scenario 4: [Edge Case - if relevant]**
- **Given** [edge condition]
- **When** [action occurs]
- **Then** [expected graceful handling]

**Scenario 5: [Additional scenarios as needed]**
[Continue with specific scenarios covering all important paths]

### Non-Functional Requirements
- [ ] Performance: [Specific requirement, e.g., "Response time < 2s for typical load"]
- [ ] Security: [Specific requirement, e.g., "Input sanitized against XSS"]
- [ ] Accessibility: [Specific requirement, e.g., "WCAG 2.1 AA compliant - keyboard navigable, proper ARIA labels"]
- [ ] Mobile: [Specific requirement, e.g., "Touch targets minimum 44x44px, works on 320px width"]
- [ ] Browser Support: [Specific browsers/versions if relevant]
- [ ] Usability: [Specific UX requirements, e.g., "Error messages are clear and actionable"]

### Quality Checklist
- [ ] Unit tests written and passing for all business logic
- [ ] Integration tests cover main scenarios
- [ ] UI matches design specifications exactly
- [ ] All acceptance criteria scenarios tested and passing
- [ ] Accessibility tested with screen reader and keyboard only
- [ ] Mobile responsive behavior tested on actual devices
- [ ] Cross-browser testing completed
- [ ] Error states tested and display correctly
- [ ] Performance validated under expected load
- [ ] Code reviewed and approved
- [ ] Documentation updated (if applicable)

## Technical Notes

### Implementation Guidance
[Specific technical considerations, constraints, or suggestions for developers]
- [Technical note 1]
- [Technical note 2]

### API/Data Model
[If applicable, describe APIs to call or data structures to use]

### Known Constraints
[Any technical limitations or constraints that affect implementation]

## Dependencies
[Other stories or technical dependencies that must be completed first]
- [Dependency 1 with story ID if applicable]
- [Dependency 2]

## Open Questions
[Any uncertainties that need resolution before or during implementation]
- [Question 1]
- [Question 2]

## Estimate
**Size**: [XS/S/M/L/XL]
**Confidence**: [High/Medium/Low]

**Reasoning**: [Detailed explanation of size estimate including complexity factors]

## Metadata
**Iteration**: [iteration-name]
**Created**: [YYYY-MM-DD]
**Last Updated**: [YYYY-MM-DD]
**Build Date**: [YYYY-MM-DD - populated when status changes to Built]
