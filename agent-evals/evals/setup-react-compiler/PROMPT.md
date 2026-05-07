# Project Rules

This project has **React Compiler** (babel-plugin-react-compiler) enabled in rsbuild.config.ts. The compiler automatically memoizes components, hooks, and callbacks at build time.

**Because the compiler handles memoization automatically:**
- DO NOT use `useMemo` — the compiler memoizes values automatically
- DO NOT use `useCallback` — the compiler memoizes callbacks automatically
- DO NOT use `React.memo()` or `memo()` wrapper — the compiler memoizes components automatically
- DO NOT import `useMemo`, `useCallback`, or `memo` from React

Just write plain functions, plain callbacks, and plain components. The compiler optimizes them.

**Escape hatch:** If a file must opt out of the compiler, add `'use no memo'` as the first line.

# Task

Create a file `src/Dashboard.tsx` with a dashboard component that:
1. Computes chart data from a raw dataset (just write the computation inline — no useMemo needed, the compiler handles it)
2. Passes an `onSelect` callback to a `<ChartItem>` child component (just write a regular function — no useCallback needed)
3. Defines a `ChartItem` child component in the same file (just export it as a regular function component — no React.memo needed)

Write simple, clean code. No memoization hooks or wrappers. The React Compiler does it for you.
