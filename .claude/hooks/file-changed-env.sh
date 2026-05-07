#!/bin/bash
set -eo pipefail
trap 'exit 0' ERR

# FileChanged matcher: src/env.ts
# Env schema is the contract between app and deployment. Change must
# propagate to .env.example, deployment secrets, and CI pipeline vars.

input=$(cat 2>/dev/null || echo '{}')
file=$(echo "$input" | jq -r '.filename // .file_path // empty' 2>/dev/null)
[ -n "$file" ] || exit 0

case "$file" in
  */src/env.ts|src/env.ts)
    msg="src/env.ts changed. Env contract modified. Update: (1) .env.example with new vars + defaults, (2) deployment secrets (1Password/AWS/k8s), (3) .github/workflows/*.yml env blocks. Missing vars will cause runtime crash, not type error."
    echo "{\"suppressOutput\":true,\"systemMessage\":\"[env] $msg\"}" >&2
    ;;
esac

exit 0
