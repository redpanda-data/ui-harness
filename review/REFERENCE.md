# Review reference

Detailed rules for `/review`. `SKILL.md` is the routing contract; this file holds longer schema and examples.

## PR comment priority policy

Use exactly one priority label on every posted or comment-ready finding:

| Label | Meaning | Merge rule |
|---|---|---|
| P0 Blocker | Crash, data loss, security/privacy exposure, corrupt state, outage, impossible core flow, or entirely missing required behavior | Block merge |
| P1 Major | Normal-user defect, regression, broken contract/spec, fake success, major accessibility failure, or high-risk edge | Block unless owner override |
| P2 Minor | Clear contained edge case, maintainability, performance, observability, or test gap | Fix or track |
| P3 Patch | Optional polish or tiny cleanup | Summary-only by default |
| P3 Future | Valid follow-up for another PR or later cleanup | Summary-only by default |

Every confirmed bug is P0 or P1. If a bug is diagnosed and reproduced, post it inline with the matching P0/P1 priority. Do not demote a bug because the fix is small.

## Targeting PR comments

Resolve the PR target in order:

1. Explicit PR URL or number from the user.
2. PR targeted by the skill invocation.
3. Open PR for the current branch.
4. If none or ambiguous, emit comment-ready output instead.

Post comments only after all hats finish and findings are merged and deduped. Never comment during individual hats.

Place comments on the tightest changed file/range introducing the issue. Prefer the exact changed line. If the exact line is outside the diff, use the nearest changed line with context. If no accurate inline location exists, produce a top-level comment-ready item and explain why inline placement is unsafe.

## Comment template

Use this shape for posted and comment-ready items:

```md
[P1 Major] <short title>
What: <one sentence about the defect>
Why: <production/user impact>
Suggested fix: <specific change>
One-shot prompt: In <repo> on <branch>, update <file:range> to <exact request>, then run <safe verify command>.
```

If no safe one-shot prompt exists, say why in one sentence.

## Report schema

```md
## Review
Fixed point: <fixed>
Diff: `git diff <fixed>...HEAD`
Subagents: thermo-nuclear-review-hat: <status/skipped: reason> | resilience-review-hat: <status/skipped: reason> | regular-review-hat: <status> | adversarial-review-hat: <status> | visual-review-hat: <status/skipped: reason> | test-perf-review-hat: <status/skipped: reason> | security-privacy-triage-hat: <status/skipped: reason>

## Standards
<findings or pass>

## Spec
<findings, pass, or no spec available>

## Local review gates
Thermo nuclear review: pass|findings|skipped: <reason>; Resilience review: pass|findings|skipped; Regular review: pass|findings; Adversarial review: pass|findings; Visual review: pass|findings|skipped; Test/perf review: pass|findings|skipped; Security/privacy triage: pass|findings|skipped.

## PR value gate
Major improvement: <quantified claim, beneficiary, evidence, delta>
Value score: HIGH|MEDIUM|LOW|NONE
Steelman: not needed | ran: <confirmed value | mixed | low-value>
Gate: pass | low-value | blocked pending override

## Summary
What's working: <1-3 concise bullets about verified strengths>
Needs attention: <P0/P1/P2 counts and highest-impact risks>
Follow-ups: <P3 Patch/Future items, skipped lanes, evidence gaps>

## PR comments
Posted: <count> | Comment-ready fallback: <count> | Skipped as summary-only: <count>
- [P0 Blocker|P1 Major|P2 Minor|P3 Patch|P3 Future] <file:line> <title> -- <posted|comment-ready|summary-only>
```

## Example inline comment

```md
[P1 Major] Mutation reports success before cache refresh
What: The save handler resolves before the list query is invalidated.
Why: Normal users can return to stale data and believe their change was lost.
Suggested fix: Await the invalidation before showing the success state.
One-shot prompt: In malinskibeniamin/skills on codex/example, update src/items/save.ts:42-47 to await query invalidation before success, then run `bun test src/items/save.test.ts`.
```
