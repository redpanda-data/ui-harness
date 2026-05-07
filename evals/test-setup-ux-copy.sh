# Evals for setup-ux-copy skill

SCRIPT="$REPO_ROOT/setup-ux-copy/scripts/ux-copy-check.sh"
SKILL_DIR="$REPO_ROOT/setup-ux-copy"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_file_eval "$SKILL_DIR/GLOSSARY.md" "GLOSSARY.md exists"
run_executable_eval "$SCRIPT" "ux-copy-check.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-ux-copy" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "allow.*ux-copy" "SKILL.md documents escape hatch"
run_content_eval "$SKILL_DIR/SKILL.md" "capitalization" "SKILL.md mentions capitalization rules"
run_content_eval "$SKILL_DIR/SKILL.md" "REDPANDA_KIT" "SKILL.md documents Redpanda opt-in"

# ── Hook: skip non-Edit/Write ───────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"echo"}}' \
  0 "skip: Bash tool"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Read","tool_input":{"file_path":"foo.tsx"}}' \
  0 "skip: Read tool"

# ── Hook: skip non-TS/TSX files ─────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.json"}}' \
  0 "skip: .json file"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.css"}}' \
  0 "skip: .css file"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.py"}}' \
  0 "skip: .py file"

# ── Hook: skip generated files ──────────────────────────────────

_ux_gen_dir=$(mktemp -d /tmp/ux-gen-XXXXXX)
printf '// @generated\nconst msg = "Created successfully!"\n' > "$_ux_gen_dir/generated.ts"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ux_gen_dir/generated.ts\"}}" \
  0 "skip: auto-generated file"

rm -rf "$_ux_gen_dir"

# Create temp dir for all file-based tests
_ux_tmpdir=$(mktemp -d /tmp/ux-copy-evals-XXXXXX)

# ── Check 1: Exclamation points ─────────────────────────────────

tmpfile="$_ux_tmpdir/test.ts"
echo 'const msg = "Something went wrong!"' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: exclamation at end of string" "No !"

# Allow: no exclamation
echo 'const msg = "Something went wrong"' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: string without exclamation"

# Allow: !== operator (not UI text)
echo 'if (value !== null) { return }' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: !== operator"

# Allow: exclamation in middle of string (not end — likely code/template)
echo 'const tpl = "Use !important only when needed"' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: exclamation in middle of string (not end)"

# ── Check 2: "successfully" ─────────────────────────────────────

tmpfile="$_ux_tmpdir/toast.ts"
echo "const msg = 'Topic successfully created'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: successfully in string" "successfully"

# Allow: past tense without "successfully"
echo "const msg = 'Topic created'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: past tense without successfully"

# ── Check 3: "click here" ───────────────────────────────────────

tmpfile="$_ux_tmpdir/test.tsx"
echo '<Link>click here</Link>' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: click here link text" "click here"

echo '<a>here</a>' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: bare here link text"

# Allow: descriptive link text
echo '<Link>View documentation</Link>' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: descriptive link text"

# ── Check 4: Blame language ─────────────────────────────────────

tmpfile="$_ux_tmpdir/error.ts"
echo "const msg = \"Oops, something went wrong\"" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: Oops in string" "casual"

echo "const msg = 'Uh oh, an error occurred'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: Uh oh in string"

# Allow: neutral error message
echo "const msg = 'Could not save changes'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: neutral error message"

# ── Check 5: Possessive pronouns ────────────────────────────────

tmpfile="$_ux_tmpdir/nav.ts"
echo "const title = 'My Settings'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: My in title" "possessive"

echo "const title = 'Your Clusters'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: Your in title" "possessive"

# Allow: just "Settings"
echo "const title = 'Settings'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: title without possessive pronoun"

# ── Check 6: Yes/No button labels ───────────────────────────────

tmpfile="$_ux_tmpdir/dialog.tsx"
echo '<Button onClick={handleConfirm}>Yes</Button>' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: Yes button label" "Yes"

