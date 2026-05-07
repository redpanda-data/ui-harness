SKILL_DIR="$REPO_ROOT/diagnose"

# ── Skill structure ───────────────────────────────────────────────
run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/scripts/hitl-loop.template.sh" "hitl-loop.template.sh exists"
run_executable_eval "$SKILL_DIR/scripts/hitl-loop.template.sh" "hitl-loop.template.sh is executable"

run_content_eval "$SKILL_DIR/SKILL.md" "^name: diagnose" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"

desc=$(grep '^description:' "$SKILL_DIR/SKILL.md" | sed 's/^description: //' | tr -d '"')
desc_len=${#desc}
if [ $desc_len -le 1024 ]; then
  echo "  PASS  description under 1024 chars ($desc_len)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  description over 1024 chars ($desc_len)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: description over 1024 chars ($desc_len)"
fi

# ── Six-phase loop ────────────────────────────────────────────────
run_content_eval "$SKILL_DIR/SKILL.md" "Phase 1.*[Bb]uild a feedback loop" "SKILL.md has Phase 1 (build feedback loop)"
run_content_eval "$SKILL_DIR/SKILL.md" "Phase 2.*[Rr]eproduce" "SKILL.md has Phase 2 (reproduce)"
run_content_eval "$SKILL_DIR/SKILL.md" "Phase 3.*[Hh]ypothesise" "SKILL.md has Phase 3 (hypothesise)"
run_content_eval "$SKILL_DIR/SKILL.md" "Phase 4.*[Ii]nstrument" "SKILL.md has Phase 4 (instrument)"
run_content_eval "$SKILL_DIR/SKILL.md" "Phase 5.*[Ff]ix" "SKILL.md has Phase 5 (fix + regression test)"
run_content_eval "$SKILL_DIR/SKILL.md" "Phase 6.*[Cc]leanup" "SKILL.md has Phase 6 (cleanup + post-mortem)"

# ── Phase 1 substance: feedback-loop ranked strategies ───────────
run_content_eval "$SKILL_DIR/SKILL.md" "[Ff]ailing test" "SKILL.md lists failing-test feedback-loop strategy"
run_content_eval "$SKILL_DIR/SKILL.md" "git bisect" "SKILL.md lists bisection harness strategy"
run_content_eval "$SKILL_DIR/SKILL.md" "[Hh]eadless browser|Playwright|Puppeteer" "SKILL.md lists headless-browser strategy"
run_content_eval "$SKILL_DIR/SKILL.md" "HITL" "SKILL.md mentions HITL bash script as last-resort"

# ── Hypothesis discipline ────────────────────────────────────────
run_content_eval "$SKILL_DIR/SKILL.md" "3.{0,2}5.*hypothes" "SKILL.md requires 3-5 ranked hypotheses"
run_content_eval "$SKILL_DIR/SKILL.md" "[Ff]alsifiable" "SKILL.md requires falsifiable hypotheses"

# ── Instrumentation hygiene ──────────────────────────────────────
run_content_eval "$SKILL_DIR/SKILL.md" "DEBUG-" "SKILL.md uses tagged debug log convention"
run_content_eval "$SKILL_DIR/SKILL.md" "[Cc]hange one variable at a time" "SKILL.md requires single-variable instrumentation"

# ── Regression test seam awareness ───────────────────────────────
run_content_eval "$SKILL_DIR/SKILL.md" "correct seam|right seam" "SKILL.md discusses seam correctness for regression tests"

# ── Cleanup checklist ────────────────────────────────────────────
run_content_eval "$SKILL_DIR/SKILL.md" "Original repro no longer reproduces|re-run.*loop" "SKILL.md verifies original repro is gone"
run_content_eval "$SKILL_DIR/SKILL.md" "instrumentation removed|grep.*prefix" "SKILL.md cleans up debug instrumentation"

# ── Vague-prose domain glossary + ADR awareness ──────────────────
run_content_eval "$SKILL_DIR/SKILL.md" "domain glossary" "SKILL.md references project domain glossary"
run_content_eval "$SKILL_DIR/SKILL.md" "ADRs" "SKILL.md references ADRs"

# ── Hand-off to architecture skill ───────────────────────────────
run_content_eval "$SKILL_DIR/SKILL.md" "/improve-codebase-architecture" "SKILL.md hands off to /improve-codebase-architecture for architectural fixes"

# ── HITL template substance ──────────────────────────────────────
run_content_eval "$SKILL_DIR/scripts/hitl-loop.template.sh" "^step\\(\\)" "hitl-loop has step() helper"
run_content_eval "$SKILL_DIR/scripts/hitl-loop.template.sh" "^capture\\(\\)" "hitl-loop has capture() helper"
run_content_eval "$SKILL_DIR/scripts/hitl-loop.template.sh" "set -euo pipefail" "hitl-loop uses strict bash"
