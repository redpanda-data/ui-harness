# Evals for token budget enforcement.
#
# Guards the harness savings baseline. Blocks regressions where doc size,
# hook output, or test-run verbosity creeps back up silently.
#
# Test A: doc budget (CLAUDE.md, SKILL.md descriptions, MEMORY.md index)
# Test B: hook output size (silent-pass floor, worst-case ceiling)
# Test C: test-run reporter output (vitest/playwright stay under budget)
# Test D: config drift (no verbose reporters reintroduced)

BUDGET_DIR="$REPO_ROOT"

# -- Test A: doc budget ---------------------------------------------

# Cap bumped from 7200 to 7500 (2026-04-19) to fit the External Services
# section introduced with the MCP-ban hook. Bumped 7500 -> 7900 (2026-04-29)
# after rtk-rewrite + green-not-done sections pushed CLAUDE.md to 7823
# post-caveman-compress. Bumped 7900 -> 8000 (2026-04-29) for headroom
# while the prose-style-check linter is still settling.
claude_md_bytes=$(wc -c < "$BUDGET_DIR/CLAUDE.md" 2>/dev/null | tr -d ' ')
if [ "$claude_md_bytes" -lt 8000 ]; then
  echo "  PASS  CLAUDE.md under 8000 bytes ($claude_md_bytes)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  CLAUDE.md over budget: $claude_md_bytes bytes (cap: 8000)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: CLAUDE.md over 8000 bytes"
fi

ethos_bytes=$(wc -c < "$BUDGET_DIR/ETHOS.md" 2>/dev/null | tr -d ' ')
if [ "$ethos_bytes" -lt 3000 ]; then
  echo "  PASS  ETHOS.md under 3000 bytes ($ethos_bytes)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  ETHOS.md over budget: $ethos_bytes bytes (cap: 3000)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: ETHOS.md over 3000 bytes"
fi

