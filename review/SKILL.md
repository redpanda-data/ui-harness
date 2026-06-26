---
name: review
description: Reviews a diff since a fixed point across Standards, Spec, and risk gates. Use when reviewing a branch, PR, WIP, or "review since X".
---

# Review

Repo/code changes: run `/deslop` before commit, push, PR, or merge.
Diff review from fixed point to `HEAD`. Keep Standards and Spec axes separate.

## Inputs

If fixed point missing, ask: "Review against what -- branch, commit, or `main`?"

Use:
- Diff: `git diff <fixed>...HEAD`
- Commits: `git log <fixed>..HEAD --oneline`

## Gather

Spec source, first found wins: issue refs in commits via `docs/agents/issue-tracker.md`; user path; PRD/spec under `docs/`, `specs/`, `.scratch/`; none -> Spec axis reports "no spec available".

Standards sources: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `CONTEXT.md`, `CONTEXT-MAP.md`, scoped `CONTEXT.md`, `docs/adr/`, style docs and config (`biome`, `eslint`, `tsconfig`, `prettier`, `.editorconfig`).

## Parallel review hats

Spawn all review hats in one message before producing findings, matching `/grill-me` fan-out. Use `general-purpose` subagents. Main agent orchestrates only: gather sources, fan out, merge, dedupe, final report.

Prefer `/swarm` under the hood when available: pass fixed point, changed files, sources, full required hat list, subagent prompt contract, and merge contract. If /swarm is unavailable, spawn hat subagents directly. Swarm must not reduce hats, evidence, lane ownership, or final output.

Required hats: `ponytail-review-hat`, `thermo-nuclear-review-hat`, `resilience-review-hat`, `regular-review-hat`, `adversarial-review-hat`, `visual-review-hat`, `test-perf-review-hat`, `security-privacy-triage-hat`.

- **`ponytail-review-hat`**: run `/ponytail-review` on every diff before other hats merge findings; output delete/stdlib/native/yagni/shrink opportunities or `Lean already. Ship.`.
- **`thermo-nuclear-review-hat`**: run `/thermo-nuclear-code-quality-review` for release candidates, large PRs, risky refactors, security/privacy/perf/test concerns, or explicit nuclear/cold-audit asks; otherwise `SKIPPED` with reason.
- **`resilience-review-hat`**: run `/resilience-review` for forms, validation, async/data, mutations, cache, state machines, config, destructive actions, or loading/error/empty states; otherwise `SKIPPED` with reason.
- **`regular-review-hat`**: Standards and Spec pass. Never invoke /review recursively. If no spec, return `Spec: no spec available`.
- **`adversarial-review-hat`**: ask "What could still be wrong if tests pass and implementation matches spec?" Max 3 findings. If no credible risk, return `APPROVED`.
- **`visual-review-hat`**: run `/visual-review` for UI, copy, forms, routes, reports, CLI/TUI output, or visual behavior; otherwise `SKIPPED` with reason.
- **`test-perf-review-hat`**: check TDD evidence, coverage gaps, flaky/missing tests, slow paths, render/network/bundle risk, and warning-free commands.
- **`security-privacy-triage-hat`**: check auth, authorization, tenant boundaries, secrets, unsafe HTML, injection, SSRF, redirects, dependency execution, logging, analytics, PII, export/import; exploitable/privacy findings escalate to Thermo nuclear.

Review priority hierarchy: 1. Ponytail review 2. Thermo nuclear review 3. Resilience review 4. Regular review 5. Adversarial review 6. Visual review 7. Test/perf review. Security/privacy triage feeds this hierarchy.

No silent skips: all hats run at least triage; `SKIPPED` needs `skip_reason`, checked files/surfaces, and absent triggers. Never skip due to time, token budget, small diff, prior confidence, or another hat passing. Thermo nuclear is fail-open. Thermo nuclear and Resilience skip only when diff evidence proves no matching risk surface. If unsure, run the review.

PR value gate: always quantify the Major improvement before verdict. Code is liability: if added surface area is not product value, defensive correctness, or test confidence, treat it as low-value until justified. Value score: HIGH|MEDIUM|LOW|NONE. Maintenance/security/resilience/test-only can score HIGH. If no Major improvement reaches MEDIUM, run `/steelman` internally against "this PR adds meaningful value". If `/steelman` confirms low-value, gate blocks pending explicit override, split, or stronger value justification.

Subagent prompt contract: include fixed point, changed files, diff command, commits command, exact review type, and sources; require lane ownership, evidence, severity, priority label, required change, and PR-comment-ready text; cap at 400 words; findings must be diff-introduced, user-impacting, actionable.

Each hat emits: `{ "reviewer": "<name>", "hat": "<ponytail|thermo-nuclear|resilience|regular|adversarial|visual|test-perf|security-privacy>", "status": "APPROVED|FINDINGS|BLOCKED|SKIPPED", "findings": [], "must_answer": [], "skip_reason": "<required when SKIPPED>" }`.

