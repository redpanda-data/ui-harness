# Thermo-Nuclear Review Reference

Inspired by Cursor Team Kit's maintainability-review skill (https://github.com/cursor/plugins/blob/3347cbab5b54136f6fba0994c3a01a56f7fb7fca/cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md), but rewritten for this frontend skills harness and Codex-style multi-agent review.

## Posture

Cold review means the reviewer ignores implementation confidence, PR prose, and author self-report until verified. Skip generated files unless the generator, schema, or manual edit is part of the change; generated files are evidence, not review targets. Prefer structural simplification over local polish: delete complexity, collapse branches, move logic to its canonical owner, and make the direct path obvious.

## Structural quality axis

Block or escalate when the PR:
- Pushes a file across 1,000 lines without a strong decomposition reason.
- Adds spaghetti or special-case branching into unrelated flows.
- Spreads feature checks across shared code instead of adding a clear ownership boundary.
- Adds wrappers, helpers, or generic mechanisms that do not reduce concepts.
- Uses casts, `unknown`, unnecessary optionality, or silent fallbacks where a typed boundary would be clearer.
- Serializes independent work or performs non-atomic updates when a simpler structure is obvious.

## Frontend harness axis

Check the project rules before commenting:
- React Compiler: functional components only; do not add `useMemo`, `useCallback`, or `React.memo` for routine memoization.
- UI: interactive controls from `@/components/ui`; all buttons use `<Button>` with `onClick`, `asChild`, `type="submit"`, or `disabled`.
- Accessibility: semantic HTML, icon-button `aria-label`, focus-visible ring, dialog labels, keyboard path, no clickable div/span without role, tabIndex, and handlers.
- Tailwind: design tokens, utility classes, `100dvh`, `width:100%`, no one-off specificity hacks.
- Routing/data: TanStack Router for routes; connect-query for server data; route `errorComponent`; query loading/error/empty states.
- State/env: zustand `create<T>()()` and `useShallow` for multi-selectors; env through `@/env`.
- Forms: `handleSubmit(onSubmit, onError)`, URL inputs `type="url"`, `aria-invalid`, all errors visible, branch values cleared on oneof/union switches.
- Tests: failing test first, `userEvent.setup()`, `getByRole`, `waitFor`, behavior over implementation, warning-free output.
- Harness integrity: `skill-manifest.json` is source of truth; check generated config drift, executable hooks, `_hook-lib.sh`, and quality scripts before blaming agents.

## Reviewer output schema

Use `agents/findings-schema.md` fields when possible. Each reviewer records checked inputs and artifacts before findings. Minimum finding:

```json
{
  "checked": ["diff", "spec", "standards", "runtime evidence"],
  "artifacts": ["test command", "screenshot path", "trace path"],
  "priority": "blocker | major | minor | nit | follow-up for other PR",
  "severity": "P0 | P1 | P2 | P3",
  "axis": "structural | standards | spec | frontend | resilience | visual | security | tests | perf | steelman",
  "file": "path",
  "line": 1,
  "evidence": "specific proof",
  "impact": "production/user/maintainer consequence",
  "required_change": "concrete requested change",
  "one_shot_prompt": "copy-pasteable fix prompt or null with reason",
  "pr_comment": "GitHub-ready concise comment"
}
```

## Severity

| Severity | Meaning | Merge rule |
|---|---|---|
| P0 | Security hole, data loss, corrupt state, outage, crash, impossible core flow | Block |
| P1 | Normal user failure, fake success, broken required behavior, major a11y miss, unhandled high-risk edge | Block unless owner override |
| P2 | Maintainability, edge-case, perf, observability, or test gap with contained impact | Fix or track |
| P3 | Minor cleanup or polish | Advisory |

If unsure, prove lower severity with evidence; otherwise bias upward for important reviews.

## Required artifacts

- Base SHA/branch and diff summary.
- Spec, standards, and PR feedback sources.
- Per-reviewer statuses and skipped-axis reasons.
- Exact test/type/lint commands and results.
- UI/customer-facing changes: `/visual-review` matrix, screenshots or terminal artifacts, environment fingerprint.
- Forms/async/state/destructive changes: `/resilience-review` failure matrix and required RED tests.
- Security/dependency changes: scan or explicit skip reason.
- Performance-sensitive changes: bundle/profile/trace evidence or explicit skip reason.

## PR comments

Run many lenses, comment few findings. Priority labels: blocker, major, minor, nit, follow-up for other PR. Map P0->blocker, P1->major, P2->minor or follow-up, P3->nit. Inline PR comments only for blocker/major or high-confidence, actionable minor with tight file/line, evidence, impact, and concrete fix. Comment template: What, Why, Suggested fix, One-shot prompt. One-shot prompt must be a copy-pasteable fix request when possible; include repo, branch, file, exact change, and verify command. Otherwise say why no safe one-shot exists. Put evidence gaps, skipped lanes, speculative architecture concerns, and duplicate root causes in the top-level summary. Do not post style nits unless they hide a P2+ risk.

## Approval bar

Approve only when no unresolved P0/P1 remains, spec and standards are accounted for, structural complexity did not regress without justification, required visual/resilience evidence exists or is explicitly skipped, and the PR body can prove what was checked.
