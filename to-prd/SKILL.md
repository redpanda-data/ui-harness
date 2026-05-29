---
name: to-prd
description: Turn current context into a PRD and publish it to issue tracker.
---

# To PRD

Synthesize current context into PRD. Do not interview unless blocked.

Issue tracker + triage labels should exist. If missing, ask which tracker and labels to use.

## Process

1. Explore repo if needed. Use domain glossary terms. Respect ADRs.
2. Sketch major modules to build/modify. Look for deep modules: small stable interface, rich impl, testable in isolation.
3. Confirm module/test focus with user.
4. Write PRD, publish to issue tracker, label `ready-for-agent`.

## PRD template

```md
## Problem Statement
User-facing problem.

## Solution
User-facing solution.

## User Stories
1. As an <actor>, I want <feature>, so that <benefit>.

## Implementation Decisions
Modules, interfaces, clarifications, architecture, schema/API contracts. No stale file paths. Prototype snippets allowed only if decision-rich.

## Testing Decisions
Good-test shape, modules tested, similar prior tests.

## Out of Scope
What not doing.

## Further Notes
Extra context.
```