echo '<Button onClick={handleCancel}>No</Button>' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: No button label" "No"

# Allow: action verb button
echo '<Button onClick={handleDelete}>Delete cluster</Button>' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: action verb button label"

# ── Check 7: Formatting in strings ──────────────────────────────

tmpfile="$_ux_tmpdir/text.ts"
echo "const msg = 'Use **bold** text here'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: bold formatting in string" "bold"

# Allow: plain text
echo "const msg = 'Use plain text here'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: plain text string"

# ── Check 8: ALL CAPS ───────────────────────────────────────────

tmpfile="$_ux_tmpdir/emphasis.ts"
echo "const msg = 'THIS WILL DELETE YOUR DATA'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: ALL CAPS for emphasis" "CAPS"

# Allow: known acronyms
echo "const msg = 'Check TLS settings'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: TLS acronym (not all-caps emphasis)"

# ── Check 9: Redpanda terms (REDPANDA_KIT=1) ────────────────────

tmpfile="$_ux_tmpdir/rp.ts"
echo "const label = 'the admin api settings'" > "$tmpfile"

REDPANDA_KIT=1 run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: lowercase Redpanda product name (with REDPANDA_KIT)" "Capitalize"

# Allow: correctly capitalized
echo "const label = 'Admin API settings'" > "$tmpfile"

REDPANDA_KIT=1 run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: correctly capitalized Redpanda term"

# Allow: no REDPANDA_KIT → skip Redpanda checks
echo "const label = 'the admin api'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: Redpanda checks skipped without REDPANDA_KIT"

# ── Check 10: Title Case ────────────────────────────────────────

tmpfile="$_ux_tmpdir/heading.ts"
echo "const title = 'Create New Topic'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: Title Case detected" "Title Case"

# Allow: sentence case
echo "const title = 'Create new topic'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: sentence case"

# ── Check 11: Spelled-out numbers ────────────────────────────────

tmpfile="$_ux_tmpdir/count.ts"
echo "const msg = 'Select one option'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: spelled-out number" "numeral"

# Allow: numeral
echo "const msg = 'Select 1 option'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: numeral instead of spelled-out"

# Allow: excluded phrase "one of"
echo "const msg = 'one of the following options'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: one of (excluded phrase)"

# ── Check 12: "and/or" ───────────────────────────────────────────

tmpfile="$_ux_tmpdir/logic.ts"
echo "const msg = 'Enable and/or disable the feature'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: and/or in string" "and/or"

echo "const msg = 'Enable or disable the feature'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: or without and/or"

# ── Check 13: "etc." ────────────────────────────────────────────

tmpfile="$_ux_tmpdir/list.ts"
echo "const msg = 'Topics, schemas, etc.'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: etc. in string" "etc."

echo "const msg = 'Topics, schemas, and connectors'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: specific list without etc."

# ── Check 14: "e.g." / "i.e." ───────────────────────────────────

tmpfile="$_ux_tmpdir/latin.ts"
echo "const msg = 'Use a valid format, e.g. JSON'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: e.g. in string" "Latin"

echo "const msg = 'Use a valid format, i.e. JSON'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: i.e. in string" "Latin"

echo "const msg = 'Use a valid format, for example JSON'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: for example (plain English)"

# ── Check 15: "please" ──────────────────────────────────────────

tmpfile="$_ux_tmpdir/polite.ts"
echo "const msg = 'Please enter your email'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: Please imperative pattern" "Please"

# Allow: direct language
echo "const msg = 'Enter your email'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: direct language without Please"

# Allow: "please" mid-sentence (acceptable in error acknowledgments)
echo "const msg = 'If the problem persists, please contact support'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: please mid-sentence (not imperative)"

# ── Check 16: Non-inclusive terminology ──────────────────────────

tmpfile="$_ux_tmpdir/terms.ts"
echo "const list = whitelist" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: whitelist (non-inclusive)" "Inclusive"

echo "const list = blacklist" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: blacklist (non-inclusive)" "Inclusive"

