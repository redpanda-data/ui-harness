# Evals for PR feedback completeness enforcement.
# Verifies the Stop hook blocks session exit when unresolved review
# feedback remains, and passes when nothing is outstanding.

HOOK="$REPO_ROOT/.claude/hooks/pr-feedback-completeness-stop.sh"
SKILL="$REPO_ROOT/resolve-pr-feedback/SKILL.md"
REF="$REPO_ROOT/resolve-pr-feedback/REFERENCE.md"
GO_SKILL="$REPO_ROOT/go/SKILL.md"
LC_SKILL="$REPO_ROOT/development-lifecycle/SKILL.md"
HOOKS_JSON="$REPO_ROOT/hooks/hooks.json"
SETTINGS_JSON="$REPO_ROOT/.claude/settings.json"

# ── Artifact existence ───────────────────────────────────────────
run_file_eval "$HOOK" "pr-feedback-completeness-stop.sh exists"
run_executable_eval "$HOOK" "pr-feedback-completeness-stop.sh is executable"

# ── Registration in both hook configs ────────────────────────────
run_content_eval "$HOOKS_JSON" "pr-feedback-completeness-stop.sh" \
  "hooks.json registers pr-feedback-completeness-stop.sh"
run_content_eval "$SETTINGS_JSON" "pr-feedback-completeness-stop.sh" \
  ".claude/settings.json registers pr-feedback-completeness-stop.sh"

# ── Skill documents enforcement ──────────────────────────────────
run_content_eval "$SKILL" "Completeness Verification" \
  "resolve-pr-feedback SKILL.md has Completeness Verification section"
run_content_eval "$SKILL" "pr-feedback-completeness-stop" \
  "resolve-pr-feedback SKILL.md references the hook by name"
run_content_eval "$SKILL" "NO iteration cap" \
  "resolve-pr-feedback SKILL.md states no cap for human feedback"
run_content_eval "$REF" "PR_FEEDBACK_ENFORCEMENT=off" \
  "REFERENCE.md documents enforcement escape hatch"

# Go + lifecycle skills reflect the distinction
run_content_eval "$GO_SKILL" "pr-feedback-completeness-stop" \
  "go/SKILL.md references the hook"
run_content_eval "$GO_SKILL" "NO cap" \
  "go/SKILL.md states human review has no cap"
run_content_eval "$GO_SKILL" "up to 3" \
  "go/SKILL.md allows up to 3 AI self-review rounds"
run_content_eval "$GO_SKILL" "[Ee]arly-exit" \
  "go/SKILL.md has early-exit condition for self-review"
run_content_eval "$LC_SKILL" "hook-enforced" \
  "development-lifecycle/SKILL.md mentions hook enforcement"
run_content_eval "$LC_SKILL" "early-exit" \
  "development-lifecycle/SKILL.md mentions early-exit"

# Self-check wrapper script (hides GraphQL detail)
run_file_eval "$REPO_ROOT/scripts/pr-unresolved-count.sh" \
  "scripts/pr-unresolved-count.sh exists"
run_executable_eval "$REPO_ROOT/scripts/pr-unresolved-count.sh" \
  "scripts/pr-unresolved-count.sh is executable"
run_content_eval "$SKILL" "scripts/pr-unresolved-count.sh" \
  "SKILL.md uses wrapper script (no raw GraphQL)"

# ── Hook unit tests ──────────────────────────────────────────────
# Set up clean session + disable real gh calls via mocks

_run_hook_with_env() {
  # Usage: _run_hook_with_env "$HOOK" "VAR1=val1" "VAR2=val with spaces" ...
  # JSON values with spaces/quotes are preserved (each env pair is one arg).
  local script="$1"; shift
  local stderr_file
  stderr_file=$(mktemp)
  local exit_code=0
  (
    export CLAUDE_SESSION_ID="eval-prfb-$$"
    for kv in "$@"; do
      export "${kv?}"
    done
    bash "$script" < /dev/null > /dev/null 2> "$stderr_file"
  ) || exit_code=$?
  _last_stderr=$(cat "$stderr_file")
  _last_exit=$exit_code
  rm -f "$stderr_file"
  rm -rf "/tmp/hook-session-eval-prfb-$$" 2>/dev/null || true
}

_assert() {
  local desc="$1" expected="$2" pattern="${3:-}"
  local ok=true
  [ "$_last_exit" -ne "$expected" ] && ok=false
  if [ -n "$pattern" ] && ! echo "$_last_stderr" | grep -qF -- "$pattern"; then
    ok=false
  fi
  if [ "$ok" = true ]; then
    echo "  PASS  $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $desc (exit=$_last_exit expected=$expected)"
    [ -n "$pattern" ] && echo "        pattern missing: $pattern"
    [ -n "$_last_stderr" ] && echo "        stderr: ${_last_stderr:0:200}"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $desc"
  fi
}

