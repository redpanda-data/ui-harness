# Setup Routines -- Reference

## Trigger configuration

### GitHub trigger: PR review

| Field | Value |
|---|---|
| Event | Pull request |
| Action | opened, synchronize |
| Filter | is draft = false, from fork = false |

### GitHub trigger: PR feedback resolve

| Field | Value |
|---|---|
| Event | Pull request |
| Action | review_submitted |
| Filter | is draft = false |

### GitHub trigger: issue triage

| Field | Value |
|---|---|
| Event | Issues |
| Action | opened |

### Schedule trigger: weekly health

| Field | Value |
|---|---|
| Frequency | Weekly (or weekdays) |
| Time | Monday 9:00 AM local |

### Schedule trigger: docs drift

| Field | Value |
|---|---|
| Frequency | Weekly |
| Time | Monday 10:00 AM local (offset from health check) |

## API trigger setup

For CI/CD integration (deploy verify, post-merge checks):

1. Create routine with prompt
2. Edit routine -> Add trigger -> API
3. Copy URL, generate token
4. Store token in CI secrets

```bash
# Example: trigger from GitHub Actions
curl -X POST https://api.anthropic.com/v1/claude_code/routines/trig_XXXXX/fire \
  -H "Authorization: Bearer $ROUTINE_TOKEN" \
  -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"Deploy $GITHUB_SHA completed. Run smoke checks.\"}"
```

GitHub Actions step:

```yaml
- name: Trigger post-deploy routine
  if: success()
  run: |
    curl -X POST "${{ secrets.ROUTINE_URL }}" \
      -H "Authorization: Bearer ${{ secrets.ROUTINE_TOKEN }}" \
      -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
      -H "anthropic-version: 2023-06-01" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"Deploy ${{ github.sha }} to ${{ github.ref_name }}\"}"
```

## Customization examples

### Scope to specific directories

Add to template prompt:

```
Only review files under src/features/ and src/components/.
Skip: node_modules/, dist/, *.gen.ts, *_pb.ts, coverage/.
```

### Add connector actions

```
After posting review, send summary to #code-reviews Slack channel
via Slack connector. Include PR title, verdict, link.
```

### Team-specific label taxonomy

Replace label table in issue-triage template:

```
| Type | Labels |
|---|---|
| Bug -- frontend | bug, area:frontend |
| Bug -- backend | bug, area:backend |
| Bug -- infra | bug, area:infra |
| Feature | enhancement, needs-design |
| Chore | chore |
```

### Filter PRs by team

Add to PR review trigger filters:

| Filter | Operator | Value |
|---|---|---|
| Head branch | starts with | `feature/` |
| Labels | is one of | `needs-review` |

## Noise reduction checklist

Before enable, verify:

- [ ] **PR review**: hooks handle style/pattern enforcement -- prompt say "skip what hooks catch"
- [ ] **PR feedback resolve**: has "skip ambiguous" + "max 2 CI attempts" guardrails
- [ ] **Issue triage**: labels-only for features, investigation-only for bugs
- [ ] **Weekly health**: delta-based, silent when stable
- [ ] **Docs drift**: verified drift only, no false positives
- [ ] **All templates**: test with "Run now" before enable triggers

## Enforcement flow diagram

```
┌─────────────┐
│ Trigger      │  schedule / GitHub event / API POST
└──────┬──────┘
       ▼
┌─────────────┐
│ Clone repo   │  picks up .claude/ hooks, CLAUDE.md, skills, agents
└──────┬──────┘
       ▼
┌─────────────┐
│ SessionStart │  session-env.sh, llm-env.sh
└──────┬──────┘
       ▼
┌─────────────┐
│ Execute      │  routine prompt drives session
│ prompt       │  ┌──────────────────────────┐
│              │  │ Every Edit/Write:        │
│              │  │  -> PostToolUse hooks fire │
│              │  │ Every Bash:              │
│              │  │  -> PreToolUse hooks fire  │
│              │  └──────────────────────────┘
└──────┬──────┘
       ▼
┌─────────────┐
│ Stop hooks   │  lint, typecheck, quality gates
└──────┬──────┘
       ▼
┌─────────────┐
│ Session ends │  results at claude.ai session URL
└─────────────┘
```

## Routine limits (research preview)

| Plan | Daily runs |
|---|---|
| Pro | 5 |
| Max | 15 |
| Team/Enterprise | 25 |

Extra runs consume subscription usage when overage enabled.

## Routine vs. Sandcastle vs. interactive

| Scenario | Use |
|---|---|
| Auto on every PR | **Routine** -- GitHub trigger, cloud-hosted |
| Scheduled health checks | **Routine** -- schedule trigger |
| 5+ independent issues parallel | **Sandcastle** -- parallel Docker agents |
| Overnight batch | **Sandcastle** -- AFK, local or CI |
| Interactive feature work | **Claude Code** -- direct session with human |
| CD pipeline integration | **Routine** -- API trigger from deploy script |

## Enforcement model

Routines run inside harness -- no bypass:

- **Hooks**: fire on every Edit/Write/Bash in routine session
- **CLAUDE.md**: loads from repo root | all rules active
- **Skills**: available via `/skill-name` in routine prompt
- **Agents**: reviewer agents (code-reviewer, self-reviewer, adversarial-reviewer) dispatchable
- **Stop hooks**: quality gates (lint, typecheck) fire before session ends

Update hook -> every future routine run picks up (next clone). No prompt changes needed.

## Routines vs. other automation

| Feature | Routines | Sandcastle | GitHub Actions | `/loop` |
|---|---|---|---|---|
| Runs on | Anthropic cloud | Local Docker | GitHub runners | Local CLI |
| Triggers | Schedule, GitHub, API | Manual/script | GitHub events | Timer/manual |
| Repo access | Clone per run | Mount/clone | Checkout | Current worktree |
| Hooks active | Yes (from clone) | Yes (in container) | No (unless configured) | Yes (local) |
| Parallel agents | No (1 per trigger) | Yes (N containers) | Yes (matrix) | No |
| Cost | Subscription | API keys + compute | GitHub minutes | API keys |
| Best for | Recurring single-repo | Batch parallel | CI/CD pipelines | In-session polling |

## Troubleshooting

**Hooks don't fire** -- Hooks load from `.claude/settings.json` in cloned repo. Verify file exists. Run `bash scripts/verify-install.sh` locally.

**Noisy comments** -- Tighten prompt: add "skip nitpicks", "only P0/P1", "silent approval". Review transcript where Claude wandered.

**Hits daily limit** -- Reduce trigger frequency. PR review: filter non-draft, non-fork only. Schedules: weekly not daily.

**Can't push branches** -- Default: routines only push to `claude/`-prefixed branches. Enable "Allow unrestricted branch pushes" in config if needed.

**GitHub trigger not firing** -- Claude GitHub App must install on repo. Trigger setup prompts install. `/web-setup` alone not enough -- grants clone access but not webhook delivery.