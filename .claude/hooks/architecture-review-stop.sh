#!/bin/bash
set -eo pipefail

# Stop hook: pre-PR architecture self-review.
# Scans session-changed files for structural issues before PR creation.
# Runs BEFORE lifecycle-stop so problems are caught before push.
#
# Checks:
#   1. Large files (>300 LOC in route files, >400 LOC elsewhere)
#   2. Custom hooks defined in route files (should be in /hooks/)
#   3. Missing errorComponent on routes with loaders
#   4. Missing test files for new components/hooks
#   5. Inline mutations (fetch with method: outside useMutation)
#
# Route detection: by content (createFileRoute/createRoute imports),
# not just /routes/ path — supports any directory structure.

source "$(dirname "$0")/../../shared/hook-lib.sh" 2>/dev/null || true

# Need session tracking
if ! hook_has_session_tracking 2>/dev/null; then
  exit 0
fi

# Get session-changed code files
changed=$(hook_session_changed_files "ts|tsx" 2>/dev/null || true)
if [ -z "$changed" ]; then
  exit 0
fi

issues=""
issue_count=0

_add_issue() {
  issues="${issues}\n- $1"
  issue_count=$((issue_count + 1))
}

# Detect if file is a route file by content or path
_is_route_file() {
  local f="$1"
  # Path-based: /routes/ dir is strong signal
  if echo "$f" | grep -qE '/routes/'; then
    return 0
  fi
  # Content-based: createFileRoute or createRoute import
  if grep -qE 'createFileRoute|createRoute|createLazyRoute' "$f" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Detect if file is a component/hook (worth testing)
_is_testable_file() {
  local f="$1"
  # Path-based
  if echo "$f" | grep -qE '/(routes|components|hooks|pages|features|modules|views)/'; then
    return 0
  fi
  # Content-based: React component or hook
  if grep -qE 'export\s+(default\s+)?function\s+[A-Z]|export\s+const\s+[A-Z].*=.*=>|function\s+use[A-Z]' "$f" 2>/dev/null; then
    return 0
  fi
  return 1
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

while IFS= read -r file; do
  [ -z "$file" ] && continue
  full_path="$repo_root/$file"
  [ -f "$full_path" ] || continue

  # Skip test/generated files
  case "$file" in
    *.test.*|*.spec.*|*.gen.*|*_pb.*|*_connectquery.*) continue ;;
  esac

  loc=$(wc -l < "$full_path" | tr -d ' ')
  is_route=false
  _is_route_file "$full_path" && is_route=true

  # ── Check 1: File size ───────────────────────────────────────
  if [ "$is_route" = true ] && [ "$loc" -gt 300 ]; then
    _add_issue "**${file}** is ${loc} LOC (route limit: 300). Run \`/request-refactor-plan\`."
  elif [ "$loc" -gt 400 ]; then
    _add_issue "**${file}** is ${loc} LOC (limit: 400). Consider splitting."
  fi

  # ── Check 2: Custom hooks in route files ─────────────────────
  if [ "$is_route" = true ]; then
    inline_hooks=$(grep -cE '^\s*(export\s+)?function\s+use[A-Z]' "$full_path" 2>/dev/null || echo "0")
    if [ "$inline_hooks" -gt 0 ]; then
      _add_issue "**${file}** has ${inline_hooks} inline hook(s). Move to \`/hooks/\` directory."
    fi
  fi

  # ── Check 3: Missing errorComponent ──────────────────────────
  if [ "$is_route" = true ]; then
    if grep -qE '\bloader\s*:|loaderFn\s*:|beforeLoad\s*:' "$full_path" 2>/dev/null; then
      if ! grep -qE '\berrorComponent\s*:' "$full_path" 2>/dev/null; then
        _add_issue "**${file}** has loader but no \`errorComponent\`."
      fi
    fi
  fi

  # ── Check 4: (removed — test coverage enforced at feature level by lifecycle-stop.sh)

  # ── Check 5: Inline mutations ────────────────────────────────
  if [ "$is_route" = true ]; then
    if grep -qE "method:\s*['\"]?(DELETE|POST|PUT|PATCH)" "$full_path" 2>/dev/null; then
      if ! grep -qE 'mutationFn|useMutation' "$full_path" 2>/dev/null; then
        _add_issue "**${file}** has inline side-effect fetch. Use \`useMutation\` in a hook."
      fi
    fi
  fi

done <<< "$changed"

if [ "$issue_count" -gt 0 ]; then
  hook_stop_finding "$(printf "Architecture: %s issue(s):%b" "$issue_count" "$issues")"
fi

exit 0
