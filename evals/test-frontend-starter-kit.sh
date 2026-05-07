# Evals for frontend-starter-kit meta-skill

SKILL_DIR="$REPO_ROOT/frontend-starter-kit"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: frontend-starter-kit" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "setup-toolchain" "references setup-toolchain"
run_content_eval "$SKILL_DIR/SKILL.md" "setup-biome" "references setup-biome"
run_content_eval "$SKILL_DIR/SKILL.md" "setup-quality-gate" "references setup-quality-gate"
run_content_eval "$SKILL_DIR/SKILL.md" "setup-agent-config" "references setup-agent-config"
run_content_eval "$SKILL_DIR/SKILL.md" "setup-react-compiler" "references setup-react-compiler"

# ── Matt Pocock community skills referenced ──────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "improve-codebase-architecture" "references improve-codebase-architecture skill"
run_content_eval "$SKILL_DIR/SKILL.md" "request-refactor-plan" "references request-refactor-plan skill"
run_content_eval "$SKILL_DIR/SKILL.md" "design-an-interface" "references design-an-interface skill"
run_content_eval "$SKILL_DIR/SKILL.md" "bunx skills@latest add" "uses bunx (not npx) to install community skills"

# ── All setup skill dependencies exist ───────────────────────────

for dep_skill in setup-toolchain setup-biome setup-quality-gate setup-agent-config setup-react-compiler; do
  run_file_eval "$REPO_ROOT/$dep_skill/SKILL.md" "dependency: $dep_skill exists"
done
