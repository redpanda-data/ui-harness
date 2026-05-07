# Atlassian Workflow Reference

## Workflow Patterns

### PRD -> Work Items (mirrors to-issues)

After `/to-prd` generate plan:

```bash
# Create epic
acli jira workitem create \
  --project "$JIRA_PROJECT" \
  --type Epic \
  --summary "User Authentication System"

# Create stories under epic
acli jira workitem create \
  --project "$JIRA_PROJECT" \
  --type Story \
  --summary "Implement JWT token generation" \
  --parent PROJ-100

acli jira workitem create \
  --project "$JIRA_PROJECT" \
  --type Story \
  --summary "Add login endpoint" \
  --parent PROJ-100
```

### Bug Triage (mirrors triage-issue)

After bug investigation:

```bash
# Create bug with investigation findings
acli jira workitem create \
  --project "$JIRA_PROJECT" \
  --type Bug \
  --priority High \
  --summary "Race condition in auth middleware causes 401 on concurrent requests" \
  --description "## Root Cause\nThe token refresh logic is not atomic...\n\n## Fix\nWrap refresh in a mutex..."

# Link to related work item
acli jira workitem link PROJ-150 PROJ-100 "is caused by"
```

### QA Session (mirrors qa skill)

During QA, auto-file findings:

```bash
acli jira workitem create \
  --project "$JIRA_PROJECT" \
  --type Bug \
  --summary "Login form does not show error on invalid credentials" \
  --label qa-session \
  --label accessibility
```

### TDD -> Work Items

After TDD diagnostics:

```bash
# File work item for flaky test
acli jira workitem create \
  --project "$JIRA_PROJECT" \
  --type Bug \
  --summary "Flaky test: auth.spec.ts intermittently fails on CI" \
  --label test-health \
  --description "## Findings\nAsync leak detected in auth.spec.ts:42..."
```

## Dual Tracker Support

When `ISSUE_TRACKER=both`:

1. Create in **both** GitHub and Jira
2. Link Jira -> GitHub issue URL
3. `gh` for PR ops (PRs in GitHub)
4. `acli` for sprint/board ops (Jira)

```bash
# Create in both
gh issue create --title "Fix auth race condition" --body "..."
acli jira workitem create --project "$JIRA_PROJECT" --type Bug --summary "Fix auth race condition"

# Link Jira to GitHub issue
acli jira workitem link PROJ-150 --url "https://github.com/org/repo/issues/42"
```

## Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `JIRA_PROJECT` | Default project key for work item creation | `CLOUD` |
| `ISSUE_TRACKER` | Tracker: `gh`, `acli`, or `both` | `acli` |

## Detection

Check `acli` available:

```bash
if command -v acli &>/dev/null && [ -n "${JIRA_PROJECT:-}" ]; then
  # acli is available and project is configured
fi
```