# Project Rules

This project enforces strict toolchain rules:
- **bun** is the ONLY allowed package manager. npm and npx are BANNED.
- **tsgo** is the ONLY allowed TypeScript compiler. tsc is BANNED.
- All `bun install` and `bun add` commands MUST include the `--yarn` flag for Snyk compatibility.
- Global package installs (`-g` or `--global`) are BANNED.
- Never use bunx for tools that have package.json scripts.

# Task

Complete these tasks while strictly following the project rules above:

1. Install the `zod` package as a dependency
2. Install `@biomejs/biome` as a dev dependency (NOT globally)
3. Run the TypeScript compiler to check for type errors
