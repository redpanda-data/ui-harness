# Routine: Documentation Drift Detection

Run weekly. Detect docs drifted from codebase. Code change but docs reference old behavior -> flag.

## Important: avoid noise

- Only flag **confirmed** drift -- verify doc content and current source before reporting
- Simple renames/typos -> fix directly in PR
- Behavior changes -> open issue for human rewrite
- No drift -> do nothing. Silent success.

## Steps

### 1. Find recent changes

```bash
# Merged PRs in last 7 days
gh pr list --state merged --search "merged:>=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)" --json number,title,files --limit 50
```

### 2. Identify changed interfaces

From merged PR file lists, find files defining public interfaces:

```bash
# Check for changed exports in modified files
for file in <changed_source_files>; do
  grep -n 'export \(interface\|type\|function\|const\|class\|def \|func \)' "$file" 2>/dev/null
done
```

Look for:
- Renamed or removed exports
- Changed function signatures (parameters, return types)
- Changed configuration options
- Changed CLI flags or commands

### 3. Scan docs for stale references

```bash
# Find all doc files
find . -name '*.md' -not -path './.git/*' -not -path './node_modules/*'

# For each changed export, search docs
grep -r "changed_name" --include='*.md' -l
```

Also check:
- README.md for outdated usage examples
- REFERENCE.md files for outdated patterns
- API documentation
- Configuration examples

### 4. Verify drift

Each potential hit -> read doc and current source. Confirm doc actually wrong -- not every reference to changed file is stale.

Skip:
- CHANGELOG.md (historical, not reference)
- Auto-generated docs (they regenerate)
- Comments referencing git history

### 5. Fix simple drift

Confirmed simple drift (renamed export, changed parameter name, updated path):

```bash
git checkout -b claude/docs-drift-$(date +%Y%m%d)
# ... make fixes ...
git add <changed_docs>
git commit -m "docs: fix documentation drift from recent changes"
gh pr create --title "docs: fix documentation drift" --body "## Summary
[List of docs updated]

## Source changes
[Which PRs caused the drift]

---
*Automated by Claude Code routine.*"
```

### 6. Flag complex drift

Behavior changes needing rewrite (not find-replace):

```bash
gh issue create \
  --title "docs: documentation drift detected -- $(date +%Y-%m-%d)" \
  --label "docs,automated" \
  --body "## Documentation drift

| Document | Stale reference | Changed in PR | What changed |
|---|---|---|---|
| [path] | [what doc says] | #N | [what code does now] |

### Actions needed
[What needs rewriting and why a simple fix won't work]

---
*Detected by Claude Code routine.*"
```

### 7. Clean weeks

No drift -> no PR, no issue. Optionally close previous open drift issues now resolved.

## Rules

- Only modify documentation files, never source code
- Verify before flagging -- false positives are noise
- Bundle simple fixes into one PR per run
- Max one PR + one issue per run
- Skip auto-generated files
- Skip CHANGELOG.md and git-history references