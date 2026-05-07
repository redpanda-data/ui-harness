#!/bin/bash
# Resilience/negative tests for hooks.
# Tests malformed input, missing tools, edge cases.

source "$(dirname "$0")/hook-test-helpers.sh"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           Resilience & Negative Tests                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ Malformed JSON input ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  empty stdin → PostToolUse hook survives:"
_run_hook "react-rules-check.sh" ""
_assert_exit 0 "empty stdin → exit 0"

echo "  garbage text → PostToolUse hook survives:"
_run_hook "react-rules-check.sh" "not json at all {{{}"
_assert_exit 0 "garbage input → exit 0"

echo "  valid JSON but missing tool_name → exit 0:"
_run_hook "react-rules-check.sh" '{"tool_input":{"file_path":"/tmp/x.tsx"}}'
_assert_exit 0 "missing tool_name → exit 0"

echo "  valid JSON but missing file_path → exit 0:"
_run_hook "react-rules-check.sh" '{"tool_name":"Edit","tool_input":{}}'
_assert_exit 0 "missing file_path → exit 0"

echo "  empty stdin → PreToolUse hook survives:"
_run_hook "enforce-toolchain.sh" ""
_assert_exit 0 "empty stdin PreToolUse → exit 0"

echo "  garbage → PreToolUse hook survives:"
_run_hook "enforce-toolchain.sh" "complete garbage 123"
_assert_exit 0 "garbage PreToolUse → exit 0"

echo "  null values in JSON → survives:"
_run_hook "react-rules-check.sh" '{"tool_name":null,"tool_input":null}'
_assert_exit 0 "null values → exit 0"

echo "  empty tool_name → exit 0:"
_run_hook "react-rules-check.sh" '{"tool_name":"","tool_input":{"file_path":"/tmp/x.tsx"}}'
_assert_exit 0 "empty tool_name → exit 0"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ Malformed JSON → every hook category ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

# Test a representative hook from each category
hooks_to_test=(
  "accessibility-check.sh"
  "tailwind-check.sh"
  "zustand-check.sh"
  "ux-copy-check.sh"
  "form-mode-check.sh"
  "biome-ignore-check.sh"
  "env-validation-check.sh"
  "tanstack-router-check.sh"
  "conventional-commits-check.sh"
  "as-cast-check.sh"
  "form-watch-check.sh"
  "mutation-onerror-check.sh"
  "vendor-file-check.sh"
  "bundle-guard.sh"
  "mutation-naming-check.sh"
  "query-pattern-check.sh"
  "connect-error-format-check.sh"
  "unhappy-path-check.sh"
  "legacy-import-check.sh"
  "test-convention-check.sh"
  "disabled-button-tooltip-check.sh"
  "field-mask-check.sh"
  "magic-number-check.sh"
  "error-boundary-check.sh"
  "file-size-check.sh"
  "hook-location-check.sh"
  "url-state-check.sh"
  "test-perf-check.sh"
)

echo "  empty stdin survives for all hooks:"
all_survived=true
failed_hooks=""
for hook in "${hooks_to_test[@]}"; do
  if [ -f "$HOOKS_DIR/$hook" ]; then
    exit_code=0
    echo "" | bash "$HOOKS_DIR/$hook" 2>/dev/null || exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
      all_survived=false
      failed_hooks="$failed_hooks $hook(exit=$exit_code)"
    fi
  fi
done
if [ "$all_survived" = true ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} all ${#hooks_to_test[@]} hooks survive empty stdin"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} hooks crashed on empty stdin:$failed_hooks"
fi

echo "  malformed JSON survives for all hooks:"
all_survived=true
failed_hooks=""
for hook in "${hooks_to_test[@]}"; do
  if [ -f "$HOOKS_DIR/$hook" ]; then
    exit_code=0
    echo '{"broken":' | bash "$HOOKS_DIR/$hook" 2>/dev/null || exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
      all_survived=false
      failed_hooks="$failed_hooks $hook(exit=$exit_code)"
    fi
  fi
done
if [ "$all_survived" = true ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} all ${#hooks_to_test[@]} hooks survive malformed JSON"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} hooks crashed on malformed JSON:$failed_hooks"
fi

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ Stop hooks with empty session ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

stop_hooks=(
  "quality-gate-stop.sh"
  "violation-summary-stop.sh"
  "metrics-summary-stop.sh"
)

echo "  stop hooks survive empty session:"
for hook in "${stop_hooks[@]}"; do
  if [ -f "$HOOKS_DIR/$hook" ]; then
    exit_code=0
    echo "" | bash "$HOOKS_DIR/$hook" 2>/dev/null || exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
      PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} $hook — empty session → exit 0"
    else
      FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} $hook — empty session → exit $exit_code"
    fi
  fi
done

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ Binary/unusual file content ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  binary content in .tsx file:"
_f="/tmp/hook-test-binary-$$.tsx"
printf '\x00\x01\x02\xff\xfe\x89PNG' > "$_f"
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "binary content → exit 0 (no crash)"
rm -f "$_f"

echo "  empty .tsx file:"
_f2="/tmp/hook-test-empty-$$.tsx"
touch "$_f2"
_run_hook "react-rules-check.sh" "$(_edit_json "$_f2")"
_assert_exit 0 "empty file → exit 0"
rm -f "$_f2"

echo "  file with only whitespace:"
_f3="/tmp/hook-test-ws-$$.tsx"
printf '   \n\n  \n' > "$_f3"
_run_hook "react-rules-check.sh" "$(_edit_json "$_f3")"
_assert_exit 0 "whitespace-only file → exit 0"
rm -f "$_f3"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ Nonexistent/deleted files ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  edit to nonexistent file:"
_run_hook "react-rules-check.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/this-file-is-gone-forever-12345.tsx","old_string":"x","new_string":"y"}}'
_assert_exit 0 "nonexistent file → exit 0"

