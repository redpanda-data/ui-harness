# Go -- Reference

## Flowchart

```mermaid
flowchart TD
    Start([/go invoked]) --> Gate{Work to ship?}

    Gate -->|No changes| Stop([Nothing to ship])
    Gate -->|Has changes| P4

    P4[4. Verify<br/>types + lint + tests] --> Green{All green?}
    Green -->|No| Fix4[Fix failures]
    Fix4 --> P4
    Green -->|Yes| Commit4[Commit passing state]

    Commit4 --> SmallDiff{Trivial?<br/>< 10 lines}
    SmallDiff -->|Yes| P5
    SmallDiff -->|No| P4b

    P4b[4b. Refine<br/>self-reviewer + adversarial] --> Findings{P0/P1?}
    Findings -->|Yes| FixFindings[Fix + re-verify]
    FixFindings -->|Round < 2| P4b
    FixFindings -->|Round = 2| P5
    Findings -->|No| P5

    P5[5. /simplify -> /commit-push-pr<br/>+ code-reviewer] --> P5b

    P5b[5b. Iterate<br/>Monitor CI] --> CI{CI status?}
    CI -->|Failing| FixCI[Diagnose + fix + push]
    FixCI --> P5b
    CI -->|Pending| Wait[Monitor: gh pr checks --watch]
    Wait --> CI
    CI -->|Passing| Reviews{Review comments?}

    Reviews -->|Yes| Resolve[/resolve-pr-feedback]
    Resolve --> Round{Round < 2?}
    Round -->|Yes| P5b
    Round -->|No| Handoff
    Reviews -->|No| Handoff

    Handoff --> Learn{Non-trivial<br/>learning?}
    Learn -->|Yes| P6[6. Compound<br/>.claude/rules/]
    Learn -->|No| Done
    P6 --> Done([PR URL + status. Stop.])

    style P4 fill:#f96,stroke:#333
    style P4b fill:#f9f,stroke:#333
    style P5 fill:#69f,stroke:#333
    style Done fill:#9c6,stroke:#333
```

## Phase 4: Verify -- Checklist

### Automated Checks

```bash
# 1. Type check
bun run type:check

# 2. Lint + autofix
bun run lint:fix

# 3. Related tests
bun vitest run --related

# 4. Visual tests (if route touched)
bun vitest run *.browser.test.tsx

# 5. Browser smoke (if available)
# scripts/skills-browser.sh / Playwright: navigate to dev server, verify UI

# 6. Frontend diff: run /visual-review
# screenshots + states + a11y + console + mobile/cross-browser where feasible
```

### Browser Verification

**Never ask user verify.** Use tools:

- `claude-in-chrome` MCP: open dev server URL, verify visual, screenshot
- Playwright: automated E2E asserts
- `Monitor: bun run dev` -- watch ready, verify

**When**: UI changes, route changes, visual regressions. **Skip**: pure logic, API, data-layer.

### Visual Review Gate

Frontend diff -> run `/visual-review` before `/commit-push-pr`, unless the change is docs-only, test-only, type-only, backend-only, or explicitly skipped with reason.

Frontend diff includes:

- `*.tsx`, `*.jsx`, `*.css`, `*.scss`, `*.html`
- `src/routes/`, `src/pages/`, `src/app/`, `src/components/`, `components/ui/`
- Tailwind/theme/config files that affect rendered UI

Use `/visual-review` output for the PR screenshot table and test plan. Follow `visual-review/REFERENCE.md` PR evidence contract.

### Commit on Green

Each passing verify state = one commit. Format: `type(scope): what changed`.

## Phase 4b: Refine -- Findings Triage

### Dispatch Rules

| Condition | Agents |
|---|---|
| Any non-trivial diff | `self-reviewer` |
| Diff >50 lines | `self-reviewer` + `adversarial-reviewer` |
| Touches auth/security paths | `self-reviewer` + `adversarial-reviewer` |
| Trivial (<10 lines, no logic) | Skip 4b entirely |

### Priority Actions

| Priority | Action |
|---|---|
| P0 (blocks merge) | Fix now, re-run tests |
| P1 (should fix) | Fix, re-run tests |
| P2 `safe_auto` | Apply auto |
| P2 `gated_auto` | Show user, apply on confirm |
| P2 `manual` | Report, user decide |
| P3 / `advisory` | Skip -- log for Phase 6 |

### Refinement Rounds

- Max 2 rounds. After each: commit fixes, re-verify (tests + types + lint)
- P0/P1 persist after round 2 -> go Phase 5, flag in PR description

## Phase 5: Simplify + Ship

### Sequence

1. **`/simplify`** -- review changed code for:
   - Reuse chances (existing components/utilities)
   - Code quality (DRY, naming, structure)
   - Efficiency (needless re-renders, bundle impact)

2. **Fix issues** from `/simplify`, commit

3. **`/visual-review`** -- if frontend diff and not already run in Phase 4. Capture screenshots, states, a11y/console issues, and cross-browser/mobile notes. Fix P0/P1 or record user-accepted skip/deferral.

4. **`/commit-push-pr`** -- handle:
   - Categorized conventional commits
   - Branch strategy
   - Push with tracking
   - PR creation with structured body
   - CI monitor

5. **`code-reviewer` agent** -- dispatch on PR for fresh-eyes review

### Security Gate

Before PR creation, verify:
- [ ] No new critical/high SAST findings
- [ ] No deps with known CVEs
- [ ] No `eval()` / `innerHTML` / `dangerouslySetInnerHTML` without sanitization
- [ ] No hardcoded secrets/tokens/API keys

## Phase 5b: Iterate

### Round 1 -- Initial

1. Push + `Monitor: gh pr checks <pr-number> --watch`
2. CI green -> dispatch `code-reviewer`
3. `/resolve-pr-feedback` to triage, fix, reply, push
4. Monitor CI again

### Round 2 -- Verification

1. `code-reviewer` (verify Round 1 fixes)
2. `/resolve-pr-feedback` for remain findings
3. New issues -> fix, push, monitor CI
4. **NO third round**

### Hand Off

1. Post final PR comment: changes, findings, how addressed, test coverage
2. `gh pr edit <number> --add-reviewer <username>`
3. **Stop.** No poll for human approval.

### Re-entry (New Session)

If human request change later:
1. `/resolve-pr-feedback` -- fetch, triage, fix, reply, push
2. Monitor CI after push
3. One more `code-reviewer` round + `/resolve-pr-feedback`
4. Re-request human review, stop

## Phase 6: Compound

### When to Compound

- Bug fix reveal non-obvious pattern
- Migration gotcha that recur
- API contract/convention team agreed on

### When NOT to Compound

- One-off fix unlikely recur
- Pattern already covered by hook
- Generic knowledge Claude already has

### Format

```markdown
<!-- .claude/rules/<topic>.md -->
---
paths:
  - "**/<matching-glob>"
---
Rule description. Auto-loads when Claude works on matching files.
```

### Regression Evals

AI-caused bug -> classify failure -> make regression test -> add to CI -> track patterns (3+ recurrences -> `.claude/rules/` entry).

## Lifecycle Integration

`/go` = phases 4-6 of `/development-lifecycle`. Lifecycle Phase 3 (Implement/TDD) hands off to `/go` when implementation done.

```
/development-lifecycle phases 1-3 -> /go phases 4-6
```

`lifecycle-stop.sh` gates still fire at session end. `/go` front-run them so no surprise blocks.