echo "const role = master" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "block: master (non-inclusive)" "Inclusive"

echo "const list = allowlist" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: allowlist (inclusive term)"

echo "const role = leader" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: leader (inclusive term)"

# ── Check 17: "There is" / "There are" ──────────────────────────

tmpfile="$_ux_tmpdir/there.ts"
echo "const msg = 'There are 3 configuration options'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: There are starter" "Subject first"

echo "const msg = 'There is no data available'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: There is starter" "Subject first"

echo "const msg = '3 configuration options are available'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: subject-first sentence"

# ── Check 18: "via" ─────────────────────────────────────────────

tmpfile="$_ux_tmpdir/via.ts"
echo "const msg = 'Connect via VPC peering'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "warn: via in string" "via"

echo "const msg = 'Connect through VPC peering'" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: through instead of via"

# ── Escape hatch ────────────────────────────────────────────────

tmpfile="$_ux_tmpdir/legacy.ts"
printf '// allow-ux-copy: legacy external API text\nconst msg = "Created successfully!"\n' > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "allow: escape hatch bypasses all checks"

# ── Hook script content checks ──────────────────────────────────

run_content_eval "$SCRIPT" "hook_has_escape" "hook supports escape hatch"
run_content_eval "$SCRIPT" "successfully" "hook checks for successfully"
run_content_eval "$SCRIPT" "click here" "hook checks for click here"
run_content_eval "$SCRIPT" "oops" "hook checks for blame language"
run_content_eval "$SCRIPT" "REDPANDA_KIT" "hook checks Redpanda terms"
run_content_eval "$SCRIPT" "Admin API" "hook checks Redpanda product names"
run_content_eval "$SCRIPT" "Title Case" "hook detects Title Case"
run_content_eval "$SCRIPT" "numeral" "hook checks for spelled-out numbers"
run_content_eval "$SCRIPT" "hook_block|hook_warn" "hook uses shared output functions"
run_content_eval "$SCRIPT" "and/or" "hook checks for and/or"
run_content_eval "$SCRIPT" "etc\." "hook checks for etc."
run_content_eval "$SCRIPT" "e\.g\." "hook checks for e.g."
run_content_eval "$SCRIPT" "Please" "hook checks for please"
run_content_eval "$SCRIPT" "whitelist|blacklist" "hook checks non-inclusive terms"
run_content_eval "$SCRIPT" "There is|There are" "hook checks There is/are starters"
run_content_eval "$SCRIPT" "via" "hook checks for via"

# ── REFERENCE content ───────────────────────────────────────────

run_content_eval "$SKILL_DIR/REFERENCE.md" "sentence" "REFERENCE has capitalization rules"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Toast" "REFERENCE has toast message rules"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Error" "REFERENCE has error message rules"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Button" "REFERENCE has button label rules"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Learn more" "REFERENCE has link placement rules"
run_content_eval "$SKILL_DIR/REFERENCE.md" "allowlist" "REFERENCE has inclusive terminology table"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Directional" "REFERENCE has directional language guidance"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Placeholder" "REFERENCE has placeholder format guidance"
run_content_eval "$SKILL_DIR/REFERENCE.md" "[Ee]m [Dd]ash" "REFERENCE has em dash guidance"

# ── GLOSSARY content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/GLOSSARY.md" "Admin API" "GLOSSARY has Admin API"
run_content_eval "$SKILL_DIR/GLOSSARY.md" "Schema Registry" "GLOSSARY has Schema Registry"
run_content_eval "$SKILL_DIR/GLOSSARY.md" "ubiquitous-language" "GLOSSARY references DDD skill"

# ── prose-style-check.sh ────────────────────────────────────────

PROSE="$REPO_ROOT/setup-ux-copy/scripts/prose-style-check.sh"

run_executable_eval "$PROSE" "prose-style-check.sh is executable"

run_content_eval "$SKILL_DIR/SKILL.md" "prose-style-check" "SKILL.md documents prose-style script"
run_content_eval "$SKILL_DIR/SKILL.md" "allow.*prose-style" "SKILL.md documents prose-style escape hatch"

