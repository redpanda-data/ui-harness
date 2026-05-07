# UX Copy Reference

## ux-copy-check.sh

> Script: [`scripts/ux-copy-check.sh`](scripts/ux-copy-check.sh)

## Escape Hatch

```tsx
// allow: ux-copy -- legacy string from external API
const message = "Operation completed successfully!"
```

Check `// allow: ux-copy` anywhere in file. Reason required. Legacy format `// allow-ux-copy:` work too.

## Capitalization

Sentence case all UI text. Capitalize first word only.

| Good | Bad |
|------|-----|
| Maximum number of topics | Maximum Number of Topics |
| Enable mTLS for Schema Registry | Enable mTLS for Schema registry |

Exceptions: product names (Admin API, Schema Registry, HTTP Proxy, Dedicated Cloud, BYOC), acronyms (ID, TLS, mTLS, SASL, OIDC, VPC, CIDR), side pane nav items.

## Toast Messages

Completed tasks: subject + past tense verb. Long-running: gerund.

| Good | Bad |
|------|-----|
| Topic created | Topic has been created |
| Client deleted | Client deleted successfully |
| Creating cluster | Cluster setup in progress |

## Error Messages

State problem. Give solution. No blame.

| Good | Bad |
|------|-----|
| Choose a password with at least 8 characters. | Oops! That password is too short. |
| Could not save changes. Check your connection. | Something went wrong! |

## Button Labels

1-4 words max. Start with verb if >1 word. No "Yes"/"No" -- use action verbs. No articles.

| Good | Bad |
|------|-----|
| Delete cluster | Yes |
| Save changes | OK |
| Add tag | Add a new tag |

## Empty States

Explain why empty, what user do next. Include button/link to next step. Running tasks: gerund ("Creating cluster" not "Cluster creation in progress").

## Tooltips

Brief. Period for full sentences, none for short phrases. No interactive elements. No redundant text ("Click to..." on button).

## Numbers and Measurements

- Numerals always, incl 0-9 ("3 topics" not "three topics")
- Thousands: K, millions: M, billions: B, no space (33K)
- Measurements: abbreviations with space (10 MB, 75 MBps)
- Time: 12-hour clock, AM/PM caps (2:30 PM)

## Links

Descriptive text -- never "click here". "Learn more" after descriptive text only. External link icon for links leaving product. One link per sentence.

## Possessive Pronouns

Avoid "my"/"your" in page names, menus, titles. OK in instructional text. "Settings" not "My Settings".

## Language

American English. Present tense, active voice. Natural contractions. Serial commas. No exclamation points. No idioms.

## Inclusive Terminology

| Banned | Use Instead |
|--------|-------------|
| whitelist/blacklist | allowlist/denylist |
| master/slave | leader/follower, primary/secondary |

## Directional Language

No physical position -- layouts change. "See the Prerequisites section" not "See above".

## Sentence Structure

- **Subject first** -- "3 options are available" not "There are 3 options"
- **Conditional phrases first** -- "If using Kubernetes, configure..."
- **Present tense** -- "The cluster restarts" not "will restart"
- **No "and/or"** -- use "and", "or", or "A, B, or both"

## Words to Avoid

| Avoid | Use Instead |
|-------|-------------|
| etc., e.g., i.e., via | specific items, for example, that is, through/using |
| please | omit (use only for significant inconvenience) |
| config | configuration |
| foo, bar, baz | contextual meaningful names |

## Placeholders

Descriptive lowercase-with-dashes in angle brackets: `<topic-name>`, `<cluster-id>`. Not `<value>`, `<my-cluster>`.

## Em Dashes

No use. Use parentheses, commas, or separate sentences.

## Common Agent Excuses

| Excuse | Counter |
|---|---|
| "The exclamation adds energy" | Adds noise. Product UI stay calm. |
| "'successfully' confirms the action" | Toast confirms. "Topic created" enough. |
| "'click here' is clear" | Meaningless without context. Describe destination. |
| "'Oops' is friendly" | Patronizing. State problem + solution direct. |
| "Title Case looks professional" | Inconsistent, harder scan. Sentence case standard. |
| "'My Settings' is user-centric" | Ambiguous in multi-user contexts. Just "Settings". |