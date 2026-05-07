# Intent detection: risk tier and directive tests

SHARED_DIR="$REPO_ROOT/shared"
INTENT_SCRIPT="$SHARED_DIR/intent-detect.sh"

run_file_eval "$INTENT_SCRIPT" "intent-detect.sh exists"
run_executable_eval "$INTENT_SCRIPT" "intent-detect.sh is executable"

# ── Risk tier: low-risk prompts emit NO risk tag ─────────────────

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"create a new component for settings"}' \
  0 \
  "low-risk prompt: no RISK tag emitted (component creation)"

# Verify low risk does NOT contain RISK: tag
_lr_stderr=$(mktemp)
echo '{"hook_event_name":"UserPromptSubmit","prompt":"write a test for the auth hook"}' \
  | "$INTENT_SCRIPT" 2>"$_lr_stderr" || true
if grep -q 'RISK:' "$_lr_stderr"; then
  echo "  FAIL  low-risk prompt should not emit RISK tag"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: low-risk prompt should not emit RISK tag"
else
  echo "  PASS  low-risk prompt: no RISK tag (test writing)"
  PASS=$((PASS + 1))
fi
rm -f "$_lr_stderr"

# ── Risk tier: medium-risk prompts emit [RISK:medium] ───────────

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"fix the bug in auth middleware"}' \
  0 \
  "medium-risk prompt: bug fix emits RISK:medium" \
  "RISK:medium"

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"debug why the page is not working"}' \
  0 \
  "medium-risk prompt: debug emits RISK:medium" \
  "RISK:medium"

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"investigate the regression in login"}' \
  0 \
  "medium-risk prompt: regression emits RISK:medium" \
  "RISK:medium"

# ── Risk tier: high-risk prompts emit [RISK:high] ───────────────

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"create a PR for the auth changes"}' \
  0 \
  "high-risk prompt: create PR emits RISK:high" \
  "RISK:high"

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"push the branch and deploy"}' \
  0 \
  "high-risk prompt: push+deploy emits RISK:high" \
  "RISK:high"

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"run the migration on the database"}' \
  0 \
  "high-risk prompt: migration emits RISK:high" \
  "RISK:high"

# ── High overrides medium (prompt matches both) ─────────────────

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"fix the bug then create a PR"}' \
  0 \
  "compound prompt: high overrides medium" \
  "RISK:high"

# ── Existing directives still work alongside risk ───────────────

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"write a test for the settings store"}' \
  0 \
  "TDD directive still emitted for test prompts" \
  "[TDD]"

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"refactor the auth module into smaller files"}' \
  0 \
  "REFACTOR directive still emitted for refactor prompts" \
  "[REFACTOR]"

# ── Non-matching prompts: no directives at all ──────────────────

_empty_stderr=$(mktemp)
echo '{"hook_event_name":"UserPromptSubmit","prompt":"what does this function do"}' \
  | "$INTENT_SCRIPT" 2>"$_empty_stderr" || true
if [ -s "$_empty_stderr" ]; then
  echo "  FAIL  question prompt should emit nothing"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: question prompt should emit nothing"
else
  echo "  PASS  question prompt: no directives emitted"
  PASS=$((PASS + 1))
fi
rm -f "$_empty_stderr"

# ── Non-UserPromptSubmit event: exits cleanly ───────────────────

run_hook_eval "$INTENT_SCRIPT" \
  '{"hook_event_name":"PostToolUse","prompt":"fix the bug"}' \
  0 \
  "non-UserPromptSubmit event: exits 0 silently"
