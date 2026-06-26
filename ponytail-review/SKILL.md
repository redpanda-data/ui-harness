---
name: ponytail-review
description: Reviews diffs for over-engineering only. Use when reviewing, desloping, or asking what to delete, inline, shrink, or replace with stdlib/native code.
license: MIT
vendored_from: https://github.com/DietrichGebert/ponytail
upstream_commit: 687c1b339872289d70f65c5eaabce850b1663867
---

# Ponytail Review

Repo/code changes: run `/deslop` before commit, push, PR, or merge.
Vendored from DietrichGebert/ponytail. Complexity only; `/deslop` owns value/defense/test gate.
Caveman terse: one finding per line, no coaching prose.

Review diffs for needless complexity. Best result: diff gets shorter.

## Format

`<file>:L<line>: <tag> <what>. <replacement>.`

Tags:

- `delete:` dead code, unused flexibility, speculative feature. Replace with nothing.
- `stdlib:` hand-rolled stdlib. Name function.
- `native:` dep/code doing platform job. Name feature.
- `yagni:` one impl, one caller, config nobody sets.
- `shrink:` same behavior, fewer lines. Show shorter form.

## Examples

- `L12-38: stdlib: 27-line validator class. "@" check; real validation is confirmation email.`
- `L4: native: moment.js for one format call. Intl.DateTimeFormat, 0 deps.`
- `repo.py:L88: yagni: AbstractRepository with one impl. Inline until second exists.`
- `L52-71: delete: retry wrapper around idempotent local call. Nothing replaces it.`
- `L30-44: shrink: manual dict loop. dict(zip(keys, values)), 1 line.`

## Scoring

End with `net: -<N> lines possible.`

Nothing to cut: `Lean already. Ship.`

## Boundary

Complexity only. Correctness, security, perf, resilience, product value -> normal review and `/deslop`. Behavior test is not bloat. List cuts; do not apply.
