---
name: improve-codebase-architecture
description: Explore codebase for architectural improvement. Focus testability via deepening shallow modules. Use when user want improve architecture, find refactoring opportunities, consolidate tightly-coupled modules, or make codebase more AI-navigable.
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities**: refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability.

This skill is _informed_ by the project's domain model. The domain glossary names good seams; ADRs in the area record decisions the skill should not re-litigate. Read both before exploring.

Use [LANGUAGE.md](LANGUAGE.md) vocabulary exactly: module, interface, implementation, depth, deep, shallow, seam, adapter, leverage, locality. Do not drift into "component," "service," "API," or "boundary."

Key principles:
- **Deletion test**: deleting a shallow module makes complexity vanish; deleting a deep module spreads complexity across callers.
- **The interface is the test surface.**
- **One adapter means a hypothetical seam. Two adapters means a real seam.**

## Process

### 1. Explore
Read the project's domain glossary and any ADRs in the area you're touching first.

Use Agent(subagent_type=Explore) when available. Otherwise explore with `rg`, `find`, tests, and call graph reading. Look for:
- One concept require bouncing between many files?
- Shallow modules: interface nearly as complex as implementation?
- Pure functions extracted for testability, but real bugs hide in how called (no locality)?
- Tightly-coupled modules leaking across seams?
- Untested or hard-to-test areas?

Apply the deletion test to anything that looks shallow.

### 2. Present candidates as an HTML report

Write a self-contained HTML file to the OS temp directory so nothing lands in the repo. Resolve temp dir from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows), and write to `<tmpdir>/architecture-review-<timestamp>.html` so each run gets a fresh file. Open it for the user (`open`, `xdg-open`, or `start`) and tell them the absolute path.

Use Tailwind via CDN and Mermaid via CDN. Mix Mermaid with hand-crafted CSS/SVG visuals. Each candidate gets a before/after visualization. See [HTML-REPORT.md](HTML-REPORT.md) for scaffold, diagram patterns, styling, and tone.

For each candidate card:
- Files/modules involved
- Problem: why current architecture causes friction
- Solution: what changes
- Benefits in terms of locality, leverage, and tests
- Before/after diagram showing shallowness vs deepening
- Recommendation strength: `Strong`, `Worth exploring`, or `Speculative`

Use [LANGUAGE.md](LANGUAGE.md) vocabulary for architecture and the project's `CONTEXT.md` vocabulary for the domain. If a candidate contradicts an existing ADR, only surface it when friction is real enough to warrant revisiting the ADR. Mark it clearly.

Do **not** propose interfaces yet. After writing the report, ask: "Which of these would you like to explore?"

### 3. Grilling loop

Once the user picks a candidate, drop into a grilling conversation. Walk the design tree: constraints, dependencies, shape of the deepened module, what sits behind the seam, what tests survive.

Side effects happen inline as decisions crystallize:
- Naming a deepened module after a concept not in `CONTEXT.md`? Add the term to `CONTEXT.md`. Create the file lazily if missing. See [../domain-model/CONTEXT-FORMAT.md](../domain-model/CONTEXT-FORMAT.md).
- Sharpening a fuzzy term? Update `CONTEXT.md` right there.
- User rejects the candidate for a load-bearing reason? Offer an ADR so future architecture reviews do not re-suggest it. See [../domain-model/ADR-FORMAT.md](../domain-model/ADR-FORMAT.md).
- Want alternative interfaces? Use [../design-an-interface/SKILL.md](../design-an-interface/SKILL.md).

### 4. Create GitHub Issue

Refactor RFC. See [REFERENCE.md](REFERENCE.md) for template and dependency categories.
