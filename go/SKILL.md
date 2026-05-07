---
name: go
description: "Ship what built. Run verify -> self-review -> simplify -> commit-push-pr -> monitor CI -> fix -> done. Use when implementation done, ready to launch."
---

# Go -- Ship What You Built

Phases 4-6 of `/development-lifecycle`, standalone command. Use when code written, ready launch.

**Assumes**: implementation done, tests written. If not -- run `/development-lifecycle`.

## Phase 4: Verify

Run all checks. Fix failures before proceed.

1. `bun run type:check` (tsgo)
2. `bun run lint:fix` (biome)
3. `bun vitest run --related` (changed files)
4. Route touched -> `bun vitest run *.browser.test.tsx`
5. Dev server running -> browser smoke via `scripts/skills-browser.sh` (Vercel agent-browser). Skip if not installed.
6. **When green: commit now.** One commit per passing state.

## Phase 4b: Refine (Self-Review Loop)

**Skip if**: trivial change (<10 lines, no logic) | test-only | docs-only.

1. Dispatch `self-reviewer` agent on session diff
2. Diff >50 lines OR touches auth/security -> also dispatch `adversarial-reviewer` parallel
3. Process findings by priority -- see [REFERENCE.md](REFERENCE.md)
4. Fix P0/P1 now, apply P2 `safe_auto`, show P2 `gated_auto` to user
5. Commit fixes: `refactor(scope): self-review fixes`
6. Re-verify (tests + types + lint)
7. **Max 2 refine rounds.** Then proceed.

## Phase 5: Simplify + Ship

1. Run `/simplify` -- review changed code for reuse, quality, efficiency
2. Fix issues, commit
3. Run `/commit-push-pr` -- conventional commits, push, open PR
4. Dispatch `code-reviewer` agent (fresh-eyes review)

## Phase 5b: Iterate

1. `Monitor: gh pr checks <number> --watch` -- stream CI background
2. CI fail -> diagnose, fix, push, re-monitor
3. `code-reviewer` agent findings -> `/resolve-pr-feedback` triage, fix, reply, push
4. **AI self-review cap**: up to 3 auto `code-reviewer` rounds. **Early-exit** when reviewer returns `APPROVED` or empty findings -- never run round N+1 on clean round N. After 3 rounds still noisy -> hand off to human.
5. **Human review (incl cloud/Copilot)**: NO cap. Address EVERY thread. `pr-feedback-completeness-stop` hook blocks session exit until `bash scripts/pr-unresolved-count.sh` returns 0 and no CHANGES_REQUESTED reviews remain.

## Phase 6: Compound

After non-trivial tasks: "Learn something worth preserve?"

- Write rule to `.claude/rules/<topic>.md` with `paths:` glob
- AI bug -> create eval/test fixture catch same error class

## Done

1. Post final PR comment: changes, review findings, test coverage
2. Request review: `gh pr edit <number> --add-reviewer <username>`
3. Report PR URL + CI status
4. **Stop.** No poll for human approval.

## Entry Gate

Before start, check work to ship:

- No uncommitted changes AND no unpushed commits -> nothing do, stop
- On default branch, no feature branch -> **auto-spawn via `scripts/mux-worktree.sh <type>/<name>`** before proceed. Never ship from main. [ETHOS: Worktree Isolation]

## Skills Composed

| Skill | Phase | How |
|---|---|---|
| `self-reviewer` agent | 4b | Auto-dispatch on diff |
| `adversarial-reviewer` agent | 4b | Conditional (>50 lines or auth/security) |
| `/simplify` | 5 | Code quality review |
| `/commit-push-pr` | 5 | Conventional commits + push + PR |
| `code-reviewer` agent | 5 | Fresh-eyes review on PR |
| `/resolve-pr-feedback` | 5b | Triage + fix review comments |

See [REFERENCE.md](REFERENCE.md) for detailed checklists, gate logic, flowchart.