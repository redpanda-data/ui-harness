# Evals for setup-registry-workflow skill

SCRIPT="$REPO_ROOT/setup-registry-workflow/scripts/registry-check.sh"
SKILL_DIR="$REPO_ROOT/setup-registry-workflow"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_executable_eval "$SCRIPT" "registry-check.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-registry-workflow" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "registry.json" "SKILL.md mentions registry.json"
run_content_eval "$SKILL_DIR/SKILL.md" "redpanda-ui" "SKILL.md mentions redpanda-ui"
run_content_eval "$SKILL_DIR/SKILL.md" "changelog" "SKILL.md mentions changelog"

# ── Hook script content ─────────────────────────────────────────

run_content_eval "$SCRIPT" "redpanda-ui/" "hook checks for redpanda-ui changes"
run_content_eval "$SCRIPT" "registry.json" "hook checks for registry.json update"
run_content_eval "$SCRIPT" "hook_(block|stop_block|stop_finding)|decision.*block|exit 2|stop-findings" "hook blocks when registry not rebuilt"
run_content_eval "$SCRIPT" "CHANGELOG|changeset" "hook reminds about changelog or changeset"

# ── hook-lib.sh: consumer repo upstream warning ──────────────────

HOOKLIB="$REPO_ROOT/shared/hook-lib.sh"
run_content_eval "$HOOKLIB" "components.json.*cli.json" "hook-lib detects consumer repos"
run_content_eval "$HOOKLIB" "UI registry" "hook-lib warns about upstream PR for consumer edits"
run_content_eval "$HOOKLIB" "registry.json" "hook-lib detects registry repo for rebuild reminder"
run_content_eval "$SCRIPT" "hook_session_changed_files" "registry-check uses session-scoped file detection"

# ── Stop hook behavioral test ───────────────────────────────────

# registry-check.sh should exit 0 when no files changed
_reg_tmpdir=$(mktemp -d /tmp/registry-eval-XXXXXX)
cd "$_reg_tmpdir"
git init -q && git commit --allow-empty -m "init" -q
actual_exit=0
"$SCRIPT" > /dev/null 2>&1 || actual_exit=$?
cd "$REPO_ROOT"
rm -rf "$_reg_tmpdir"

if [ "$actual_exit" -eq 0 ]; then
  echo "  PASS  registry-check exits 0 on clean repo (no changes)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  registry-check exits $actual_exit on clean repo (expected 0)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: registry-check exits $actual_exit on clean repo"
fi
