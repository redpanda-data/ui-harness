---
name: scaffold-exercises
description: Create exercise dirs, readmes, variants, and lint-clean course stubs.
---

# Scaffold Exercises

Create `exercises/` structure that passes `pnpm ai-hero-cli internal lint`, then commit.

## Naming

- Sections: `XX-section-name/`
- Exercises: `XX.YY-exercise-name/`
- dash-case names.

## Variants

Each exercise needs at least one: `problem/`, `solution/`, `explainer/`. Default stub: `explainer/`.

Each variant needs non-empty `readme.md`. Code variants also need `main.ts` >1 line.

## Workflow

1. Parse plan -> sections, exercises, variant types.
2. `mkdir -p` dirs.
3. Create stub readmes with title + sentence.
4. Run `pnpm ai-hero-cli internal lint`.
5. Fix until green.

## Moving

Use `git mv`, update numeric prefixes, rerun lint.

No `.gitkeep`, `speaker-notes.md`, broken links, or `pnpm run exercise` in readmes.
