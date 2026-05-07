#!/bin/bash
# SubagentStart hook — injects session context into all subagents.
# Provides: touched files, dirty baseline, branch/PR info, findings schema path.
# Cannot block subagent creation (SubagentStart limitation) — context injection only.

set -euo pipefail
trap 'exit 0' ERR

# ── Parse stdin ──────────────────────────────────────────────────
input=$(cat)
agent_type=$(echo "$input" | jq -r '.agent_type // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# ── Session state ────────────────────────────────────────────────
session_dir="/tmp/hook-session-${session_id:-${CLAUDE_SESSION_ID:-$$}}"
context_parts=()

# ── Touched files ────────────────────────────────────────────────
touched_file="$session_dir/session-touched-files"
if [ -f "$touched_file" ] && [ -s "$touched_file" ]; then
  touched_list=$(sort -u "$touched_file" | head -50)
  context_parts+=("## Session-Touched Files\nThese files were modified in this session:\n\`\`\`\n${touched_list}\n\`\`\`")
fi

# ── Dirty baseline ──────────────────────────────────────────────
baseline_file="$session_dir/dirty-files-baseline"
if [ -f "$baseline_file" ] && [ -s "$baseline_file" ]; then
  baseline_list=$(cat "$baseline_file" | head -50)
  context_parts+=("## Pre-Existing Changes (Dirty Baseline)\nThese files were already modified before this session started. Issues in these files should be marked \`pre_existing: true\`:\n\`\`\`\n${baseline_list}\n\`\`\`")
fi

# ── Branch/PR context ────────────────────────────────────────────
branch=$(git branch --show-current 2>/dev/null || echo "unknown")
pr_number=""
if command -v gh >/dev/null 2>&1; then
  pr_number=$(gh pr view --json number -q '.number' 2>/dev/null || echo "")
fi

branch_context="## Branch Context\n- Branch: \`${branch}\`"
if [ -n "$pr_number" ]; then
  branch_context="${branch_context}\n- PR: #${pr_number}"
fi
context_parts+=("$branch_context")

# ── Reviewer-specific context ────────────────────────────────────
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
case "$agent_type" in
  self-reviewer|code-reviewer|adversarial-reviewer)
    context_parts+=("## Review Output Format\nYou MUST output findings as structured JSON per the findings-schema.md in the agents/ directory. Read \`${repo_root}/agents/findings-schema.md\` for the exact format.")
    ;;
esac

# ── Emit context ─────────────────────────────────────────────────
if [ ${#context_parts[@]} -gt 0 ]; then
  combined=$(printf '%b\n\n' "${context_parts[@]}")
  # Escape for JSON
  escaped=$(echo "$combined" | jq -Rs . 2>/dev/null) || exit 0
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SubagentStart\",\"additionalContext\":${escaped}}}" >&2
fi

exit 0
