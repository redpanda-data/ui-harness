# Evals for v3.2.0 additions:
#   - ETHOS.md
#   - agents/karpathy-failure-modes.md
#   - adversarial-reviewer trigger gate
#   - code-reviewer Codex wiring + karpathy required reading
#   - self-reviewer karpathy required reading
#   - cso, canary, benchmark, mux skills
#   - docs/rfc/browser-daemon.md

run_file_eval "$REPO_ROOT/ETHOS.md" "ETHOS.md exists"
# Renamed in v4.0 — principles now reflect actual enforced hook rules
for p in "Tests Gate Everything" "Types Are The First Reviewer" "Every Thread Resolved" "Worktree Isolation" "Grill Before Build" "Search Before Add" "Toolchain Discipline" "User Sovereignty"; do
  run_content_eval "$REPO_ROOT/ETHOS.md" "$p" "ETHOS.md has principle: $p"
done

# v4.0: ETHOS + Karpathy are reference docs, NOT injected. Principles
# are enforced by specific hooks (see ETHOS.md map, llm-failure-mode-check.sh).
# Verify subagent-start.sh does NOT inject them (token cost avoidance).
if grep -qE "ETHOS\.md" "$REPO_ROOT/.claude/hooks/subagent-start.sh" 2>/dev/null; then
  echo "  FAIL  subagent-start.sh still injects ETHOS (should be hook-enforced, not ambient)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: ambient ETHOS injection reintroduced"
else
  echo "  PASS  subagent-start.sh does not inject ETHOS (hook-enforced instead)"
  PASS=$((PASS + 1))
fi

run_file_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "karpathy-failure-modes.md exists"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "Hallucinated APIs" "karpathy: hallucinated APIs"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "Confident Wrong Types" "karpathy: confident wrong types"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "Unvalidated LLM Shapes" "karpathy: unvalidated LLM shapes"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "SSRF" "karpathy: SSRF"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "Silent Fallbacks" "karpathy: silent fallbacks"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "karpathy_checks" "karpathy: machine-readable checks"

# v4.1: MAST multi-agent failure taxonomy (Cemri et al. NeurIPS 2025)
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "MAST" "MAST taxonomy section present"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "Multi-Agent System Failure Taxonomy" "MAST full name"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "FC1 -- System Design Issues" "MAST category FC1"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "FC2 -- Inter-Agent Misalignment" "MAST category FC2"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "FC3 -- Task Verification" "MAST category FC3"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "Disobey Task Specification" "MAST FM-1.1"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "Step Repetition" "MAST FM-1.3"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "Reasoning-Action Mismatch" "MAST FM-2.6"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "Premature Termination" "MAST FM-3.1"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "mast_checks" "MAST reviewer output field"
run_content_eval "$REPO_ROOT/agents/karpathy-failure-modes.md" "arXiv:2503.13657" "MAST citation"

# v4.1 distribution fix: karpathy-failure-modes.md must be registered in plugin agents[]
if grep -q '"./agents/karpathy-failure-modes.md"' "$REPO_ROOT/.claude-plugin/plugin.json"; then
  echo "  PASS  karpathy-failure-modes.md registered in .claude-plugin/plugin.json agents[]"
  PASS=$((PASS + 1))
else
  echo "  FAIL  karpathy-failure-modes.md MISSING from .claude-plugin/plugin.json agents[] (reviewer agents reference it via relative link)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: karpathy-failure-modes.md not in claude plugin agents[]"
fi

run_content_eval "$REPO_ROOT/agents/adversarial-reviewer.md" "Trigger Gate" \
  "adversarial-reviewer has trigger gate"
run_content_eval "$REPO_ROOT/agents/adversarial-reviewer.md" "diff_lines > 200" \
  "adversarial-reviewer trigger: diff size"
run_content_eval "$REPO_ROOT/agents/adversarial-reviewer.md" "karpathy-failure-modes" \
  "adversarial-reviewer references karpathy checklist"
run_content_eval "$REPO_ROOT/agents/adversarial-reviewer.md" "SKIPPED" \
  "adversarial-reviewer has skip block"

run_content_eval "$REPO_ROOT/agents/code-reviewer.md" "codex exec" \
  "code-reviewer wires codex exec"
run_content_eval "$REPO_ROOT/agents/code-reviewer.md" "karpathy-failure-modes" \
  "code-reviewer references karpathy"
run_content_eval "$REPO_ROOT/agents/code-reviewer.md" "codex_status" \
  "code-reviewer handles codex-unavailable"
run_content_eval "$REPO_ROOT/agents/self-reviewer.md" "karpathy-failure-modes" \
  "self-reviewer references karpathy"

# (Skills /cso, /canary, /benchmark, /mux removed in v4.0 —
# replaced by native-form hooks (perf-regression-stop) and helper
# scripts (mux-worktree.sh invoked by /go + lifecycle). See
# docs/rfc/browser-daemon.md and v4.0 changelog entry.)

# Browser daemon RFC
run_file_eval "$REPO_ROOT/docs/rfc/browser-daemon.md" "browser-daemon RFC exists"
run_content_eval "$REPO_ROOT/docs/rfc/browser-daemon.md" "Migration Path" "RFC has migration path"
run_content_eval "$REPO_ROOT/docs/rfc/browser-daemon.md" "Non-Goals" "RFC has non-goals"
run_content_eval "$REPO_ROOT/docs/rfc/browser-daemon.md" "claude-in-chrome" "RFC references legacy MCP"
