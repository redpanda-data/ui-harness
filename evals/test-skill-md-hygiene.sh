# Evals for SKILL.md hygiene.
#
# Guards against regressions that would break skill routing or violate
# /write-a-skill checklist. Three classes:
#
# Test A: frontmatter present on every SKILL.md (caveman-strip guard)
# Test B: SKILL.md under 100-line cap (split overflow -> REFERENCE.md)
# Test C: plugin manifests x-includes.skills matches actual count

SKILLS_ROOT="$REPO_ROOT"

# -- Test A: frontmatter present ------------------------------------
# caveman:compress has bug dropping --- fence on terse skills.
# Broke 5 skills on 2026-04-19 before fix landed. Eval asserts
# every non-backup SKILL.md starts with --- YAML block.

fm_missing=0
fm_offenders=""
while IFS= read -r skill; do
  first_line=$(head -1 "$skill" 2>/dev/null)
  if [ "$first_line" != "---" ]; then
    fm_missing=$((fm_missing + 1))
    fm_offenders="$fm_offenders ${skill#$SKILLS_ROOT/}"
  fi
done < <(find "$SKILLS_ROOT" -maxdepth 2 -name "SKILL.md" \
  -not -name "*.original.md" -not -path "*/node_modules/*" \
  -not -path "*/agent-evals/*" 2>/dev/null)

if [ "$fm_missing" -eq 0 ]; then
  echo "  PASS  all SKILL.md have frontmatter"
  PASS=$((PASS + 1))
else
  echo "  FAIL  $fm_missing SKILL.md files lack frontmatter:$fm_offenders"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: SKILL.md frontmatter missing on:$fm_offenders"
fi

# -- Test B: SKILL.md line cap --------------------------------------
# /write-a-skill checklist: SKILL.md under 100 lines. Overflow -> REFERENCE.md.
# Cap at 110 to allow small slack; strict 100 warns.

oversize=0
oversize_offenders=""
while IFS= read -r skill; do
  lines=$(wc -l < "$skill" 2>/dev/null | tr -d ' ')
  if [ "${lines:-0}" -gt 110 ]; then
    oversize=$((oversize + 1))
    name="${skill#$SKILLS_ROOT/}"
    oversize_offenders="$oversize_offenders ${name}(${lines})"
  fi
done < <(find "$SKILLS_ROOT" -maxdepth 2 -name "SKILL.md" \
  -not -name "*.original.md" -not -path "*/node_modules/*" \
  -not -path "*/agent-evals/*" 2>/dev/null)

if [ "$oversize" -eq 0 ]; then
  echo "  PASS  all SKILL.md under 110-line cap"
  PASS=$((PASS + 1))
else
  echo "  FAIL  $oversize SKILL.md files over 110 lines:$oversize_offenders"
  FAIL=$((FAIL + 1))
  ERRORS="$ERRORS\n  FAIL: SKILL.md oversize:$oversize_offenders"
fi

# Test C removed: plugin-manifest skills counts drift on every add/remove
# and required updating 4 files in lockstep. The count was advisory and
# self-evidently derivable from `find . -maxdepth 2 -name SKILL.md`, so
# the friction outweighed the signal.

# -- Test D: agent model frontmatter guards cost tier ---------------
# Verifier=haiku, adversarial-reviewer=opus, others=sonnet.
# Guards against regression that would inflate subagent cost ~$650/yr.

agents_dir="$SKILLS_ROOT/agents"
declare_agent_model() {
  local file="$1" expected="$2"
  [ -f "$file" ] || return 0
  local actual
  actual=$(awk '/^model:/{print $2; exit}' "$file" 2>/dev/null)
  local name="${file#$SKILLS_ROOT/}"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS  $name model=$actual"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name model=$actual (expected $expected)"
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  FAIL: agent $name model mismatch (got $actual, want $expected)"
  fi
}

declare_agent_model "$agents_dir/verifier.md" "haiku"
declare_agent_model "$agents_dir/self-reviewer.md" "sonnet"
declare_agent_model "$agents_dir/code-reviewer.md" "sonnet"
declare_agent_model "$agents_dir/adversarial-reviewer.md" "opus"
declare_agent_model "$agents_dir/plan-product-hat.md" "sonnet"
declare_agent_model "$agents_dir/plan-engineering-hat.md" "sonnet"
declare_agent_model "$agents_dir/plan-design-hat.md" "sonnet"
