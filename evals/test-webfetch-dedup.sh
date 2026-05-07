# Evals for webfetch-dedup.sh — PreToolUse WebFetch hook that nudges on
# duplicate fetches within a session.

HOOK="$REPO_ROOT/.claude/hooks/webfetch-dedup.sh"

run_file_eval "$HOOK" "webfetch-dedup.sh exists"
run_executable_eval "$HOOK" "webfetch-dedup.sh executable"

_fresh_session() {
  export CLAUDE_SESSION_ID="test-webfetch-$RANDOM-$$"
}

_run_fetch() {
  local url="$1" prompt="${2:-default prompt}"
  local err; err=$(mktemp); local ec=0
  local payload
  payload=$(jq -cn --arg u "$url" --arg p "$prompt" \
    '{tool_name:"WebFetch",tool_input:{url:$u,prompt:$p}}')
  echo "$payload" | bash "$HOOK" 2>"$err" >/dev/null || ec=$?
  _last_stderr=$(cat "$err"); _last_exit=$ec
  rm -f "$err"
}

# 1. First fetch: silent pass
_fresh_session
_run_fetch "https://example.com/docs" "summarize"
if [ "$_last_exit" = "0" ] && [ -z "$_last_stderr" ]; then
  echo "  PASS  first fetch silent pass"
  PASS=$((PASS + 1))
else
  echo "  FAIL  first fetch should be silent (exit=$_last_exit, stderr=$_last_stderr)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: first fetch not silent"
fi

# 2. Second fetch same URL+prompt: nudge fires (single occurrence)
_run_fetch "https://example.com/docs" "summarize"
if echo "$_last_stderr" | grep -q "already fetched once"; then
  echo "  PASS  2nd fetch emits soft nudge"
  PASS=$((PASS + 1))
else
  echo "  FAIL  2nd fetch missing soft nudge"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: 2nd fetch nudge"
fi

# 3. Third+ fetch: escalated nudge (mentions "STRONG sign")
_run_fetch "https://example.com/docs" "summarize"
if echo "$_last_stderr" | grep -q "STRONG sign"; then
  echo "  PASS  3rd fetch escalates nudge"
  PASS=$((PASS + 1))
else
  echo "  FAIL  3rd fetch missing escalation"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: 3rd fetch escalation"
fi

# 4. Same URL different prompt: treated as distinct, silent pass
_fresh_session
_run_fetch "https://example.com/docs" "question A"
_run_fetch "https://example.com/docs" "question B"
if [ "$_last_exit" = "0" ] && [ -z "$_last_stderr" ]; then
  echo "  PASS  different prompt on same URL is silent"
  PASS=$((PASS + 1))
else
  echo "  FAIL  different prompt should be silent"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: different prompt nudged"
fi

# 5. Non-WebFetch tool: silent pass
ec=0
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | bash "$HOOK" 2>/dev/null >/dev/null || ec=$?
if [ "$ec" = "0" ]; then
  echo "  PASS  non-WebFetch silent pass"
  PASS=$((PASS + 1))
else
  echo "  FAIL  non-WebFetch should exit 0"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: non-WebFetch"
fi

# 6. Valid JSON output on nudge
_fresh_session
_run_fetch "https://a.test" "x"
_run_fetch "https://a.test" "x"
if echo "$_last_stderr" | python3 -c "
import json,sys
d = json.loads(sys.stdin.read())
assert d['hookSpecificOutput']['hookEventName'] == 'PreToolUse'
assert 'additionalContext' in d['hookSpecificOutput']
" 2>/dev/null; then
  echo "  PASS  dedup nudge emits valid JSON"
  PASS=$((PASS + 1))
else
  echo "  FAIL  dedup nudge JSON malformed"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: dedup JSON"
fi

unset CLAUDE_SESSION_ID
