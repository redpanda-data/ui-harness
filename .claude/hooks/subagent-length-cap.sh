#!/bin/bash
set -euo pipefail

# PreToolUse Agent: inject length budget + terse-style directive into the
# subagent prompt. Motivation (30d audit):
#   Explore subagent    — 815 calls, avg 7,297 chars (~1,200 words)
#   Plan subagent       —  39 calls, avg 14,247 chars (~2,400 words)
#   general-purpose     — 390 calls, avg 3,079 chars (~500 words, already tight)
#   Total subagent vol  — 8.2M chars/mo — bigger than Gmail+browser MCP combined
#
# Budgets (words of OUTPUT the subagent should target):
#   Plan                — 1,000 words (preserve depth; user values deep plans)
#   Explore             —   500 words (survey, not novel)
#   general-purpose     —   500 words (default)
#   claude-code-guide   —   400 words (lookup answers)
#
# Style: caveman-adjacent. Terse, drop filler, cite specifics, no preamble.

_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else exit 0; fi

_in=$(cat)
tool_name=$(echo "$_in" | jq -r '.tool_name // empty' 2>/dev/null || true)

if [ "$tool_name" != "Agent" ] && [ "$tool_name" != "Task" ]; then
  exit 0
fi

# Extract original prompt and subagent_type
orig_prompt=$(echo "$_in" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)
subagent_type=$(echo "$_in" | jq -r '.tool_input.subagent_type // "general-purpose"' 2>/dev/null || true)

if [ -z "$orig_prompt" ]; then
  exit 0
fi

# Skip if user already included a word/length budget — don't double-budget
if echo "$orig_prompt" | grep -qiE '(≤|<=|under|within|max(imum)?|limit(ed)? to|no more than)\s+[0-9]+\s+(word|char|line)'; then
  exit 0
fi

# Pick budget by subagent_type. Plan is uncapped -- user values deep plans
# and has explicitly opted out of length constraints on them.
case "$subagent_type" in
  Plan|plan)
    # No cap, no style rider -- let the Plan agent run as fully as it needs.
    _hook_log_entry "skip" "subagent-length-cap" 2>/dev/null || true
    exit 0
    ;;
  Explore|explore)
    budget=500
    note="Survey, not novel. Caveman-terse: fragments OK, no preamble, cite file:line for findings."
    ;;
  claude-code-guide)
    budget=400
    note="Lookup answers. Quote official doc snippets verbatim; terse prose for the rest."
    ;;
  *)
    budget=500
    note="Caveman-terse: drop articles/filler, fragments OK, no preamble, cite file:line for specifics."
    ;;
esac

directive=$(cat <<EOF

---
Report constraints: ≤${budget} words. ${note} Skip closing summary -- end on the last finding.
EOF
)

# Build full modified input. updatedInput replaces entire tool_input,
# so preserve description/subagent_type/etc. We JSON-merge: take original
# tool_input, override only .prompt.
new_input=$(echo "$_in" | jq --arg p "$(printf '%s%s' "$orig_prompt" "$directive")" \
  '.tool_input | .prompt = $p')

# Emit the PreToolUse response with updatedInput
_hook_log_entry "modify" "subagent-length-cap" 2>/dev/null || true
jq -n --argjson ui "$new_input" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    updatedInput: $ui
  }
}' >&2

exit 0
