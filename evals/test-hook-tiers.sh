# Evals for new hook tiers added in 2.2.2: info, nudge, block-strict, diagnostic.

LIB="$REPO_ROOT/.claude/hooks/_hook-lib.sh"

run_file_eval "$LIB" "_hook-lib.sh exists"

# ── Each new function defined ───────────────────────────────────
for fn in hook_info hook_nudge hook_block_strict hook_emit_diagnostic; do
  if grep -qE "^${fn}\s*\(\)" "$LIB"; then
    echo "  PASS  $fn() defined in _hook-lib.sh"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $fn() missing from _hook-lib.sh"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $fn() missing"
  fi
done

# ── hook_info exits 0 silently (no system message) ──────────────
_test_script=$(mktemp)
cat > "$_test_script" <<EOF
#!/bin/bash
source "$LIB"
hook_info "test-rule"
EOF
chmod +x "$_test_script"

_out=$(echo '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/x.ts"}}' | "$_test_script" 2>&1)
_rc=$?
if [ "$_rc" = "0" ] && [ -z "$_out" ]; then
  echo "  PASS  hook_info exits 0 with no output"
  PASS=$((PASS + 1))
else
  echo "  FAIL  hook_info should exit 0 silently (got rc=$_rc, out=$_out)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: hook_info not silent"
fi
rm -f "$_test_script"

# ── hook_nudge emits systemMessage with [nudge] prefix ──────────
_test_script=$(mktemp)
cat > "$_test_script" <<EOF
#!/bin/bash
source "$LIB"
hook_nudge "consider X" "test-rule"
EOF
chmod +x "$_test_script"

_out=$(echo '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/x.ts"}}' | "$_test_script" 2>&1)
_rc=$?
if [ "$_rc" = "0" ] && echo "$_out" | grep -q '\[nudge\]'; then
  echo "  PASS  hook_nudge emits [nudge]-prefixed systemMessage"
  PASS=$((PASS + 1))
else
  echo "  FAIL  hook_nudge missing [nudge] prefix (out=$_out)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: hook_nudge prefix wrong"
fi
rm -f "$_test_script"

# ── hook_block_strict exits 2 with [STRICT] prefix ──────────────
_test_script=$(mktemp)
cat > "$_test_script" <<EOF
#!/bin/bash
source "$LIB"
hook_block_strict "sec issue" "test-rule"
EOF
chmod +x "$_test_script"

_out=$(echo '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/x.ts"}}' | "$_test_script" 2>&1 || true)
_rc=0
echo '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/x.ts"}}' | "$_test_script" >/dev/null 2>&1 || _rc=$?
if [ "$_rc" = "2" ] && echo "$_out" | grep -q '\[STRICT\]'; then
  echo "  PASS  hook_block_strict exits 2 with [STRICT] prefix"
  PASS=$((PASS + 1))
else
  echo "  FAIL  hook_block_strict wrong behavior (rc=$_rc)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: hook_block_strict behavior"
fi
rm -f "$_test_script"

# ── Timing: _hook_elapsed_ms returns integer ───────────────────
_test_script=$(mktemp)
cat > "$_test_script" <<EOF
#!/bin/bash
source "$LIB"
_hook_elapsed_ms
EOF
chmod +x "$_test_script"
_out=$("$_test_script" 2>&1)
if echo "$_out" | grep -qE '^[0-9]+$'; then
  echo "  PASS  _hook_elapsed_ms returns integer ($_out ms)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  _hook_elapsed_ms output not numeric: $_out"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: elapsed_ms not numeric"
fi
rm -f "$_test_script"

# ── session-end.sh includes perf_ms field (moved from metrics-summary-stop in 2.2.4) ─
if grep -q 'perf_ms' "$REPO_ROOT/.claude/hooks/session-end.sh"; then
  echo "  PASS  session-end.sh emits perf_ms field (schema v2)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  session-end.sh missing perf_ms emission"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: metrics schema v2 not wired in session-end"
fi
