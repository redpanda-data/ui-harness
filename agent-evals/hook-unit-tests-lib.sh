#!/bin/bash
# Unit tests for _hook-lib.sh shared library functions.
# Tests each exported function directly.

source "$(dirname "$0")/hook-test-helpers.sh"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           _hook-lib.sh — Shared Library Tests            ║"
echo "╚═══════════════════════════════════════════════════════════╝"

# Helper: create inline test script that sources _hook-lib.sh correctly
_make_hook_script() {
  local script_path="$1"
  local body="$2"
  cat > "$script_path" <<EOF
#!/bin/bash
set -euo pipefail
source "$HOOKS_DIR/_hook-lib.sh"
$body
EOF
  chmod +x "$script_path"
}

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ _safe_json_escape ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session
source "$HOOKS_DIR/_hook-lib.sh"

echo "  basic string:"
result=$(_safe_json_escape "hello world")
if [ "$result" = '"hello world"' ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} basic string escaped"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} basic string (got: $result)"
fi

echo "  string with double quotes:"
result=$(_safe_json_escape 'say "hello"')
if echo "$result" | grep -qF '\"hello\"'; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} double quotes escaped"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} double quotes (got: $result)"
fi

echo "  string with backslash:"
result=$(_safe_json_escape 'path\to\file')
if echo "$result" | grep -qF '\\'; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} backslash escaped"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} backslash (got: $result)"
fi

echo "  string with newline:"
result=$(_safe_json_escape "line1
line2")
if echo "$result" | grep -qF '\n'; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} newline escaped"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} newline (got: $result)"
fi

echo "  string with tab:"
result=$(_safe_json_escape "col1	col2")
if echo "$result" | grep -qF '\t'; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} tab escaped"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} tab (got: $result)"
fi

echo "  empty string:"
result=$(_safe_json_escape "")
if [ "$result" = '""' ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} empty string produces \"\""
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} empty string (got: $result)"
fi

echo "  unicode characters:"
result=$(_safe_json_escape "café ñ 日本語")
if echo "$result" | grep -q 'café'; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} unicode preserved"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} unicode (got: $result)"
fi

echo "  mixed special chars:"
result=$(_safe_json_escape 'error in "file.ts": can'\''t parse\n')
if echo "$result" | grep -qF '\"file.ts\"'; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} mixed specials escaped"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} mixed (got: $result)"
fi

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ hook_parse_edit_write ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_test_file="/tmp/hook-test-parse-$$.tsx"
echo "const x = 1;" > "$_test_file"
_parse_script="/tmp/hook-test-parse-script-$$.sh"
_make_hook_script "$_parse_script" 'hook_parse_edit_write
echo "FILE_PATH=$file_path" >&2
exit 0'

echo "  Edit tool → sets file_path:"
result_stderr=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_test_file\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_parse_script" 2>&1 || true)
if echo "$result_stderr" | grep -qF "FILE_PATH=$_test_file"; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} Edit sets file_path"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} Edit file_path (got: $result_stderr)"
fi

echo "  non-Edit tool → exit 0 immediately:"
exit_code=0
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | bash "$_parse_script" 2>/dev/null || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} non-Edit exits 0"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} non-Edit exit (got: $exit_code)"
fi

echo "  nonexistent file → exit 0:"
exit_code=0
echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/this-file-does-not-exist-ever.tsx","old_string":"x","new_string":"y"}}' | bash "$_parse_script" 2>/dev/null || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} nonexistent file exits 0"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} nonexistent file (got: $exit_code)"
fi

rm -f "$_test_file" "$_parse_script"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ hook_filter_extensions ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_filter_script="/tmp/hook-test-filter-$$.sh"
_make_hook_script "$_filter_script" 'hook_parse_edit_write
hook_filter_extensions "ts|tsx"
echo "PASSED_FILTER" >&2
exit 0'

echo "  matching extension (tsx):"
_test_file="/tmp/hook-test-ext-$$.tsx"
echo "const x = 1;" > "$_test_file"
exit_code=0
echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_test_file\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_filter_script" 2>/dev/null || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} .tsx matches ts|tsx filter"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} .tsx match (exit: $exit_code)"
fi

echo "  non-matching extension (css):"
_test_file2="/tmp/hook-test-ext-$$.css"
echo "body{}" > "$_test_file2"
exit_code=0
echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_test_file2\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_filter_script" 2>/dev/null || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} .css exits 0 for ts|tsx filter"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} .css filter (exit: $exit_code)"
fi