# Skip non-prose files
run_hook_eval "$PROSE" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.tsx"}}' \
  0 "prose: skip .tsx file"

run_hook_eval "$PROSE" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.json"}}' \
  0 "prose: skip .json file"

# Block: em dash
_em_file="$_ux_tmpdir/em.md"
printf 'This is fine — but it has an em dash.\n' > "$_em_file"
_em_content=$(cat "$_em_file")
_em_input=$(jq -nc --arg fp "$_em_file" --arg c "$_em_content" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
run_hook_eval "$PROSE" "$_em_input" 2 "prose: block em dash" "em dashes"

# Block: canned opener
_open_file="$_ux_tmpdir/opener.md"
printf "Let's dive in to the topic.\n" > "$_open_file"
_open_content=$(cat "$_open_file")
_open_input=$(jq -nc --arg fp "$_open_file" --arg c "$_open_content" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
run_hook_eval "$PROSE" "$_open_input" 2 "prose: block 'Let's dive in'" "canned opener"

# Block: AI-tell hard
_delve_file="$_ux_tmpdir/delve.md"
printf 'Let us delve into the architecture.\n' > "$_delve_file"
_delve_content=$(cat "$_delve_file")
_delve_input=$(jq -nc --arg fp "$_delve_file" --arg c "$_delve_content" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
run_hook_eval "$PROSE" "$_delve_input" 2 "prose: block 'delve'" "AI-tell"

# Warn (exit 0): AI-tell soft
_soft_file="$_ux_tmpdir/soft.md"
printf 'We leverage Redpanda for streaming.\n' > "$_soft_file"
_soft_content=$(cat "$_soft_file")
_soft_input=$(jq -nc --arg fp "$_soft_file" --arg c "$_soft_content" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
run_hook_eval "$PROSE" "$_soft_input" 0 "prose: warn 'leverage' (soft)" "leverage"

# Allow: clean prose
_clean_file="$_ux_tmpdir/clean.md"
printf 'This document explains the migration steps in plain English.\n' > "$_clean_file"
_clean_content=$(cat "$_clean_file")
_clean_input=$(jq -nc --arg fp "$_clean_file" --arg c "$_clean_content" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
run_hook_eval "$PROSE" "$_clean_input" 0 "prose: allow clean prose"

# Allow: em dash inside fenced code block (false-positive guard)
_fenced_file="$_ux_tmpdir/fenced.md"
printf '%s\n' '```' 'echo "x — y"' '```' > "$_fenced_file"
_fenced_content=$(cat "$_fenced_file")
_fenced_input=$(jq -nc --arg fp "$_fenced_file" --arg c "$_fenced_content" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
run_hook_eval "$PROSE" "$_fenced_input" 0 "prose: allow em dash in indented code"

# Allow: em dash inside inline code span
_inline_file="$_ux_tmpdir/inline.md"
printf 'Use the `git log --oneline — file.txt` command.\n' > "$_inline_file"
_inline_content=$(cat "$_inline_file")
_inline_input=$(jq -nc --arg fp "$_inline_file" --arg c "$_inline_content" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
run_hook_eval "$PROSE" "$_inline_input" 0 "prose: allow em dash in inline code"

# Allow: escape hatch (HTML comment)
_escape_file="$_ux_tmpdir/escape.md"
printf '<!-- allow: prose-style legacy doc -->\nWe leverage delve patterns — comprehensively.\n' > "$_escape_file"
_escape_content=$(cat "$_escape_file")
_escape_input=$(jq -nc --arg fp "$_escape_file" --arg c "$_escape_content" \
  '{tool_name:"Write", tool_input:{file_path:$fp, content:$c}}')
run_hook_eval "$PROSE" "$_escape_input" 0 "prose: escape hatch (HTML comment)"

# ── Cleanup ─────────────────────────────────────────────────────

rm -rf "$_ux_tmpdir"
