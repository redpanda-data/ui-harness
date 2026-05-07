#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# PostToolUse Edit|Write: enforce 7 Karpathy LLM failure modes.
# See ETHOS.md (Types First Reviewer) + agents/karpathy-failure-modes.md.
# Types + silent fallbacks are delegated to existing hooks.

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

hook_has_escape "llm-failure" && exit 0

scan=$(printf '%s' "$added_lines" | sed 's/^+//')
# Derive project root from the edited file, not cwd — hooks fire from
# outside the target project in tests and multi-worktree flows.
repo_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null || _hook_current_worktree_root 2>/dev/null || pwd)

# 1. Hallucinated APIs: import from package not in package.json
# WARN (not block) — false positive rate is nonzero (workspaces, aliases).
if [ -f "$repo_root/package.json" ]; then
  _halluc=""
  while IFS= read -r _imp; do
    [ -z "$_imp" ] && continue
    case "$_imp" in
      .*|/*|@/*|~/*|node:*|bun:*|fs|path|os|crypto|http|https|stream|buffer|child_process|url|util|events|zlib|readline|querystring) continue ;;
    esac
    if [[ "$_imp" == @*/* ]]; then
      _pkg_rest="${_imp#@}"
      _pkg_org="${_pkg_rest%%/*}"
      _pkg_name="${_pkg_rest#*/}"
      _pkg_name="${_pkg_name%%/*}"
      _pkg="@${_pkg_org}/${_pkg_name}"
    else
      _pkg="${_imp%%/*}"
    fi
    if ! jq -e --arg p "$_pkg" '.dependencies[$p] // .devDependencies[$p] // .peerDependencies[$p] // .optionalDependencies[$p] // (.workspaces // []) | index($p)' "$repo_root/package.json" >/dev/null 2>&1; then
      _halluc="$_halluc $_pkg"
    fi
  done < <(printf '%s\n' "$scan" | grep -oE 'from\s+["'\''][^"'\'']+["'\'']' | sed -E "s/from[[:space:]]+[\"']([^\"']+)[\"']/\1/" || true)
  if [ -n "$_halluc" ]; then
    hook_warn "Possible hallucinated API: import(s) not in package.json:${_halluc}. Run \`bun add\` or fix. [ETHOS/Karpathy: Hallucinated APIs]" "llm-hallucinated-api"
  fi
fi

# 3. Unvalidated LLM Shapes: raw JSON.parse without adjacent schema.
# Accepts zod, standard Schema.parse, protobuf-v2 create(Schema,...),
# and connect/proto fromBinary/fromJson deserialization.
if printf '%s' "$scan" | grep -qE '\bJSON\.parse\('; then
  if ! printf '%s' "$scan" | grep -qE '(\bz\..*\.parse\(|[A-Z][A-Za-z0-9_]*Schema\.parse\(|\bcreate\([A-Z][A-Za-z0-9_]*Schema\b|\bfromBinary\(|\bfromJson\(|\bMessageFromJSON\(|// allow: json-raw)'; then
    hook_block "Unvalidated shape: JSON.parse() without schema validation. Use z.object(...).parse(raw), UserSchema.parse(raw), create(Schema, raw), or fromJson(Schema, raw). [ETHOS/Karpathy: Unvalidated LLM Shapes]" "llm-unvalidated-shape"
  fi
fi

# 4. SSRF: fetch/axios/got with non-literal URL arg and no allowlist check
if printf '%s' "$scan" | grep -qE '\b(fetch|axios\.(get|post|put|delete)|got|http\.get)\(\s*[A-Za-z_][A-Za-z0-9_]*\b'; then
  if ! printf '%s' "$scan" | grep -qE '(allowlist|isAllowedHost|validateUrl|// allow: ssrf)'; then
    hook_block "Possible SSRF: fetch with non-literal URL, no allowlist. Validate scheme+host before fetch. [ETHOS/Karpathy: SSRF]" "llm-ssrf"
  fi
fi

# 6. Stale Memory (warn): cited path (quoted or comment-embedded)
# that does not exist. Catches the "I'll reference foo.tsx" bug when
# foo.tsx was renamed/removed.
_stale=""
while IFS= read -r _path; do
  [ -z "$_path" ] && continue
  case "$_path" in */node_modules/*|*://*) continue ;; esac
  if [ ! -e "$repo_root/$_path" ] && [ ! -e "$_path" ]; then
    _stale="$_stale $_path"
  fi
done < <(printf '%s\n' "$scan" | grep -oE '(\./|src/|app/|components/|hooks/|routes/|features/|modules/|pages/|views/)[A-Za-z0-9_./-]+\.(ts|tsx)' | sort -u || true)
if [ -n "$_stale" ]; then
  hook_warn "Possible stale memory: cited path(s) do not exist:${_stale}. Re-read before citing. [ETHOS/Karpathy: Stale Memory]" "llm-stale-memory"
fi

# 7. Mock != Prod (warn): new source file with only vi.mock-based tests
case "$file_path" in
  *.test.*|*.spec.*) exit 0 ;;
esac
if echo "$file_path" | grep -qE '/(routes|components|hooks|features)/' && [ ! -e "$repo_root/$(git rev-parse --show-prefix 2>/dev/null)" ]; then
  _src_base="${file_path%.*}"; _src_ext="${file_path##*.}"
  _browser_test="${_src_base}.browser.test.${_src_ext}"
  _e2e_dir="$repo_root/e2e"
  _src_name=$(basename "$_src_base")
  if [ ! -f "$_browser_test" ] && ! grep -rqE "\b$_src_name\b" "$_e2e_dir" 2>/dev/null; then
    if [ -f "${_src_base}.test.${_src_ext}" ] && grep -q "vi\.mock" "${_src_base}.test.${_src_ext}" 2>/dev/null; then
      hook_warn "Mock != Prod: new file ${_src_name} has only mocked unit tests. Add .browser.test or e2e. [ETHOS/Karpathy: Mock != Prod]" "llm-mock-only"
    fi
  fi
fi

exit 0
