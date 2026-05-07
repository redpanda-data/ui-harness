# Evals for hook scripts (SubagentStart, SubagentStop)

HOOKS_DIR="$REPO_ROOT/.claude/hooks"
SHARED_DIR="$REPO_ROOT/shared"

# ── Hook scripts exist and are executable ────────────────────────
run_file_eval "$SHARED_DIR/subagent-start.sh" "subagent-start.sh exists"
run_executable_eval "$SHARED_DIR/subagent-start.sh" "subagent-start.sh is executable"
run_file_eval "$SHARED_DIR/subagent-stop.sh" "subagent-stop.sh exists"
run_executable_eval "$SHARED_DIR/subagent-stop.sh" "subagent-stop.sh is executable"

# ── Real files in .claude/hooks (no symlinks — 2.2.1 dereferenced) ──
# Plugin packager resolves relative symlinks to absolute paths at
# package time, creating dangling links in install cache. Enforce
# real files to prevent regression.
if [ -f "$HOOKS_DIR/subagent-start.sh" ] && [ ! -L "$HOOKS_DIR/subagent-start.sh" ]; then
  echo "  PASS  .claude/hooks/subagent-start.sh is a real file (no symlink)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  .claude/hooks/subagent-start.sh missing or is symlink (plugin will break)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: .claude/hooks/subagent-start.sh not a real file"
fi

if [ -f "$HOOKS_DIR/subagent-stop.sh" ] && [ ! -L "$HOOKS_DIR/subagent-stop.sh" ]; then
  echo "  PASS  .claude/hooks/subagent-stop.sh is a real file (no symlink)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  .claude/hooks/subagent-stop.sh missing or is symlink (plugin will break)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: .claude/hooks/subagent-stop.sh not a real file"
fi

# ── Sentinel: no dangling symlinks anywhere in .claude/hooks/ ───
_symlink_count=$(find "$HOOKS_DIR" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')
if [ "$_symlink_count" = "0" ]; then
  echo "  PASS  .claude/hooks/ has 0 symlinks (plugin-packager safe)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  .claude/hooks/ has $_symlink_count symlinks — plugin packager will break"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: $_symlink_count symlinks in .claude/hooks/"
fi

# ── Defensive _hook-lib.sh source pattern (prevents N×error loop) ─
# If cache install corrupts _hook-lib.sh (dangling symlink, missing file),
# every PostToolUse hook fires and spams an error per Edit. Defensive
# preamble warns once + no-ops for the session. Block regression to
# plain `source` that would reintroduce the N×error loop.
_plain_source_count=$({ grep -lE '^source "\$\(dirname "\$0"\)/_hook-lib\.sh"$' "$HOOKS_DIR"/*.sh 2>/dev/null || true; } | wc -l | tr -d ' ')
if [ "$_plain_source_count" = "0" ]; then
  echo "  PASS  all hooks use defensive _hook-lib.sh source (no N×error loop risk)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  $_plain_source_count hooks use plain 'source _hook-lib.sh' — broken cache will spam N×errors"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: $_plain_source_count hooks missing defensive source preamble"
fi

# ── settings.json has SubagentStart and SubagentStop entries ─────
run_content_eval "$REPO_ROOT/.claude/settings.json" "SubagentStart" "settings.json has SubagentStart hook"
run_content_eval "$REPO_ROOT/.claude/settings.json" "SubagentStop" "settings.json has SubagentStop hook"

# ── SubagentStop: non-reviewer agent passes through (exit 0) ────
run_hook_eval "$SHARED_DIR/subagent-stop.sh" \
  '{"agent_type":"verifier","session_id":"test-eval","last_assistant_message":"all good"}' \
  0 \
  "subagent-stop passes through non-reviewer agents"

# ── SubagentStop: valid findings JSON accepted (exit 0) ──────────
VALID_FINDINGS='{"agent_type":"code-reviewer","session_id":"test-eval","last_assistant_message":"```json\n{\"reviewer\":\"code-reviewer\",\"status\":\"APPROVED\",\"findings\":[],\"testing_gaps\":[],\"simplification_opportunities\":[]}\n```"}'
run_hook_eval "$SHARED_DIR/subagent-stop.sh" \
  "$VALID_FINDINGS" \
  0 \
  "subagent-stop accepts valid findings JSON"

# ── SubagentStop: missing JSON block rejected (exit 2) ───────────
run_hook_eval "$SHARED_DIR/subagent-stop.sh" \
  '{"agent_type":"self-reviewer","session_id":"test-eval","last_assistant_message":"Looks good, no issues found."}' \
  2 \
  "subagent-stop rejects reviewer output without JSON block"

# ── SubagentStop: invalid status enum rejected (exit 2) ──────────
INVALID_STATUS='{"agent_type":"code-reviewer","session_id":"test-eval","last_assistant_message":"```json\n{\"reviewer\":\"code-reviewer\",\"status\":\"LGTM\",\"findings\":[]}\n```"}'
run_hook_eval "$SHARED_DIR/subagent-stop.sh" \
  "$INVALID_STATUS" \
  2 \
  "subagent-stop rejects invalid status enum"

# ── SubagentStop: missing required finding fields rejected (exit 2)
MISSING_FIELDS='{"agent_type":"code-reviewer","session_id":"test-eval","last_assistant_message":"```json\n{\"reviewer\":\"code-reviewer\",\"status\":\"NEEDS_CHANGES\",\"findings\":[{\"title\":\"bug\"}]}\n```"}'
run_hook_eval "$SHARED_DIR/subagent-stop.sh" \
  "$MISSING_FIELDS" \
  2 \
  "subagent-stop rejects findings with missing required fields"

# ── SubagentStart: emits context on stderr (exit 0) ─────────────
run_hook_eval "$SHARED_DIR/subagent-start.sh" \
  '{"agent_type":"self-reviewer","session_id":"test-eval"}' \
  0 \
  "subagent-start exits 0 for reviewer agent"

# ── SubagentStart: emits context with branch info ────────────────
run_hook_eval "$SHARED_DIR/subagent-start.sh" \
  '{"agent_type":"code-reviewer","session_id":"test-eval"}' \
  0 \
  "subagent-start exits 0 for code-reviewer" \
  "Branch Context"

# ── lifecycle-stop.sh has adjacent-test fallback (no false-flag on
#    worktree / multi-session flows where tests exist on disk but
#    were not edited this session) ─────────────────────────────────
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "_adjacent_tests_for_all" \
  "lifecycle-stop has adjacent-test fallback"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "__tests__" \
  "lifecycle-stop adjacent fallback checks __tests__ dir"
