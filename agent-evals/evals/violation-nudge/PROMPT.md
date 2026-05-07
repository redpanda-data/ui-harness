# Project Rules

This project enforces zustand best practices via PostToolUse hooks:
- Use **double-parens** `create<T>()()` pattern (NOT single-parens `create<T>()`).
- For selecting multiple values from a store, use **`useShallow`** wrapper.
- **NEVER use `localStorage` directly** — use the `persist` middleware.

A mid-session violation nudge hook is active: if you trigger the same hook block 3+ times, you will receive a `[VIOLATION PATTERN]` message telling you to adjust your approach.

# Task

Create three zustand stores at:
1. `src/stores/auth-store.ts` — fields: `token` (string), `isLoggedIn` (boolean); actions: `login`, `logout`; persist to localStorage via middleware
2. `src/stores/theme-store.ts` — fields: `mode` (string), `fontSize` (number); actions: `setMode`, `setFontSize`; persist to localStorage via middleware
3. `src/stores/cart-store.ts` — fields: `items` (array), `total` (number); actions: `addItem`, `removeItem`, `clear`; persist to localStorage via middleware

Then create `src/components/Dashboard.tsx` that uses all three stores with `useShallow` for multi-value selectors.
