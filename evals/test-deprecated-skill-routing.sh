# Evals for deprecated local skills. Keep installed, discourage auto-use.

for skill in design-an-interface qa request-refactor-plan ubiquitous-language domain-model; do
  case "$skill" in
    design-an-interface) replacement="prototype" ;;
    qa) replacement="triage" ;;
    request-refactor-plan) replacement="improve-codebase-architecture" ;;
    ubiquitous-language) replacement="grill-with-docs" ;;
    domain-model) replacement="grill-with-docs" ;;
  esac
  run_file_eval "$REPO_ROOT/$skill/SKILL.md" "deprecated/legacy skill kept: $skill"
  run_content_eval "$REPO_ROOT/$skill/SKILL.md" "DEPRECATED|LEGACY" "$skill marked deprecated or legacy"
  run_content_eval "$REPO_ROOT/$skill/SKILL.md" "$replacement" "$skill points to replacement $replacement"
  run_content_eval "$REPO_ROOT/$skill/SKILL.md" "explicitly" "$skill requires explicit user request"
done

run_content_eval "$REPO_ROOT/development-lifecycle/SKILL.md" "/grill-with-docs" "lifecycle prefers grill-with-docs"
run_content_eval "$REPO_ROOT/development-lifecycle/SKILL.md" "/prototype" "lifecycle prefers prototype"
run_content_eval "$REPO_ROOT/triage/SKILL.md" "/grill-with-docs" "triage uses grill-with-docs for docs grill"
run_content_eval "$REPO_ROOT/commit-push/SKILL.md" "/prototype" "commit-push recommends prototype over legacy design fan-out"
run_content_eval "$REPO_ROOT/commit-push/SKILL.md" "/improve-codebase-architecture" "commit-push recommends architecture skill over refactor-plan"
run_content_eval "$REPO_ROOT/commit-push-pr/REFERENCE.md" "/prototype" "commit-push-pr recommends prototype over legacy design fan-out"
run_content_eval "$REPO_ROOT/commit-push-pr/REFERENCE.md" "/triage" "commit-push-pr recommends triage over qa"
