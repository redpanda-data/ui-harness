# Evals for autopilot enforcement: TDD hard block, lifecycle auto-remediation, intent injection

HOOKS_DIR="$REPO_ROOT/.claude/hooks"

# ── tdd-prompt-check.sh: once-per-session reminder ──────────────

run_file_eval "$HOOKS_DIR/tdd-prompt-check.sh" "tdd-prompt-check.sh exists"
run_executable_eval "$HOOKS_DIR/tdd-prompt-check.sh" "tdd-prompt-check.sh is executable"
run_content_eval "$HOOKS_DIR/tdd-prompt-check.sh" "hook_warn" "tdd-prompt-check uses hook_warn (advisory, not block)"
run_content_eval "$HOOKS_DIR/tdd-prompt-check.sh" "tdd-reminded" "tdd-prompt-check uses session marker (once per session)"
run_content_eval "$HOOKS_DIR/tdd-prompt-check.sh" "/tdd" "tdd-prompt-check prescribes /tdd skill"
run_content_eval "$HOOKS_DIR/tdd-prompt-check.sh" "per-feature|feature" "tdd-prompt-check references feature-level testing"

# ── lifecycle-stop.sh: test coverage gate (step 0) ─────────────

run_file_eval "$HOOKS_DIR/lifecycle-stop.sh" "lifecycle-stop.sh exists"
run_executable_eval "$HOOKS_DIR/lifecycle-stop.sh" "lifecycle-stop.sh is executable"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "Coverage gap analysis" "lifecycle-stop has coverage gap analysis (step 0)"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "coverage-summary.json" "lifecycle-stop parses vitest coverage JSON"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "threshold" "lifecycle-stop has coverage threshold"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "coverage analysis unavailable" "lifecycle-stop falls back when coverage not available"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "/tdd" "lifecycle-stop prescribes /tdd for coverage gaps"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "/simplify" "lifecycle-stop prescribes /simplify in remediation"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "/commit-push" "lifecycle-stop prescribes /commit-push for uncommitted changes"

# ── lifecycle-stop.sh: auto-remediation messages ────────────────

run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "Run:.*git push" "lifecycle-stop prescribes exact push command"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "Create one NOW" "lifecycle-stop prescribes PR creation"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "Monitor tool" "lifecycle-stop prescribes Monitor for CI"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "Do not stop until CI green" "lifecycle-stop mandates CI fix loop"
run_content_eval "$HOOKS_DIR/lifecycle-stop.sh" "Request review NOW" "lifecycle-stop prescribes review request"

# ── intent-detect.sh: lifecycle mandate injection ───────────────

run_file_eval "$HOOKS_DIR/intent-detect.sh" "intent-detect.sh exists"
run_executable_eval "$HOOKS_DIR/intent-detect.sh" "intent-detect.sh is executable"
run_content_eval "$HOOKS_DIR/intent-detect.sh" "LIFECYCLE.*MANDATORY" "intent-detect has lifecycle mandate directive"
run_content_eval "$HOOKS_DIR/intent-detect.sh" "/tdd.*failing test" "intent-detect lifecycle includes /tdd"
run_content_eval "$HOOKS_DIR/intent-detect.sh" "/simplify" "intent-detect lifecycle includes /simplify"
run_content_eval "$HOOKS_DIR/intent-detect.sh" "/commit-push" "intent-detect lifecycle includes /commit-push"
run_content_eval "$HOOKS_DIR/intent-detect.sh" "RISK:" "intent-detect has risk tier classification"

# ── intent-detect.sh: implementation intent triggers lifecycle ──

run_hook_eval "$HOOKS_DIR/intent-detect.sh" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"build a new feature for user profiles"}' \
  0 \
  "intent-detect injects lifecycle for 'build feature' prompt" \
  "LIFECYCLE"

run_hook_eval "$HOOKS_DIR/intent-detect.sh" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"implement dark mode toggle"}' \
  0 \
  "intent-detect injects lifecycle for 'implement' prompt" \
  "LIFECYCLE"

run_hook_eval "$HOOKS_DIR/intent-detect.sh" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"add a new component for notifications"}' \
  0 \
  "intent-detect injects lifecycle for 'add component' prompt" \
  "LIFECYCLE"

run_hook_eval "$HOOKS_DIR/intent-detect.sh" \
  '{"hook_event_name":"UserPromptSubmit","prompt":"what does this function do?"}' \
  0 \
  "intent-detect does NOT inject lifecycle for non-implementation prompt"

# Verify non-implementation prompt does NOT get LIFECYCLE directive
_eval_stderr=$(mktemp)
echo '{"hook_event_name":"UserPromptSubmit","prompt":"what does this function do?"}' | "$HOOKS_DIR/intent-detect.sh" 2>"$_eval_stderr" || true
if grep -q "LIFECYCLE" "$_eval_stderr"; then
  echo "  FAIL  non-implementation prompt should NOT get LIFECYCLE directive"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: non-implementation prompt should NOT get LIFECYCLE directive"
else
  echo "  PASS  non-implementation prompt correctly skips LIFECYCLE directive"
  PASS=$((PASS + 1))
fi
rm -f "$_eval_stderr"

# ── CLAUDE.md: imperative lifecycle language ────────────────────

run_content_eval "$REPO_ROOT/CLAUDE.md" "MANDATORY.*hooks enforce" "CLAUDE.md lifecycle section is marked MANDATORY"
run_content_eval "$REPO_ROOT/CLAUDE.md" "Hooks block skipped steps" "CLAUDE.md uses imperative enforcement language"
run_content_eval "$REPO_ROOT/CLAUDE.md" "/tdd.*every" "CLAUDE.md mandates /tdd for new files"
run_content_eval "$REPO_ROOT/CLAUDE.md" "/simplify" "CLAUDE.md mandates /simplify before commit"
run_content_eval "$REPO_ROOT/CLAUDE.md" "/commit-push" "CLAUDE.md mandates /commit-push in ship phase"
