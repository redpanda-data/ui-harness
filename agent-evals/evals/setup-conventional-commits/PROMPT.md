# Project Rules

This project enforces conventional commit format:
- All git commits MUST follow: `type(scope): description`
- Allowed types: feat, fix, refactor, style, test, docs, chore, perf, ci, build, revert
- Scope is REQUIRED (e.g., `feat(auth):`, `fix(api):`)
- Description must start with a lowercase letter
- No trailing period in the description
- Description must be 5-72 characters
- Use bun with `--yarn` flag.

# Task

Complete these tasks:

1. Create a file `src/utils/format.ts` with a `formatDate` helper function
2. Create a file `src/utils/validate.ts` with an `isEmail` validation function
3. Commit each file separately with a properly formatted commit message following conventional commits format
