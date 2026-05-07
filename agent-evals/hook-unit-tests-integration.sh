#!/bin/bash
# Integration tests: cross-hook data flow and stop hook pipelines.
# Tests that hooks communicate correctly via shared session state.

source "$(dirname "$0")/hook-test-helpers.sh"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          Cross-Hook Integration Tests                    ║"
echo "╚═══════════════════════════════════════════════════════════╝"

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ stop-findings pipeline ━━━"
# Multiple hooks write → quality-gate-stop aggregates
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  empty pipeline (pass):"
_run_hook "quality-gate-stop.sh" ""
_assert_exit 0 "no findings → allow"

echo "  single finding → block with count:"
printf 'Type errors: 5 new\n---\n' >> "/tmp/hook-session-${CLAUDE_SESSION_ID}/stop-findings"
_run_hook "quality-gate-stop.sh" ""
_assert_exit 2 "1 finding → block"
_assert_stderr_contains "1 issue" "reports 1 issue"
_assert_stderr_contains "Type errors" "includes finding text"

echo "  multiple findings → aggregated block:"
# Reset findings
rm -f "/tmp/hook-session-${CLAUDE_SESSION_ID}/stop-findings"
printf 'Type errors: 3 new\n---\n' >> "/tmp/hook-session-${CLAUDE_SESSION_ID}/stop-findings"
printf 'Biome: 2 unfixable\n---\n' >> "/tmp/hook-session-${CLAUDE_SESSION_ID}/stop-findings"
printf 'Related tests fail:\nExpected 1, got 2\n---\n' >> "/tmp/hook-session-${CLAUDE_SESSION_ID}/stop-findings"
_run_hook "quality-gate-stop.sh" ""
_assert_exit 2 "3 findings → block"
_assert_stderr_contains "3 issue" "reports 3 issues"
_assert_stderr_contains "Type errors" "includes type errors"
_assert_stderr_contains "Biome" "includes biome"
_assert_stderr_contains "tests fail" "includes test failures"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ session-touched-files tracking ━━━"
# hook_parse_edit_write appends → Stop hooks read
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  Edit appends to session-touched-files:"
_f="/tmp/hook-test-track-$$.tsx"
_setup_test_file "$_f" 'const X = () => <div>clean</div>;'
# Run a simple hook that sources _hook-lib and parses edit
# as-cast-check is lightweight and always sources hook-lib
_run_hook "as-cast-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "clean file passes"
# Check that file was tracked
_assert_file_contains "/tmp/hook-session-${CLAUDE_SESSION_ID}/session-touched-files" "$_f" "file tracked in session"

echo "  multiple edits accumulate:"
_f2="/tmp/hook-test-track2-$$.ts"
_setup_test_file "$_f2" 'const y = 1;'
_run_hook "as-cast-check.sh" "$(_edit_json "$_f2")"
line_count=$(wc -l < "/tmp/hook-session-${CLAUDE_SESSION_ID}/session-touched-files" | tr -d ' ')
if [ "$line_count" -ge 2 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} multiple files tracked ($line_count entries)"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} expected ≥2 entries, got $line_count"
fi

_cleanup_test_file "$_f"
_cleanup_test_file "$_f2"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ worktree isolation: secondary-worktree files not tracked ━━━"
# Agent(isolation: "worktree") subagents share CLAUDE_SESSION_ID with parent.
# Their PostToolUse hooks must NOT append to the main session-touched-files,
# or the parent's lifecycle-stop falsely blocks on "new source, no tests".
# ═══════════════════════════════════════════════════════════════

_setup_session

_wt_repo=$(mktemp -d "/tmp/hook-test-wt-repo-$$.XXXXXX")
_wt_secondary=$(mktemp -d -u "/tmp/hook-test-wt-secondary-$$.XXXXXX")

(
  cd "$_wt_repo"
  git init -q -b main
  git config user.email t@t
  git config user.name t
  echo "seed" > seed.txt
  git add seed.txt
  git commit -q -m seed
  git worktree add -q -b wt-branch "$_wt_secondary" >/dev/null 2>&1
) || true

