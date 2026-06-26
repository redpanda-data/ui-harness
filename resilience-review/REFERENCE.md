# Resilience Review Reference

## Frame

Murphy law: if normal user/system can hit weird state, assume it will. Focus resilience, not security review.

Prior art: layered workflows, gstack QA (evidence -> tests), Matt Pocock skills (small SKILL.md), footgun checklists.

## Standard

If user can do wrong thing or system can drift bad, that path should not be allowed. Prevent, block, recover. Do not rely on docs, copy, or expert memory.

Non-author view: obvious to builder is invisible to user. Assume missing fields, stale UI, wrong project/resource, wrong secret, impatient clicks, reload/back, multi-tab, slow net.

## Probes

For each form/API/mutation/config/job:

- User mistakes: missing required fields, wrong format/project/env/secret/resource, accidental click.
- Controls: Stale enabled button, disabled bypass, hidden submit, Enter key submit, autofill.
- Value: empty, null, duplicate, stale, malformed, huge, unsupported enum.
- Time: stale, slow, timeout, cancelled, double submit, tab race.
- State: mode switch, partial edit, dirty form, deleted resource, stale cache.
- System: partial outage, 500, retry storm, queue delay, background failure.
- UX: loading, empty, error, success, disabled, optimistic, rollback.

## Layers

Core: Precondition -> Postcondition -> Fallback -> Observability.

| Layer | Ask | Defense |
|---|---|---|
| Precondition | Can bad action start? | schema, type guard, field error, disabled submit |
| Invariant | Can bad state exist? | cross-field check, ownership match, exhaustive switch |
| Postcondition | Did action finish right? | verify state, idempotency, rollback, cache update |
| Fallback | Dependency fails? | retry, error state, partial data, safe empty |
| Observability | Will we know? | log context, metric, audit event, request ID |

## Finding pipeline

Every real finding gets own loop:

1. `/diagnosing-bugs`: build feedback loop; repro exact symptom; capture artifact.
2. `/tdd`: convert finding to RED test before fix; public UI/API seam preferred.
3. Fix: pass test; add snapshot/verification for visual, serialized, config state.
4. `/visual-review`: UI pass for error text, disabled state, loading/error/empty/success, layout.
5. PR evidence: finding -> diagnosing-bugs loop -> RED test/snapshot -> fix -> visual review or skip reason.

## Verdict

| Verdict | Use when | Action |
|---|---|---|
| `PASS` | Covered/harmless | Document evidence |
| `NEEDS_GUARDS` | User stuck/confused, bad config, support/on-call noise | Add guard/test or accepted deferral |
| `BLOCKED` | Crash, corrupt state, data loss, outage, irreversible wrong action | Stop, fix before ship |

P0=crash/corruption/data loss/outage. P1=normal-user stuck path/silent failure/fake success/no recovery. P2=edge/polish/observability. P3=copy/help.

## Examples

- form validation: Missing required fields -> inline errors, no request; invalid URL -> field error; server errors -> all errors visible. Finding queue: Diagnose empty submit/error mapping; TDD RED tests; Visual review error text/focus/disabled submit.
- disabled button edge and double submit: Stale enabled button, Enter key bypass, double click -> submit handler revalidates + pending/idempotency lock. Diagnose validator race; TDD out-of-order validation test; Visual review button/spinner/recovery/focus.
- partial outage: Save 500 keeps form dirty + retry; stale cache updates row; deleted resource explains 404, no crash. Diagnose 500/stale-cache/deleted-resource; TDD recovery/cache tests; Visual review loading/error/retry/success.
- config/resource footgun: wrong project secret rejected by ownership check; mode switch ghost data clears inactive fields. Diagnose wrong-project payload; TDD ownership/ghost-data tests; Visual review selected project/resource before submit.

PR evidence minimum: risk surface, Failure matrix, Finding queue, required tests/deferrals, polish gaps, observability note.
