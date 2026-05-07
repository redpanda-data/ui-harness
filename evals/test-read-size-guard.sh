# Evals for read-size-guard.sh — PreToolUse Read nudge on large files
# when no `limit:` parameter is set.

HOOK="$REPO_ROOT/.claude/hooks/read-size-guard.sh"

run_file_eval "$HOOK" "read-size-guard.sh exists"
run_executable_eval "$HOOK" "read-size-guard.sh executable"

_run_read() {
  local path="$1" limit="${2:-}"
  local err; err=$(mktemp); local ec=0
  local payload
  if [ -n "$limit" ]; then
    payload=$(jq -cn --arg p "$path" --argjson l "$limit" \
      '{tool_name:"Read",tool_input:{file_path:$p,limit:$l}}')
  else
    payload=$(jq -cn --arg p "$path" '{tool_name:"Read",tool_input:{file_path:$p}}')
  fi
  echo "$payload" | bash "$HOOK" 2>"$err" >/dev/null || ec=$?
  _last_stderr=$(cat "$err"); _last_exit=$ec
  rm -f "$err"
}

# Fixture: small file — should be silent
small=$(mktemp)
for i in $(seq 1 50); do echo "line $i"; done > "$small"
_run_read "$small"
if [ "$_last_exit" = "0" ] && [ -z "$_last_stderr" ]; then
  echo "  PASS  small file silent pass"
  PASS=$((PASS + 1))
else
  echo "  FAIL  small file should be silent"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: small file"
fi
rm -f "$small"

# Fixture: large file (>800 lines AND >25KB)
large=$(mktemp)
for i in $(seq 1 1000); do echo "this is line number $i with some padding text for byte count"; done > "$large"
_run_read "$large"
if echo "$_last_stderr" | grep -q "read-size"; then
  echo "  PASS  large file triggers nudge"
  PASS=$((PASS + 1))
else
  echo "  FAIL  large file missing nudge"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: large file nudge"
fi

# Large file WITH limit — silent pass
_run_read "$large" 100
if [ "$_last_exit" = "0" ] && [ -z "$_last_stderr" ]; then
  echo "  PASS  large file with limit silent"
  PASS=$((PASS + 1))
else
  echo "  FAIL  large file with limit should be silent"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: limit silences nudge"
fi
rm -f "$large"

# Non-Read tool: silent pass
ec=0
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | bash "$HOOK" 2>/dev/null >/dev/null || ec=$?
if [ "$ec" = "0" ]; then
  echo "  PASS  non-Read tool silent"
  PASS=$((PASS + 1))
else
  echo "  FAIL  non-Read should exit 0"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: non-Read"
fi

# Binary (image) extension skipped
_run_read "/tmp/nonexistent.png"
if [ "$_last_exit" = "0" ] && [ -z "$_last_stderr" ]; then
  echo "  PASS  image path skipped"
  PASS=$((PASS + 1))
else
  echo "  FAIL  image path should skip"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: image skip"
fi
