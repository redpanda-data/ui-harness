# Evals for thermo-nuclear-code-quality-review skill.

SKILL_DIR="$REPO_ROOT/thermo-nuclear-code-quality-review"

run_file_eval "$SKILL_DIR/SKILL.md" "thermo-nuclear SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "thermo-nuclear REFERENCE.md exists"
run_content_eval "$SKILL_DIR/SKILL.md" "^name: thermo-nuclear-code-quality-review" "skill has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "description has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "very important PR|important PR|high-stakes PR" "skill targets important PRs"
run_content_eval "$SKILL_DIR/SKILL.md" "auth.*billing.*permissions.*migrations|billing.*permissions.*migrations" "skill names high-risk PR surfaces"
run_content_eval "$SKILL_DIR/SKILL.md" "cold review" "skill requires cold review posture"
run_content_eval "$SKILL_DIR/SKILL.md" "parallel subagents|parallel reviewers" "skill fans out parallel reviewers"
run_content_eval "$SKILL_DIR/SKILL.md" "/review" "skill composes /review"
run_content_eval "$SKILL_DIR/SKILL.md" "/visual-review" "skill composes /visual-review"
run_content_eval "$SKILL_DIR/SKILL.md" "/resilience-review" "skill composes /resilience-review"
run_content_eval "$SKILL_DIR/SKILL.md" "/steelman" "skill composes /steelman"
run_content_eval "$SKILL_DIR/SKILL.md" "/resolve-pr-feedback.*review only|review only.*/resolve-pr-feedback|Do not use /resolve-pr-feedback" "skill excludes resolve-pr-feedback action workflow"
run_content_eval "$SKILL_DIR/SKILL.md" "PR comments" "skill produces PR comment-ready findings"
run_content_eval "$SKILL_DIR/SKILL.md" "REFERENCE.md" "skill links reference"
if ! grep -q "disable-model-invocation" "$SKILL_DIR/SKILL.md" 2>/dev/null; then echo "  PASS  no Cursor-only disable-model-invocation"; PASS=$((PASS+1)); else echo "  FAIL  Cursor-only disable-model-invocation present"; FAIL=$((FAIL+1)); ERRORS="$ERRORS\n  FAIL: Cursor-only disable-model-invocation present"; fi

for path in "$SKILL_DIR/SKILL.md:100" "$SKILL_DIR/REFERENCE.md:140"; do
  file=${path%:*}; max=${path#*:}; lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ' || echo 999)
  if [ "$lines" -le "$max" ]; then echo "  PASS  ${file#$REPO_ROOT/} compact ($lines <= $max)"; PASS=$((PASS+1)); else echo "  FAIL  ${file#$REPO_ROOT/} too verbose ($lines > $max)"; FAIL=$((FAIL+1)); ERRORS="$ERRORS\n  FAIL: ${file#$REPO_ROOT/} too verbose"; fi
done

run_content_eval "$SKILL_DIR/REFERENCE.md" "structural simplification|code-judo|delete complexity" "reference emphasizes structural simplification"
run_content_eval "$SKILL_DIR/REFERENCE.md" "1,000 lines|1000 lines" "reference checks file-size sprawl"
run_content_eval "$SKILL_DIR/REFERENCE.md" "spaghetti|special-case" "reference checks spaghetti growth"
run_content_eval "$SKILL_DIR/REFERENCE.md" "React Compiler" "reference includes React Compiler axis"
run_content_eval "$SKILL_DIR/REFERENCE.md" "@/components/ui" "reference includes UI registry axis"
run_content_eval "$SKILL_DIR/REFERENCE.md" "<Button>" "reference includes Button rule"
run_content_eval "$SKILL_DIR/REFERENCE.md" "TanStack Router" "reference includes routing axis"
run_content_eval "$SKILL_DIR/REFERENCE.md" "connect-query" "reference includes data-fetching axis"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Zustand|zustand" "reference includes state axis"
run_content_eval "$SKILL_DIR/REFERENCE.md" "@/env" "reference includes env axis"
run_content_eval "$SKILL_DIR/REFERENCE.md" "generated files" "reference skips generated files"
run_content_eval "$SKILL_DIR/REFERENCE.md" "P0.*P1.*P2.*P3" "reference defines severity levels"
run_content_eval "$SKILL_DIR/REFERENCE.md" "findings-schema" "reference uses structured findings schema"
run_content_eval "$SKILL_DIR/REFERENCE.md" "checked.*artifacts|artifacts.*checked" "reference requires checked artifact evidence per reviewer"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Run many lenses.*comment few|comment few.*Run many lenses" "reference limits PR comment volume"
run_content_eval "$SKILL_DIR/REFERENCE.md" "blocker.*major.*minor.*nit.*follow-up" "reference defines PR comment priority labels"
run_content_eval "$SKILL_DIR/REFERENCE.md" "One-shot prompt.*What.*Why.*Suggested fix|What.*Why.*Suggested fix.*One-shot prompt" "reference requires one-shot fix prompt template"
run_content_eval "$SKILL_DIR/REFERENCE.md" ""priority".*blocker.*major.*minor.*nit.*follow-up for other PR" "reference schema includes priority labels"
run_content_eval "$SKILL_DIR/REFERENCE.md" "repo.*branch.*file.*verify|branch.*file.*verify" "reference defines one-shot prompt ingredients"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Inspired by Cursor Team Kit" "reference attributes inspiration without copying"

run_content_eval "$REPO_ROOT/.claude-plugin/plugin.json" "./thermo-nuclear-code-quality-review/" "Claude plugin registers skill"
run_content_eval "$REPO_ROOT/README.md" "/thermo-nuclear-code-quality-review" "README documents thermo-nuclear skill"
