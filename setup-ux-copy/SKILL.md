---
name: setup-ux-copy
description: Install UX-string and prose-style hooks. Use when configuring copy checks or Redpanda capitalization; use ux-copy to write or review UI text.
---

Install hooks; do not use regex results as a tone verdict. For writing or review, read
[ux-copy](../ux-copy/SKILL.md) and its [reference](../ux-copy/REFERENCE.md).

## Install

1. Copy executable `scripts/ux-copy-check.sh`, `scripts/prose-style-check.sh`, and
   `scripts/_hook-lib.sh` into the project's `.claude/hooks/`.
2. Add both check scripts to PostToolUse `Edit|Write`, preserving existing hooks.
3. Bundle the sibling `ux-copy/` skill, including its hidden `.upstream/` snapshot,
   scripts, reference and evals. Preserve symlinks within the bundle.
   Expose it through the host's project skill directory. For Claude, configure its
   `scripts/ux-copy-context.sh` on PreToolUse `Read|Edit|Write`; use an absolute path
   or quote `${CLAUDE_PROJECT_DIR}`. Other hosts need scoped instructions to read it.
4. Use [GLOSSARY.md](GLOSSARY.md) for Redpanda capitalization when appropriate.
   `REDPANDA_KIT=1` enables product-name checks.

## Boundaries

The UX hook blocks selected TS/TSX violations, including exclamation points,
"successfully", generic link text, Yes/No buttons and non-inclusive terms. Other
patterns warn. JSX and i18n need semantic review. The prose hook checks Markdown,
not conversational replies. Keep both scripts' existing behavior.

Reasoned escapes: `// allow: ux-copy [reason]`, legacy `// allow-ux-copy: [reason]`,
and `<!-- allow: prose-style [reason] -->`. They exempt the file, not the review.

## Verify

Trigger the actual configured events: bad TSX reports the existing block, bad Markdown
reports prose feedback, and TSX/i18n paths receive UX-copy context. Clean source passes;
generated files and unrelated JSON stay silent. Confirm hook activation in each host.
Context delivery proves wiring, not model compliance or tone improvement.
