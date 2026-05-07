# Evals for hook-audit retro extension (session flow analytics).

SKILL="$REPO_ROOT/hook-audit/SKILL.md"

run_file_eval "$SKILL" "hook-audit SKILL.md exists"
run_content_eval "$SKILL" "retro" "description mentions retro / team analytics"
run_content_eval "$SKILL" "Retro analytics" "skill has Retro Analytics section"

# Metrics covered in retro
run_content_eval "$SKILL" "Sessions .* PR lag" "retro covers session-to-PR lag"
run_content_eval "$SKILL" "CI first-try pass rate" "retro covers CI first-try pass rate"
run_content_eval "$SKILL" "Phases skipped" "retro covers phases skipped"
run_content_eval "$SKILL" "Review-round distribution" "retro covers review-round distribution"
run_content_eval "$SKILL" "Human-review resolution" "retro covers human-review latency"
run_content_eval "$SKILL" "Worktree sprawl" "retro covers worktree sprawl"

# Mode flags
run_content_eval "$SKILL" "\\-\\-hooks" "supports --hooks mode"
run_content_eval "$SKILL" "\\-\\-retro" "supports --retro mode"
run_content_eval "$SKILL" "\\-\\-all" "supports --all mode"
