#!/bin/bash
set -eo pipefail
trap 'exit 0' ERR

# FileChanged matcher: biome.jsonc, tsconfig.json, tsconfig.*.json, vitest.config.*
# Config that affects the whole project. A change may flip lint/type
# results across many files silently.

input=$(cat 2>/dev/null || echo '{}')
file=$(echo "$input" | jq -r '.filename // .file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

msg=""
case "$file" in
  */biome.jsonc|biome.jsonc|*/biome.json|biome.json)
    msg="Biome config changed. Rules may now flag previously clean files. Run \`bun run lint\` across the project, not just changed files."
    ;;
  */tsconfig.json|tsconfig.json|*/tsconfig.*.json|tsconfig.*.json)
    msg="tsconfig changed. Compiler options shift may break type:check project-wide. Run \`bun run type:check\` on full project before committing."
    ;;
  */vitest.config.*|vitest.config.*)
    msg="Vitest config changed. Test include/exclude or environment may have shifted. Run full \`bun run test\` to verify all tests still collected."
    ;;
esac

[ -n "$msg" ] || exit 0
echo "{\"suppressOutput\":true,\"systemMessage\":\"[config] $msg\"}" >&2
exit 0
