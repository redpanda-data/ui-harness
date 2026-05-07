---
name: commit-push-pr
description: Analyze changes, create categorized conventional commits, push, and open a PR. Use when user asks to open a PR, invokes `/commit-push-pr`, or requests a full commit -> push -> PR flow with CI monitoring.
---

# Commit, push, and open PR

See [REFERENCE.md](REFERENCE.md) for commit-type table, auto-label map, PR body template.

## Step 0: Gather context

Run these Bash commands before proceed:

- `git status -sb` -- working-tree state
- `git diff HEAD` -- staged + unstaged changes
- `git branch --show-current` -- current branch
- `gh repo view --json defaultBranchRef -q '.defaultBranchRef.name'` -- default branch
- `git log --oneline -5` -- recent commits for style ref
- `gh pr list --head $(git branch --show-current) --json number,url,title --jq '.[0] // empty'` -- existing PR on branch

## Prerequisites

1. Verify `gh --version` -- if missing, stop, ask user install
2. Verify `gh auth status` -- if not authed, ask user run `gh auth login` and stop
3. Verify inside git repo

## Your task

Execute full commit-push-PR flow below in single response.

### Phase 0: Pre-flight -- verify review skill ran

Check REFERENCE.md for review skill list. If NONE ran this session, warn and block unless user confirms skip.

### Phase 1: Scope confirmation

1. Inspect status and diff above
2. PR exists on branch (from context) -> inform user, new commits update existing PR. Skip to Phase 3.
3. Worktree has unrelated changes -> **ask user** which files belong. Never default `git add -A`
4. Present file list grouped by category for confirmation before proceed

### Phase 2: Branch strategy

1. On default branch -> create new branch `type/description` (e.g. `feat/add-commit-push-command`) and switch
2. Else stay on current branch

### Phase 3: Categorized commits

Group changed files by conventional commit type (see REFERENCE.md type table).

**For each category with files:**

1. Stage only relevant files with explicit paths: `git add <file1> <file2> ...` -- never `git add -A` or `git add .`
2. Commit: `type(scope): terse description`
   - Infer scope from directory/module
   - Lowercase first letter, 5-72 chars, no trailing period
   - Include `Co-Authored-By` trailer
3. Next category

Record commit types created -- used for auto-labeling Phase 5.

### Phase 4: Push

1. Show what push: `git log --oneline origin/<branch>..HEAD 2>/dev/null || git log --oneline -5`
2. Push with tracking: `git push -u origin $(git branch --show-current)`
3. Never force push -- `--force-with-lease` OK when needed (after rebase)

### Phase 5: Open pull request

**PR exists** (from context) -> skip to Phase 6, push updated it already.

1. Determine base branch from context
2. Build `gh pr create` with `--base`, `--fill-verbose`, `--assignee @me`
3. Auto-label from commit types (see REFERENCE.md auto-label map)
4. Override auto-filled body with structured template (see REFERENCE.md PR body template)
5. Frontend change detected (REFERENCE.md rule) -> include Screenshots table summarizing visual changes. One row per affected view (before/after/notes). Omit section if no frontend diff
6. Print PR URL

### Phase 6: Watch CI (MANDATORY)

1. **Always** stream CI checks: `gh pr checks <PR_NUMBER> --watch` via Monitor tool
2. Never use `sleep` + polling -- use `--watch` flag
3. Never skip -- CI failures caught here save time
4. Checks fail -> read logs, diagnose, fix, commit, push, re-watch
5. No CI configured -> note and proceed

### Phase 7: Verify and summarize

1. Run `git status` and `git diff` to confirm clean worktree
2. Anything uncommitted remains -> warn user
3. Summarize: branch name, commits, PR URL (or existing PR URL), CI status, remaining user actions

### Safety

- Never stage unrelated changes silently
- Never push without confirming scope when worktree mixed
- Never force push -- `--force-with-lease` OK when needed (after rebase)
- No accessible git remote -> stop, explain blocker
- `gh pr create` fails -> show error, suggest `--recover` flag for retry