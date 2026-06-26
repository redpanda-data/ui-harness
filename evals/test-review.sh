# Evals for /review skill PR comment workflow.

SKILL_DIR="$REPO_ROOT/review"
REF="$SKILL_DIR/REFERENCE.md"

run_file_eval "$SKILL_DIR/SKILL.md" "review SKILL.md exists"
run_file_eval "$REF" "review REFERENCE.md exists"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "review description uses trigger wording"
run_content_eval "$SKILL_DIR/SKILL.md" "REFERENCE.md" "review SKILL.md references one-level details"
run_content_eval "$REF" "Report schema" "review reference has detailed schema"
run_content_eval "$REF" "Example inline comment" "review reference has concrete example"
review_skill_lines=$(wc -l < "$SKILL_DIR/SKILL.md" | tr -d ' ')
if [ "$review_skill_lines" -lt 100 ]; then
  echo "  PASS  review SKILL.md under 100 lines"
  PASS=$((PASS + 1))
else
  echo "  FAIL  review SKILL.md under 100 lines (got $review_skill_lines)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: review SKILL.md under 100 lines"
fi
run_content_eval "$SKILL_DIR/SKILL.md" "post inline PR comments automatically" "review auto-posts PR comments when available"
run_content_eval "$SKILL_DIR/SKILL.md" "user does not need to ask" "review does not require explicit comment request"
run_content_eval "$SKILL_DIR/SKILL.md" "After all hats finish" "review comments after all review hats finish"
run_content_eval "$SKILL_DIR/SKILL.md" "Do not comment during individual hats" "review forbids per-hat real-time comments"
run_content_eval "$SKILL_DIR/SKILL.md" "Do not dump the whole review" "review avoids dumping full review as PR comment"
run_content_eval "$SKILL_DIR/SKILL.md" "P0 bug/blocker.*P1 major.*P2 minor.*P3 patch.*Future follow-up" "review defines priority label mapping"
run_content_eval "$SKILL_DIR/SKILL.md" "P0 for Blocker.*P1 for Major.*P2 for Minor.*P3 for Patch or Future" "review uses requested priority wording"
run_content_eval "$SKILL_DIR/SKILL.md" "Every confirmed bug is P0 or P1" "review escalates confirmed bugs"
run_content_eval "$SKILL_DIR/SKILL.md" "diagnosed and reproduced.*must be posted inline" "review posts reproduced bugs inline"
run_content_eval "$SKILL_DIR/SKILL.md" "open or targeted PR" "review comments against open or targeted PR"
run_content_eval "$SKILL_DIR/SKILL.md" "tightest changed file/range" "review places comments on the most specific PR location"
run_content_eval "$SKILL_DIR/SKILL.md" "Every posted/comment-ready item must include exactly one priority label" "review requires one priority per comment"
run_content_eval "$SKILL_DIR/SKILL.md" "keep P3 and Future items in the summary" "review keeps low-priority items out of inline comments by default"
run_content_eval "$SKILL_DIR/SKILL.md" "What's working" "review summary includes what's working"
run_content_eval "$SKILL_DIR/SKILL.md" "Needs attention" "review summary includes needs attention"
run_content_eval "$SKILL_DIR/SKILL.md" "Follow-ups" "review summary includes follow-ups"
run_content_eval "$SKILL_DIR/SKILL.md" "Comment template: What, Why, Suggested fix, One-shot prompt" "review defines concise PR comment template"
run_content_eval "$SKILL_DIR/SKILL.md" "comment-ready output" "review has fallback when PR comment tooling unavailable"
run_content_eval "$SKILL_DIR/SKILL.md" "Posted: <count> \\| Comment-ready fallback: <count> \\| Skipped as summary-only: <count>" "review reports posted and skipped comment counts"