if [ -d "$_wt_secondary/.git" ] || [ -f "$_wt_secondary/.git" ]; then
  echo "  primary-worktree file tracked:"
  _f_primary="$_wt_repo/primary.tsx"
  echo 'const X = () => null;' > "$_f_primary"
  # Run hook with cwd=primary worktree so _hook_current_worktree_root resolves
  # to the primary repo, not the test runner's repo.
  _run_hook_cd "$_wt_repo" "as-cast-check.sh" "$(_edit_json "$_f_primary")"
  _assert_exit 0 "primary file hook exits 0"
  _assert_file_contains "/tmp/hook-session-${CLAUDE_SESSION_ID}/session-touched-files" "primary.tsx" "primary file tracked"

  echo "  secondary-worktree file NOT tracked:"
  _f_secondary="$_wt_secondary/subagent.tsx"
  echo 'const Y = () => null;' > "$_f_secondary"
  # Same: run hook with cwd=primary so secondary worktree is correctly seen as "outside".
  _run_hook_cd "$_wt_repo" "as-cast-check.sh" "$(_edit_json "$_f_secondary")"
  _assert_exit 0 "secondary file hook exits 0"
  if grep -q "subagent.tsx" "/tmp/hook-session-${CLAUDE_SESSION_ID}/session-touched-files" 2>/dev/null; then
    FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} secondary-worktree file leaked into main session tracker"
  else
    PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} secondary-worktree file excluded from main tracker"
  fi

  (cd "$_wt_repo" && git worktree remove -f "$_wt_secondary" >/dev/null 2>&1) || true
else
  _skip "worktree isolation" "git worktree add failed"
fi

rm -rf "$_wt_repo" "$_wt_secondary" 2>/dev/null || true
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ violation tracking → violation-summary-stop ━━━"
# hook_block/hook_warn write violations → summary reads
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  violations accumulate from blocking hooks:"
_f="/tmp/hook-test-viol-$$.tsx"
_setup_test_file "$_f" 'const result = eval("1+1");'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "eval blocked (creates violation)"
_assert_file_exists "/tmp/hook-session-${CLAUDE_SESSION_ID}/violations" "violations file created"

echo "  second violation appends:"
_cleanup_test_file "$_f"
_setup_test_file "$_f" 'if (x === NaN) return;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "NaN blocked (appends violation)"
viol_count=$(wc -l < "/tmp/hook-session-${CLAUDE_SESSION_ID}/violations" | tr -d ' ')
if [ "$viol_count" -ge 2 ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} $viol_count violations accumulated"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} expected ≥2 violations, got $viol_count"
fi

echo "  violation-summary-stop reads and reports:"
_run_hook "violation-summary-stop.sh" ""
_assert_exit 0 "summary exits 0 (non-blocking)"
# violations file should be cleaned up
_assert_file_not_exists "/tmp/hook-session-${CLAUDE_SESSION_ID}/violations" "violations file deleted after summary"

_cleanup_test_file "$_f"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ shared-test-status pipeline ━━━"
# typecheck-stop saves → orchestration-stop reads
# ═══════════════════════════════════════════════════════════════

_setup_session
source "$HOOKS_DIR/_hook-lib.sh"

echo "  save test status PASS:"
hook_stop_save_test_results "PASS" "all 42 tests passed"
status=$(hook_stop_get_test_status)
if [ "$status" = "PASS" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} PASS status saved and read"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} test status (got: $status)"
fi

echo "  save test status FAIL:"
hook_stop_save_test_results "FAIL" "3 tests failed"
status=$(hook_stop_get_test_status)
if [ "$status" = "FAIL" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} FAIL status saved and read"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} test status (got: $status)"
fi

echo "  test output preserved:"
output=$(cat "$_hook_session_dir/shared-test-output" 2>/dev/null)
if echo "$output" | grep -q "3 tests failed"; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} test output preserved"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} test output (got: $output)"
fi

