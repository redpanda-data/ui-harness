# Out-of-Scope Knowledge Base

`.out-of-scope/` dir in repo store persistent records of rejected feature requests. Two purposes:

1. **Institutional memory** -- why feature rejected, so reasoning not lost when issue closed
2. **Deduplication** -- new issue match prior rejection, skill surface previous decision instead of re-litigate

## Directory structure

```
.out-of-scope/
├── dark-mode.md
├── plugin-system.md
└── graphql-api.md
```

One file per **concept**, not per issue. Multiple issues for same thing grouped under one file.

## File format

Write relaxed, readable style -- more like short design doc than database entry. Use paragraphs, code samples, examples to make reasoning clear to first-time reader.

```markdown
# Dark Mode

This project does not support dark mode or user-facing theming.

## Why this is out of scope

The rendering pipeline assumes a single color palette defined in
`ThemeConfig`. Supporting multiple themes would require:

- A theme context provider wrapping the entire component tree
- Per-component theme-aware style resolution
- A persistence layer for user theme preferences

This is a significant architectural change that doesn't align with the
project's focus on content authoring. Theming is a concern for downstream
consumers who embed or redistribute the output.

```ts
// The current ThemeConfig interface is not designed for runtime switching:
interface ThemeConfig {
  colors: ColorPalette; // single palette, resolved at build time
  fonts: FontStack;
}
```

## Prior requests

- #42 -- "Add dark mode support"
- #87 -- "Night theme for accessibility"
- #134 -- "Dark theme option"
```

### Naming the file

Short, descriptive kebab-case concept name: `dark-mode.md`, `plugin-system.md`, `graphql-api.md`. Name recognizable enough that browser of dir understand what rejected without opening file.

### Writing the reason

Reason substantive -- not "we don't want this" but why. Good reasons reference:

- Project scope/philosophy ("This project focuses on X; theming is a downstream concern")
- Technical constraints ("Supporting this would require Y, which conflicts with our Z architecture")
- Strategic decisions ("We chose to use A instead of B because...")

Reason durable. Avoid temporary circumstances ("we're too busy right now") -- those not real rejections, just deferrals.

## When to check `.out-of-scope/`

During triage (Step 1: Gather context), read all files in `.out-of-scope/`. When evaluating new issue:

- Check if request matches existing out-of-scope concept
- Match by concept similarity, not keyword -- "night theme" matches `dark-mode.md`
- If match, surface to maintainer: "This is similar to `.out-of-scope/dark-mode.md` -- we rejected this before because [reason]. Do you still feel the same way?"

Maintainer may:

- **Confirm** -- new issue added to existing file's "Prior requests" list, then closed
- **Reconsider** -- out-of-scope file deleted or updated, issue proceeds through normal triage
- **Disagree** -- issues related but distinct, proceed with normal triage

## When to write to `.out-of-scope/`

Only when **enhancement** (not bug) rejected as `wontfix`. Flow:

1. Maintainer decides feature request out of scope
2. Check if matching `.out-of-scope/` file exists
3. If yes: append new issue to "Prior requests" list
4. If no: create new file with concept name, decision, reason, first prior request
5. Post comment on issue explaining decision, mention `.out-of-scope/` file
6. Close issue with `wontfix` label

## Updating or removing out-of-scope files

If maintainer changes mind about previously rejected concept:

- Delete `.out-of-scope/` file
- Skill not need reopen old issues -- they historical records
- New issue that triggered reconsideration proceeds through normal triage