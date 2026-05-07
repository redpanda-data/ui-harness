# Project Rules

This project enforces environment variable validation:
- **NEVER access `process.env.X` directly.** Import from `@/env` instead.
- All environment variables MUST be declared in `src/env.ts` using t3-env + zod.
- The `src/env.ts` file is the single source of truth for all env vars.
- Use bun with `--yarn` flag.

# Task

Create these files:

1. `src/env.ts` — environment validation using t3-env + zod with these variables:
   - `DATABASE_URL` (required string)
   - `API_KEY` (required string)
   - `NODE_ENV` (enum: development, production, test)

2. `src/config.ts` — configuration module that imports validated env vars from `@/env` (NOT from `process.env`) and exports typed config values
