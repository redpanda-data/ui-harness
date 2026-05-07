# Evals for setup-conventional-commits skill

SCRIPT="$REPO_ROOT/setup-conventional-commits/scripts/conventional-commits-check.sh"
SKILL_DIR="$REPO_ROOT/setup-conventional-commits"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_executable_eval "$SCRIPT" "conventional-commits-check.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-conventional-commits" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "scope" "SKILL.md mentions scope requirement"

# ── Hook: skip non-Bash ─────────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"test.tsx"}}' \
  0 "skip: Edit tool"

# ── Hook: skip non-commit commands ──────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"git status"}}' \
  0 "skip: git status"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"bun run test"}}' \
  0 "skip: non-git command"

# ── Hook: block missing type ────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"bad message\""}}' \
  2 "block: missing type" "type"

# ── Hook: block missing scope ───────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: add button\""}}' \
  2 "block: missing scope" "scope"

# ── Hook: block uppercase description ────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat(ui): Add button component\""}}' \
  2 "block: uppercase first letter" "lowercase"

# ── Hook: block trailing period ──────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat(ui): add button component.\""}}' \
  2 "block: trailing period" "period"

# ── Hook: block short description ────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat(ui): fix\""}}' \
  2 "block: description too short"

# ── Hook: allow valid commit ─────────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat(webui): add user profile avatar upload\""}}' \
  0 "allow: valid conventional commit"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"fix(backend): handle null response from auth endpoint\""}}' \
  0 "allow: valid fix commit"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"chore(deps): bump tanstack-query to v5.62\""}}' \
  0 "allow: valid chore commit"

# ── Hook: allow single quotes ────────────────────────────────────

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m 'refactor(api): extract validation utility'\"}}" \
  0 "allow: single-quoted commit message"

# ── Script content ──────────────────────────────────────────────

run_content_eval "$SCRIPT" "feat|fix|refactor" "hook validates commit types"
run_content_eval "$SCRIPT" "scope" "hook validates scope"
run_content_eval "$SCRIPT" "hook_deny" "hook uses shared deny function"
run_content_eval "$SCRIPT" "min 5" "hook validates min description length"
run_content_eval "$SCRIPT" "max 72" "hook validates max description length"
