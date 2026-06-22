# Acceptance Criteria Format Guide

## Overview

Acceptance criteria define the conditions that must be met for a user story to be considered complete. This guide establishes the Given-When-Then format as the standard for writing clear, testable acceptance criteria.

## Given-When-Then Format

The Given-When-Then format structures acceptance criteria as scenarios with three distinct parts:

```
GIVEN [initial context/precondition]
WHEN [action or event occurs]
THEN [expected outcome]
```

### Components

**GIVEN (Preconditions)**
- Describes the initial state or context before the action
- Sets up the scenario
- Can include multiple conditions (AND clauses)
- Examples:
  - "GIVEN the user is logged in as an admin"
  - "GIVEN there are 50 survey responses in the database"
  - "GIVEN the user has not submitted a survey in the last hour"

**WHEN (Action/Event)**
- Describes the specific action or event being tested
- Should be a single, clear action
- Written in present tense
- Examples:
  - "WHEN the user clicks the 'Export CSV' button"
  - "WHEN the user submits the survey form"
  - "WHEN the system receives an API request"

**THEN (Expected Outcome)**
- Describes the expected result or behavior
- Must be specific and measurable
- Should be verifiable/testable
- Can include multiple outcomes (AND clauses)
- Examples:
  - "THEN a CSV file downloads with all survey responses"
  - "THEN the success message displays 'Thank you for your feedback'"
  - "THEN the response is stored in the database with timestamp"

## Writing Effective Acceptance Criteria

### Best Practices

1. **Be Specific and Measurable**
   - Bad: "THEN the system responds quickly"
   - Good: "THEN the API returns a response within 200ms"

2. **Cover Happy Path First**
   - Start with the main success scenario
   - Then add edge cases and error conditions

3. **Make Testable**
   - Each criterion should have clear pass/fail conditions
   - Avoid ambiguous terms like "should work well"

4. **Use Concrete Examples**
   - Include specific data or values when relevant
   - Show exact expected outputs or behaviors

5. **One Scenario Per Set**
   - Don't combine unrelated behaviors
   - Create separate Given-When-Then blocks for different scenarios

### Structure for Multiple Scenarios

When a story has multiple scenarios, organize them clearly:

```
## Acceptance Criteria

### Scenario 1: [Happy Path Description]
GIVEN [context]
WHEN [action]
THEN [outcome]
AND [additional outcome]

### Scenario 2: [Edge Case Description]
GIVEN [different context]
WHEN [action]
THEN [different outcome]

### Scenario 3: [Error Condition Description]
GIVEN [error context]
WHEN [action]
THEN [error handling]
```

## Examples

### Example 1: Simple Form Submission

```
### Scenario 1: Successful Survey Submission
GIVEN the user has opened the survey page
AND all questions are displayed
WHEN the user completes the survey and clicks "Submit"
THEN the survey response is saved to the database
AND the user is redirected to the thank you page
AND a success message displays "Thank you for your feedback"

### Scenario 2: Duplicate Submission Prevention
GIVEN the user has already submitted a survey in the last hour
WHEN the user attempts to submit another survey
THEN the submission is rejected
AND an error message displays "You can only submit one survey per hour"
AND the response is not saved to the database
```

### Example 2: Admin Export Feature

```
### Scenario 1: Export All Responses
GIVEN the admin is logged in
AND there are 100 survey responses in the database
WHEN the admin clicks "Export CSV"
THEN a CSV file named "survey-responses-[date].csv" downloads
AND the file contains all 100 responses with headers
AND each row includes timestamp, IP address, and all question responses

### Scenario 2: Export Empty Database
GIVEN the admin is logged in
AND there are 0 survey responses in the database
WHEN the admin clicks "Export CSV"
THEN a CSV file downloads with headers only
AND a message displays "No responses found"

### Scenario 3: Export Authorization
GIVEN the user is not logged in as admin
WHEN the user attempts to access the export page
THEN the user is redirected to the login page
AND no CSV file is generated
```

### Example 3: Validation Rules

```
### Scenario 1: Valid Email Format
GIVEN the user is on the registration page
WHEN the user enters "user@example.com" in the email field
AND submits the form
THEN the form is accepted
AND the account is created

### Scenario 2: Invalid Email Format
GIVEN the user is on the registration page
WHEN the user enters "invalid-email" in the email field
AND submits the form
THEN an error message displays "Please enter a valid email address"
AND the form is not submitted
AND the email field is highlighted in red
```

## Common Patterns

### User Authentication
```
GIVEN the user is not authenticated
WHEN the user attempts to access [protected resource]
THEN the user is redirected to the login page
```

### Data Validation
```
GIVEN the user has entered [invalid data]
WHEN the user submits the form
THEN an error message displays "[specific error]"
AND the form is not submitted
```

### API Responses
```
GIVEN the API receives a valid request
WHEN the endpoint is called with [specific parameters]
THEN the API returns status code [code]
AND the response body contains [expected data]
```

### Rate Limiting
```
GIVEN the user has made [X] requests in the last [timeframe]
WHEN the user makes another request
THEN the request is rejected with status code 429
AND the response includes "Rate limit exceeded"
```

## Anti-Patterns to Avoid

### Too Vague
```
Bad:  THEN the system works correctly
Good: THEN the API returns status 200 and the response contains the user ID
```

### Testing Implementation
```
Bad:  THEN the React component renders with useState hook
Good: THEN the user sees the updated count displayed on screen
```

### Multiple Unrelated Actions
```
Bad:  WHEN the user logs in AND submits a survey AND exports data
Good: Separate into three different scenarios
```

### Missing Context
```
Bad:  WHEN the user clicks submit THEN it works
Good: GIVEN the form is filled with valid data
      WHEN the user clicks submit
      THEN the response is saved and confirmation displays
```

## Checklist for Quality Acceptance Criteria

- [ ] Uses Given-When-Then format consistently
- [ ] Covers the happy path (main success scenario)
- [ ] Includes relevant edge cases
- [ ] Addresses error conditions and validation
- [ ] Each criterion is specific and measurable
- [ ] Each criterion is testable with clear pass/fail
- [ ] Uses concrete examples and values
- [ ] Focuses on user-observable behavior, not implementation
- [ ] Organized into clear scenarios with descriptive titles
- [ ] Free of ambiguous terms like "should work well"

## References

- BDD (Behavior-Driven Development) practices
- Gherkin syntax for behavior specifications
- INVEST criteria for user stories (Independent, Negotiable, Valuable, Estimable, Small, Testable)
