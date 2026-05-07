---
name: improve-codebase-architecture
description: Explore codebase for architectural improvement. Focus testability via deepening shallow modules. Use when user want improve architecture, find refactoring opportunities, consolidate tightly-coupled modules, or make codebase more AI-navigable.
---

# Improve Codebase Architecture

Surface architectural friction, improve testability via module-deepening refactors -> GitHub issue RFCs.

This skill is _informed_ by the project's domain model. The domain glossary names good seams; ADRs in the area record decisions the skill should not re-litigate. Read both before exploring.

**Deep module** = small interface, big implementation. More testable, more AI-navigable, test at boundary not inside. See [LANGUAGE.md](LANGUAGE.md) for the canonical vocabulary (module / interface / seam / adapter / depth / leverage / locality + the deletion test).

## Process

### 1. Explore
Read the project's domain glossary and any ADRs in the area first.

Use Agent(subagent_type=Explore). Look for:
- One concept require bouncing between many files?
- Interface near as complex as implementation (shallow)?
- Pure functions extracted for testability, but real bugs in how called?
- Tightly-coupled modules create integration risk?
- Untested or hard-to-test areas?

### 2. Present Candidates
Numbered list: cluster of related modules, why coupled, dependency category, test impact. Use [LANGUAGE.md](LANGUAGE.md) vocabulary for architecture and the project's `CONTEXT.md` vocabulary for the domain. No interfaces yet.

If a candidate contradicts an existing ADR, only surface it when the friction is real enough to warrant revisiting the ADR. Mark it clearly (_"contradicts ADR-0007 -- but worth reopening because..."_). Don't list every theoretical refactor an ADR forbids.

### 3. User Picks

### 4. Frame Problem Space
Constraints new interface must satisfy. Rough illustrative code sketch.

### 5. Design Interfaces
Spawn 3+ parallel sub-agents, different constraints each. Outputs: signature, usage, what hides, dependency strategy, trade-offs. Give own recommendation.

### 6. User Picks

### 7. Create GitHub Issue
Refactor RFC. See [REFERENCE.md](REFERENCE.md) for template and dependency categories.