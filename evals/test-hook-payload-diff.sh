# Evals for hook_get_added_lines payload-diff behavior.
#
# Regression guard against the "pre-existing noise" bug where
# git-diff-HEAD fallback `cat` scanned the full file and flagged
# violations the current Edit/Write didn't introduce.
#
# Strategy: drive as-cast-check.sh (which sources hook-lib.sh and
# calls hook_get_added_lines) with crafted Edit/Write payloads and
# assert exit codes.

HOOKS_DIR="$REPO_ROOT/.claude/hooks"
HOOK="$HOOKS_DIR/as-cast-check.sh"

_tmpdir=$(mktemp -d)
trap 'rm -rf "$_tmpdir"' EXIT

_mkfile() {
  local name="$1" body="$2"
  local path="$_tmpdir/$name"
  printf '%s' "$body" > "$path"
  echo "$path"
}

_payload_edit() {
  local file="$1" old="$2" new="$3"
  jq -nc \
    --arg f "$file" --arg o "$old" --arg n "$new" \
    '{tool_name:"Edit",tool_input:{file_path:$f,old_string:$o,new_string:$n}}'
}

_payload_write() {
  local file="$1" content="$2"
  jq -nc \
    --arg f "$file" --arg c "$content" \
    '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}'
}

# ── 1. Edit ADDS `as any` → block (exit 2) ─────────────────────
f1=$(_mkfile "clean.ts" "const x = 1;\n")
run_hook_eval "$HOOK" \
  "$(_payload_edit "$f1" "const x = 1;" "const x = y as any;")" \
  2 \
  "payload-diff: Edit adding 'as any' blocks"

# ── 2. Edit on file w/ pre-existing `as any`, change is elsewhere → pass ──
# Both old_string and new_string carry the same `as any` line; the
# actual diff is a different line. Legacy `cat`-fallback would flag
# the untouched `as any`; payload diff must not.
f2=$(_mkfile "preexisting.ts" $'const x = y as any;\nconst msg = \'hi\';\n')
run_hook_eval "$HOOK" \
  "$(_payload_edit "$f2" \
      $'const x = y as any;\nconst msg = \'hi\';' \
      $'const x = y as any;\nconst msg = \'hello\';')" \
  0 \
  "payload-diff: Edit ignoring pre-existing 'as any' passes"

# ── 3. Write new file with `as any` → block ────────────────────
f3="$_tmpdir/new.ts"
: > "$f3"  # file must exist for hook's -f check; not tracked by git
run_hook_eval "$HOOK" \
  "$(_payload_write "$f3" "const x = y as any;\n")" \
  2 \
  "payload-diff: Write new file with 'as any' blocks"

# ── 4. Write with identical content to file on disk → pass ─────
# Simulates idempotent Write where payload carries no new violation.
f4=$(_mkfile "noop.ts" "const x = 1;\n")
run_hook_eval "$HOOK" \
  "$(_payload_write "$f4" "const x = 1;\n")" \
  0 \
  "payload-diff: Write with clean content passes"

# ── 5. Edit on untracked file, pre-existing violation NOT in delta → pass ──
# Regression case from snyk-frontend-sweep: untracked dir, file full
# of legacy `as any`, user edits an unrelated line → must not fire.
f5=$(_mkfile "untracked.ts" $'const a = b as any;\nconst c = 2;\n')
run_hook_eval "$HOOK" \
  "$(_payload_edit "$f5" "const c = 2;" "const c = 3;")" \
  0 \
  "payload-diff: untracked file, edit outside violation passes"

# ── 6. Edit with no change (old==new) → pass ───────────────────
f6=$(_mkfile "nochange.ts" "const x = 1;\n")
run_hook_eval "$HOOK" \
  "$(_payload_edit "$f6" "const x = 1;" "const x = 1;")" \
  0 \
  "payload-diff: no-op Edit passes"
