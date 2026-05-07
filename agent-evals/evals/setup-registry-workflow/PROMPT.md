# Project Rules

This project is a UI component registry (shadcn-style). Read each rule carefully.

## Component Taxonomy

Every component must be classified as Atom, Molecule, or Organism based on:
- useState count: 0-1 = Atom, 2 = Molecule, 3+ = Organism
- Registry imports: 0 = Atom, 1-2 = Molecule, 3+ = Organism
- Custom keyboard handlers: 0 = Atom, 1-10 lines = Molecule, 10+ = Organism
- Portal usage: No = Atom, Maybe = Molecule, Often = Organism

Atoms: single-responsibility primitives, pure presentation via props.
Molecules: combine 2-3 atoms, limited local state.
Organisms: compose multiple molecules/atoms, significant state, custom keyboard nav, portals.

## Functional Programming

- Components are pure render functions — no side effects in render body
- All side effects in hooks (useEffect/useCallback/custom hooks), never in component body
- Immutable state updates only — spread, map, filter, concat. Never mutate state.
- Derive values with useMemo instead of useState + useEffect sync
- 3+ interrelated useState → consolidate into useReducer with pure reducer function defined OUTSIDE component
- Extract data transformations into named pure functions

## Registry Workflow

- When modifying registry components, always rebuild registry.json
- Never upstream business logic (string equality checks on business data, feature flags, API endpoints)
- Import differences between registry (@/components/X) and consumers (../components/X) are noise, not drift

## Type Safety

- Use discriminated unions for variant prop types
- Use generics for reusable components
- Export all prop interfaces
- Extend native elements with React.ComponentProps<'element'>

## Package Manager

- Use bun with `--yarn` flag.

# Task

Create the following files:

## 1. `src/components/StatusBadge.tsx`

An **Atom** component that:
1. Accepts `variant` prop: 'success' | 'warning' | 'error' | 'info'
2. Accepts `children` prop for label text
3. Uses discriminated union props: when variant is 'error', accepts optional `onRetry` callback
4. Uses class-variance-authority (cva) for variant styling
5. Forwards ref and spreads remaining props to root element
6. Exports the prop interface
7. Has ZERO useState — pure presentation
8. NO side effects in the component body

## 2. `src/components/StatusFilter.tsx`

A **Molecule** component that:
1. Composes StatusBadge + Button from the registry
2. Has exactly 2 useState: selectedStatus and isExpanded
3. Derives filtered items using useMemo (NOT useState + useEffect)
4. Accepts items array via generic prop `<T extends { status: string }>`
5. Uses immutable state updates only (no .push, .splice, etc.)

## 3. `src/components/StatusDashboard.tsx`

An **Organism** component that:
1. Composes StatusFilter + StatusBadge + Card + Dialog from the registry
2. Uses useReducer (NOT 3+ useState) for interrelated state: selectedItem, filterStatus, isDialogOpen
3. Reducer function defined OUTSIDE the component
4. Includes keyboard handler for Escape to close dialog
5. Renders Dialog as a portal component
6. Extracts data transformation (groupByStatus) as a named pure function outside component
7. NO direct state mutation anywhere
8. NO useState + useEffect sync pattern
