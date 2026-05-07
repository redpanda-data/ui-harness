# Evals for worktree isolation + branch-safety.
# Covers:
#   - hook-lib helpers: _hook_current_worktree_root, _hook_file_outside_current_worktree
#   - _hook_assert_bound_worktree drift → exit 0 no-op
#   - session-env.sh writes bound-worktree + bound-branch
#   - session-env.sh deterministic fallback session id (md5 of worktree)
#   - branch-safety-check.sh deny/pass/rebind cases

HOOKS="$REPO_ROOT/.claude/hooks"
SHARED="$REPO_ROOT/shared"

run_file_eval "$HOOKS/branch-safety-check.sh" "branch-safety-check.sh exists"
run_executable_eval "$HOOKS/branch-safety-check.sh" "branch-safety-check.sh executable"
run_content_eval "$REPO_ROOT/skill-manifest.json" "branch-safety-check.sh" \
  "manifest registers branch-safety-check.sh"
run_content_eval "$REPO_ROOT/hooks/hooks.json" "branch-safety-check.sh" \
  "hooks.json registers branch-safety-check.sh"
run_content_eval "$REPO_ROOT/.claude/settings.json" "branch-safety-check.sh" \
  "settings.json registers branch-safety-check.sh"

# ── Hook-lib helpers defined ────────────────────────────────────
run_content_eval "$SHARED/hook-lib.sh" "_hook_current_worktree_root" \
  "hook-lib.sh defines _hook_current_worktree_root"
run_content_eval "$SHARED/hook-lib.sh" "_hook_file_outside_current_worktree" \
  "hook-lib.sh defines _hook_file_outside_current_worktree"
run_content_eval "$SHARED/hook-lib.sh" "_hook_assert_bound_worktree" \
  "hook-lib.sh defines _hook_assert_bound_worktree"
run_content_eval "$HOOKS/_hook-lib.sh" "_hook_file_outside_current_worktree" \
  "_hook-lib.sh (plugin copy) mirrors the helper"
run_content_eval "$HOOKS/_hook-lib.sh" "_hook_assert_bound_worktree" \
  "_hook-lib.sh (plugin copy) mirrors assert_bound_worktree"

# ── session-env.sh writes bound-worktree + bound-branch ──────────
run_content_eval "$HOOKS/session-env.sh" "bound-worktree" \
  "session-env.sh writes bound-worktree"
run_content_eval "$HOOKS/session-env.sh" "bound-branch" \
  "session-env.sh writes bound-branch"
run_content_eval "$HOOKS/session-env.sh" "MUX_" \
  "session-env.sh reads /mux session-hint"
run_content_eval "$HOOKS/session-env.sh" "md5" \
  "session-env.sh has deterministic session_id fallback"

# ── branch-safety-check.sh: unit tests ───────────────────────────
_setup_bs() {
  export CLAUDE_SESSION_ID="eval-bs-$$"
  local d="/tmp/hook-session-$CLAUDE_SESSION_ID"
  mkdir -p "$d"
  echo "$1" > "$d/bound-branch"
  _BS_DIR="$d"
}
_teardown_bs() {
  find /tmp -maxdepth 1 -name "hook-session-eval-bs-*" -exec rm -rf {} + 2>/dev/null || true
  unset CLAUDE_SESSION_ID _BS_DIR
}
_run_bs() {
  local stderr_file
  stderr_file=$(mktemp)
  local exit_code=0
  echo "$1" | bash "$HOOKS/branch-safety-check.sh" 2>"$stderr_file" > /dev/null || exit_code=$?
  _last_stderr=$(cat "$stderr_file")
  _last_exit=$exit_code
  rm -f "$stderr_file"
}
_assert_bs() {
  local desc="$1" expected="$2" pattern="${3:-}"
  local ok=true
  [ "$_last_exit" -ne "$expected" ] && ok=false
  if [ -n "$pattern" ] && ! echo "$_last_stderr" | grep -qF -- "$pattern"; then ok=false; fi
  if [ "$ok" = true ]; then
    echo "  PASS  $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL  $desc (exit=$_last_exit expected=$expected)"
    [ -n "$pattern" ] && echo "        pattern missing: $pattern"
    FAIL=$((FAIL + 1)); ERRORS="$ERRORS\n  FAIL: $desc"
  fi
}

# Current branch in the ui-harness repo
_actual_branch=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "main")

# Same branch → pass (exit 0)
_setup_bs "$_actual_branch"
_run_bs '{"tool_name":"Bash","tool_input":{"command":"git commit -m foo"}}'
_assert_bs "branch-safety: same branch passes" 0
_teardown_bs

# Drift → deny (exit 2)
_setup_bs "feat/definitely-not-current-$RANDOM"
_run_bs '{"tool_name":"Bash","tool_input":{"command":"git commit -m foo"}}'
_assert_bs "branch-safety: drift denies" 2 "Refusing this git call"
_teardown_bs

# Rebind env → pass (exit 0) and update bound-branch
_setup_bs "feat/drift-$RANDOM"
CLAUDE_BRANCH_REBIND=1 _run_bs '{"tool_name":"Bash","tool_input":{"command":"git commit -m foo"}}'
_assert_bs "branch-safety: rebind env passes" 0 "rebound"
unset CLAUDE_BRANCH_REBIND
_teardown_bs

# Non-git command → pass
_setup_bs "feat/irrelevant"
_run_bs '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
_assert_bs "branch-safety: non-git command passes" 0
_teardown_bs

# Detached HEAD / empty current → pass (do not gate)
_setup_bs ""
_run_bs '{"tool_name":"Bash","tool_input":{"command":"git push"}}'
_assert_bs "branch-safety: empty bound passes" 0
_teardown_bs

# No bound file → pass (first turn)
export CLAUDE_SESSION_ID="eval-bs-unbound-$$"
mkdir -p "/tmp/hook-session-$CLAUDE_SESSION_ID"
_run_bs '{"tool_name":"Bash","tool_input":{"command":"git commit -m foo"}}'
_assert_bs "branch-safety: unbound session passes" 0
find /tmp -maxdepth 1 -name "hook-session-eval-bs-unbound-*" -exec rm -rf {} + 2>/dev/null || true
unset CLAUDE_SESSION_ID
