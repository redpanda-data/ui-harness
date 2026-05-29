---
name: obsidian-vault
description: Search, create, and organize Obsidian notes with wikilinks and indexes.
---

# Obsidian Vault

Vault: `/mnt/d/Obsidian Vault/AI Research/`.

Flat root. Organize through `[[wikilinks]]` + `*Index.md` notes.

## Rules

- Note filenames: Title Case.
- Index notes aggregate related `[[Note Title]]` links.
- Put related links at bottom.
- Search before create.

## Commands

```bash
find "/mnt/d/Obsidian Vault/AI Research/" -name "*.md" | grep -i "keyword"
grep -rl "keyword" "/mnt/d/Obsidian Vault/AI Research/" --include="*.md"
grep -rl "\[\[Note Title\]\]" "/mnt/d/Obsidian Vault/AI Research/"
```

## Create

1. Title Case filename.
2. Write one unit of learning.
3. Add wikilinks to related notes.
4. Add/update index note if cluster exists.
