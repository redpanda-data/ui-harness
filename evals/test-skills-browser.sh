# Evals for scripts/skills-browser.sh (Vercel agent-browser wrapper).

SCRIPT="$REPO_ROOT/scripts/skills-browser.sh"

run_file_eval "$SCRIPT" "skills-browser.sh exists"
run_executable_eval "$SCRIPT" "skills-browser.sh executable"
run_content_eval "$SCRIPT" "agent-browser" "wraps agent-browser CLI"
run_content_eval "$SCRIPT" "brew install" "prints brew install hint"
run_content_eval "$SCRIPT" "cargo install" "prints cargo install hint"
run_content_eval "$SCRIPT" "browser-daemon.md" "references RFC in commentary"

# Exits 127 if agent-browser missing (script does not pretend to work).
# Force a clean PATH so the test runs the same way whether or not the
# dev has agent-browser installed locally.
_ec=0
PATH=/usr/bin:/bin "$SCRIPT" navigate https://example.com >/dev/null 2>&1 || _ec=$?
if [ "$_ec" -eq 127 ]; then
  echo "  PASS  exits 127 when agent-browser missing"
  PASS=$((PASS + 1))
else
  echo "  FAIL  exit was $_ec, expected 127"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: skills-browser 127 exit"
fi

# qa and go reference the wrapper
run_content_eval "$REPO_ROOT/qa/SKILL.md" "skills-browser" \
  "/qa uses skills-browser for optional browser capture"
run_content_eval "$REPO_ROOT/go/SKILL.md" "skills-browser" \
  "/go phase 4 uses skills-browser for smoke test"

# qa clarifies Playwright test code boundary
run_content_eval "$REPO_ROOT/qa/SKILL.md" "for test code" \
  "/qa clarifies skills-browser vs test code boundary"
