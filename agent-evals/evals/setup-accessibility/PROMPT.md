# Project Rules

This project enforces strict accessibility rules:
- Every `<img>` MUST have an `alt` attribute.
- Clickable `<div>` or `<span>` elements MUST have `role`, `tabIndex`, and a keyboard handler (`onKeyDown` or `onKeyUp`).
- Custom widgets with `role="combobox"` MUST have `aria-expanded` and `aria-controls`.
- Custom widgets with `role="dialog"` MUST have `aria-label` or `aria-labelledby`.
- Custom widgets with `role="tablist"` MUST have child `role="tab"` elements.
- NEVER use `onClick` on a `<div>` or `<span>` without also adding `onKeyDown` and `tabIndex`.
- Icon-only buttons MUST have `aria-label`.
- Use shadcn/ui components (e.g., `<Button>` from `@/components/ui/button`).

# Task

Create a React component at `src/SearchPanel.tsx` that:
1. Has an image with alt text describing what it shows
2. Has a custom combobox (div with role="combobox") with proper aria-expanded and aria-controls
3. Has a clickable div that opens a settings panel — with proper role, tabIndex, and keyboard handler
4. Has a dialog (div with role="dialog") with aria-labelledby pointing to a heading inside it
5. Has an icon-only button with aria-label
6. Uses Tailwind utility classes for styling
