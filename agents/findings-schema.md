# Structured Findings Schema

All reviewer agents (`self-reviewer`, `code-reviewer`, `adversarial-reviewer`) MUST output findings as a single JSON block. This enables programmatic triage, autofix routing, and cross-reviewer deduplication.

## Output Format

```json
{
  "reviewer": "self-reviewer | code-reviewer | adversarial-reviewer",
  "status": "APPROVED | CONCERNS | NEEDS_CHANGES",
  "findings": [
    {
      "title": "Missing null check on API response",
      "severity": "P0 | P1 | P2 | P3",
      "file": "src/components/UserProfile.tsx",
      "line": 42,
      "category": "security | type-safety | error-handling | accessibility | testing | maintainability | performance | simplification",
      "why_it_matters": "Impact description -- not symptom, not fix. Why this matters to production.",
      "autofix_class": "safe_auto | gated_auto | manual | advisory",
      "suggested_fix": "Concrete code change, or null if manual",
      "pre_existing": false,
      "confidence": 0.85
    }
  ],
  "testing_gaps": [
    "No test for error state when API returns 500",
    "Missing edge case: empty array response"
  ],
  "simplification_opportunities": [
    "handleSubmit and handleUpdate share 80% logic -- extract shared validator"
  ]
}
```

## Field Reference

### severity

| Level | Meaning | Action |
|-------|---------|--------|
| `P0` | Blocks merge: breakage, exploitable vuln, data loss | Fix immediately |
| `P1` | Should fix: defects in normal usage, breaking contracts | Fix before review |
| `P2` | Fix if easy: edge cases, perf regression, maintainability | Fix or acknowledge |
| `P3` | Discretionary: minor improvements, style nits | Skip or log |

### autofix_class

| Class | Meaning | Handling |
|-------|---------|----------|
| `safe_auto` | Trivial fix, no behavior change (missing import, typo, formatting) | Apply without asking |
| `gated_auto` | Likely correct but changes behavior (error handling, edge case fix) | Show to user, apply on confirmation |
| `manual` | Needs human judgment (architecture, trade-offs) | Report only |
| `advisory` | Informational, no action needed now | Log for compound phase |

### pre_existing

`true` if the issue existed before this session's changes (found in dirty baseline). Pre-existing findings are reported but NEVER block merge -- they're logged for future cleanup.

### confidence

Calibrated 0.0-1.0 per finding:
- **0.80+**: High -- can trace execution path to the issue
- **0.60-0.79**: Moderate -- pattern match but not fully verified
- **<0.60**: Low -- suspicion only, flag as advisory

## Rules

1. Output MUST be a single fenced JSON code block (` ```json ... ``` `)
2. `findings` array MAY be empty (when status is APPROVED)
3. Every finding MUST have all fields -- use `null` for `suggested_fix` when manual
4. `title` max 10 words -- it's a label, not an explanation
5. `why_it_matters` explains impact, not symptom -- "Users see stale data after mutation" not "Missing cache invalidation"
6. Deduplicate: if same issue appears in multiple files, report once with the most impactful instance
