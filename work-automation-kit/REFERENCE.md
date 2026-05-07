# Work Automation Kit Reference

## Workflow Map

```
Feature idea
  -> /to-prd (community) -- interactive PRD creation
  -> /development-lifecycle -- plan phase
  -> /domain-model -- stress-test plan + update CONTEXT.md/ADRs (auto-invoked)
  -> /to-issues (community) -- break into GitHub/Jira issues
  -> implement (use /tdd skill)
  -> code review (development-lifecycle review phase)
  -> merge

Bug report
  -> /diagnose -- feedback-loop-first, 6-phase debugging
  -> /triage -- explore codebase, find root cause, TDD fix plan, file ticket
  -> implement fix (/tdd: failing test -> fix -> verify)
  -> code review (development-lifecycle review phase)
  -> merge

Issue management
  -> /triage -- triage via state machine (GitHub via gh, Jira via acli)
  -> /qa -- interactive QA session -> auto-file issues

Design decision
  -> /brainstorming -- explore approaches + challenge decisions
  -> /development-lifecycle -- plan the chosen approach
  -> /domain-model -- stress-test the plan + sharpen terminology (auto-invoked)
  -> implement

Quick question (on a specific decision)
  -> /domain-model -- stress-test against domain model
  -> /grill-me -- lightweight stress-test (no DDD docs)
```

## Owned vs Community Skills

| Category | Owned | Community (mattpocock) |
|---|---|---|
| Testing | tdd | -- |
| Debugging | diagnose | -- |
| Triage | triage, qa | -- |
| Planning | development-lifecycle (plan phase) | to-prd, to-issues |
| Review | development-lifecycle (review phase) | -- |
| Design | brainstorming, design-an-interface | -- |
| Architecture | improve-codebase-architecture, request-refactor-plan | -- |
| DDD | domain-model | ubiquitous-language |
| Meta | write-a-skill, grill-me, zoom-out | git-guardrails |

Owned skills ship with repo. "Community" skills install from mattpocock/skills.

## Optional Integrations

| Integration | Requires | What it adds |
|---|---|---|
| setup-atlassian-workflow | `acli` installed + authenticated | Jira work items alongside GitHub issues |
| codex-plugin-cc | OpenAI API key | `/codex:adversarial-review` for cross-model challenge |