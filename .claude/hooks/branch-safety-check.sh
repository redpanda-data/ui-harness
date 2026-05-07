#!/bin/bash
set -eo pipefail

# PreToolUse(Bash): prevent commits/pushes/checkouts that would drift a
# worktree from the branch it was bound to at session start.
#
# Why: with 4 Claude Code terminals on 4 worktrees, a subagent or a
# mis-typed `git switch` can silently land a commit on the wrong branch
# or open a PR against the wrong base. This hook denies the operation
# and surfaces a remediation.
#
# Escape hatch: `CLAUDE_BRANCH_REBIND=1` on the failing Bash call — the
# hook rebinds to the new current branch and passes. Intentionally noisy
# so the user has to opt in each time.

source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true

hook_parse_bash

# Gate only branch-affecting git verbs.
case "$command" in
  *"git commit"*|*"git push"*|*"git checkout"*|*"git switch"*) : ;;
  *) exit 0 ;;
esac

_bound_file="$_hook_session_dir/bound-branch"
[ -f "$_bound_file" ] || exit 0  # not bound yet (first session turn)

_bound=$(cat "$_bound_file" 2>/dev/null)
_current=$(git branch --show-current 2>/dev/null || echo "")

# Detached HEAD or unclear branch → do not gate.
{ [ -z "$_bound" ] || [ -z "$_current" ]; } && exit 0

# Same branch → fine.
[ "$_bound" = "$_current" ] && exit 0

# Rebind opt-in: user explicitly acknowledges branch change.
if [ "${CLAUDE_BRANCH_REBIND:-0}" = "1" ]; then
  echo "$_current" > "$_bound_file" 2>/dev/null || true
  echo "{\"suppressOutput\":true,\"systemMessage\":\"[branch-safety] rebound: '$_bound' -> '$_current'\"}" >&2
  exit 0
fi

# Drift — deny with remediation.
hook_deny "Session bound to branch '$_bound' but HEAD is '$_current'. Refusing this git call — worktree drift would commit to the wrong branch. Options: (a) git checkout $_bound then retry, (b) re-run the command prefixed with CLAUDE_BRANCH_REBIND=1 to rebind for this session, (c) /mux <new-branch> to spawn a fresh worktree + session for the other branch." "branch-safety"