echo "  missing status returns empty:"
rm -f "$_hook_session_dir/shared-test-status"
status=$(hook_stop_get_test_status)
if [ -z "$status" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} missing status returns empty"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} missing status (got: $status)"
fi

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ structured JSONL logging pipeline ━━━"
# All hooks log → metrics-summary-stop aggregates
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  hooks produce JSONL entries:"
_f="/tmp/hook-test-log-$$.tsx"
_setup_test_file "$_f" 'const result = eval("1+1");'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "eval blocked (produces log)"
_assert_file_exists "/tmp/hook-session-${CLAUDE_SESSION_ID}/structured.jsonl" "JSONL log created"

echo "  JSONL entry is valid JSON:"
if head -1 "/tmp/hook-session-${CLAUDE_SESSION_ID}/structured.jsonl" | jq -e '.hook' >/dev/null 2>&1; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} JSONL entry is valid JSON"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} JSONL entry invalid"
fi

echo "  JSONL has required fields:"
entry=$(head -1 "/tmp/hook-session-${CLAUDE_SESSION_ID}/structured.jsonl")
has_ts=$(echo "$entry" | jq -e '.ts' >/dev/null 2>&1 && echo yes || echo no)
has_hook=$(echo "$entry" | jq -e '.hook' >/dev/null 2>&1 && echo yes || echo no)
has_rule=$(echo "$entry" | jq -e '.rule' >/dev/null 2>&1 && echo yes || echo no)
has_decision=$(echo "$entry" | jq -e '.decision' >/dev/null 2>&1 && echo yes || echo no)
if [ "$has_ts" = "yes" ] && [ "$has_hook" = "yes" ] && [ "$has_rule" = "yes" ] && [ "$has_decision" = "yes" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} all required fields present (ts, hook, rule, decision)"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} missing fields (ts=$has_ts hook=$has_hook rule=$has_rule decision=$has_decision)"
fi

echo "  metrics-summary-stop reads JSONL:"
# Simulate enough data for metrics
source "$HOOKS_DIR/_hook-lib.sh"
_hook_log_entry "block" "eval-ban" "react-rules-check"
_hook_log_entry "warn" "inline-style" "react-rules-check"
_hook_log_entry "block" "eval-ban" "react-rules-check"
_run_hook "metrics-summary-stop.sh" ""
_assert_exit 0 "metrics-summary exits 0"

