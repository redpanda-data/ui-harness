---
name: redpanda-frontend-kit
description: Meta-skill that runs the generic frontend-starter-kit plus additional React skills and Redpanda-specific registry workflow. Use when bootstrapping a new Redpanda frontend project or setting up the full Redpanda frontend stack.
---

# Redpanda Frontend Kit

Run **frontend-starter-kit** (14 setup + workflow skills), then add Redpanda tooling.

## Additional Setup

### Redpanda-specific
- **setup-registry-workflow** -- UI registry component workflow

### Redpanda environment (session-env.sh)
```bash
echo "export UI_LIB_DIRS=components/ui|redpanda-ui" >> "$CLAUDE_ENV_FILE"
echo "export REDPANDA_KIT=1" >> "$CLAUDE_ENV_FILE"
```
`REDPANDA_KIT=1` enables registry nudges (useProtoForm, Typography, KeyValueField, registry sync).

### Chakra UI ban (add to react-rules-check.sh)
```bash
if echo "$added_lines" | grep -qE "from\s+['\"]@chakra-ui/"; then
  echo '{"suppressOutput":true,"systemMessage":"@chakra-ui/react banned. Use @/components/ui/."}' >&2
  exit 2
fi
if echo "$added_lines" | grep -qE "from\s+['\"]@redpanda-data/ui['\"/]"; then
  echo '{"suppressOutput":true,"systemMessage":"@redpanda-data/ui legacy (Chakra). Use redpanda-ui registry."}' >&2
  exit 2
fi
```

## Steps
1. Run frontend-starter-kit (all 14 setup + workflow + community skills)
2. Configure Redpanda env vars
3. Add Chakra ban to react-rules-check.sh
4. Run setup-registry-workflow

## Verify
- [ ] All hooks executable, settings.json complete
- [ ] `REDPANDA_KIT=1` in session env
- [ ] connect-query-check.sh match detected protobuf version