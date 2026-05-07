# Evals for setup-react-compiler skill

SCRIPT="$REPO_ROOT/setup-react-compiler/scripts/react-compiler-check.sh"
SKILL_DIR="$REPO_ROOT/setup-react-compiler"

# ── File structure ──────────────────────────────────────────────

run_file_eval "$SKILL_DIR/SKILL.md" "SKILL.md exists"
run_file_eval "$SKILL_DIR/REFERENCE.md" "REFERENCE.md exists"
run_executable_eval "$SCRIPT" "react-compiler-check.sh is executable"

# ── SKILL.md content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/SKILL.md" "^name: setup-react-compiler" "SKILL.md has correct name"
run_content_eval "$SKILL_DIR/SKILL.md" "Use when" "SKILL.md has trigger phrase"
run_content_eval "$SKILL_DIR/SKILL.md" "rsbuild" "SKILL.md mentions rsbuild"
run_content_eval "$SKILL_DIR/SKILL.md" "use no memo" "SKILL.md mentions escape hatch"

# ── Hook: skip non-Edit/Write tools ────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}' \
  0 "skip: Bash tool"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Read","tool_input":{"file_path":"foo.tsx"}}' \
  0 "skip: Read tool"

# ── Hook: skip non-JSX/TSX files ───────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.ts"}}' \
  0 "skip: .ts file (not tsx/jsx)"

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.css"}}' \
  0 "skip: .css file"

# ── Hook: skip component library directories ────────────────────

tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/components/ui"
echo "const x = useMemo(() => 1, [])" > "$tmpdir/components/ui/Button.tsx"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpdir/components/ui/Button.tsx\"}}" \
  0 "skip: components/ui directory"

# Test UI_LIB_DIRS override for custom directories
mkdir -p "$tmpdir/redpanda-ui"
echo "const x = useMemo(() => 1, [])" > "$tmpdir/redpanda-ui/Button.tsx"

UI_LIB_DIRS="components/ui|redpanda-ui" run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpdir/redpanda-ui/Button.tsx\"}}" \
  0 "skip: redpanda-ui via UI_LIB_DIRS override"

rm -rf "$tmpdir"

# ── Hook: skip files with 'use no memo' ────────────────────────

_rc_tmpdir=$(mktemp -d /tmp/compiler-evals-XXXXXX)
# Mock package.json with react-compiler so the hook activates
echo '{"devDependencies":{"babel-plugin-react-compiler":"*"}}' > "$_rc_tmpdir/package.json"
tmpfile="$_rc_tmpdir/test.tsx"
printf "'use no memo'\nconst x = useMemo(() => 1, [])\n" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "skip: file with 'use no memo' directive"

# tmpfile reused in tmpdir

# ── Hook: skip nonexistent file ─────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Write","tool_input":{"file_path":"/tmp/nonexistent-abc123.tsx"}}' \
  0 "skip: nonexistent file"

# ── Hook: skip empty file_path ──────────────────────────────────

run_hook_eval "$SCRIPT" \
  '{"tool_name":"Edit","tool_input":{"file_path":""}}' \
  0 "skip: empty file_path"

# ── Hook: annotation mode — skip files without 'use memo' ──────

# In annotation mode, useMemo is allowed in files without "use memo"
tmpfile="$_rc_tmpdir/test.tsx"
echo "const val = useMemo(() => compute(), [dep])" > "$tmpfile"

# Run from tmpdir so hook finds mock package.json with react-compiler
cd "$_rc_tmpdir"

REACT_COMPILER_MODE=annotation run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  0 "annotation mode: allow useMemo without 'use memo' directive"

# In annotation mode, useMemo is blocked in files WITH "use memo"
printf "'use memo'\nconst val = useMemo(() => compute(), [dep])\n" > "$tmpfile"

REACT_COMPILER_MODE=annotation run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "annotation mode: block useMemo in file with 'use memo'" "useMemo"

# In default (infer) mode, useMemo is always blocked
echo "const val = useMemo(() => compute(), [dep])" > "$tmpfile"

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$tmpfile\"}}" \
  2 "infer mode: block useMemo (default)" "useMemo"

cd "$REPO_ROOT"

# ── Check 2: Derived state via useState + useEffect anti-pattern ─

_ds_tmpdir=$(mktemp -d /tmp/derived-state-evals-XXXXXX)
echo '{"devDependencies":{"babel-plugin-react-compiler":"*"}}' > "$_ds_tmpdir/package.json"
_ds_file="$_ds_tmpdir/test.tsx"

# Block: useState + useEffect that sets state (derived state)
cat > "$_ds_file" <<'TSXEOF'
const [filtered, setFiltered] = useState([])
useEffect(() => { setFiltered(items.filter(i => i.visible)) }, [items])
TSXEOF

cd "$_ds_tmpdir"
run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ds_file\"}}" \
  2 "block: derived state via useState + useEffect" "derive"

# Allow: useEffect that does NOT set state (genuine side effect)
cat > "$_ds_file" <<'TSXEOF'
const [data, setData] = useState(null)
useEffect(() => { document.title = data?.name ?? 'App' }, [data])
TSXEOF

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ds_file\"}}" \
  0 "allow: useEffect without setState (genuine side effect)"

cd "$REPO_ROOT"
rm -rf "$_ds_tmpdir"

# ── Check 3: useRef as memoization cache ─────────────────────────

_ref_tmpdir=$(mktemp -d /tmp/ref-cache-evals-XXXXXX)
echo '{"devDependencies":{"babel-plugin-react-compiler":"*"}}' > "$_ref_tmpdir/package.json"
_ref_file="$_ref_tmpdir/test.tsx"

# Block: useRef with ??= assignment (memoization cache pattern)
cat > "$_ref_file" <<'TSXEOF'
const cache = useRef(null)
if (cache.current === null) { cache.current = expensiveCompute() }
TSXEOF

cd "$_ref_tmpdir"
run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ref_file\"}}" \
  2 "block: useRef as memoization cache" "cach"

# Allow: useRef for DOM reference (legitimate)
cat > "$_ref_file" <<'TSXEOF'
const inputRef = useRef(null)
return <input ref={inputRef} />
TSXEOF

run_hook_eval "$SCRIPT" \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$_ref_file\"}}" \
  0 "allow: useRef for DOM reference"

cd "$REPO_ROOT"
rm -rf "$_ref_tmpdir"

# ── Hook script content ─────────────────────────────────────────

run_content_eval "$SCRIPT" "useMemo" "hook checks for useMemo"
run_content_eval "$SCRIPT" "useCallback" "hook checks for useCallback"
run_content_eval "$SCRIPT" "React.memo" "hook checks for React.memo"
run_content_eval "$SCRIPT" "hook_skip_ui_dirs" "hook uses shared UI dir skip"
run_content_eval "$SCRIPT" "use no memo" "hook respects 'use no memo'"
run_content_eval "$SCRIPT" "hook_block|hook_warn" "hook uses shared output functions"
run_content_eval "$SCRIPT" "useRef.*memoization|memoization cache" "hook includes anti-caching heuristic"

# ── REFERENCE content ────────────────────────────────────────────

run_content_eval "$SKILL_DIR/REFERENCE.md" "infer" "REFERENCE documents infer mode"
run_content_eval "$SKILL_DIR/REFERENCE.md" "annotation" "REFERENCE documents annotation mode"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Inline callbacks" "REFERENCE has inline callbacks guidance"
run_content_eval "$SKILL_DIR/REFERENCE.md" "Derive.*don.*store|derive.*inline" "REFERENCE has derive-don't-store rule"

rm -rf "$_rc_tmpdir"
