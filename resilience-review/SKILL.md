---
name: resilience-review
description: Resilience Review checks resilience. Use when edge cases, errors, fallback, async/data, state, or polish matter.
---

# Resilience Review

Repo/code changes: run `/deslop` before commit, push, PR, or merge.
Murphy pass: find every plausible unhappy path, then block, guard, recover, observe.

## Use when
Run `/resilience-review` for diffs touching forms, validation, submit, async/data, mutations, cache, retries, state machines, mode/union switches, config/resource choice, destructive actions, or loading/empty/error/success UI.

Skip docs/test/style/trivial pure logic only; record reason.

## Workflow
1. Risk surface: user action, path, state change, side effects, deps.
2. Unhappy-path inventory: normal-user mistakes, stale state, disabled-control edge, invalid input, race, outage, recovery.
3. Probes:
   - Input: empty, null, duplicate, malformed, stale, huge, out-of-order.
   - Timing: double submit, tab race, retry, slow net, timeout, cancel.
   - System: partial outage, 500, stale cache, deleted resource, permission drift.
   - UX: unclear disabled state, lost errors, fake success, no recovery.
4. Defenses: Precondition -> Postcondition -> Fallback -> Observability.
5. Finding loop: /diagnosing-bugs feedback loop -> /tdd RED test/snapshot -> /visual-review for UI validation.

## Output
```md
## Resilience review
Risk surface:
- ...
Failure matrix:
| Scenario | Trigger | Expected behavior | Guard | Test | Observability |
Finding queue:
| Finding | Repro/diagnosing-bugs loop | RED test or snapshot | Owner | Visual review needed |
Required tests:
- ...
Polish gaps:
- ...
Verdict: PASS | NEEDS_GUARDS | BLOCKED
```

Rules: cite files/routes/forms/API. Docs/help text not enough when code can prevent bad state. Real gap unfixed -> PR evidence with owner/deferral.

See [REFERENCE.md](REFERENCE.md).
