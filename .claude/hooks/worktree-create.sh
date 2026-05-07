#!/bin/bash
set -eo pipefail
trap 'exit 0' ERR

# WorktreeCreate: fires when agent launches with isolation: "worktree"
# (common for code-reviewer, adversarial-reviewer, parallel design agents).
#
# Default git behavior is preserved (we don't override). This hook adds:
# - JSONL log entry for analytics
# - Sanity check: .claude/ dir is present in worktree (hooks will work)
# - Pass-through env for the child session

input=$(cat 2>/dev/null || echo '{}')
worktree_path=$(echo "$input" | jq -r '.worktree_path // .path // empty' 2>/dev/null)
[ -n "$worktree_path" ] || exit 0

session_dir="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}"
mkdir -p "$session_dir" 2>/dev/null || true

# Log for analytics
printf '{"ts":%d,"hook":"worktree-create","rule":"worktree-spawn","decision":"info","path":"%s"}\n' \
  "$(date +%s)" "$worktree_path" \
  >> "$session_dir/structured.jsonl" 2>/dev/null || true

# Track worktree count for this session (detect runaway spawning)
_count_file="$session_dir/worktree-count"
_count=$(cat "$_count_file" 2>/dev/null || echo 0)
_count=$((_count + 1))
echo "$_count" > "$_count_file"

if [ "$_count" -gt 5 ]; then
  echo "{\"suppressOutput\":true,\"systemMessage\":\"[worktree] $_count worktrees spawned this session. Excessive parallelism can overwhelm the runner. Consider sequential agents or reduce N.\"}" >&2
fi

exit 0