rm -f "$_test_file" "$_test_file2" "$_filter_script"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ hook_has_escape ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session
source "$HOOKS_DIR/_hook-lib.sh"

echo "  new format — // allow: rule-name:"
_esc_file="/tmp/hook-test-escape-$$.tsx"
echo '// allow: useEffect reason here
const x = 1;' > "$_esc_file"
file_path="$_esc_file"
if hook_has_escape "useEffect"; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} new format detected"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} new format not detected"
fi

echo "  legacy format — // allow-rule-name:"
echo '// allow-dangerouslySetInnerHTML: sanitized
const x = 1;' > "$_esc_file"
if hook_has_escape "dangerouslySetInnerHTML"; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} legacy format detected"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} legacy format not detected"
fi

echo "  no escape present:"
echo 'const x = 1;' > "$_esc_file"
if hook_has_escape "useEffect"; then
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} false positive escape detection"
else
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} no escape correctly returns false"
fi

echo "  partial match — 'use' should not match 'useEffect':"
echo '// allow: use something
const x = 1;' > "$_esc_file"
if hook_has_escape "useEffect"; then
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} partial match false positive"
else
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} partial match correctly rejected"
fi

rm -f "$_esc_file"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ hook_skip_generated ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_skipgen_script="/tmp/hook-test-skipgen-$$.sh"
_make_hook_script "$_skipgen_script" 'hook_parse_edit_write
hook_skip_generated
echo "NOT_SKIPPED" >&2
exit 0'

echo "  .gen.ts file (should skip):"
_gen_file="/tmp/hook-test-gen-$$.gen.ts"
echo 'export const x = 1;' > "$_gen_file"
result_stderr=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_gen_file\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_skipgen_script" 2>&1 || true)
if echo "$result_stderr" | grep -q "NOT_SKIPPED"; then
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} .gen.ts was not skipped"
else
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} .gen.ts skipped"
fi

echo "  _pb.ts file (should skip):"
_pb_file="/tmp/hook-test-pb-$$_pb.ts"
echo 'export const x = 1;' > "$_pb_file"
result_stderr=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_pb_file\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_skipgen_script" 2>&1 || true)
if echo "$result_stderr" | grep -q "NOT_SKIPPED"; then
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} _pb.ts was not skipped"
else
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} _pb.ts skipped"
fi

echo "  @generated marker in file (should skip):"
_atgen_file="/tmp/hook-test-atgen-$$.ts"
printf '// @generated by protobuf-ts\nexport const x = 1;\n' > "$_atgen_file"
result_stderr=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_atgen_file\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_skipgen_script" 2>&1 || true)
if echo "$result_stderr" | grep -q "NOT_SKIPPED"; then
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} @generated was not skipped"
else
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} @generated skipped"
fi

echo "  normal .ts file (should NOT skip):"
_normal_file="/tmp/hook-test-normal-$$.ts"
echo 'export const x = 1;' > "$_normal_file"
result_stderr=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_normal_file\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_skipgen_script" 2>&1 || true)
if echo "$result_stderr" | grep -q "NOT_SKIPPED"; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} normal .ts not skipped"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} normal .ts was incorrectly skipped"
fi

rm -f "$_gen_file" "$_pb_file" "$_atgen_file" "$_normal_file" "$_skipgen_script"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ hook_skip_tests ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_skiptests_script="/tmp/hook-test-skiptests-$$.sh"
_make_hook_script "$_skiptests_script" 'hook_parse_edit_write
hook_skip_tests
echo "NOT_SKIPPED" >&2
exit 0'

echo "  .test.tsx file (should skip):"
_test_tsx="/tmp/hook-test-comp-$$.test.tsx"
echo 'test("x", () => {})' > "$_test_tsx"
result_stderr=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_test_tsx\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_skiptests_script" 2>&1 || true)
if echo "$result_stderr" | grep -q "NOT_SKIPPED"; then
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} .test.tsx was not skipped"
else
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} .test.tsx skipped"
fi

echo "  .spec.ts file (should skip):"
_spec_ts="/tmp/hook-test-comp-$$.spec.ts"
echo 'test("x", () => {})' > "$_spec_ts"
result_stderr=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_spec_ts\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_skiptests_script" 2>&1 || true)
if echo "$result_stderr" | grep -q "NOT_SKIPPED"; then
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} .spec.ts was not skipped"
else
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} .spec.ts skipped"
fi

