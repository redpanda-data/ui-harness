# Project Rules

This project enforces zustand best practices:
- Use **double-parens** `create<T>()()` pattern (NOT single-parens `create<T>()`).
- For selecting multiple values from a store, use **`useShallow`** wrapper (NOT inline object selectors like `(state) => ({ a: state.a, b: state.b })`).
- **NEVER use `localStorage` directly** in zustand stores. Use the `persist` middleware instead.
- Use bun with `--yarn` flag.

# Task

Create a zustand store at `src/stores/settings-store.ts` that:
1. Uses the double-parens `create<T>()()` pattern
2. Has fields: `theme` (string), `language` (string), `sidebarOpen` (boolean)
3. Has actions: `setTheme`, `setLanguage`, `toggleSidebar`
4. Uses persist middleware to save to sessionStorage (NOT direct localStorage)

Then create `src/components/SettingsPanel.tsx` that:
1. Uses the store with `useShallow` for selecting multiple values (NOT inline object selectors)
2. Renders controls for theme, language, and sidebar toggle
3. Uses `<Button>` from `@/components/ui/button` (NOT raw `<button>`)