if [ -x "$HOOK" ] && command -v jq &>/dev/null; then
  # No PR on branch → pass through
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_MOCK_PR=none"
  _assert "exits 0 when branch has no PR" 0

  # Clean PR: no threads, no reviews → pass
  clean_threads='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}'
  clean_reviews='{"reviews":[]}'
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_MOCK_PR=42" "PR_FEEDBACK_MOCK_THREADS=$clean_threads" "PR_FEEDBACK_MOCK_REVIEWS=$clean_reviews"
  _assert "exits 0 when PR has no unresolved feedback" 0

  # Unresolved non-bot thread → block
  unresolved='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":false,"isOutdated":false,"comments":{"nodes":[{"author":{"login":"alice"},"body":"use const not let"}]}}]}}}}}'
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_MOCK_PR=42" "PR_FEEDBACK_MOCK_THREADS=$unresolved" "PR_FEEDBACK_MOCK_REVIEWS=$clean_reviews"
  _assert "blocks (exit 2) on unresolved non-bot thread" 2 "unresolved review thread"
  _assert "prescribes /resolve-pr-feedback" 2 "/resolve-pr-feedback"

  # Bot-only thread → pass (bots should not block humans)
  bot_thread='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":false,"isOutdated":false,"comments":{"nodes":[{"author":{"login":"copilot[bot]"},"body":"nit"}]}}]}}}}}'
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_MOCK_PR=42" "PR_FEEDBACK_MOCK_THREADS=$bot_thread" "PR_FEEDBACK_MOCK_REVIEWS=$clean_reviews"
  _assert "exits 0 for bot-only unresolved threads" 0

  # Outdated thread → pass
  outdated='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":false,"isOutdated":true,"comments":{"nodes":[{"author":{"login":"alice"},"body":"old"}]}}]}}}}}'
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_MOCK_PR=42" "PR_FEEDBACK_MOCK_THREADS=$outdated" "PR_FEEDBACK_MOCK_REVIEWS=$clean_reviews"
  _assert "exits 0 for outdated unresolved threads" 0

  # Resolved thread → pass
  resolved='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":true,"isOutdated":false,"comments":{"nodes":[{"author":{"login":"alice"},"body":"fixed"}]}}]}}}}}'
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_MOCK_PR=42" "PR_FEEDBACK_MOCK_THREADS=$resolved" "PR_FEEDBACK_MOCK_REVIEWS=$clean_reviews"
  _assert "exits 0 when all threads resolved" 0

  # CHANGES_REQUESTED pending → block
  cr='{"reviews":[{"author":{"login":"alice"},"state":"CHANGES_REQUESTED","submittedAt":"2026-04-17T10:00:00Z"}]}'
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_MOCK_PR=42" "PR_FEEDBACK_MOCK_THREADS=$clean_threads" "PR_FEEDBACK_MOCK_REVIEWS=$cr"
  _assert "blocks when reviewer state is CHANGES_REQUESTED" 2 "CHANGES_REQUESTED"

  # CHANGES_REQUESTED superseded by APPROVED → pass
  cr_ok='{"reviews":[{"author":{"login":"alice"},"state":"CHANGES_REQUESTED","submittedAt":"2026-04-17T10:00:00Z"},{"author":{"login":"alice"},"state":"APPROVED","submittedAt":"2026-04-17T11:00:00Z"}]}'
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_MOCK_PR=42" "PR_FEEDBACK_MOCK_THREADS=$clean_threads" "PR_FEEDBACK_MOCK_REVIEWS=$cr_ok"
  _assert "exits 0 when APPROVED follows CHANGES_REQUESTED" 0

  # Global disable → pass even with unresolved thread
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_ENFORCEMENT=off" "PR_FEEDBACK_MOCK_PR=42" "PR_FEEDBACK_MOCK_THREADS=$unresolved" "PR_FEEDBACK_MOCK_REVIEWS=$clean_reviews"
  _assert "PR_FEEDBACK_ENFORCEMENT=off disables hook" 0

  # Block message mentions PR number
  _run_hook_with_env "$HOOK" "PR_FEEDBACK_MOCK_PR=99" "PR_FEEDBACK_MOCK_THREADS=$unresolved" "PR_FEEDBACK_MOCK_REVIEWS=$clean_reviews"
  _assert "block message includes PR number" 2 "PR #99"

  # Block message quotes first comment body (truncated safe)
  _assert "block message includes quoted comment" 2 "use const not let"
else
  echo "  SKIP  hook unit tests (hook or jq unavailable)"
  SKIP=$((SKIP + 3))
fi