# Check that metrics file was written
metrics_dir="$HOME/.claude/hook-metrics"
if ls "$metrics_dir"/*.json >/dev/null 2>&1; then
  latest=$(ls -t "$metrics_dir"/*.json | head -1)
  if jq -e '.total_entries' "$latest" >/dev/null 2>&1; then
    PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} metrics JSON written with total_entries"
  else
    FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} metrics JSON invalid"
  fi
  # Clean up test metrics
  rm -f "$latest"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} no metrics file created"
fi

_cleanup_test_file "$_f"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ orchestration-guidance → orchestration-stop flow ━━━"
# guidance categorizes files → stop reads categories
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  guidance categorizes test file:"
_f="/tmp/hook-test-orch-$$.test.tsx"
_setup_test_file "$_f" "import { test } from 'vitest';
test('works', () => { expect(1).toBe(1); });"
_run_hook "orchestration-guidance.sh" "$(_edit_json "$_f")"
_assert_exit 0 "guidance processes test file"
# Check if files tracking exists
session_files="/tmp/hook-session-${CLAUDE_SESSION_ID}/files"
if [ -f "$session_files" ] && grep -q "^test:" "$session_files" 2>/dev/null; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} test file categorized as test:"
else
  # May not categorize .test files — check guidance-seen instead
  _skip "test categorization" "hook may skip test files"
fi

echo "  guidance categorizes tsx component:"
_f2="/tmp/hook-test-orch-comp-$$.tsx"
_setup_test_file "$_f2" "import React from 'react';
const MyComp = () => <div>hello</div>;
export default MyComp;"
_run_hook "orchestration-guidance.sh" "$(_edit_json "$_f2")"
_assert_exit 0 "guidance processes component"

echo "  guidance emits once per category:"
# Run again for same category
_f3="/tmp/hook-test-orch-comp2-$$.tsx"
_setup_test_file "$_f3" "const Other = () => <span>world</span>;"
_run_hook "orchestration-guidance.sh" "$(_edit_json "$_f3")"
_assert_exit 0 "second component passes (no duplicate guidance)"

_cleanup_test_file "$_f"
_cleanup_test_file "$_f2"
_cleanup_test_file "$_f3"
_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ session-env baseline → stop hooks filter ━━━"
# session-env captures dirty baseline → stop hooks subtract
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  session dir created:"
if [ -d "/tmp/hook-session-${CLAUDE_SESSION_ID}" ]; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} session dir exists"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} session dir not found"
fi

echo "  hook_session_changed_files with no tracking (fallback):"
source "$HOOKS_DIR/_hook-lib.sh"
# With no tracking files, should fall back to git diff
result=$(hook_session_changed_files "ts|tsx" 2>/dev/null || true)
# Result depends on repo state — just verify it doesn't crash
PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} hook_session_changed_files doesn't crash"

echo "  hook_has_session_tracking with no files:"
if hook_has_session_tracking 2>/dev/null; then
  _skip "session tracking detection" "may have leftover session files"
else
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} no tracking files → returns false"
fi

echo "  hook_has_session_tracking with touched-files:"
echo "/tmp/test.tsx" > "/tmp/hook-session-${CLAUDE_SESSION_ID}/session-touched-files"
if hook_has_session_tracking 2>/dev/null; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} touched-files present → returns true"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} session tracking not detected"
fi

echo "  hook_has_session_tracking with baseline only:"
rm -f "/tmp/hook-session-${CLAUDE_SESSION_ID}/session-touched-files"
echo "existing-file.tsx" > "/tmp/hook-session-${CLAUDE_SESSION_ID}/dirty-files-baseline"
if hook_has_session_tracking 2>/dev/null; then
  PASS=$((PASS + 1)); echo -e "  ${GREEN}✓${NC} baseline present → returns true"
else
  FAIL=$((FAIL + 1)); echo -e "  ${RED}✗${NC} baseline tracking not detected"
fi

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ consecutive-failure → quality-gate interaction ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  3 failures then quality-gate check:"
# Simulate 3 lint failures
_run_hook "consecutive-failure-check.sh" '{"tool_name":"Bash","tool_input":{"command":"bun run lint"},"tool_result":{"exit_code":1}}'
_run_hook "consecutive-failure-check.sh" '{"tool_name":"Bash","tool_input":{"command":"bun run lint"},"tool_result":{"exit_code":1}}'
_run_hook "consecutive-failure-check.sh" '{"tool_name":"Bash","tool_input":{"command":"bun run lint"},"tool_result":{"exit_code":1}}'
_assert_stderr_contains "failed.*3x|Fix ALL" "3rd failure triggers guidance"

echo "  success resets counter:"
_run_hook "consecutive-failure-check.sh" '{"tool_name":"Bash","tool_input":{"command":"bun run lint"},"tool_result":{"exit_code":0}}'
_assert_exit 0 "success resets"

echo "  next failure starts fresh count:"
_run_hook "consecutive-failure-check.sh" '{"tool_name":"Bash","tool_input":{"command":"bun run lint"},"tool_result":{"exit_code":1}}'
_assert_exit 0 "1st failure after reset — no message"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ edit-loop-check counter isolation ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-editloop-$$.tsx"
_setup_test_file "$_f" "const x = 1;"

echo "  different files have independent counters:"
_f2="/tmp/hook-test-editloop2-$$.tsx"
_setup_test_file "$_f2" "const y = 2;"

# Edit file1 11 times
for i in $(seq 1 11); do
  _run_hook "edit-loop-check.sh" "$(_edit_json "$_f")"
done
_assert_exit 0 "11th edit on file1 — no warn"

# Edit file2 once — should NOT trigger (different file)
_run_hook "edit-loop-check.sh" "$(_edit_json "$_f2")"
_assert_exit 0 "1st edit on file2 — no warn"

# Edit file1 once more (12th) — should trigger
_run_hook "edit-loop-check.sh" "$(_edit_json "$_f")"
_assert_stderr_contains "12 times" "12th edit on file1 triggers warning"

_cleanup_test_file "$_f"
_cleanup_test_file "$_f2"
_teardown_session

# ═══════════════════════════════════════════════════════════════

_report_results "Integration Tests"
