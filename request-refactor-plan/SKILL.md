---
name: request-refactor-plan
description: Create a detailed refactor plan with tiny commits via user interview, then file it as a GitHub issue. Use when user wants to plan a refactor, create a refactoring RFC, or break a refactor into safe incremental steps.
---

# Request Refactor Plan

## Process

### 1. Understand
Ask problem + solution ideas. What wrong? What "better" mean?

### 2. Verify
Agent(subagent_type=Explore) verify claims vs codebase. Check real state.

### 3. Alternatives
Ask other approaches + trade-offs.

### 4. Drill Into Details
Scope, interface contracts (before/after), data migrations, backcompat, incremental path.

### 5. Test Coverage
Assess coverage. Insufficient -> ask test plan first.

### 6. Tiny Commits
Each step: deployable alone, tests green, one change.

### 7. GitHub Issue

`gh issue create`:

    ## Problem Statement
    What wrong and why.

    ## Solution
    Chosen approach and rationale.

    ## Commits
    1. [description] -- what changes, tests green
    2. [description] -- what changes, tests green

    ## Decisions
    Key decisions + rationale from interview.

    ## Testing
    New tests needed, existing tests changed.

    ## Out of Scope
    What NOT touched.