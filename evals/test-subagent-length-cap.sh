# Evals for subagent-length-cap.sh — PreToolUse Agent hook that appends
# a word-budget + caveman-style directive to subagent prompts.
#
# Invariants under test:
#   - Explore/general-purpose/claude-code-guide get a budget appended
#   - Plan subagent is EXPLICITLY uncapped (user values deep plans)
#   - User-supplied budget in prompt short-circuits the hook (no double-cap)
#   - Non-Agent tools pass silently
#   - Output is valid JSON with updatedInput.prompt preserving original text

HOOK="$REPO_ROOT/.claude/hooks/subagent-length-cap.sh"

run_file_eval "$HOOK" "subagent-length-cap.sh exists"
run_executable_eval "$HOOK" "subagent-length-cap.sh executable"

_run_agent() {
  local subagent="$1" prompt="$2"
  local err; err=$(mktemp); local ec=0
  local payload
  payload=$(jq -cn --arg s "$subagent" --arg p "$prompt" \
    '{tool_name:"Agent",tool_input:{subagent_type:$s,prompt:$p,description:"test"}}')
  echo "$payload" | bash "$HOOK" 2>"$err" >/dev/null || ec=$?
  _last_stderr=$(cat "$err"); _last_exit=$ec
  rm -f "$err"
}

# 1. Explore gets 500-word cap
_run_agent "Explore" "Find all auth handlers"
if echo "$_last_stderr" | grep -q "500 words" && echo "$_last_stderr" | grep -q "updatedInput"; then
  echo "  PASS  Explore gets 500-word cap"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Explore missing 500-word cap"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Explore cap"
fi

# 2. claude-code-guide gets 400-word cap
_run_agent "claude-code-guide" "What's the hook schema?"
if echo "$_last_stderr" | grep -q "400 words"; then
  echo "  PASS  claude-code-guide gets 400-word cap"
  PASS=$((PASS + 1))
else
  echo "  FAIL  claude-code-guide missing 400-word cap"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: guide cap"
fi

# 3. Plan is UNCAPPED — silent pass
_run_agent "Plan" "Design the migration"
if [ "$_last_exit" = "0" ] && [ -z "$_last_stderr" ]; then
  echo "  PASS  Plan subagent is uncapped (silent pass)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Plan should be uncapped (exit=$_last_exit, stderr len=${#_last_stderr})"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Plan uncap"
fi

# 4. User-supplied budget short-circuits
_run_agent "Explore" "Find things. Report in under 200 words."
if [ "$_last_exit" = "0" ] && [ -z "$_last_stderr" ]; then
  echo "  PASS  user-supplied budget short-circuits hook"
  PASS=$((PASS + 1))
else
  echo "  FAIL  hook double-capped existing budget"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: double-cap"
fi

# 5. Default subagent gets 500-word cap
_run_agent "general-purpose" "Investigate a thing"
if echo "$_last_stderr" | grep -q "500 words"; then
  echo "  PASS  general-purpose gets 500-word cap"
  PASS=$((PASS + 1))
else
  echo "  FAIL  general-purpose missing 500-word cap"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: default cap"
fi

# 6. Non-Agent tool passes silently
payload='{"tool_name":"Bash","tool_input":{"command":"ls"}}'
err=$(mktemp); ec=0
echo "$payload" | bash "$HOOK" 2>"$err" >/dev/null || ec=$?
stderr_content=$(cat "$err"); rm -f "$err"
if [ "$ec" = "0" ] && [ -z "$stderr_content" ]; then
  echo "  PASS  non-Agent tool silent pass"
  PASS=$((PASS + 1))
else
  echo "  FAIL  non-Agent tool should silent-pass"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: non-Agent passthrough"
fi

# 7. JSON validity on modify
_run_agent "Explore" "search for X"
if echo "$_last_stderr" | python3 -c "
import json,sys
d = json.loads(sys.stdin.read())
assert d['hookSpecificOutput']['permissionDecision'] == 'allow'
assert 'updatedInput' in d['hookSpecificOutput']
assert 'search for X' in d['hookSpecificOutput']['updatedInput']['prompt']
" 2>/dev/null; then
  echo "  PASS  updatedInput preserves original prompt"
  PASS=$((PASS + 1))
else
  echo "  FAIL  updatedInput malformed or loses original prompt"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: updatedInput integrity"
fi