echo "  regular .tsx file (should NOT skip):"
_reg_tsx="/tmp/hook-test-comp-$$.tsx"
echo 'const X = () => <div/>;' > "$_reg_tsx"
result_stderr=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$_reg_tsx\",\"old_string\":\"x\",\"new_string\":\"y\"}}" | bash "$_skiptests_script" 2>&1 || true)
if echo "$result_stderr" | grep -q "NOT_SKIPPED"; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} regular .tsx not skipped"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} regular .tsx incorrectly skipped"
fi

rm -f "$_test_tsx" "$_spec_ts" "$_reg_tsx" "$_skiptests_script"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ ERR trap behavior ━━━"
# ═══════════════════════════════════════════════════════════════

_err_script="/tmp/hook-test-err-$$.sh"
_make_hook_script "$_err_script" '# Force an error
false
echo "SHOULD_NOT_REACH" >&2'

echo "  default ERR trap (exit 0 on crash):"
exit_code=0
echo "" | bash "$_err_script" 2>/dev/null || exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} default trap → exit 0"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} default trap (exit: $exit_code, expected 0)"
fi

echo "  HOOKS_FAIL_CLOSED=1 trap (exit 2 on crash):"
_err_fc_script="/tmp/hook-test-errfc-$$.sh"
cat > "$_err_fc_script" <<EOF
#!/bin/bash
set -euo pipefail
HOOKS_FAIL_CLOSED=1
source "$HOOKS_DIR/_hook-lib.sh"
false
echo "SHOULD_NOT_REACH" >&2
EOF
chmod +x "$_err_fc_script"
exit_code=0
echo "" | bash "$_err_fc_script" 2>/dev/null || exit_code=$?
if [ "$exit_code" -eq 2 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} fail-closed trap → exit 2"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} fail-closed trap (exit: $exit_code, expected 2)"
fi

rm -f "$_err_script" "$_err_fc_script"

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ hook_block / hook_warn / hook_deny output format ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_block_script="/tmp/hook-test-block-$$.sh"
_make_hook_script "$_block_script" 'hook_block "Test error message"'

echo "  hook_block outputs valid JSON on stderr:"
local_stderr="/tmp/hook-test-block-stderr-$$"
exit_code=0
echo "" | bash "$_block_script" 2>"$local_stderr" || exit_code=$?
stderr_out=$(cat "$local_stderr"); rm -f "$local_stderr"
if echo "$stderr_out" | jq -e '.suppressOutput' >/dev/null 2>&1; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} hook_block produces valid JSON"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} hook_block JSON invalid (got: $stderr_out)"
fi
if [ "$exit_code" -eq 2 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} hook_block exits 2"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} hook_block exit (got: $exit_code)"
fi

_warn_script="/tmp/hook-test-warn-$$.sh"
_make_hook_script "$_warn_script" 'hook_warn "Test warning"'

echo "  hook_warn outputs valid JSON, exits 0:"
local_stderr="/tmp/hook-test-warn-stderr-$$"
exit_code=0
echo "" | bash "$_warn_script" 2>"$local_stderr" || exit_code=$?
stderr_out=$(cat "$local_stderr"); rm -f "$local_stderr"
if echo "$stderr_out" | jq -e '.suppressOutput' >/dev/null 2>&1; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} hook_warn produces valid JSON"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} hook_warn JSON invalid (got: $stderr_out)"
fi
if [ "$exit_code" -eq 0 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} hook_warn exits 0"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} hook_warn exit (got: $exit_code)"
fi

_deny_script="/tmp/hook-test-deny-$$.sh"
_make_hook_script "$_deny_script" 'hook_deny "Test deny"'

echo "  hook_deny outputs permissionDecision:"
local_stderr="/tmp/hook-test-deny-stderr-$$"
exit_code=0
echo "" | bash "$_deny_script" 2>"$local_stderr" || exit_code=$?
stderr_out=$(cat "$local_stderr"); rm -f "$local_stderr"
if echo "$stderr_out" | jq -e '.hookSpecificOutput.permissionDecision' >/dev/null 2>&1; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} hook_deny outputs permissionDecision"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} hook_deny JSON (got: $stderr_out)"
fi
if [ "$exit_code" -eq 2 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} hook_deny exits 2"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} hook_deny exit (got: $exit_code)"
fi