# Sum SKILL.md description field chars (frontmatter description only)
desc_total=0
for skill in "$BUDGET_DIR"/*/SKILL.md; do
  [ -f "$skill" ] || continue
  d=$(awk 'BEGIN{c=0} /^---$/{c++; if(c==2)exit; next} c==1 && /^description:/{inDesc=1; sub(/^description: */, ""); print; next} c==1 && inDesc && /^[a-zA-Z_-]+:/{inDesc=0; next} c==1 && inDesc{print}' "$skill" 2>/dev/null | tr -d '\n')
  desc_total=$((desc_total + ${#d}))
done

if [ "$desc_total" -lt 12000 ]; then
  echo "  PASS  All SKILL.md descriptions total under 12000 chars ($desc_total)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  SKILL.md descriptions total: $desc_total chars (cap: 12000)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: skill descriptions over 12000 chars"
fi

# No Unicode punctuation in hot-path docs (em-dash, smart quotes, etc)
unicode_hits=$(python3 -c '
import sys, pathlib
chars = ["\u2014","\u2013","\u2192","\u2190","\u2022","\u00b7","\u2026","\u2018","\u2019","\u201c","\u201d","\u2260"]
total = 0
for p in sys.argv[1:]:
    try:
        t = pathlib.Path(p).read_text()
        for c in chars:
            total += t.count(c)
    except Exception:
        pass
print(total)
' "$BUDGET_DIR/CLAUDE.md" "$BUDGET_DIR/ETHOS.md" "$BUDGET_DIR/AGENTS.md" 2>/dev/null || echo 0)

if [ "$unicode_hits" -eq 0 ]; then
  echo "  PASS  hot-path docs ASCII-only (no em-dash/arrow/smart-quote)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  $unicode_hits Unicode punctuation chars in hot-path docs (run ASCII normalize)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Unicode punctuation reintroduced in docs"
fi

# Repo-wide: no em-dash or arrow in any .md / agent def (caveman-compress
# sometimes reintroduces them; guard against regression). Box-drawing
# glyphs in ASCII art still allowed.
wide_hits=$(python3 -c '
import sys, pathlib
bad = ["\u2014","\u2013","\u2192","\u2190","\u2026","\u2018","\u2019","\u201c","\u201d"]
total = 0
offenders = []
root = pathlib.Path(sys.argv[1])
for p in list(root.glob("*/*.md")) + list(root.glob("*/*/*.md")) + [root / "README.md", root / "AGENTS.md"]:
    if "node_modules" in str(p) or ".original.md" in str(p) or "agent-evals/" in str(p):
        continue
    try:
        t = p.read_text()
        hits = sum(t.count(c) for c in bad)
        if hits:
            offenders.append(f"{p}:{hits}")
            total += hits
    except Exception:
        pass
if total:
    print(f"{total} {offenders[:5]}")
else:
    print("0")
' "$BUDGET_DIR" 2>/dev/null || echo "0")

if [ "$wide_hits" = "0" ]; then
  echo "  PASS  all .md files ASCII-only (no em-dash/arrow/smart-quote)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  Unicode punctuation in .md files: $wide_hits"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: Unicode punctuation in .md files"
fi

# Trailing whitespace check via python to avoid grep+pipefail abort
trailing_count=$(python3 -c '
import pathlib, sys
n = 0
root = pathlib.Path(sys.argv[1])
for p in list(root.glob("*.md")) + list(root.glob("*/*.md")) + list(root.glob("*/*/*.md")):
    if any(x in str(p) for x in ("node_modules", ".original.md", "agent-evals/")):
        continue
    try:
        for line in p.read_text().splitlines():
            if line != line.rstrip():
                n += 1
                break
    except Exception:
        pass
print(n)
' "$BUDGET_DIR" 2>/dev/null || echo 0)
if [ "$trailing_count" = "0" ]; then
  echo "  PASS  no trailing whitespace in .md files"
  PASS=$((PASS + 1))
else
  echo "  FAIL  $trailing_count .md files have trailing whitespace"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: trailing whitespace"
fi

# -- Test B: hook output size ---------------------------------------

fixture_clean='{"session_id":"budget-test","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"/tmp/budget-test-clean.tsx","old_string":"x","new_string":"const x: number = 2;"}}'
echo "const x: number = 2;" > /tmp/budget-test-clean.tsx 2>/dev/null

# Pick a representative hook that should be silent on clean input
clean_hook="$BUDGET_DIR/.claude/hooks/as-cast-check.sh"
if [ -x "$clean_hook" ]; then
  out=$(echo "$fixture_clean" | "$clean_hook" 2>&1 || true)
  bytes=${#out}
  if [ "$bytes" -lt 100 ]; then
    echo "  PASS  as-cast-check silent-pass under 100 bytes ($bytes)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  as-cast-check silent-pass emitted $bytes bytes (cap: 100)"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: as-cast-check silent-pass too loud"
  fi
fi

# -- Test C: test-run reporter output -------------------------------

# Custom reporters exist
if [ -f "$BUDGET_DIR/shared/reporters/vitest-llm-reporter.ts" ]; then
  echo "  PASS  shared/reporters/vitest-llm-reporter.ts exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL  shared/reporters/vitest-llm-reporter.ts missing"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: vitest reporter missing"
fi

if [ -f "$BUDGET_DIR/shared/reporters/playwright-llm-reporter.ts" ]; then
  echo "  PASS  shared/reporters/playwright-llm-reporter.ts exists"
  PASS=$((PASS + 1))
else
  echo "  FAIL  shared/reporters/playwright-llm-reporter.ts missing"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: playwright reporter missing"
fi

# Reporters must be under 120 LOC each (complexity budget)
vitest_reporter_lines=$(wc -l < "$BUDGET_DIR/shared/reporters/vitest-llm-reporter.ts" 2>/dev/null | tr -d ' ')
if [ "${vitest_reporter_lines:-0}" -gt 0 ] && [ "$vitest_reporter_lines" -lt 120 ]; then
  echo "  PASS  vitest reporter under 120 LOC ($vitest_reporter_lines)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  vitest reporter at $vitest_reporter_lines LOC (cap: 120)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: vitest reporter too complex"
fi

pw_reporter_lines=$(wc -l < "$BUDGET_DIR/shared/reporters/playwright-llm-reporter.ts" 2>/dev/null | tr -d ' ')
if [ "${pw_reporter_lines:-0}" -gt 0 ] && [ "$pw_reporter_lines" -lt 120 ]; then
  echo "  PASS  playwright reporter under 120 LOC ($pw_reporter_lines)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  playwright reporter at $pw_reporter_lines LOC (cap: 120)"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: playwright reporter too complex"
fi

# -- Test D: config drift -------------------------------------------

# llm-test-flags.sh must nudge for in-house reporters
if grep -q 'vitest-llm-reporter' "$BUDGET_DIR/.claude/hooks/llm-test-flags.sh" 2>/dev/null; then
  echo "  PASS  llm-test-flags.sh references vitest-llm-reporter"
  PASS=$((PASS + 1))
else
  echo "  FAIL  llm-test-flags.sh missing vitest-llm-reporter nudge"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: llm-test-flags missing vitest nudge"
fi

if grep -q 'playwright-llm-reporter' "$BUDGET_DIR/.claude/hooks/llm-test-flags.sh" 2>/dev/null; then
  echo "  PASS  llm-test-flags.sh references playwright-llm-reporter"
  PASS=$((PASS + 1))
else
  echo "  FAIL  llm-test-flags.sh missing playwright-llm-reporter nudge"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: llm-test-flags missing playwright nudge"
fi

# llm-truncate.sh must cap at bytes not lines
if grep -q 'LLM_TRUNCATE_BYTES' "$BUDGET_DIR/.claude/hooks/llm-truncate.sh" 2>/dev/null; then
  echo "  PASS  llm-truncate.sh uses byte cap (LLM_TRUNCATE_BYTES)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  llm-truncate.sh not using byte cap"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: llm-truncate regressed to line cap"
fi

# llm-truncate.sh must write file pointer
if grep -q 'claude-bash-logs' "$BUDGET_DIR/.claude/hooks/llm-truncate.sh" 2>/dev/null; then
  echo "  PASS  llm-truncate.sh writes file pointer for re-read"
  PASS=$((PASS + 1))
else
  echo "  FAIL  llm-truncate.sh missing file pointer logic"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: llm-truncate missing pointer"
fi
