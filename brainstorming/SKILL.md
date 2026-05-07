---
name: brainstorming
description: "Use when exploring design options, starting new features, or needing to think before coding. Two modes: design (explore approaches with trade-offs) and challenge (stress-test decisions). No implementation until design is approved."
---

# Brainstorming

**GATE: no code, no files, no impl until design presented and approved.**

## Design Mode (default)

1. Explore context -- read files, docs, recent commits
2. Clarify -- one question at time, not list
3. Propose 2-3 approaches with trade-offs
4. Optional: HTML mockup -> `agent-browser` -> annotated screenshot
5. Present design -> get approval
6. Write spec doc if needed

## Challenge Mode

1. Question every assumption -- "Why this? What breaks if X changes?"
2. Present alternatives
3. Push back on weak reasoning
4. Find edge cases -- "Empty list? 10,000 items?"
5. Consensus only when all concerns addressed

## When to Use

| Situation | Mode |
|---|---|
| New feature / architecture choice | Design |
| Review proposed approach / risky refactor | Challenge |
| "Should we use X or Y?" | Design -> Challenge winner |