rm -f "$_block_script" "$_warn_script" "$_deny_script"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ HOOK_VERBOSITY levels ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_verb_warn_script="/tmp/hook-test-verb-$$.sh"
cat > "$_verb_warn_script" <<EOF
#!/bin/bash
set -euo pipefail
export HOOK_VERBOSITY=terse
source "$HOOKS_DIR/_hook-lib.sh"
hook_warn "Should be suppressed"
EOF
chmod +x "$_verb_warn_script"

echo "  terse mode — warns suppressed:"
local_stderr="/tmp/hook-test-terse-stderr-$$"
exit_code=0
echo "" | bash "$_verb_warn_script" 2>"$local_stderr" || exit_code=$?
stderr_out=$(cat "$local_stderr"); rm -f "$local_stderr"
if [ -z "$stderr_out" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} terse suppresses warns"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} terse didn't suppress (got: $stderr_out)"
fi

_verb_block_script="/tmp/hook-test-verbblock-$$.sh"
cat > "$_verb_block_script" <<EOF
#!/bin/bash
set -euo pipefail
export HOOK_VERBOSITY=quiet
source "$HOOKS_DIR/_hook-lib.sh"
hook_block "Should be suppressed"
EOF
chmod +x "$_verb_block_script"

echo "  quiet mode — blocks suppressed:"
local_stderr="/tmp/hook-test-quiet-stderr-$$"
exit_code=0
echo "" | bash "$_verb_block_script" 2>"$local_stderr" || exit_code=$?
stderr_out=$(cat "$local_stderr"); rm -f "$local_stderr"
if [ -z "$stderr_out" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} quiet suppresses blocks"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} quiet didn't suppress (got: $stderr_out)"
fi
# But exit code should still be 2
if [ "$exit_code" -eq 2 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} quiet still exits 2 for blocks"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} quiet exit (got: $exit_code, expected 2)"
fi

rm -f "$_verb_warn_script" "$_verb_block_script"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ _hook_track_violation ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session
source "$HOOKS_DIR/_hook-lib.sh"

echo "  violation logged to file:"
_hook_track_violation "test-rule"
_hook_track_violation "test-rule"
_hook_track_violation "other-rule"
if [ -f "$_hook_violations_file" ]; then
  count=$(wc -l < "$_hook_violations_file" | tr -d ' ')
  if [ "$count" -eq 3 ]; then
    PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} 3 violations logged"
  else
    FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} violation count (got: $count, expected 3)"
  fi
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} violations file not created"
fi

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ _hook_log_entry (structured JSONL) ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session
source "$HOOKS_DIR/_hook-lib.sh"

echo "  log entry is valid JSONL:"
file_path="/tmp/test/src/component.tsx"
_hook_log_entry "block" "test-rule" "test-hook"
if [ -f "$_hook_log_file" ]; then
  if jq -e '.hook == "test-hook" and .rule == "test-rule" and .decision == "block"' "$_hook_log_file" >/dev/null 2>&1; then
    PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} JSONL entry valid with correct fields"
  else
    FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} JSONL fields wrong (got: $(cat "$_hook_log_file"))"
  fi
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} log file not created"
fi

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ hook_stop_finding + hook_stop_save_test_results ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session
source "$HOOKS_DIR/_hook-lib.sh"

echo "  stop finding appended to file:"
hook_stop_finding "Type errors: 3 new"
hook_stop_finding "Biome: 2 unfixable"
if [ -f "$_hook_session_dir/stop-findings" ]; then
  finding_count=$(grep -c '^---$' "$_hook_session_dir/stop-findings")
  if [ "$finding_count" -eq 2 ]; then
    PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} 2 findings with delimiters"
  else
    FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} finding count (got: $finding_count)"
  fi
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} stop-findings file not created"
fi

echo "  test results saved:"
hook_stop_save_test_results "PASS" "all tests passed"
status=$(hook_stop_get_test_status)
if [ "$status" = "PASS" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} test status PASS saved and retrieved"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} test status (got: $status)"
fi

echo "  test results output saved:"
if [ -f "$_hook_session_dir/shared-test-output" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} test output file exists"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} test output file not created"
fi

_teardown_session

# ═══════════════════════════════════════════════════════════════

_report_results "_hook-lib.sh"
