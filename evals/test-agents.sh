# Evals for agents definitions and findings schema

AGENTS_DIR="$REPO_ROOT/agents"

# ── Schema exists ────────────────────────────────────────────────
run_file_eval "$AGENTS_DIR/findings-schema.md" "findings-schema.md exists"

# ── Schema has required field definitions ────────────────────────
run_content_eval "$AGENTS_DIR/findings-schema.md" "severity" "findings-schema defines severity"
run_content_eval "$AGENTS_DIR/findings-schema.md" "autofix_class" "findings-schema defines autofix_class"
run_content_eval "$AGENTS_DIR/findings-schema.md" "pre_existing" "findings-schema defines pre_existing"
run_content_eval "$AGENTS_DIR/findings-schema.md" "confidence" "findings-schema defines confidence"
run_content_eval "$AGENTS_DIR/findings-schema.md" "P0.*P1.*P2.*P3" "findings-schema has all severity levels"
run_content_eval "$AGENTS_DIR/findings-schema.md" "safe_auto.*gated_auto.*manual.*advisory" "findings-schema has all autofix classes"

# ── All agent definitions exist ──────────────────────────────────
for agent in self-reviewer adversarial-reviewer code-reviewer verifier; do
  run_file_eval "$AGENTS_DIR/${agent}.md" "${agent}.md exists"
done

# ── All agents have required frontmatter ─────────────────────────
for agent_file in "$AGENTS_DIR"/self-reviewer.md "$AGENTS_DIR"/adversarial-reviewer.md "$AGENTS_DIR"/code-reviewer.md "$AGENTS_DIR"/verifier.md; do
  agent_name=$(basename "$agent_file" .md)
  run_content_eval "$agent_file" "^name: ${agent_name}" "${agent_name} has correct name in frontmatter"
  run_content_eval "$agent_file" "^description:" "${agent_name} has description"
  run_content_eval "$agent_file" "^allowed-tools:" "${agent_name} has allowed-tools"
done

# ── Reviewer agents reference findings-schema ────────────────────
for reviewer in self-reviewer adversarial-reviewer code-reviewer; do
  run_content_eval "$AGENTS_DIR/${reviewer}.md" "findings-schema" "${reviewer} references findings-schema"
done

# ── self-reviewer has test/lint/type-check tools ─────────────────
run_content_eval "$AGENTS_DIR/self-reviewer.md" "vitest" "self-reviewer has test runner tool"
run_content_eval "$AGENTS_DIR/self-reviewer.md" "bun run lint" "self-reviewer has lint tool"
run_content_eval "$AGENTS_DIR/self-reviewer.md" "bun run type:check" "self-reviewer has type-check tool"

# ── adversarial-reviewer is read-only (no test/lint tools) ───────
if grep -qE "Bash\(vitest|Bash\(bun run lint|Bash\(bun run type" "$AGENTS_DIR/adversarial-reviewer.md"; then
  echo "  FAIL  adversarial-reviewer should not have test/lint tools (read-only agent)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: adversarial-reviewer should not have test/lint tools"
else
  echo "  PASS  adversarial-reviewer is read-only (no test/lint tools)"
  PASS=$((PASS + 1))
fi

# ── Reviewer agent models (adversarial=opus for depth; others=sonnet) ──
for reviewer in self-reviewer code-reviewer; do
  run_content_eval "$AGENTS_DIR/${reviewer}.md" "^model: sonnet" "${reviewer} uses sonnet model"
done
run_content_eval "$AGENTS_DIR/adversarial-reviewer.md" "^model: opus" "adversarial-reviewer uses opus model"

# ── verifier does NOT reference findings-schema (not a reviewer) ─
if grep -q "findings-schema" "$AGENTS_DIR/verifier.md"; then
  echo "  FAIL  verifier should not reference findings-schema (not a reviewer)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: verifier should not reference findings-schema"
else
  echo "  PASS  verifier does not reference findings-schema (correct)"
  PASS=$((PASS + 1))
fi
