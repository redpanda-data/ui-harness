# Evals for setup-biome skill
# Tests file structure, SKILL.md, REFERENCE.md, and hook script content

SCRIPT="$REPO_ROOT/setup-biome/scripts/biome-autofix.sh"
SKILL_DIR="$REPO_ROOT/setup-biome"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_executable_eval "$SCRIPT" "biome-autofix.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-biome" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "^description:" "SKILL.md has description"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md description has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "ultracite" "SKILL.md mentions ultracite"
run_content_eval "$SKILL_DIR/SKILL.md" "Stop" "SKILL.md mentions Stop hook"
run_content_eval "$SKILL_DIR/SKILL.md" "noUnusedImports" "SKILL.md mentions import loop prevention"

# ── REFERENCE.md content ────────────────────────────────────────

run_content_eval "$SKILL_DIR/REFERENCE.md" "ultracite/biome/core" "REFERENCE has core extends"
run_content_eval "$SKILL_DIR/REFERENCE.md" "ultracite/biome/react" "REFERENCE has react extends"
run_content_eval "$SKILL_DIR/REFERENCE.md" "noConsole" "REFERENCE has noConsole override"
run_content_eval "$SKILL_DIR/REFERENCE.md" "maxAllowedComplexity.*15" "REFERENCE has complexity threshold 15"
run_content_eval "$SKILL_DIR/REFERENCE.md" "noDeprecatedImports" "REFERENCE has noDeprecatedImports"
run_content_eval "$SKILL_DIR/REFERENCE.md" "moment" "REFERENCE restricts moment"
run_content_eval "$SKILL_DIR/REFERENCE.md" "lodash" "REFERENCE restricts lodash"
run_content_eval "$SKILL_DIR/REFERENCE.md" "classnames" "REFERENCE restricts classnames"
run_content_eval "$SKILL_DIR/REFERENCE.md" "mobx" "REFERENCE restricts mobx"
run_content_eval "$SKILL_DIR/REFERENCE.md" "yup" "REFERENCE restricts yup"
run_content_eval "$SKILL_DIR/REFERENCE.md" "useExhaustiveSwitchCases" "REFERENCE has exhaustive switch cases"
run_content_eval "$SKILL_DIR/REFERENCE.md" "noClassComponent" "REFERENCE documents noClassComponent removal"
run_content_eval "$SKILL_DIR/REFERENCE.md" "assist" "REFERENCE uses assist for organizeImports (Biome v2)"
run_content_eval "$SKILL_DIR/REFERENCE.md" "project" "REFERENCE uses project group for noDeprecatedImports"
run_content_eval "$SKILL_DIR/REFERENCE.md" "noReactForwardRef" "REFERENCE has noReactForwardRef in suspicious"
run_content_eval "$SKILL_DIR/REFERENCE.md" "noExplicitAny.*error" "REFERENCE re-enables noExplicitAny in tests"
run_content_eval "$SKILL_DIR/REFERENCE.md" "useIgnoreFile" "REFERENCE has VCS ignore file"
run_content_eval "$SKILL_DIR/REFERENCE.md" "noRestrictedImports" "REFERENCE has restricted imports rule"
run_content_eval "$SKILL_DIR/REFERENCE.md" "useFilenamingConvention" "REFERENCE has filename convention rule"
run_content_eval "$SKILL_DIR/REFERENCE.md" "kebab-case" "REFERENCE enforces kebab-case filenames"
run_content_eval "$SKILL_DIR/REFERENCE.md" "strictCase" "REFERENCE uses strictCase for filenames"

# ── Hook script content checks ──────────────────────────────────

run_content_eval "$SCRIPT" "noUnusedImports" "hook skips noUnusedImports"
run_content_eval "$SCRIPT" "bun run lint:fix:file" "hook runs bun run lint:fix:file (not lint:fix which hardcodes .)"
run_content_eval "$SCRIPT" "bun run lint:file" "hook runs bun run lint:file for error checking"
run_content_eval "$SCRIPT" "git diff --name-only" "hook checks for changed JS/TS files"
run_content_eval "$SCRIPT" "hook_(block|stop_block|stop_finding)|decision.*block|exit 2|stop-findings" "hook blocks on unfixable errors"
run_content_eval "$SCRIPT" "UI_LIB_DIRS" "hook supports UI_LIB_DIRS env var"
run_content_eval "$SCRIPT" "components/ui" "hook auto-detects components/ui"
run_content_eval "$SCRIPT" "scripts.*lint:file" "hook skips when lint:file script missing"
run_content_eval "$SCRIPT" "hook_(block|stop_block|stop_finding)|decision.*block|exit 2|stop-findings" "hook blocks on unfixable errors"
run_content_eval "$SCRIPT" "hook_session_changed_files" "hook uses session-scoped file detection"

# ── Stop hook behavioral tests ──────────────────────────────────

# biome-autofix.sh should exit 0 when no JS/TS files changed (clean repo)
# We test this by running in a tmpdir with no git changes
_biome_tmpdir=$(mktemp -d /tmp/biome-eval-XXXXXX)
cd "$_biome_tmpdir"
git init -q && git commit --allow-empty -m "init" -q
actual_exit=0
"$SCRIPT" > /dev/null 2>&1 || actual_exit=$?
cd "$REPO_ROOT"
rm -rf "$_biome_tmpdir"

if [ "$actual_exit" -eq 0 ]; then
  echo "  PASS  biome-autofix exits 0 on clean repo (no changed files)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  biome-autofix exits $actual_exit on clean repo (expected 0)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: biome-autofix exits $actual_exit on clean repo"
fi

# ── SKILL.md has file-targeted scripts ─────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "lint:file" "SKILL.md documents lint:file script"
run_content_eval "$SKILL_DIR/SKILL.md" "lint:fix:file" "SKILL.md documents lint:fix:file script"

# ── New rules from PR audit (2025-2026) ─────────────────────────

run_content_eval "$SKILL_DIR/REFERENCE.md" "@redpanda-data/ui" "REFERENCE restricts @redpanda-data/ui imports"
run_content_eval "$SKILL_DIR/REFERENCE.md" "lucide-react" "REFERENCE restricts lucide-react imports"
run_content_eval "$SKILL_DIR/REFERENCE.md" "noRestrictedElements" "REFERENCE has noRestrictedElements for raw HTML"
run_content_eval "$SKILL_DIR/REFERENCE.md" "useConsistentTestIt" "REFERENCE has useConsistentTestIt (nursery)"
run_content_eval "$SKILL_DIR/REFERENCE.md" "noPlaywrightWaitForTimeout" "REFERENCE has noPlaywrightWaitForTimeout"
