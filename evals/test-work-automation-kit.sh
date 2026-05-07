# Evals for work-automation-kit meta-skill

SKILL_DIR="$REPO_ROOT/work-automation-kit"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: work-automation-kit" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "to-prd" "references to-prd (mattpocock)"
run_content_eval "$SKILL_DIR/SKILL.md" "brainstorming" "references brainstorming (owned)"
run_content_eval "$SKILL_DIR/SKILL.md" "to-issues" "references to-issues (mattpocock)"
run_content_eval "$SKILL_DIR/SKILL.md" "bunx skills@latest add" "uses bunx (not npx) to install"