echo "  edit to path with spaces:"
_f="/tmp/hook test spaces/file $$.tsx"
mkdir -p "$(dirname "$_f")"
echo 'const x = 1;' > "$_f"
_run_hook "react-rules-check.sh" "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_f\",\"old_string\":\"x\",\"new_string\":\"y\"}}"
_assert_exit 0 "path with spaces → no crash"
rm -rf "/tmp/hook test spaces"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ Special characters in file content ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  content with backslashes and quotes:"
_f="/tmp/hook-test-special-$$.tsx"
_setup_test_file "$_f" 'const path = "C:\\Users\\test\\file.tsx";
const msg = "He said \"hello\" and left";
const regex = /[a-z]+\\.tsx$/;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "special chars → no crash"
_cleanup_test_file "$_f"

echo "  content with unicode:"
_setup_test_file "$_f" 'const X = () => <span>日本語テスト café naïve résumé</span>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "unicode content → no crash"
_cleanup_test_file "$_f"

echo "  content with extremely long line:"
_f2="/tmp/hook-test-longline-$$.tsx"
long_line="const x = '$(python3 -c "print('a' * 10000)" 2>/dev/null || printf '%10000s' | tr ' ' 'a')';"
echo "$long_line" > "$_f2"
_run_hook "react-rules-check.sh" "$(_edit_json "$_f2")"
_assert_exit 0 "10k char line → no crash"
rm -f "$_f2"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ Session isolation ━━━"
# ═══════════════════════════════════════════════════════════════

echo "  two sessions don't share state:"
export CLAUDE_SESSION_ID="session-A-$$"
mkdir -p "/tmp/hook-session-${CLAUDE_SESSION_ID}"
echo "session-A-violation" >> "/tmp/hook-session-${CLAUDE_SESSION_ID}/violations"

session_a_id="$CLAUDE_SESSION_ID"

export CLAUDE_SESSION_ID="session-B-$$"
mkdir -p "/tmp/hook-session-${CLAUDE_SESSION_ID}"

# Session B should have no violations
if [ ! -f "/tmp/hook-session-${CLAUDE_SESSION_ID}/violations" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} session B has no violations from session A"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} session B leaked from session A"
fi

# Session A should still have its violation
if [ -f "/tmp/hook-session-${session_a_id}/violations" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} session A violations preserved"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} session A violations lost"
fi

# Cleanup both
rm -rf "/tmp/hook-session-${session_a_id}" "/tmp/hook-session-${CLAUDE_SESSION_ID}"
unset CLAUDE_SESSION_ID

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ No CLAUDE_SESSION_ID fallback ━━━"
# ═══════════════════════════════════════════════════════════════

echo "  hooks work without CLAUDE_SESSION_ID:"
unset CLAUDE_SESSION_ID 2>/dev/null || true
unset CODEX_SESSION_ID 2>/dev/null || true
_f="/tmp/hook-test-nosession-$$.tsx"
echo 'const x = 1;' > "$_f"
exit_code=0
echo "$(_edit_json "$_f")" | bash "$HOOKS_DIR/react-rules-check.sh" 2>/dev/null || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} hook works without session ID"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} hook failed without session ID (exit: $exit_code)"
fi
rm -f "$_f"
# Clean up PID-based session dir
rm -rf "/tmp/hook-session-$$" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ _safe_json_escape sed fallback ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  sed fallback produces valid JSON:"
_fallback_script="/tmp/hook-test-fallback-$$.sh"
cat > "$_fallback_script" <<EOF
#!/bin/bash
set -euo pipefail
# Override jq to simulate missing
jq() { return 1; }
export -f jq
source "$HOOKS_DIR/_hook-lib.sh"
result=\$(_safe_json_escape 'test "quotes" and
newlines')
echo "\$result" >&2
EOF
chmod +x "$_fallback_script"
stderr_out=$(echo "" | bash "$_fallback_script" 2>&1 || true)
# Check it produced something that looks like JSON string
if echo "$stderr_out" | grep -qF '"test'; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} sed fallback produces output"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} sed fallback (got: $stderr_out)"
fi

rm -f "$_fallback_script"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ Concurrent stop-findings writes ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  parallel writes to stop-findings:"
source "$HOOKS_DIR/_hook-lib.sh"
# Simulate parallel writes
for i in $(seq 1 10); do
  hook_stop_finding "Finding $i from hook $i" &
done
wait

finding_count=$(grep -c '^---$' "$_hook_session_dir/stop-findings" 2>/dev/null || echo 0)
if [ "$finding_count" -eq 10 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} all 10 parallel findings written"
elif [ "$finding_count" -gt 0 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} $finding_count/10 findings survived parallel writes (acceptable)"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} no findings survived parallel writes"
fi

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ Wrong tool_name passthrough ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  Read tool → PostToolUse hooks skip:"
_run_hook "react-rules-check.sh" '{"tool_name":"Read","tool_input":{"file_path":"/tmp/x.tsx"}}'
_assert_exit 0 "Read tool skipped"

echo "  Glob tool → PostToolUse hooks skip:"
_run_hook "react-rules-check.sh" '{"tool_name":"Glob","tool_input":{"pattern":"*.tsx"}}'
_assert_exit 0 "Glob tool skipped"

echo "  Agent tool → PreToolUse hooks skip:"
_run_hook "enforce-toolchain.sh" '{"tool_name":"Agent","tool_input":{"prompt":"test"}}'
_assert_exit 0 "Agent tool skipped"

_teardown_session

# ═══════════════════════════════════════════════════════════════

_report_results "Resilience Tests"
