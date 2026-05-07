#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/_hook-lib.sh"

hook_parse_edit_write
hook_filter_extensions "ts|tsx"

# Skip files where process.env is correct (build config, env definitions, scripts)
case "$(basename "$file_path")" in
  env.ts|env.mts|env.mjs|env.js) exit 0 ;;
  rsbuild.config.*|vite.config.*|webpack.config.*) exit 0 ;;
  next.config.*|nuxt.config.*|astro.config.*) exit 0 ;;
  vitest.config.*|jest.config.*|playwright.config.*) exit 0 ;;
  tailwind.config.*|postcss.config.*|biome.jsonc) exit 0 ;;
  tsconfig.*|.eslintrc.*|.prettierrc.*) exit 0 ;;
  Dockerfile|docker-compose.*) exit 0 ;;
esac

# Skip config directories
if echo "$file_path" | grep -qE '(config/|scripts/|\.config\.)'; then
  exit 0
fi

hook_skip_tests
hook_get_added_lines

# Check for raw process.env access (exclude build-time constants)
if echo "$added_lines" | grep -vE 'process\.env\.(NODE_ENV|DEV|PROD|SSR|TEST)' | grep -qE 'process\.env\.'; then
  hook_block "No raw process.env. Import from @/env. Declare vars in src/env.ts with t3-env+zod. Exception: NODE_ENV."
fi

exit 0
