# Brainstorming Reference

## Design Mode Checklist

1. [ ] Explored project context (relevant files, docs, recent commits)
2. [ ] Asked clarifying questions one at time (not list)
3. [ ] Proposed 2-3 approaches with trade-offs
4. [ ] User approved design direction
5. [ ] Wrote spec document (if needed)
6. [ ] Self-reviewed spec: no TBD, no contradictions, clear scope

## Challenge Mode Checklist

1. [ ] Questioned every assumption ("Why not X instead?")
2. [ ] Presented concrete alternatives
3. [ ] Pushed back on weak reasoning
4. [ ] Found edge cases designer missed
5. [ ] Reached consensus, all concerns addressed

## Visual Mockups with agent-browser

**Install** (one-time): `bun install -g agent-browser && agent-browser install`

No auth. Render local HTML headless. Work in CI.

Auth pages -> use `claude-in-chrome` MCP.

UI designs -> generate HTML mockup:

```bash
# 1. Write a self-contained HTML mockup
cat > /tmp/mockup.html << 'HTML'
<!DOCTYPE html>
<html>
<head><style>/* Tailwind-like styles */</style></head>
<body>
  <!-- Your mockup here -->
</body>
</html>
HTML

# 2. Open in agent-browser and take annotated screenshot
agent-browser open file:///tmp/mockup.html
agent-browser screenshot --annotate /tmp/mockup-v1.png

# 3. Show to user, iterate based on feedback
# Update the HTML, re-screenshot for comparison
agent-browser open file:///tmp/mockup-v2.html
agent-browser screenshot --annotate /tmp/mockup-v2.png
```

**When to use mockups:**
- New page layouts or component arrangements
- Compare Option A vs B visually
- Responsive design decisions
- Before/after refactor viz

**When NOT to use mockups:**
- API design, data modeling, architecture decisions (use text/diagrams)
- Simple changes where description enough

## Spec Document Template

```markdown
# [Feature] Design Spec

**Date:** YYYY-MM-DD
**Status:** Draft / Approved

## Problem
[What problem are we solving?]

## Approaches Considered
### Option A: [Name]
- Trade-offs: ...
### Option B: [Name]
- Trade-offs: ...

## Chosen Approach
[Which option and why]

## Scope
- In scope: ...
- Out of scope: ...

## Open Questions
[Any unresolved decisions]
```