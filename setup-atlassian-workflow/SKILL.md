---
name: setup-atlassian-workflow
description: Opt-in Atlassian/Jira integration via acli -- create work items, transition status, comment, link PRs. Mirrors gh-based workflow skills for Jira users. Use when working with Jira, Atlassian, or acli.
---

# Setup Atlassian Workflow

Opt-in Jira integration via `acli` (Atlassian CLI). Works alongside `gh`. If `acli` missing, Jira ops skip silent.

Capabilities: create/transition/comment work items, link PRs, search/view for context.

See [REFERENCE.md](REFERENCE.md) for acli command patterns.

## Steps

### 1. Install + Authenticate
```bash
# Install: https://developer.atlassian.com/cloud/acli/guides/installation/
acli jira auth login
acli jira auth status  # verify
```

### 2. Configure session-env.sh
```bash
if command -v acli &>/dev/null; then
  echo "export JIRA_PROJECT=YOUR_PROJECT_KEY" >> "$CLAUDE_ENV_FILE"
  echo "export ISSUE_TRACKER=acli" >> "$CLAUDE_ENV_FILE"
fi
```
Set `ISSUE_TRACKER=both` for parallel gh + acli.

### 3. Verify
- [ ] `acli jira auth status` authenticated
- [ ] `JIRA_PROJECT` set in session env