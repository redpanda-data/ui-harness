---
name: hook-audit
description: Analyze hook effectiveness + session retro from collected metrics. Use when user asks to audit hooks, invokes `/hook-audit`, wants to identify silent/over-aggressive/under-enforced hooks, or asks for a retro / team analytics across recent sessions.
---

# Hook audit

## Step 0: Gather context

Run Bash commands before proceed:

- `ls "$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/"*.sh 2>/dev/null | wc -l` -- installed hook scripts
- `ls ~/.claude/hook-metrics/*.json 2>/dev/null | wc -l` -- session summaries collected
- `ls ~/.claude/hook-metrics/*.json 2>/dev/null | head -1 | xargs -I{} jq -r '.date' {}` -- earliest date
- `ls ~/.claude/hook-metrics/*.json 2>/dev/null | tail -1 | xargs -I{} jq -r '.date' {}` -- latest date

Metrics dir: `~/.claude/hook-metrics/`

## Your task

Analyze hook effectiveness across all session metrics. Read every JSON in `~/.claude/hook-metrics/`. Produce report:

### 1. Hook activity

Each hook fired >=1 across sessions:
- Total blocks, warns, denies
- Avg fires per session
- Trend: up or down over time?

### 2. Silent hooks

List hook scripts in `.claude/hooks/` with **zero entries** in any metrics file. Prune candidates -- never trigger or not wired to logging.

### 3. Over-aggressive hooks

High block counts hurt productivity:
- Blocks-per-session ratio > 3 -> flag too strict
- Same rule blocked repeat in one session -> agent retry and fail

### 4. Enforcement gaps

Cross-ref CLAUDE.md rules vs hook activity:
- Rules with hook but zero fires -> followed perfect or untested
- Rules with no hook -> advisory, no enforce

### 5. Recommendations

From data:
- **Prune**: hooks never fire (remove or merge)
- **Soften**: hooks block too much (demote to warn)
- **Harden**: warns fire often (promote to block)
- **Add**: CLAUDE.md rules with no hook enforce

### 6. Retro analytics (session flow)

Broader than hook-level. Pull from session JSONL + git log same window as metrics.

- **Sessions -> PR lag**: median time from first edit to PR open. High lag = planning thrash.
- **CI first-try pass rate**: PRs green on first CI run / total PRs. Low = hooks missed pre-commit catches.
- **Phases skipped in `/development-lifecycle`**: sessions wrote code without prior grill step (infer from session-touched-files + absence of grill markers). High skip = gate ineffective.
- **Review-round distribution**: how often hit 0/1/2/3 AI self-review rounds? Bulk at 3 = reviewer too picky or code quality trending down.
- **Human-review resolution latency**: time from human review comment -> resolved thread. High = bottleneck.
- **Worktree sprawl**: count active worktrees per repo. >4 sustained -> investigate with `/mux --list` candidates for prune.

Output per-metric: current value, 7-day trend (up/down/flat), actionable next step.

### Mode flags

`$ARGUMENTS`:
- empty / `--hooks` -> run sections 1-5 only (default).
- `--retro` -> run sections 1-6 with emphasis on section 6.
- `--all` -> all sections, no emphasis.

### Output format

Structured report. Tables where data fit. End with prioritized action list (max 5). If <5 session files, note data limited, recs preliminary.