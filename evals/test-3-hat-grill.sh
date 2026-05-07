# Evals for 3-hat grill fan-out (Phase 2b of /grill-me).

AGENT_DIR="$REPO_ROOT/agents"

for hat in plan-product-hat plan-engineering-hat plan-design-hat; do
  run_file_eval "$AGENT_DIR/$hat.md" "$hat.md exists"
  run_content_eval "$AGENT_DIR/$hat.md" "^name: $hat" "$hat has name frontmatter"
  run_content_eval "$AGENT_DIR/$hat.md" "^model:" "$hat declares model"
  run_content_eval "$AGENT_DIR/$hat.md" "^allowed-tools:" "$hat declares allowed-tools"
  run_content_eval "$AGENT_DIR/$hat.md" "phase 2b" "$hat mentions phase 2b"
  run_content_eval "$AGENT_DIR/$hat.md" "findings-schema" "$hat references findings-schema"
  run_content_eval "$AGENT_DIR/$hat.md" "must_answer" "$hat emits must_answer list"
  run_content_eval "$AGENT_DIR/$hat.md" "Non-Goals" "$hat declares non-goals"

  # Registered in plugin.json
  run_content_eval "$REPO_ROOT/.claude-plugin/plugin.json" "\"./agents/$hat.md\"" \
    "plugin.json registers $hat"
done

# Each hat is distinct — no overlap in responsibilities
run_content_eval "$AGENT_DIR/plan-product-hat.md" "persona" "product-hat covers persona"
run_content_eval "$AGENT_DIR/plan-product-hat.md" "[Ss]uccess metric" "product-hat covers success metric"
run_content_eval "$AGENT_DIR/plan-product-hat.md" "[Rr]eversibility" "product-hat covers reversibility"

run_content_eval "$AGENT_DIR/plan-engineering-hat.md" "[Aa]rchitecture" "engineering-hat covers architecture"
run_content_eval "$AGENT_DIR/plan-engineering-hat.md" "[Rr]ollback" "engineering-hat covers rollback"
run_content_eval "$AGENT_DIR/plan-engineering-hat.md" "test_first" "engineering-hat surfaces test_first"

run_content_eval "$AGENT_DIR/plan-design-hat.md" "[Aa]ccessibility" "design-hat covers a11y"
run_content_eval "$AGENT_DIR/plan-design-hat.md" "[Ee]mpty" "design-hat covers empty state"
run_content_eval "$AGENT_DIR/plan-design-hat.md" "[Kk]eyboard" "design-hat covers kbd path"

# grill-me wired to fan-out
run_content_eval "$REPO_ROOT/grill-me/SKILL.md" "Three-Hat Fan-Out" \
  "/grill-me has three-hat fan-out section"
run_content_eval "$REPO_ROOT/grill-me/SKILL.md" "plan-product-hat" \
  "/grill-me invokes plan-product-hat"
run_content_eval "$REPO_ROOT/grill-me/SKILL.md" "plan-engineering-hat" \
  "/grill-me invokes plan-engineering-hat"
run_content_eval "$REPO_ROOT/grill-me/SKILL.md" "plan-design-hat" \
  "/grill-me invokes plan-design-hat"
run_content_eval "$REPO_ROOT/grill-me/SKILL.md" "in parallel" \
  "/grill-me spawns hats in parallel"
run_content_eval "$REPO_ROOT/grill-me/SKILL.md" "BLOCKED" \
  "/grill-me honors BLOCKED status"
run_content_eval "$REPO_ROOT/grill-me/SKILL.md" "ETHOS: Grill Before Build" \
  "/grill-me cross-references ETHOS principle"
