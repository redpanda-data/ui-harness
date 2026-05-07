# Evals for setup-react-doctor skill

SCRIPT="$REPO_ROOT/setup-react-doctor/scripts/react-doctor-stop.sh"
SKILL_DIR="$REPO_ROOT/setup-react-doctor"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_executable_eval "$SCRIPT" "react-doctor-stop.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-react-doctor" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "react-doctor" "SKILL.md mentions react-doctor"
run_content_eval "$SKILL_DIR/SKILL.md" "biome-overlapping" "SKILL.md mentions biome-overlapping rules"
run_content_eval "$SKILL_DIR/SKILL.md" "react-doctor.config.json" "SKILL.md mentions config file"

# ── REFERENCE content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/REFERENCE.md" "--diff" "REFERENCE documents diff mode"
run_content_eval "$SKILL_DIR/REFERENCE.md" "--score" "REFERENCE documents score mode"
run_content_eval "$SCRIPT" "bun run doctor" "script uses package.json script"
run_content_eval "$SCRIPT" "hook_(block|stop_block|stop_finding)|decision.*block|exit 2" "script blocks on failure"

# ── Hook script content ─────────────────────────────────────────

run_content_eval "$SCRIPT" "bun run doctor" "hook uses package.json script (not bunx)"
run_content_eval "$SCRIPT" "git diff --name-only" "hook checks for changed files"
run_content_eval "$SCRIPT" "tsx|jsx" "hook filters React files"
run_content_eval "$SCRIPT" "scripts.*doctor" "hook skips when doctor script missing"
run_content_eval "$SCRIPT" "doctor-fail-count" "hook tracks consecutive doctor failures"
run_content_eval "$SCRIPT" "decision.*allow.*attempts" "hook downgrades to allow after repeated failures"
run_content_eval "$SCRIPT" "hook_session_changed_files" "hook uses session-scoped file detection"

# ── Stop hook behavioral test ───────────────────────────────────

# react-doctor-stop.sh should exit 0 when no React files changed
_rd_tmpdir=$(mktemp -d /tmp/react-doctor-eval-XXXXXX)
cd "$_rd_tmpdir"
git init -q && git commit --allow-empty -m "init" -q
actual_exit=0
"$SCRIPT" > /dev/null 2>&1 || actual_exit=$?
cd "$REPO_ROOT"
rm -rf "$_rd_tmpdir"

if [ "$actual_exit" -eq 0 ]; then
  echo "  PASS  react-doctor-stop exits 0 on clean repo (no changed React files)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  react-doctor-stop exits $actual_exit on clean repo (expected 0)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: react-doctor-stop exits $actual_exit on clean repo"
fi
