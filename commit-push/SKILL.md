---
name: commit-push
description: Analyze changes, create categorized conventional commits, and push. Use when user asks to commit and push, invokes `/commit-push`, or requests conventional commits without a PR.
---

# Commit and push

## Step 0: Gather context

Run these Bash commands before proceed:

- `git status -sb` -- worktree state
- `git diff HEAD` -- staged + unstaged changes
- `git branch --show-current` -- current branch
- `gh repo view --json defaultBranchRef -q '.defaultBranchRef.name'` -- default branch
- `git log --oneline -5` -- recent commits for style

## Prerequisites

1. Verify inside git repo
2. Verify git remote exist: `git remote -v` -- if none, stop + explain

## Your task

Run full commit-and-push flow below in one response.

### Phase 0: Pre-flight -- verify review skill ran

1. Check if review skill invoked this session:
   - `/simplify` -- small fixes/tweaks
   - `/request-refactor-plan` -- refactors
   - `/improve-codebase-architecture` -- cleanup (oversized files, shallow modules, tangled deps)
   - `/design-an-interface` -- redesign module or layout
2. If NONE ran: warn -- "Lifecycle requires review skill before shipping. Recommend: `/simplify` for small changes, `/request-refactor-plan` for refactors, `/improve-codebase-architecture` for cleanup."
3. Proceed only if review skill ran or user confirm skip

### Phase 1: Scope confirmation

1. Inspect status + diff above
2. If worktree has unrelated changes, **ask user** which files belong -- no default `git add -A`
3. Show file list grouped by category for confirm before proceed

### Phase 2: Branch strategy

1. If on default branch -> make new branch `type/description` (e.g. `feat/add-commit-push-command`) + switch
2. Else stay on current branch
3. Check existing PR: `gh pr list --head $(git branch --show-current) --json number,url --jq '.[0]'` -- if PR exist, tell user (push update it)

### Phase 3: Categorized commits

Analyze changed files, group by purpose into conventional commit types:

| Type | Matches |
|------|---------|
| `docs` | *.md, SKILL.md, REFERENCE.md, comments-only changes |
| `test` | *.test.ts, *.test.tsx, *.spec.ts, EVAL.ts, agent-evals/ |
| `refactor` | restructure without behavior change |
| `style` | formatting, whitespace, lint-only fixes |
| `fix` | bug fixes, error corrections |
| `feat` | new features, components, endpoints |
| `chore` | config, deps, build scripts, tooling |
| `perf` | perf improvements |
| `ci` | CI/CD pipeline changes |
| `build` | build system changes |

**Each category with files:**

1. Stage only relevant files explicit paths: `git add <file1> <file2> ...` -- never `git add -A` or `git add .`
2. Commit: `type(scope): terse description`
   - Infer scope from dir/module
   - Lowercase first letter, 5-72 chars, no trailing period
   - Include `Co-Authored-By` trailer
3. Next category

File fit multiple categories -> pick most specific.

### Phase 4: Pre-push review

1. Show what push: `git log --oneline origin/<branch>..HEAD 2>/dev/null || git log --oneline -5`
2. Confirm commit count + branch target with user before push

### Phase 5: Push

1. Push with tracking: `git push -u origin $(git branch --show-current)`
2. Never force push -- `--force-with-lease` OK when needed (after rebase)

### Phase 6: Verify and summarize

1. Run `git status` + `git diff` to confirm clean worktree
2. If anything uncommitted, warn user
3. Summarize: branch name, commits made, remote URL, remaining user actions

### Safety

- Never stage unrelated changes silent
- Never push without confirm scope when worktree mixed
- Never force push -- `--force-with-lease` OK when needed (after rebase)
- No git remote reachable -> stop + explain blocker