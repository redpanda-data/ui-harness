#!/bin/bash
# Shared test helpers for hook unit test suites.
# Source this at top of each test file.

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.claude/hooks" && pwd)"
SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../shared" && pwd)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
SKIP=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# ── Session helpers ─────────────────────────────────────────────

_setup_session() {
  export CLAUDE_SESSION_ID="test-$$-$(date +%s)-$RANDOM"
  _session_dir="/tmp/hook-session-${CLAUDE_SESSION_ID}"
  mkdir -p "$_session_dir"
}

_teardown_session() {
  rm -rf "/tmp/hook-session-${CLAUDE_SESSION_ID}" 2>/dev/null || true
  unset CLAUDE_SESSION_ID
}

# ── File helpers ────────────────────────────────────────────────

_setup_test_file() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  echo "$content" > "$path"
  git add "$path" 2>/dev/null || true
}

_cleanup_test_file() {
  local path="$1"
  git checkout -- "$path" 2>/dev/null || true
  rm -f "$path" 2>/dev/null || true
}

_cleanup_test_dir() {
  local dir="$1"
  rm -rf "$dir" 2>/dev/null || true
}

# ── Hook runner ─────────────────────────────────────────────────

_run_hook() {
  local hook="$1"
  local input="$2"
  local stderr_file="/tmp/hook-test-stderr-$$-$RANDOM"
  local exit_code=0
  echo "$input" | bash "$HOOKS_DIR/$hook" 2>"$stderr_file" || exit_code=$?
  _last_stderr=$(cat "$stderr_file")
  _last_exit=$exit_code
  rm -f "$stderr_file"
}

_run_hook_cd() {
  # Same as _run_hook but runs the hook from a specified cwd. Required for
  # tests that probe worktree-aware logic (`_hook_current_worktree_root`
  # uses git rev-parse, which reads the caller's cwd).
  local cwd="$1"
  local hook="$2"
  local input="$3"
  local stderr_file="/tmp/hook-test-stderr-$$-$RANDOM"
  local exit_code=0
  ( cd "$cwd" && echo "$input" | bash "$HOOKS_DIR/$hook" 2>"$stderr_file" ) || exit_code=$?
  _last_stderr=$(cat "$stderr_file")
  _last_exit=$exit_code
  rm -f "$stderr_file"
}

_run_hook_with_env() {
  local hook="$1"
  local input="$2"
  shift 2
  # Remaining args are VAR=val pairs
  local stderr_file="/tmp/hook-test-stderr-$$-$RANDOM"
  local exit_code=0
  echo "$input" | env "$@" bash "$HOOKS_DIR/$hook" 2>"$stderr_file" || exit_code=$?
  _last_stderr=$(cat "$stderr_file")
  _last_exit=$exit_code
  rm -f "$stderr_file"
}

# Run hook from shared/ directory
_run_shared_hook() {
  local hook="$1"
  local input="$2"
  local stderr_file="/tmp/hook-test-stderr-$$-$RANDOM"
  local exit_code=0
  echo "$input" | bash "$SHARED_DIR/$hook" 2>"$stderr_file" || exit_code=$?
  _last_stderr=$(cat "$stderr_file")
  _last_exit=$exit_code
  rm -f "$stderr_file"
}

# ── Assertions ──────────────────────────────────────────────────

_assert_exit() {
  local expected="$1"
  local test_name="$2"
  if [ "$_last_exit" -eq "$expected" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $test_name (expected exit $expected, got $_last_exit)"
    if [ -n "$_last_stderr" ]; then echo "    stderr: $(echo "$_last_stderr" | head -3)"; fi
  fi
}

_assert_stderr_contains() {
  local pattern="$1"
  local test_name="$2"
  if echo "$_last_stderr" | grep -qE "$pattern"; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $test_name (stderr missing pattern: $pattern)"
    echo "    stderr: $(echo "$_last_stderr" | head -3)"
  fi
}

_assert_stderr_not_contains() {
  local pattern="$1"
  local test_name="$2"
  if echo "$_last_stderr" | grep -qE "$pattern"; then
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $test_name (stderr unexpectedly contains: $pattern)"
    echo "    stderr: $(echo "$_last_stderr" | head -3)"
  else
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $test_name"
  fi
}

_assert_file_contains() {
  local file="$1"
  local pattern="$2"
  local test_name="$3"
  if [ -f "$file" ] && grep -qE "$pattern" "$file"; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $test_name (file missing pattern: $pattern)"
  fi
}

_assert_file_exists() {
  local file="$1"
  local test_name="$2"
  if [ -f "$file" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $test_name (file not found: $file)"
  fi
}

_assert_file_not_exists() {
  local file="$1"
  local test_name="$2"
  if [ ! -f "$file" ]; then
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}✓${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}✗${NC} $test_name (file unexpectedly exists: $file)"
  fi
}

_skip() {
  local test_name="$1"
  local reason="${2:-}"
  SKIP=$((SKIP + 1))
  echo -e "  ${YELLOW}○${NC} $test_name${reason:+ ($reason)}"
}

# ── Reporting ───────────────────────────────────────────────────

_report_results() {
  local suite_name="${1:-Tests}"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "$suite_name: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ "$FAIL" -gt 0 ]; then
    return 1
  fi
  return 0
}

# ── Convenience: make Edit JSON ─────────────────────────────────

_edit_json() {
  local file_path="$1"
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$file_path"
}

_write_json() {
  local file_path="$1"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$file_path"
}

_bash_json() {
  local cmd="$1"
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd"
}
