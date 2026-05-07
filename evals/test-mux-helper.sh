# Evals for scripts/mux-worktree.sh + lifecycle integration.

SCRIPT="$REPO_ROOT/scripts/mux-worktree.sh"

run_file_eval "$SCRIPT" "mux-worktree.sh exists"
run_executable_eval "$SCRIPT" "mux-worktree.sh executable"

# Required modes
run_content_eval "$SCRIPT" "\\-\\-list" "supports --list"
run_content_eval "$SCRIPT" "\\-\\-clean" "supports --clean"

# Safety: conventional-commits validation, no path traversal
run_content_eval "$SCRIPT" "invalid branch name" "rejects invalid branch name"
run_content_eval "$SCRIPT" "worktree exists" "refuses to clobber existing worktree"
run_content_eval "$SCRIPT" "session-hint" "writes session-hint for bind"
run_content_eval "$SCRIPT" "settings.local.json" "copies settings.local.json if present"

# Integration: /development-lifecycle and /go invoke the helper
run_content_eval "$REPO_ROOT/development-lifecycle/SKILL.md" "mux-worktree.sh" \
  "development-lifecycle invokes mux-worktree"
run_content_eval "$REPO_ROOT/development-lifecycle/SKILL.md" "ETHOS: Worktree Isolation" \
  "development-lifecycle cross-refs ETHOS"
run_content_eval "$REPO_ROOT/go/SKILL.md" "mux-worktree.sh" \
  "go invokes mux-worktree on default branch"

# Invalid-branch exit path
_ec=0
"$SCRIPT" "bogus-no-type" 2>/dev/null >/dev/null || _ec=$?
if [ "$_ec" -eq 1 ]; then
  echo "  PASS  rejects branch without type prefix (exit 1)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  invalid branch exit was $_ec"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: invalid branch exit"
fi

_ec=0
"$SCRIPT" "feat/has spaces" 2>/dev/null >/dev/null || _ec=$?
if [ "$_ec" -eq 1 ]; then
  echo "  PASS  rejects branch with spaces"
  PASS=$((PASS + 1))
else
  echo "  FAIL  spaces-in-branch exit was $_ec"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: spaces-in-branch"
fi

_ec=0
"$SCRIPT" "feat/../traversal" 2>/dev/null >/dev/null || _ec=$?
if [ "$_ec" -eq 1 ]; then
  echo "  PASS  rejects path-traversal attempt"
  PASS=$((PASS + 1))
else
  echo "  FAIL  traversal exit was $_ec"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: traversal"
fi

# --list runs cleanly
_ec=0
"$SCRIPT" --list >/dev/null 2>&1 || _ec=$?
if [ "$_ec" -eq 0 ]; then
  echo "  PASS  --list exits 0"
  PASS=$((PASS + 1))
else
  echo "  FAIL  --list exit was $_ec"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: --list"
fi
