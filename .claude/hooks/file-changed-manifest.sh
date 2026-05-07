#!/bin/bash
set -eo pipefail
trap 'exit 0' ERR

# FileChanged matcher: skill-manifest.json
# Auto-regenerate .claude/settings.json and hooks/hooks.json. Prevents
# drift bug (v2.2.0) from ever recurring — configs are always in sync
# with the manifest structurally, not through discipline.

input=$(cat 2>/dev/null || echo '{}')
file=$(echo "$input" | jq -r '.filename // .file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

case "$file" in
  */skill-manifest.json|skill-manifest.json) ;;
  *) exit 0 ;;
esac

root=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)
generator="$root/scripts/generate-hook-configs.sh"
[ -x "$generator" ] || exit 0

out=$("$generator" --apply 2>&1) || {
  echo "{\"suppressOutput\":true,\"systemMessage\":\"[manifest] Codegen FAILED: $out — configs may be stale.\"}" >&2
  exit 0
}

echo "{\"suppressOutput\":true,\"systemMessage\":\"[manifest] skill-manifest.json changed — .claude/settings.json and hooks/hooks.json regenerated.\"}" >&2
exit 0
