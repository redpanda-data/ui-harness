# Evals for setup-atlassian-workflow skill

SKILL_DIR="$REPO_ROOT/setup-atlassian-workflow"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-atlassian-workflow" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "acli" "SKILL.md mentions acli"
run_content_eval "$SKILL_DIR/SKILL.md" "JIRA_PROJECT" "SKILL.md mentions JIRA_PROJECT"
run_content_eval "$SKILL_DIR/SKILL.md" "ISSUE_TRACKER" "SKILL.md mentions ISSUE_TRACKER"
run_content_eval "$SKILL_DIR/SKILL.md" "opt-in|Opt-in" "SKILL.md indicates opt-in"

# ── REFERENCE.md content ───────────────────────────────────────

run_content_eval "$SKILL_DIR/REFERENCE.md" "workitem create" "REFERENCE has create work item pattern"
run_content_eval "$SKILL_DIR/REFERENCE.md" "workitem link" "REFERENCE has link pattern"
run_content_eval "$SKILL_DIR/REFERENCE.md" "ISSUE_TRACKER=both" "REFERENCE documents dual tracker mode"
run_content_eval "$SKILL_DIR/REFERENCE.md" "to-issues|PRD" "REFERENCE has PRD workflow"
run_content_eval "$SKILL_DIR/REFERENCE.md" "triage|Bug" "REFERENCE has bug triage workflow"
run_content_eval "$SKILL_DIR/REFERENCE.md" "command -v acli" "REFERENCE has detection pattern"

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
