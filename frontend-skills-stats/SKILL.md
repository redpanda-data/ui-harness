---
name: frontend-skills-stats
description: Analytics dashboard for frontend-skills hook harness. Latency percentiles, top-violated rules, zero-fire hooks, session trends. Use when user ask for hook harness stats, invoke `/frontend-skills-stats`, or want latency profiling and manifest drift checks.
---

# Frontend skills stats

## Step 0: Gather context

Run these Bash commands before proceed:

- `ls "$(git rev-parse --show-toplevel 2>/dev/null)/.claude/hooks/"*.sh 2>/dev/null | wc -l` -- installed hook scripts
- `jq '[.hooks[]?[]?.hooks[]?] | length' "$(git rev-parse --show-toplevel 2>/dev/null)/skill-manifest.json"` -- wired hooks
- `ls ~/.claude/hook-metrics/*.json 2>/dev/null | wc -l` -- session summaries
- `ls ~/.claude/hook-metrics/*.json 2>/dev/null | head -1 | xargs -I{} jq -r '.date' {}` -- earliest date
- `ls ~/.claude/hook-metrics/*.json 2>/dev/null | tail -1 | xargs -I{} jq -r '.date' {}` -- latest date

Metrics dir: `~/.claude/hook-metrics/`

## Your task

Analyze frontend-skills harness across all session metrics. Read every JSON in `~/.claude/hook-metrics/`. Produce prioritized report.

### 1. Latency profile

Parse `perf_ms` from each session summary (added 2.2.2). Each hook:

| Hook | P50 (ms) | P95 (ms) | Invocations | Total wall-clock |
|---|---|---|---|---|

Flag hooks:
- P95 > 100ms -> perf budget breach
- P95 > 500ms -> critical
- Invocations = 0 all sessions -> zero-fire candidate

### 2. Rule activity

Each rule fired once+:

| Rule | Blocks | Warns | Nudges | Info | Diagnostic |
|---|---|---|---|---|---|

Detect new tier usage (nudge, info, diagnostic -- added 2.2.2). Report adoption rate.

### 3. Silent hooks (zero fires)

List wired hooks, zero fires all sessions. Prune candidates.

### 4. Over-aggressive hooks

- Blocks-per-session > 3 -> too strict, demote to warn
- Same rule blocked >= 2x one session -> Claude retrying, message unclear
- block-strict, no escape-hatch adoption -> rule too harsh

### 5. Under-enforced rules

Cross-ref CLAUDE.md rules vs hook activity:
- Rule in CLAUDE.md, no hook -> advisory; add hook or accept doc-only
- Rule has hook, zero fires -> Claude never violates; safe
- Rule has hook, high fire rate -> document in README prominently

### 6. Session health signals

- Sessions with hook errors (exit > 0 not in {0, 2}) -> config bug
- Sessions with >20 blocks same rule -> feedback loop
- Sessions with 0 hook fires -> perfect compliance or hooks dead

### 7. Manifest drift check

Compare `skill-manifest.json` vs `.claude/settings.json` and `hooks/hooks.json`:

```
bash scripts/generate-hook-configs.sh --check
```

Drift detected: RED FLAG -- drift bug regression. Run `--apply` to fix.

### Output format

Structured report. Tables for numeric data. End with prioritized action list (max 5 items). If <5 session files, mark recommendations preliminary.

Plain markdown. No emojis.