# Anthropic "Lessons from Building Claude Code" Blog Evaluation

**Date:** 2026-04-13
**Status:** Analysed -- no action needed
**Source:** Anthropic blog post "Lessons from Building Claude Code: How We Use Skills"

## What It Covers

Anthropic's internal lessons from hundreds of skills in active use. Defines 9 skill categories, 11 authoring tips, and distribution/marketplace patterns.

## Skill Categories: Coverage Map

| Category | Blog Examples | Our Coverage | Notes |
|---|---|---|---|
| **Library & API Reference** | billing-lib, internal-platform-cli, frontend-design | **Covered** -- setup-connect-query, setup-react-rules, setup-registry-workflow | Our skills go further: they enforce via hooks, not just document |
| **Product Verification** | signup-flow-driver, checkout-verifier | **Partial** -- verifier.md agent exists | No flow-specific verification skills with programmatic assertions. Outside core scope (we're enforcement, not QA) |
| **Data Fetching & Analysis** | funnel-query, cohort-compare, grafana | **N/A** | Outside scope -- we're frontend enforcement skills |
| **Business Process** | standup-post, create-ticket, weekly-recap | **Partial** -- setup-atlassian-workflow, work-automation-kit | Enough for our needs |
| **Code Scaffolding** | new-workflow, new-migration, create-app | **Covered** -- frontend-starter-kit (14 skills), redpanda-frontend-kit | |
| **Code Quality & Review** | adversarial-review, code-style, testing-practices | **Exceeds** -- 3 reviewer agents, 13 PostToolUse validators, structured findings schema | Our strongest category |
| **CI/CD & Deployment** | babysit-pr, deploy-service, cherry-pick-prod | **Partial** -- setup-ci-pipeline, development-lifecycle monitors CI | No babysit-pr equivalent |
| **Runbooks** | service-debugging, oncall-runner | **N/A** | Outside scope |
| **Infrastructure Ops** | orphan-cleanup, dependency-management | **N/A** | Outside scope |

## Authoring Tips: Coverage Map

| Tip | Blog Advice | Our Status |
|---|---|---|
| **Don't State Obvious** | Focus on info that pushes Claude out of defaults | **Already do** -- skills focus on enforcement + edge cases |
| **Gotchas Section** | Highest-signal content in any skill | **Handled differently** -- our hooks catch violations reactively + REFERENCE.md covers edge cases proactively. See analysis below |
| **File System & Progressive Disclosure** | Skill = folder, not just markdown | **Already do** -- 3-tier SKILL/SETUP/REFERENCE + scripts/ dirs |
| **Avoid Railroading** | Give flexibility, not rigid scripts | **Already do** -- escape hatches (`// allow: [rule] [reason]`) in every enforcement hook |
| **Think Through Setup** | config.json per skill for user setup | **Different approach** -- env vars (REACT_COMPILER_MODE, etc). Works fine |
| **Description Field for Model** | Description = trigger condition, not summary | **Already do** -- SKILL.md frontmatter descriptions are trigger-focused |
| **Memory & Storing Data** | Append-only logs, SQLite, CLAUDE_PLUGIN_DATA | **Session-scoped only** -- /tmp/hook-session-*. Cross-session data not needed for enforcement |
| **Store Scripts & Generate Code** | Give Claude composable code | **Already do** -- 35 hook scripts, shared hook-lib.sh |
| **On-Demand Hooks** | /careful blocks destructive ops, /freeze blocks edits | **Not implemented** -- novel idea but outside our enforcement domain |
| **Distribution** | Marketplace vs checked-in | **Both** -- marketplace.json + .claude-plugin + .codex-plugin |
| **Measuring Skills** | PreToolUse hook logging usage | **Already do** -- violation tracking via hook_block/hook_warn, aggregated at Stop |

## Key Analysis: Why We Don't Need Gotchas Sections

Blog says gotchas = highest-signal content. True for most skills. Not for ours.

The gotchas pattern assumes: guidance -> Claude attempts -> fails -> user adds gotcha -> next time Claude reads gotcha -> avoids mistake.

Our architecture closes this loop differently:

1. **SKILL.md** tells Claude the rules (proactive guidance)
2. **Hooks** catch violations in real-time (reactive enforcement)
3. **Violation feedback** teaches Claude mid-session (adaptive correction)

A gotchas section would duplicate what hooks already enforce. The few genuine gotchas too nuanced for hook detection (for example, protobuf Timestamp sub-millisecond precision loss) are already in REFERENCE.md files.

## What We Exceed

- **Hook architecture**: 35 hooks, 7 lifecycle events, symlink management -- blog shows basic examples
- **Enforcement**: PostToolUse validation on every Edit/Write -- blog skills are mostly passive
- **Measurement**: Per-session violation tracking with aggregation -- blog suggests basic PreToolUse logging
- **Multi-harness**: Claude Code + Codex compatibility -- blog covers Claude Code only
- **Reviewer infrastructure**: 3 agents with structured JSON findings schema -- blog mentions adversarial-review without detail
- **Escape hatches**: Every enforcement rule has `// allow:` override -- blog doesn't address this

## Conclusion

We're architecturally ahead. Blog validates our approach -- every major recommendation is either already implemented or deliberately out of scope. No action items.
