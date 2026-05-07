# Evals for setup-sandcastle skill

SKILL_DIR="$REPO_ROOT/setup-sandcastle"

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-sandcastle" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "sandcastle" "SKILL.md mentions sandcastle"
run_content_eval "$SKILL_DIR/SKILL.md" "sandbox" "SKILL.md mentions sandboxes"
run_content_eval "$SKILL_DIR/SKILL.md" "Docker" "SKILL.md mentions Docker"
run_content_eval "$SKILL_DIR/REFERENCE.md" "main.ts" "REFERENCE has orchestration template"
run_content_eval "$SKILL_DIR/REFERENCE.md" "implement.md" "REFERENCE has implementation prompt"
run_content_eval "$SKILL_DIR/REFERENCE.md" "review.md" "REFERENCE has review prompt"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Dogfooding" "REFERENCE has dogfooding section"
run_content_eval "$SKILL_DIR/REFERENCE.md" "COMPLETE" "REFERENCE has completion signal"
run_content_eval "$SKILL_DIR/REFERENCE.md" "code-reviewer" "REFERENCE references code-reviewer agent"
run_content_eval "$SKILL_DIR/REFERENCE.md" "sandbox: docker()" "REFERENCE has required sandbox option"
run_content_eval "$SKILL_DIR/REFERENCE.md" "branchStrategy" "REFERENCE has branchStrategy config"
run_content_eval "$SKILL_DIR/REFERENCE.md" "@ai-hero/sandcastle/sandboxes/docker" "REFERENCE imports docker from correct subpath"

# Verify removed APIs are not referenced
if grep -qE "worktreeMode|WorktreeMode" "$SKILL_DIR/REFERENCE.md"; then
  echo "  FAIL  REFERENCE.md still references removed worktreeMode API"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: REFERENCE.md still references removed worktreeMode API"
else
  echo "  PASS  REFERENCE.md does not reference removed worktreeMode API"
  PASS=$((PASS + 1))
fi

desc=$(grep '^description:' "$SKILL_DIR/SKILL.md" | sed 's/^description: //' | tr -d '"')
desc_len=${#desc}
if [ $desc_len -le 250 ]; then
  echo "  PASS  description under 250 chars ($desc_len)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  description over 250 chars ($desc_len)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: description over 250 chars ($desc_len)"
fi

line_count=$(wc -l < "$SKILL_DIR/SKILL.md" | tr -d ' ')
if [ "$line_count" -le 100 ]; then
  echo "  PASS  SKILL.md under 100 lines ($line_count)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  SKILL.md over 100 lines ($line_count)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: SKILL.md over 100 lines ($line_count)"
fi
