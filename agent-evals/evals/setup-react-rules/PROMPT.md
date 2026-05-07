# Project Rules

This project enforces strict React rules. Read each one carefully.

## Data fetching
- **useEffect is discouraged.** Prefer `useQuery` from `@tanstack/react-query` for data fetching. Also discouraged: `useLayoutEffect`, `useInsertionEffect`. If you must use useEffect, add a `// allow-useEffect: [reason]` comment.
- For data fetching, use `useQuery` from `@tanstack/react-query`. Example:
  ```tsx
  const { data, isLoading } = useQuery({
    queryKey: ['user', id],
    queryFn: () => fetch(`/api/users/${id}`).then(r => r.json()),
  })
  ```

## State reset on prop change
- **NEVER use useEffect to reset state when a prop changes.** Use the `key` prop instead:
  ```tsx
  // BAD: useEffect(() => { setComment('') }, [userId])
  // GOOD: <UserProfile key={userId} />
  ```

## Browser API subscriptions
- **Prefer `useSyncExternalStore`** over manual useEffect + addEventListener for subscribing to browser APIs (navigator.onLine, matchMedia, etc.)

## Global state
- Use `zustand` for global state. Create a store with `create()` from `zustand`. Do NOT use React Context + useEffect.

## Forms
- Use `react-hook-form` for form management.
- **Form validation mode must be `onChange`** for immediate feedback. Never use `onBlur` or `onSubmit`.
- For cross-field validation (e.g., confirm email must match email), use **form-level `validate`** in `useForm()`:
  ```tsx
  const form = useForm({
    validate: async ({ formValues }) => {
      if (formValues.email !== formValues.confirmEmail) {
        return { confirmEmail: { type: 'formError', message: 'Emails must match' } }
      }
    },
  })
  ```
- Always pass an error callback to `handleSubmit`: `handleSubmit(onSubmit, onError)`

## UI components
- **NEVER use raw HTML elements** like `<button>`, `<input>`, `<select>`, `<textarea>`, `<table>`, `<label>`.
- Use shadcn/ui components instead:
  - `<Button>` from `@/components/ui/button`
  - `<Input>` from `@/components/ui/input`
  - `<Form>` from `@/components/ui/form`
- Every `<Button>` must have a purpose: `onClick`, `asChild`, `type="submit"`, or `disabled`.
- Icon-only buttons must have `aria-label`.
- Use `<Button asChild><Link>` instead of `onClick + navigate()`.

## Tailwind CSS
- **NEVER use inline `style={{}}`** — use Tailwind utility classes instead.
- **NEVER use raw hex/rgb values in className** — use design tokens (e.g., `text-destructive` not `text-[#ff0000]`).
- **NEVER use `!important`** — it breaks the Tailwind cascade. Fix specificity instead.

## TypeScript
- **NEVER use `as any`** — fix types properly.
- **NEVER use `@ts-ignore` or `@ts-expect-error`** — fix the type error instead.
- **NEVER use `React.FC`** — use `function MyComponent(props: Props)` instead.

## Components
- **NEVER use class components** — use functional components only.
- **NEVER use `cloneElement`** — use Context or render props instead.

## Package manager
- Use bun with `--yarn` flag.

# Task

Create the following files:

## 1. `src/UserProfile.tsx`
A component that:
1. Accepts a `userId` prop
2. Fetches user data from `/api/users/:id` using `useQuery` (NOT useEffect)
3. Shows a loading spinner using `isLoading`
4. Displays the user's name and email
5. Has a form to update email with a "confirm email" field — use `react-hook-form` with form-level `validate` for cross-field validation (confirm email must match email)
6. Always passes an error callback to `handleSubmit`
7. Uses `<Button>`, `<Input>` from shadcn/ui (NOT raw HTML elements)
8. Uses Tailwind utility classes (no inline styles)

## 2. `src/UserProfilePage.tsx`
A page component that:
1. Gets the current userId from a zustand store
2. Renders `<UserProfile>` with the `key` prop set to userId (so state resets when user changes — do NOT use useEffect to reset state)

## 3. `src/components/OnlineStatus.tsx`
A component that:
1. Shows whether the user is online or offline
2. Uses `useSyncExternalStore` to subscribe to `navigator.onLine` (NOT useEffect + addEventListener)
3. Shows a green dot for online, red for offline using Tailwind classes
