---
name: to-issues
description: Break PRD or plan into tracker issues as thin vertical slices.
---

# To Issues

Break plan into independently grabbable vertical slices.

Issue tracker + triage labels should exist. If missing, ask which tracker and labels to use.

## Process

1. Read current context or passed issue/path.
2. Explore code if needed. Use domain glossary, respect ADRs.
3. Draft tracer-bullet slices: narrow complete path through schema/API/UI/tests. Demoable alone. Prefer many thin slices.
4. Mark each HITL or AFK. Prefer AFK where safe.
5. Ask user: granularity, dependencies, merge/split, HITL/AFK right?
6. Publish approved issues in dependency order with ready label.

## Issue template

```md
## Parent
<parent ref if any>

## What to build
End-to-end behavior. Avoid stale file paths/code. Prototype snippet OK if decision-rich.

## Acceptance criteria
- [ ] ...

## Blocked by
<refs> or None - can start immediately

## Notes for agent
Domain terms, ADRs, risks.
```
