# Evals for mattpocock/skills vendoring completeness.

VENDORED=(
  caveman
  edit-article
  git-guardrails-claude-code
  grill-with-docs
  migrate-to-shoehorn
  obsidian-vault
  prototype
  review
  scaffold-exercises
  setup-pre-commit
  to-issues
  to-prd
  writing-beats
  writing-fragments
  writing-shape
)

for skill in "${VENDORED[@]}"; do
  run_file_eval "$REPO_ROOT/$skill/SKILL.md" "vendored Matt skill exists: $skill"
  run_content_eval "$REPO_ROOT/$skill/SKILL.md" "^name: $skill$" "vendored Matt skill has matching name: $skill"
  run_content_eval "$REPO_ROOT/.claude-plugin/plugin.json" "\./$skill/" "Claude plugin registers vendored Matt skill: $skill"
done

run_content_eval "$REPO_ROOT/caveman/SKILL.md" "Ultra-compressed|token usage|terse" "caveman skill keeps compression purpose"
run_content_eval "$REPO_ROOT/prototype/SKILL.md" "prototype|throwaway|test" "prototype skill keeps prototype intent"
run_content_eval "$REPO_ROOT/to-prd/SKILL.md" "PRD|requirements" "to-prd skill keeps PRD intent"
run_content_eval "$REPO_ROOT/to-issues/SKILL.md" "issue|GitHub" "to-issues skill keeps issue intent"
run_content_eval "$REPO_ROOT/grill-with-docs/SKILL.md" "CONTEXT\.md|ADR" "grill-with-docs keeps docs sync intent"
