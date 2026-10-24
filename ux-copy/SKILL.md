---
name: ux-copy
description: Write or review product UI copy. Use when changing headings, labels, buttons, help, messages, navigation, i18n strings, or product terminology.
---

Read the complete [upstream skill](.upstream/ux-copy/SKILL.md) and
[reference](REFERENCE.md). Resolve upstream links from `.upstream/ux-copy/`.
[Provenance and refresh](UPSTREAM.md) pin the unchanged source snapshot.

## Host rules

These rules override upstream installation and hook semantics:

- Writing or review never installs hooks. Use [setup-ux-copy](../setup-ux-copy/SKILL.md)
  only when configuration is requested; preserve existing host settings.
- The active `setup-ux-copy` scripts retain this harness's block/warn behavior.
  Upstream's warning-only scripts are reference material, not wired hooks.
- [`scripts/ux-copy-context.sh`](scripts/ux-copy-context.sh) injects upstream guidance
  and these overrides for UI source and translation paths through PreToolUse.
  Project instructions cover hosts without hooks. Delivery does not prove tone.
