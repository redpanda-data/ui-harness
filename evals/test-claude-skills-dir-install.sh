# Evals for Claude Code v2.1.157+ skills-directory plugin install.

README_INSTALL_BLOCK=$(awk '/^## Install/{flag=1} /^<details>/{flag=0} flag{print}' "$REPO_ROOT/README.md")

if printf '%s\n' "$README_INSTALL_BLOCK" | grep -qE 'git clone https://github.com/redpanda-data/ui-harness \$HOME/\.claude/skills/frontend-skills|git clone https://github.com/redpanda-data/ui-harness ~/\.claude/skills/frontend-skills'; then
  echo "  PASS  README primary Claude install uses skills-directory clone"
  PASS=$((PASS + 1))
else
  echo "  FAIL  README primary Claude install should use ~/.claude/skills/frontend-skills clone"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: README primary Claude install not simplified"
fi

if printf '%s\n' "$README_INSTALL_BLOCK" | grep -q '/plugin marketplace add\|/plugin install'; then
  echo "  FAIL  README primary Claude install still requires marketplace commands"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: README primary Claude install still mentions marketplace"
else
  echo "  PASS  README primary Claude install has no marketplace commands"
  PASS=$((PASS + 1))
fi

run_content_eval "$REPO_ROOT/README.md" 'Claude Code 2\.1\.157\+' \
  "README calls out Claude Code 2.1.157+ no-marketplace path"
run_content_eval "$REPO_ROOT/README.md" 'Still a plugin' \
  "README clarifies plugin manifest still needed for hooks and agents"
run_content_eval "$REPO_ROOT/README.md" 'Legacy: marketplace install' \
  "README keeps legacy marketplace fallback discoverable"
run_content_eval "$REPO_ROOT/README.md" 'claude plugin list' \
  "README verify step checks Claude sees skills-dir plugin"

tmp_home=$(mktemp -d)
mkdir -p "$tmp_home/.claude/skills"
ln -s "$REPO_ROOT" "$tmp_home/.claude/skills/frontend-skills"
verify_output=$(HOME="$tmp_home" bash "$REPO_ROOT/scripts/verify-install.sh" 2>&1 || true)
rm -rf "$tmp_home"

if printf '%s\n' "$verify_output" | grep -q -- '--- Install Mode: skills-dir-plugin ---'; then
  echo "  PASS  verify-install detects skills-directory plugin install"
  PASS=$((PASS + 1))
else
  echo "  FAIL  verify-install should detect skills-directory plugin install"
  echo "        output: $(printf '%s\n' "$verify_output" | head -5 | tr '\n' ' ')"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: verify-install misses skills-dir plugin"
fi
