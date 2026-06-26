---
name: deslop
description: "Question changed code as liability and remove unjustified surface area. Use before commit, push, PR, merge, or when a change feels overbuilt or low-value."
---

# Deslop

Repo/code changes: run `/deslop` before commit, push, PR, or merge.
Code is liability. Every added line can break, page someone, or need support.

## Inputs

- Run `/simplify`, `/ponytail-review`, `/ponytail-audit` for broad bloat, and `/ponytail-debt` for `ponytail:` markers; then use this skill as the stricter certainty gate.
- Read `git diff --stat` and `git diff` for changed files.
- Read nearby code before proposing new helpers or abstractions.
- If the goal/spec is unclear, ask one question before judging value.

## Loop: Delete -> Inline -> Justify

1. **Inventory additions** -- new files, functions, branches, deps, config, hooks.
2. **Ponytail review** -- run `/ponytail-review`; record delete/stdlib/native/yagni/shrink candidates before judging value.
3. **Ponytail audit/debt** -- for repo-wide cleanup or marked shortcuts, run `/ponytail-audit` and `/ponytail-debt`. Pair audit/debt with /improve when fixes are not immediate.
4. **Reuse-first ladder** -- before owning new code, prefer deletion, standard library, native platform, already-installed dependency, then one-line local code.
5. **Question every addition** -- keep code only when you are certain it proves product value, defensive correctness, or test confidence.
6. **Delete first** -- remove dead paths, speculative options, unused exports, wrapper layers.
7. **Inline second** -- inline one-use helpers/components; prefer direct code until reuse is real.
8. **Tighten last** -- flatten branches, improve names, shrink tests without weakening assertions.
9. **Eval evidence** -- skill or harness changes need matching evals changed, with RED->GREEN or failing->passing evidence. No eval evidence means block or record why the change is docs-only/non-deterministic.
10. **Verify** -- rerun focused tests/type/lint. Green alone is not enough if diff is noisy.

## Blocking finding

Return `NEEDS_CHANGES` when the diff is low-value, sloppy, untested, non-defensive, or larger than the problem needs. Do not commit, push, or merge until the smallest passing diff is clear.

## Output

- Kept: why each major addition deserves ownership cost.
- Deleted/inlined: what surface area shrank.
- Still risky: blockers, tests to add, or user decisions.

See [REFERENCE.md](REFERENCE.md) for the surface-area budget checklist.
