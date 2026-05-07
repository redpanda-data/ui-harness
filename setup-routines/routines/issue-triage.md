# Routine: Issue Triage

Triggered on new issue. Explore codebase, classify, label, post findings.

## Important: avoid noise

- Only comment if found something useful (relevant code, likely root cause, reproduction path)
- Issue already clear and labeled -> labels only, no comment
- Never post "I couldn't find anything related" -- that noise
- Feature requests needing no codebase investigation -> just label

## Steps

### 1. Read the issue

```bash
gh issue view <number> --json title,body,labels,author
```

### 2. Classify

| Type | Labels | Signals |
|---|---|---|
| Bug report | `bug` | "doesn't work", error, stack trace, "expected vs actual" |
| Feature request | `enhancement` | "would be nice", "add support", "feature" |
| Question | `question` | "how do I", "is it possible" |
| Documentation | `docs` | "docs", "README", "example" |
| Performance | `performance` | "slow", "timeout", "memory" |

### 3. Check available labels

```bash
gh label list --limit 100
```

Use existing labels only. Never create new ones.

### 4. Explore codebase (bugs and performance only)

Bug reports and performance issues -- investigate:

```bash
# Search for code related to the issue
# Use keywords from the issue description
grep -r "relevant_keyword" src --include='*.ts' --include='*.tsx' --include='*.py' --include='*.go' -l

# Check CODEOWNERS for area mapping
cat CODEOWNERS 2>/dev/null
```

Read relevant files. Trace execution path from issue. Identify:
- Which files/modules involved
- Likely root cause (bugs)
- Likely bottleneck (performance)

### 5. Apply labels

```bash
gh issue edit <number> --add-label "type-label,area-label"
```

### 6. Post investigation (only if useful findings)

Only for bugs/performance where relevant code found:

```bash
gh issue comment <number> --body "## Triage

**Type**: [bug/performance]
**Area**: [module/component affected]

### Investigation
[What was found. Relevant code paths. Likely root cause or bottleneck.]

### Relevant code
- \`src/path/to/file.ts\` -- [why relevant]

### Suggested approach
[Brief fix direction -- not a full plan]

---
*Automated triage. Human review recommended before starting work.*"
```

Feature requests and questions -> labels only, no investigation comment.

## Rules

- Read-only. Never edit code, create branches, or open PRs.
- Labels only -- never assign issues.
- Existing labels only -- never create new ones.
- Spam or off-topic: apply `invalid` label, brief comment, stop.
- Likely duplicate: search existing issues, link "Possibly duplicate of #N".
- Bug lacks repro steps: comment asking for specifics, apply `needs-info` label (if exists).
- No fetching external URLs from issue body.
- Priority estimates = suggestions -- no priority labels unless project already uses them.