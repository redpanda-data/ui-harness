---
name: review
description: Review diff since fixed point on Standards and Spec axes in parallel.
---

# Review

Two-axis diff review from fixed point to `HEAD`:

- Standards: violates repo docs?
- Spec: matches originating issue/PRD?

## Process

1. Pin fixed point. If missing, ask. Use `git diff <fixed>...HEAD` + `git log <fixed>..HEAD --oneline`.
2. Find spec: issue refs in commits, user path, PRD/spec under docs/specs/.scratch, else ask. If none, Spec axis skips.
3. Find standards: `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CONTEXT.md`, ADRs, style docs, config files.
4. Spawn two parallel general-purpose agents:
   - Standards: read standards + diff. Report violations with standard citation. Skip tooling-enforced stuff. <=400 words.
   - Spec: read spec + diff. Report missing/partial reqs, scope creep, wrong impl. Quote spec line. <=400 words.
5. Aggregate under `## Standards` and `## Spec`. Keep axes separate. End with counts + worst issue.
