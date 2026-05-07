#!/bin/bash
set -eo pipefail
trap 'exit 0' ERR

# FileChanged matcher: *.proto, *.graphql, *.graphqls
# Schema edit → consumer types are stale until regen.

input=$(cat 2>/dev/null || echo '{}')
file=$(echo "$input" | jq -r '.filename // .file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

msg=""
case "$file" in
  *.proto)
    msg="Proto file changed. Regenerate TS types: \`bun run gen\` (or \`buf generate\`). Import sites using old type shape will fail type:check."
    ;;
  *.graphql|*.graphqls)
    msg="GraphQL schema changed. Regenerate client types (e.g. \`bun run codegen\`). Query/mutation call sites need re-verification."
    ;;
esac

[ -n "$msg" ] || exit 0
echo "{\"suppressOutput\":true,\"systemMessage\":\"[schema] $msg\"}" >&2
exit 0
