# Violation nudge: mid-session feedback loop tests

SHARED_DIR="$REPO_ROOT/shared"
NUDGE_SCRIPT="$SHARED_DIR/violation-nudge.sh"

run_file_eval "$NUDGE_SCRIPT" "violation-nudge.sh exists"
run_executable_eval "$NUDGE_SCRIPT" "violation-nudge.sh is executable"

# ── Real file in .claude/hooks (2.2.1 dereferenced symlinks) ─────

if [ -f "$REPO_ROOT/.claude/hooks/violation-nudge.sh" ] && [ ! -L "$REPO_ROOT/.claude/hooks/violation-nudge.sh" ]; then
  echo "  PASS  .claude/hooks/violation-nudge.sh is a real file"
  PASS=$((PASS + 1))
else
  echo "  FAIL  .claude/hooks/violation-nudge.sh missing or is symlink"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: .claude/hooks/violation-nudge.sh"
fi

# ── settings.json has PreToolUse entry for violation-nudge ───────

run_content_eval "$REPO_ROOT/.claude/settings.json" "violation-nudge" "settings.json has violation-nudge hook"

# ── Setup: temp session dir for isolated tests ───────────────────

_test_session_id="eval-nudge-$$"
_test_session_dir="/tmp/hook-session-${_test_session_id}"
mkdir -p "$_test_session_dir"

# ── No violations: exits silently ────────────────────────────────

_nv_stderr=$(mktemp)
CLAUDE_SESSION_ID="$_test_session_id" "$NUDGE_SCRIPT" 2>"$_nv_stderr" </dev/null || true
if [ -s "$_nv_stderr" ]; then
  echo "  FAIL  no violations should produce no output"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: no violations should produce no output"
else
  echo "  PASS  no violations: silent exit"
  PASS=$((PASS + 1))
fi
rm -f "$_nv_stderr"

# ── Under threshold (2 violations): silent ───────────────────────

printf 'zustand-check\nzustand-check\n' > "$_test_session_dir/violations"
_ut_stderr=$(mktemp)
CLAUDE_SESSION_ID="$_test_session_id" "$NUDGE_SCRIPT" 2>"$_ut_stderr" </dev/null || true
if [ -s "$_ut_stderr" ]; then
  echo "  FAIL  2 violations (under threshold) should be silent"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: 2 violations (under threshold) should be silent"
else
  echo "  PASS  under threshold (2x same rule): silent"
  PASS=$((PASS + 1))
fi
rm -f "$_ut_stderr"

# ── At threshold (3 violations): emits nudge ────────────────────

# Clean nudge markers from previous test
rm -f "$_test_session_dir"/nudge-* 2>/dev/null || true
printf 'zustand-check\nzustand-check\nzustand-check\n' > "$_test_session_dir/violations"
_at_stderr=$(mktemp)
CLAUDE_SESSION_ID="$_test_session_id" "$NUDGE_SCRIPT" 2>"$_at_stderr" </dev/null || true
if grep -q 'VIOLATION PATTERN' "$_at_stderr" && grep -q '3x zustand-check' "$_at_stderr"; then
  echo "  PASS  3x same rule: emits nudge with rule name and count"
  PASS=$((PASS + 1))
else
  echo "  FAIL  3x same rule should emit VIOLATION PATTERN nudge"
  echo "        stderr: $(cat "$_at_stderr")"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: 3x same rule should emit VIOLATION PATTERN nudge"
fi
rm -f "$_at_stderr"

# ── Dedup: same violations don't re-nudge ────────────────────────

_dup_stderr=$(mktemp)
CLAUDE_SESSION_ID="$_test_session_id" "$NUDGE_SCRIPT" 2>"$_dup_stderr" </dev/null || true
if [ -s "$_dup_stderr" ]; then
  echo "  FAIL  duplicate nudge should be suppressed (marker exists)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: duplicate nudge should be suppressed"
else
  echo "  PASS  dedup: same violation set not re-nudged"
  PASS=$((PASS + 1))
fi
rm -f "$_dup_stderr"

# ── New violations trigger new nudge ─────────────────────────────

printf 'accessibility-check\naccessibility-check\naccessibility-check\n' >> "$_test_session_dir/violations"
_new_stderr=$(mktemp)
CLAUDE_SESSION_ID="$_test_session_id" "$NUDGE_SCRIPT" 2>"$_new_stderr" </dev/null || true
if grep -q 'VIOLATION PATTERN' "$_new_stderr"; then
  echo "  PASS  new violation pattern triggers fresh nudge"
  PASS=$((PASS + 1))
else
  echo "  FAIL  new violation pattern should trigger fresh nudge"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: new violation pattern should trigger fresh nudge"
fi
rm -f "$_new_stderr"

# ── Multiple rules in same nudge ─────────────────────────────────

rm -f "$_test_session_dir"/nudge-* 2>/dev/null || true
printf 'react-rules-check\nreact-rules-check\nreact-rules-check\nform-mode-check\nform-mode-check\nform-mode-check\n' > "$_test_session_dir/violations"
_multi_stderr=$(mktemp)
CLAUDE_SESSION_ID="$_test_session_id" "$NUDGE_SCRIPT" 2>"$_multi_stderr" </dev/null || true
if grep -q 'react-rules-check' "$_multi_stderr" && grep -q 'form-mode-check' "$_multi_stderr"; then
  echo "  PASS  multiple rules: both mentioned in nudge"
  PASS=$((PASS + 1))
else
  echo "  FAIL  multiple rules should both appear in nudge"
  echo "        stderr: $(cat "$_multi_stderr")"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: multiple rules should both appear in nudge"
fi
rm -f "$_multi_stderr"

# ── Cleanup ──────────────────────────────────────────────────────

rm -rf "$_test_session_dir" 2>/dev/null || true
