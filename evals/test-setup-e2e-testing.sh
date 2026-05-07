# Evals for setup-e2e-testing skill

SKILL_DIR="$REPO_ROOT/setup-e2e-testing"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/SETUP.md" "SETUP.md exists"

# ── SKILL.md content (auto-loaded, edit-time guidance) ──────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-e2e-testing" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "Test IDs|getByTestId" "SKILL.md has test ID conventions"
run_content_eval "$SKILL_DIR/SKILL.md" "getByRole" "SKILL.md has selector priority"
run_content_eval "$SKILL_DIR/SKILL.md" "agent-browser|Playwright" "SKILL.md mentions test tools"

# ── SETUP.md content (one-time setup, not auto-loaded) ──────────

run_content_eval "$SKILL_DIR/SETUP.md" "playwright/test" "SETUP has Playwright install"
run_content_eval "$SKILL_DIR/SETUP.md" "GenericContainer" "SETUP has Testcontainers setup"
run_content_eval "$SKILL_DIR/SETUP.md" "AxeBuilder" "SETUP has axe-core fixture"

# ── Description length ──────────────────────────────────────────

desc=$(grep '^description:' "$SKILL_DIR/SKILL.md" | sed 's/^description: //')
desc_len=${#desc}
if [ $desc_len -le 250 ]; then
  echo "  PASS  description under 250 chars ($desc_len)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  description over 250 chars ($desc_len)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: description over 250 chars ($desc_len)"
fi

# ── Line count ──────────────────────────────────────────────────

line_count=$(wc -l < "$SKILL_DIR/SKILL.md" | tr -d ' ')
if [ "$line_count" -le 100 ]; then
  echo "  PASS  SKILL.md under 100 lines ($line_count)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  SKILL.md over 100 lines ($line_count)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: SKILL.md over 100 lines ($line_count)"
fi
