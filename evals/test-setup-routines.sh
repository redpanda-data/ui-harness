# Evals for setup-routines skill

SKILL_DIR="$REPO_ROOT/setup-routines"
ROUTINES_DIR="$SKILL_DIR/routines"

# Core files exist
run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"

# SKILL.md structure
run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-routines" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "claude.ai/code/routines" "SKILL.md links to routines UI"
run_content_eval "$SKILL_DIR/SKILL.md" "Enforcement model" "SKILL.md explains enforcement model"
run_content_eval "$SKILL_DIR/SKILL.md" "Sandcastle" "SKILL.md compares with Sandcastle"

# All 5 routine templates exist
run_file_eval "$ROUTINES_DIR/pr-review.md" "pr-review template exists"
run_file_eval "$ROUTINES_DIR/pr-feedback-resolve.md" "pr-feedback-resolve template exists"
run_file_eval "$ROUTINES_DIR/issue-triage.md" "issue-triage template exists"
run_file_eval "$ROUTINES_DIR/weekly-health.md" "weekly-health template exists"
run_file_eval "$ROUTINES_DIR/docs-drift.md" "docs-drift template exists"

# Noise controls: every template must have noise avoidance section
for template in pr-review pr-feedback-resolve issue-triage weekly-health docs-drift; do
  run_content_eval "$ROUTINES_DIR/$template.md" "avoid noise" "$template has noise avoidance section"
done

# Stack-agnostic: templates must NOT hardcode frontend-specific patterns
for template in pr-review pr-feedback-resolve issue-triage weekly-health docs-drift; do
  if grep -qE '@redpanda-data/ui|lucide-react|React Compiler handles' "$ROUTINES_DIR/$template.md"; then
    echo "  FAIL  $template contains hardcoded frontend patterns"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: $template contains hardcoded frontend patterns"
  else
    echo "  PASS  $template is stack-agnostic"
    PASS=$((PASS + 1))
  fi
done

# Templates reference CLAUDE.md as source of truth (not inline rules)
run_content_eval "$ROUTINES_DIR/pr-review.md" "CLAUDE.md" "pr-review defers to CLAUDE.md"

# Security: untrusted input handling
run_content_eval "$ROUTINES_DIR/pr-feedback-resolve.md" "untrusted" "pr-feedback-resolve marks comments as untrusted"
run_content_eval "$ROUTINES_DIR/pr-review.md" "untrusted" "pr-review marks comments as untrusted"

# Read-only enforcement on observation-only routines
run_content_eval "$ROUTINES_DIR/issue-triage.md" "Read-only" "issue-triage is read-only"
run_content_eval "$ROUTINES_DIR/weekly-health.md" "Read-only|Never edit code" "weekly-health is read-only"

# PR feedback has GraphQL mutations for thread resolution
run_content_eval "$ROUTINES_DIR/pr-feedback-resolve.md" "resolveReviewThread" "pr-feedback-resolve can resolve threads"
run_content_eval "$ROUTINES_DIR/pr-feedback-resolve.md" "addPullRequestReviewComment" "pr-feedback-resolve can reply to threads"

# Weekly health compares with previous (delta-based)
run_content_eval "$ROUTINES_DIR/weekly-health.md" "previous report|last report|Compare|regressions" "weekly-health is delta-based"

# Docs drift handles both simple and complex drift
run_content_eval "$ROUTINES_DIR/docs-drift.md" "gh pr create" "docs-drift creates PRs for simple fixes"
run_content_eval "$ROUTINES_DIR/docs-drift.md" "gh issue create" "docs-drift creates issues for complex drift"

# REFERENCE.md content
run_content_eval "$SKILL_DIR/REFERENCE.md" "API trigger" "REFERENCE has API trigger setup"
run_content_eval "$SKILL_DIR/REFERENCE.md" "GitHub trigger" "REFERENCE has GitHub trigger config"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Noise reduction" "REFERENCE has noise reduction checklist"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Troubleshooting" "REFERENCE has troubleshooting section"
run_content_eval "$SKILL_DIR/REFERENCE.md" "anthropic-beta" "REFERENCE includes API beta header"

# Plugin registration
run_content_eval "$REPO_ROOT/.claude-plugin/plugin.json" "setup-routines" "plugin.json includes setup-routines"
run_content_eval "$REPO_ROOT/.claude-plugin/plugin.json" "routines" "plugin.json has routines keyword"

# SKILL.md size constraints
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
if [ "$line_count" -le 120 ]; then
  echo "  PASS  SKILL.md under 120 lines ($line_count)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  SKILL.md over 120 lines ($line_count)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: SKILL.md over 120 lines ($line_count)"
fi
