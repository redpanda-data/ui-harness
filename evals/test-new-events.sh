# Evals for new hook events added in 2.2.4:
# SessionEnd, PreCompact, PostToolUseFailure, FileChanged (5 matchers), WorktreeCreate.

HOOKS_DIR="$REPO_ROOT/.claude/hooks"

# ── Scripts exist and are executable ────────────────────────────
for script in session-end.sh pre-compact.sh post-tool-failure.sh \
              file-changed-deps.sh file-changed-schema.sh \
              file-changed-config.sh file-changed-env.sh file-changed-manifest.sh \
              worktree-create.sh; do
  if [ -x "$HOOKS_DIR/$script" ]; then
    echo "  PASS  $script exists and executable"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $script missing or not executable"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $script"
  fi
done

# ── Manifest wires all new events ───────────────────────────────
for event in SessionEnd PreCompact PostToolUseFailure FileChanged WorktreeCreate; do
  if jq -e ".hooks.$event" "$REPO_ROOT/skill-manifest.json" >/dev/null 2>&1; then
    echo "  PASS  manifest wires $event"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  manifest missing $event"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: manifest missing $event"
  fi
done

# ── FileChanged has 5 matchers ──────────────────────────────────
_matchers=$(jq '.hooks.FileChanged | keys | length' "$REPO_ROOT/skill-manifest.json" 2>/dev/null)
if [ "$_matchers" = "5" ]; then
  echo "  PASS  FileChanged has 5 matchers (deps/schema/config/env/manifest)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  FileChanged matcher count wrong: $_matchers (expected 5)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: FileChanged matcher count"
fi

# ── metrics-summary-stop no longer wired in Stop (moved to SessionEnd) ─
if jq -e '.hooks.Stop[""] | index("metrics-summary-stop.sh")' "$REPO_ROOT/skill-manifest.json" >/dev/null 2>&1; then
  echo "  FAIL  metrics-summary-stop.sh still wired in Stop — should be in SessionEnd"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: metrics-summary-stop in Stop"
else
  echo "  PASS  metrics-summary-stop.sh removed from Stop (replaced by SessionEnd)"
  PASS=$((PASS + 1))
fi

# ── PreCompact injects additionalContext (paired with PostCompact) ─
if grep -q 'hookEventName.*PreCompact' "$HOOKS_DIR/pre-compact.sh"; then
  echo "  PASS  pre-compact.sh emits additionalContext for PreCompact"
  PASS=$((PASS + 1))
else
  echo "  FAIL  pre-compact.sh missing additionalContext emission"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: pre-compact emit"
fi

# ── file-changed-manifest auto-regens configs (drift prevention) ───
if grep -q 'generate-hook-configs.sh' "$HOOKS_DIR/file-changed-manifest.sh"; then
  echo "  PASS  file-changed-manifest.sh invokes codegen (drift prevention)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  file-changed-manifest.sh not wired to regen"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: manifest file watcher not auto-regen"
fi

# ── Syntax-check new hooks ──────────────────────────────────────
_bad=0
for script in session-end.sh pre-compact.sh post-tool-failure.sh \
              file-changed-deps.sh file-changed-schema.sh \
              file-changed-config.sh file-changed-env.sh file-changed-manifest.sh \
              worktree-create.sh; do
  if ! bash -n "$HOOKS_DIR/$script" 2>/dev/null; then
    _bad=$((_bad + 1))
  fi
done
if [ "$_bad" = "0" ]; then
  echo "  PASS  all 9 new hooks pass bash -n syntax check"
  PASS=$((PASS + 1))
else
  echo "  FAIL  $_bad of 9 new hooks have syntax errors"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: syntax in new hooks"
fi
