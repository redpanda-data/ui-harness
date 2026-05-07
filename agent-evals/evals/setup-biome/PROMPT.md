# Project Rules

This project enforces strict code quality rules:
- `moment` is BANNED. Use `date-fns` instead.
- `classnames` is BANNED. Use `clsx` or `cn` instead.
- `console.log` is BANNED in production code. Remove all console statements.
- **NEVER run `bunx biome` or `bunx @biomejs/biome` directly.** Biome is only run via package.json scripts: `bun run lint` (check) or `bun run lint:fix` (auto-fix). If you need to check or fix lint issues, use `bun run lint:fix`.
- Use bun as package manager with `--yarn` flag.

# Task

Create a file `src/Counter.tsx` with a counter component that:
- Uses `useState` for the count
- Shows the current time using `date-fns` `format()` function (NOT moment)
- Has a CSS class applied conditionally using `clsx` (NOT classnames)
- Has a button to increment

Write clean code that follows the rules above. Do NOT run any linting commands — the project's CI handles that automatically.
