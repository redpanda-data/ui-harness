---
name: setup-accessibility
description: Enforce ARIA accessibility via PostToolUse hooks -- labels, keyboard handlers, widget attributes, Playwright AXE setup. Use when setting up a11y enforcement, WCAG 2.1 AA compliance, or accessibility testing.
paths:
  - "src/components/**/*.tsx"
---

# Accessibility Enforcement

## What This Catches

- **`<img>` without `alt`** -- use `alt=""` for decorative img
- **Mouse-only `onClick` on `<div>`/`<span>`** -- needs `role` + `tabIndex` + `onKeyDown`/`onKeyUp`
- **Missing ARIA on widget roles** -- `role="combobox"` needs `aria-expanded` + `aria-controls`, `role="dialog"` needs `aria-label`/`aria-labelledby`, `role="tablist"` needs child `role="tab"`

Escape hatch: `// allow: a11y-skip [reason]`

## No Nested Pressables

Interactive components ONE pattern -- never both:

**Pattern A: Container clickable** -- no interactive children.
```tsx
<ListCard onClick={handleSelect}>
  <Avatar src={user.avatar} />
  <Text>{user.name}</Text>
  <ChevronRightIcon /> {/* visual indicator only, not a button */}
</ListCard>
```

**Pattern B: Children interactive** -- container not clickable.
```tsx
<ListCard>
  <Avatar src={user.avatar} />
  <Text>{user.name}</Text>
  <DropdownMenu>
    <DropdownMenuTrigger asChild>
      <Button variant="ghost" size="icon"><MoreVerticalIcon /></Button>
    </DropdownMenuTrigger>
  </DropdownMenu>
</ListCard>
```

Why: ambiguous click targets, event bubbling bugs, screen readers can't convey interaction model, touch targets overlap on mobile.

## Visual Checklist

- [ ] Focus rings visible on all interactive elements (min 2px, contrasting color)
- [ ] Hover and focus styles match (no mouse-only affordances)
- [ ] Color not sole means of conveying info
- [ ] Touch targets min 44x44 CSS pixels
- [ ] `prefers-reduced-motion` respected for animations
- [ ] `forced-colors` / high-contrast mode: use `currentcolor` for SVG fills
- [ ] Text resizable to 200% without content loss

Initial setup (install, AXE fixture, hook config): see [SETUP.md](SETUP.md).