Merge contract: wait for all hats; dedupe by file/range + reference; Dedupe across hats by root cause, not wording; preserve Standards and Spec separately; keep highest severity on disagreement; if subagents unavailable, stop unless user accepts degraded solo review.

## PR comments
After all hats finish, merge, dedupe, and verify priority before posting or printing review comments. Do not comment during individual hats.
If the target is a GitHub PR and PR comment tooling is available, post inline PR comments automatically to the open or targeted PR; the user does not need to ask. Resolve target in order: explicit PR URL/number, PR targeted by the skill invocation, then the open PR for the current branch. If PR comment tooling is unavailable, no PR exists, or multiple PRs are ambiguous, emit comment-ready output instead.
Do not dump the whole review into the PR. Comment only distinct, high-confidence, actionable findings with tight file/line evidence. Prefer P0/P1 comments; include P2 only when the fix is clear and useful; keep P3 Patch or P3 Future items in the summary unless explicitly worth an inline note. In legacy terms: keep P3 and Future items in the summary.
Priority mapping: P0 for Blocker, P1 for Major, P2 for Minor, P3 for Patch or Future. Legacy aliases normalize to this scale: P0 bug/blocker, P1 major, P2 minor, P3 patch, Future follow-up. Every posted/comment-ready item must include exactly one priority label. P0/P1 block merge; P2 fix or track; P3 optional polish or later cleanup.
Every confirmed bug is P0 or P1. If a bug is diagnosed and reproduced, it must be posted inline with the matching P0/P1 priority; do not demote bugs to P2/P3 because the fix is small. P0 = merge-blocking crash, data loss, security/privacy exposure, corrupt state, outage, impossible core flow, or entirely missing required behavior. P1 = normal-user defect, regression, broken contract/spec, fake success, major accessibility failure, or high-risk edge.
Place each PR comment on the tightest changed file/range that introduces the issue. Prefer the exact changed line; if the exact line is not in the diff, use the nearest changed line with context. If no accurate inline location exists, use a top-level PR comment-ready item and explain why inline placement is unsafe.
Comment template: What, Why, Suggested fix, One-shot prompt. Prefix every comment with Priority. Keep each comment short. One-shot prompt must be one sentence when simple and name repo/branch, file/range, exact requested change, and verify command when safe; otherwise say why no safe one-shot exists.

### Standards

Read standards + diff. Report documented violations only. Cite file + rule. Separate hard violations from judgment calls. Skip what tooling enforces. Max 400 words.

### Spec

Read spec + diff. Report missing/partial requirements, scope creep, wrong behavior. Quote spec line for each finding. Max 400 words. Skip if no spec.

## Local review routing

Each hat checks its gate: UI/copy/forms/routes/reports/CLI/TUI/visual -> `/visual-review`; forms/validation/async/data/mutations/cache/state/config/destructive/error/loading/empty -> `/resilience-review`; auth/permissions/tenant/secrets/HTML/parsing/network/file/deps/logging/privacy -> security/privacy triage; assumptions/abuse/bypass/rollback/surprise/spec holes -> adversarial; behavior/tests/perf/bundle/runtime/render/network -> test/perf; release candidate/large PR/risky refactor/security/privacy/perf/test concern -> `/thermo-nuclear-code-quality-review`.

Do not recursively invoke /review from a local gate already running inside `/review`. Do not duplicate local gate reports. Link or summarize verdicts.

## Output
See [REFERENCE.md](REFERENCE.md) for detailed report schema and examples.

```md
## Review
Fixed point: <fixed>
Diff: `git diff <fixed>...HEAD`
Subagents: ponytail-review-hat: <status> | thermo-nuclear-review-hat: <status/skipped: reason> | resilience-review-hat: <status/skipped: reason> | regular-review-hat: <status> | adversarial-review-hat: <status> | visual-review-hat: <status/skipped: reason> | test-perf-review-hat: <status/skipped: reason> | security-privacy-triage-hat: <status/skipped: reason>
## Standards: <findings or pass>
## Spec: <findings, pass, or no spec available>
## Local review gates: Ponytail review: pass|findings; <per-hat pass|findings|skipped>
## PR value gate:
Major improvement: <quantified claim, beneficiary, evidence, delta>
Value score: HIGH|MEDIUM|LOW|NONE
Steelman: not needed | ran: <confirmed value | mixed | low-value>
Gate: pass | low-value | blocked pending override
## Summary: What's working: <1-3 bullets>; Needs attention: <P0/P1/P2 counts>; Follow-ups: <P3 Patch/Future items, skipped lanes, evidence gaps>
## PR comments:
Posted: <count> | Comment-ready fallback: <count> | Skipped as summary-only: <count>
- [P0 Blocker|P1 Major|P2 Minor|P3 Patch|P3 Future] <file:line> <title> -- <posted|comment-ready|summary-only>
```

Rules: keep Standards and Spec separate. Findings need evidence. No vague praise.
