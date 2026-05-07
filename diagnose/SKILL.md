---
name: diagnose
description: Disciplined diagnosis loop for hard bugs and performance regressions. Reproduce -> minimise -> hypothesise -> instrument -> fix -> regression-test. Use when user says "diagnose this" / "debug this", reports a bug, says something is broken/throwing/failing, or describes a performance regression.
---

# Diagnose

Discipline for hard bugs. Skip phase only if justify.

When explore codebase, use project domain glossary for mental model of relevant modules, check ADRs in area you touch.

## Phase 1 -- Build a feedback loop

**This the skill.** Rest mechanical. Fast, deterministic, agent-runnable pass/fail signal for bug -> find cause; bisection, hypothesis-test, instrument just eat that signal. No loop -> no staring at code save you. Spend big effort here. **Be aggressive. Be creative. No give up.**

### Strategies (try in roughly this order)

1. **Failing test** at any seam reach bug -- unit, integration, e2e.
2. **Curl / HTTP script** against running dev server.
3. **CLI invocation** with fixture input, diff stdout vs known-good snapshot.
4. **Headless browser script** (Playwright / Puppeteer) -- drive UI, assert DOM/console/network.
5. **Replay captured trace.** Save real network request / payload / event log to disk; replay through code path isolated.
6. **Throwaway harness.** Spin minimal subset of system (one service, mocked deps) that hit bug code path with single function call.
7. **Property / fuzz loop.** If bug "sometimes wrong output", run 1000 random inputs, watch failure mode.
8. **Bisection harness.** If bug appeared between two known states (commit, dataset, version), automate "boot at state X, check, repeat" so `git bisect run` work.
9. **Differential loop.** Run same input through old-version vs new-version (or two configs), diff output.
10. **HITL bash script.** Last resort. If human must click, drive _them_ with `scripts/hitl-loop.template.sh` so loop still structured. Captured output feed back to you.

Build right feedback loop, bug 90% fixed.

### Iterate on the loop itself

Treat loop as product. Once have _a_ loop, ask: faster? (cache setup, narrow test scope.) Sharper signal? (assert specific symptom, not "didn't crash".) More deterministic? (pin time, seed RNG, isolate filesystem, freeze network.)

30-second flaky loop barely better than no loop. 2-second deterministic loop = debug superpower.

### Non-deterministic bugs

Goal not clean repro but **higher repro rate**. Loop trigger 100x, parallel, add stress, narrow timing window, inject sleep. 50%-flake bug debuggable; 1% not -- raise rate till is.

### When you genuinely cannot build a loop

Stop. Say so. List what tried. Ask user for: (a) access to env that repro, (b) captured artifact (HAR, log dump, core dump, screen record with timestamps), or (c) permission for temporary production instrument. Do **not** hypothesise without loop.

No proceed to Phase 2 till have loop you believe.

## Phase 2 -- Reproduce

Run loop. Watch bug appear.

Confirm:

- [ ] Loop produce failure mode **user** described -- not different failure nearby. Wrong bug = wrong fix.
- [ ] Failure repro across multiple runs (or, for non-determ, repro at high enough rate to debug).
- [ ] Captured exact symptom (error message, wrong output, slow timing) so later phase verify fix really address it.

No proceed till repro bug.

## Phase 3 -- Hypothesise

Generate **3-5 ranked hypotheses** before test any. Single-hypothesis anchor on first plausible idea.

Each hypothesis must be **falsifiable**: state prediction.

> Format: "If <X> is the cause, then <changing Y> will make the bug disappear / <changing Z> will make it worse."

If cannot state prediction, hypothesis = vibe -- discard or sharpen.

**Show ranked list to user before test.** They often have domain knowledge that re-rank instant ("we just deployed change to #3"), or know hypotheses already ruled out. Cheap checkpoint, big time save. No block on it -- proceed with your ranking if user AFK.

## Phase 4 -- Instrument

Each probe must map to specific prediction from Phase 3. **Change one variable at a time.**

Tool preference:

1. **Debugger / REPL inspection** if env support. One breakpoint beat ten logs.
2. **Targeted logs** at boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at end = single grep. Untagged logs survive; tagged logs die.

**Perf branch.** For perf regression, logs usually wrong. Instead: establish baseline measurement (timing harness, `performance.now()`, profiler, query plan), then bisect. Measure first, fix second.

## Phase 5 -- Fix + regression test

Write regression test **before fix** -- but only if **correct seam** for it.

Correct seam = one where test exercise **real bug pattern** as occur at call site. If only seam too shallow (single-caller test when bug need multiple callers, unit test that can't replicate chain that triggered bug), regression test there give false confidence.

**If no correct seam exist, that itself the finding.** Note it. Codebase architecture preventing bug from lockdown. Flag for next phase.

If correct seam exist:

1. Turn minimised repro into failing test at that seam.
2. Watch it fail.
3. Apply fix.
4. Watch it pass.
5. Re-run Phase 1 feedback loop vs original (un-minimised) scenario.

## Phase 6 -- Cleanup + post-mortem

Required before declare done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes (or absence of seam is documented)
- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix)
- [ ] Throwaway prototypes deleted (or moved to a clearly-marked debug location)
- [ ] The hypothesis that turned out correct is stated in the commit / PR message -- so the next debugger learns

**Then ask: what would prevent this bug?** If answer involve architecture change (no good test seam, tangled callers, hidden coupling) hand off to `/improve-codebase-architecture` with specifics. Make recommendation **after** fix in, not before -- have more info now than at start.