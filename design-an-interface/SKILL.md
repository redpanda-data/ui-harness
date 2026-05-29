---
name: design-an-interface
description: "DEPRECATED. Prefer `/prototype` for design exploration and runnable UI variations. Do not use unless user explicitly says `/design-an-interface` or asks for legacy skill."
---

> Deprecated: prefer replacement named in description. Keep only for backward compatibility.

# Design an Interface

"Design It Twice" (A Philosophy of Software Design): first idea rare best. Generate radical different designs, compare.

## Workflow

### 1. Gather Requirements
- Problem? Callers? Key ops? Constraints? Hide vs expose?
- Ask: "What does this module need to do? Who will use it?"

### 2. Generate Designs (Parallel Sub-Agents)
Spawn 3+ agents parallel. Each **radical different** approach, different constraint:
- Agent 1: min method count (1-3 max)
- Agent 2: max flexibility
- Agent 3: optimize common case
- Agent 4: inspiration from [specific paradigm]

Each output: interface signature, usage example, what hides, trade-offs.

### 3. Present Designs
Show sequential: signature, usage, what hides. User absorb each before compare.

### 4. Compare
- Interface simplicity (fewer methods, simpler params)
- General-purpose vs specialized
- Implementation efficiency
- Depth: small interface hide complexity (good) vs large interface thin impl (bad)
- Ease correct use vs ease misuse

Discuss prose, no tables. Highlight divergence points.

### 5. Synthesize
Best design often combine insights. Ask: "Which fits your case? Any elements from others worth incorporating?"

## Anti-Patterns
- Similar designs waste exercise -- enforce radical difference
- Always compare -- value in contrast
- Interface shape only -- no implement
- Ignore implementation effort in evaluation
