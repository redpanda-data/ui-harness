# Evals for /swarm parallel-executor skill

SKILL_DIR="$REPO_ROOT/swarm"

run_file_eval "$SKILL_DIR/SKILL.md" "swarm SKILL.md exists"
run_content_eval "$SKILL_DIR/SKILL.md" "^name: swarm" "swarm has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "parallel executor" "swarm defines parallel executor role"
run_content_eval "$SKILL_DIR/SKILL.md" "not a planner|not planner" "swarm does not replace planning"
run_content_eval "$SKILL_DIR/SKILL.md" "swarm manifest" "swarm shows manifest before launch"
run_content_eval "$SKILL_DIR/SKILL.md" "same branch/worktree/PR" "swarm defaults to shared workspace"
run_content_eval "$SKILL_DIR/SKILL.md" "worktree" "swarm supports per-agent worktrees"
run_content_eval "$SKILL_DIR/SKILL.md" "Task packet" "swarm defines task packet"
run_content_eval "$SKILL_DIR/SKILL.md" "agent_name" "swarm names subagents consistently"
run_content_eval "$SKILL_DIR/SKILL.md" "output schema" "swarm requires output schema"
run_content_eval "$SKILL_DIR/SKILL.md" "Codex.*Claude|Claude.*Codex" "swarm is Codex and Claude compatible"
run_content_eval "$SKILL_DIR/SKILL.md" "coordinator" "swarm has coordinator ownership"
run_content_eval "$SKILL_DIR/SKILL.md" "conflicting" "swarm handles conflicting results"
run_content_eval "$SKILL_DIR/SKILL.md" "model" "swarm leaves room for model policy"
run_content_eval "$SKILL_DIR/SKILL.md" "eval ownership|matching evals" "swarm assigns eval ownership for skill and harness lanes"
run_content_eval "$SKILL_DIR/SKILL.md" "RED.*GREEN|failing-test evidence" "swarm TDD lanes require red-green proof"
run_content_eval "$SKILL_DIR/SKILL.md" "visual-review.*setup-ux-copy|copywriting.*visual-review" "swarm can split visual review and copywriting lanes"
run_content_eval "$REPO_ROOT/.claude-plugin/plugin.json" '"./swarm/"' "swarm registered in Claude plugin skills"

lines=$(wc -l < "$SKILL_DIR/SKILL.md" 2>/dev/null | tr -d ' ' || echo 999)
if [ "${lines:-999}" -le 110 ]; then
  echo "  PASS  swarm SKILL.md stays terse"
  PASS=$((PASS + 1))
else
  echo "  FAIL  swarm SKILL.md too long (${lines} lines)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: swarm SKILL.md too long"
fi
