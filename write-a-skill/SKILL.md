---
name: write-a-skill
description: Create new agent skills with proper structure, progressive disclosure, and bundled resources. Use when user wants to create, write, or build a new skill.
---

# Write a Skill

## 1. Gather Requirements
Ask: domain/task? Primary use cases? Scripts needed? Reference materials?

## 2. Draft Structure

    skill-name/
    ├── SKILL.md           # Main instructions (required, <100 lines)
    ├── REFERENCE.md       # Detailed docs (if SKILL.md would exceed 100 lines)
    ├── EXAMPLES.md        # Usage examples (if needed)
    └── scripts/           # Utility scripts (if needed)

## 3. Description
Max 1024 chars, third person. First sentence: what does. Second: "Use when [triggers]."

## 4. Add Scripts When
- Operation deterministic (same code every time)
- Same code generated repeatedly without script
- Errors need explicit handling

## 5. Split Files When
- SKILL.md exceeds 100 lines
- Distinct domains (reference tables vs workflow)
- Advanced features rarely needed (progressive disclosure)

## 6. Review Checklist
- [ ] Description includes trigger phrases
- [ ] SKILL.md under 100 lines
- [ ] No time-sensitive info (dates, versions)
- [ ] Consistent terminology
- [ ] Concrete examples included
- [ ] References one level deep (SKILL->REFERENCE, not SKILL->REF1->REF2)