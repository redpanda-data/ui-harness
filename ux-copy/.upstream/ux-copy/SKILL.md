---
name: ux-copy
description: Write or review product UI copy. Use when changing headings, labels, buttons, help, messages, navigation, i18n strings, or product terminology.
---

Read [REFERENCE.md](REFERENCE.md) for tone, capitalization, budgets, and examples.
State one useful point per sentence. Cut filler and repetition.
Preserve safety, limits, uncertainty, and accessible labels.
Use project glossary and canonical product names; [GLOSSARY.md](GLOSSARY.md) is product-specific.

## Write

Draft the shortest accurate string per element. Check the whole view.
Make only requested changes. Flag unverified facts; never invent behavior,
permissions, causes, or recovery. Do not imply human approval.

## Review

Read changed strings in context. Give location, exact quote, named pattern, rewrite/removal.
Relocate useful facts. A clean review names files read and distinct UI strings checked.
Report missing context; do not claim visual checks from source. Review does not edit.

## Scope and checks

Include TSX/JSX, navigation, i18n, and UI around chat. Exclude prose documentation,
generated reference descriptions, and conversational replies. Explicit project rules win.

Install executable PostToolUse `Edit|Write` hooks from `scripts/`: `ux-copy-check.sh`,
`prose-style-check.sh`, `_hook-lib.sh`. Preserve host configuration. UX checks warn on
selected TS/TSX patterns only; JSX/i18n need review. Verify host activation.
Escapes need reasons: `// allow: ux-copy [reason]`, `<!-- allow: prose-style [reason] -->`.

Tone evals: [evals/RUBRIC.md](evals/RUBRIC.md). Hook passes do not prove tone.
