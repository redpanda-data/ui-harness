---
name: work-automation-kit
description: Install planning/project management skills -- PRD creation, implementation planning, issue breakdown, bug triage, code review. Use when setup project planning workflows or creating PRDs.
---

# Work Automation Kit

## Skills Installed

**Owned** (hook-integrated): brainstorming, domain-model, triage, diagnose, qa, zoom-out

**Community**: to-prd, to-issues, write-a-skill

**Optional**: setup-atlassian-workflow (Jira via acli, opt-in), codex-plugin-cc (cross-model review)

## Install

```bash
# Owned
bunx skills@latest add redpanda-data/ui-harness/brainstorming --agent claude-code -y

# Owned
bunx skills@latest add redpanda-data/ui-harness/domain-model --agent claude-code -y
bunx skills@latest add redpanda-data/ui-harness/triage --agent claude-code -y
bunx skills@latest add redpanda-data/ui-harness/diagnose --agent claude-code -y
bunx skills@latest add redpanda-data/ui-harness/qa --agent claude-code -y
bunx skills@latest add redpanda-data/ui-harness/zoom-out --agent claude-code -y

# Community
bunx skills@latest add mattpocock/skills/write-a-skill --agent claude-code -y
```

## Optional: Atlassian/Jira
Run `setup-atlassian-workflow` if team use Jira.