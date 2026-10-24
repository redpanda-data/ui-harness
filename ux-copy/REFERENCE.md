# UX copy reference

Use for product UI, not prose documentation or chat responses. Start with the whole view:
what task is happening, what each element contributes, and what the product actually does.
Choose each element's job: name, fact, instruction, result, or warning.
Prefer precise facts over brevity that hides a consequence. Local product requirements and
verified behavior outrank illustrative examples below.

## Sentence-level concision

Lead with the fact or action; put necessary conditions before their effects.
Use direct verbs and the shortest natural wording.
Prefer familiar words: "use", not "utilize". Keep technical terms when they add precision.
Use active voice when the actor matters; passive voice can keep a result in focus.
Cut preambles, filler, roundabout phrases, redundant clauses, and repeated conclusions.
Delete sentences that add no distinct fact or needed action.

Preserve conditions, uncertainty, safety facts, and natural grammar. Concise does not mean
cryptic fragments or an arbitrary word cap. Let sentence length follow meaning: split
unrelated points, not a fact from the condition that makes it true.

Before: "It is important to note that audit logs are retained for a period of 30 days. This
means audit logs are stored for 30 days."
After: "Audit logs are retained for 30 days."

## Remove ambiguous readings

- Put modifiers beside their target. "Only operators can revoke tokens" restricts the
  actor; "Operators can only revoke tokens" restricts the action. Verify which is true.
- Name the object when "it", "this", or "they" could refer to multiple things. Expand
  dense noun strings into relationships: "backup deletion permission" becomes
  "permission to delete backups".
- Make grouped requirements explicit. If every exporter needs a role and a permission,
  say so; do not imply that one role bypasses the permission. Distinguish inclusive
  alternatives from exactly one choice using the verified behavior.
- Keep articles, prepositions, and repeated nouns when they prevent a second reading.
  Compact labels may omit words that help text needs. Rephrase awkward copy instead of
  enforcing a grammar rule that makes it harder to understand.

## Patterns to remove

These names make review findings actionable. A word or punctuation match is a clue, not a
verdict about authorship or quality. Fix the missing fact, not just the flagged word.

| Pattern | Direction | Before -> after |
|---|---|---|
| 1. Heading as phrase | Name sections with noun phrases; name task screens with verb phrases. | What to watch -> Input; Backup creation -> Create backup |
| 2. Subtitle scaffolding | Remove section/card/step subtitles; move useful facts into body or field help. | Input / The signal this policy monitors, and the shape of trouble it looks for. -> Input |
| 3. Advice instead of facts | Describe behavior in descriptions; keep instructions where the task needs them. | Start in Observe; promote once the backtest looks right. -> Describe each mode's verified effect. |
| 4. Personality or reassurance | State the condition without jokes, encouragement, or sales language. | That's normal for a new agent. -> Remove, or state a verified prerequisite. |
| 5. Staccato punchlines | Use a plain sentence or label, not fragments for effect. | Twitchy on purpose. Catches incidents fast. -> Faster detection produces more false positives on bursty traffic. |
| 6. Rhetorical construction | Replace slogans and clause pairs joined by semicolons, colons, or em dashes with direct facts. | Fast, not reckless. -> State the actual detection interval. |
| 7. Repetition | Keep each fact once per view, where needed. | Heading, helper, and tooltip repeat the same definition -> Keep the useful instance. |
| 8. Explanation in label | Name in the label, explain in help. | Burst · sudden spike -> Burst; help: Detects sudden spikes. |
| 9. Vague empty state or error | Name the condition, known cause, or required permission. | Something went wrong -> A specific known failure; do not guess its cause. |
| 10. Inflated vocabulary | Replace generic praise with a concrete fact, or remove it. | Robust, seamless governance -> Policies apply to every request (only if verified). |
| 11. Cheerful status | Confirm the actual result. | You're all set! -> Topic created |
| 12. Copula avoidance | Prefer a direct relationship or verb. | Serves as a control point -> Applies policies |
| 13. Trailing benefit claim | Remove unsupported "ensuring..." or "helping teams..." tails. | Stores events, ensuring reliability -> State the verified retention or durability property. |
| 14. Vague relationship | Name how objects relate. | Key associated with agent -> Agent uses this key |
| 15. Empty disclaimer | Drop "Note that" and unnamed "in some cases"; preserve real conditions and uncertainty. | Note that limits may vary -> Name the plan-dependent limits, if known. |
| 16. Chat language | Keep the interface out of conversation mode. | Here's how to get started -> Task-specific control or instruction |
| 17. Template residue | Replace scaffolding before shipping. | [Feature name], TBD, Add description here -> Verified copy |
| 18. Ambiguous scope | Make actors, modifiers, and grouped conditions explicit. | Operators can only revoke tokens -> Only operators can revoke tokens (if the restriction concerns roles) |

Do not turn these into blind bans. A factual contrast can be essential to a safety warning.
"API key" is a domain noun, not inflated "key features". A colon in a timestamp is not
rhetorical copy. Literal identifiers, user content, and third-party names are not rewritten
to satisfy tone rules. Examples involving product behavior require verification before reuse.

### Words to question

- Generic emphasis: additionally, crucial, pivotal, valuable, key (adjective), highlight,
  underscore, enhance, bolster, foster, delve, intricate, landscape, tapestry.
- Marketing: robust, seamless, powerful, effortless, cutting-edge, unlock, empower, leverage.
- Minimizers: easily, just, simply. They can hide effort or make a failure sound like blame.

Several in one view warrant a context review. Do not replace them mechanically or treat
membership in a frozen word list as the test. "Optimize" is useful when it names a real
operation; "robust" without a concrete property is not.

## Where text belongs

Budgets guide editing, not truncation or deletion of critical facts. If a string needs more
room, improve placement or design. Keep safety and task-critical help visible.

| Element | Job | Default budget |
|---|---|---|
| Section heading, navigation item | Name the thing, noun phrase, no period | 1-3 words |
| Task-screen heading | Name the goal, verb phrase, no period | As short as the task permits |
| Field/value label | Persistent accessible name, no inline explanation | 1-3 words |
| Button | Specific action + object, no period | 1-2 words; usually at most 4 |
| Toggle/checkbox label | Action enabled, verb first | As short as the object name permits |
| Page subtitle | Optional new limit, effect, or prerequisite | At most 1 sentence |
| Field help | Format, restriction, dependency, or effect of leaving blank | Usually 1 sentence |
| Placeholder | Example value or expected format | A value, not an instruction |
| Tooltip | Supplemental meaning only | 1 short sentence |
| Empty state | Condition and an available next action | 1 sentence + optional control |
| Error | Known cause and supported recovery | Usually 1-2 sentences |
| Toast | Result or actual progress | Short phrase |

Section/card/step subtitles are not a second help layer. For example, keep "Limits apply
per API key and reset every 60 seconds" as body text or field help, not a card subtitle.
Never delete its scope or interval just to shorten the card.

## Capitalization, grammar, and tone

- Sentence case everywhere, including side-pane navigation. Preserve proper names and
  approved acronyms: API, ID, TLS, mTLS. Match the project glossary and API spelling.
- Descriptions state third-person facts about the object. Avoid "we", "our", and "let's".
  Instructions, confirmation dialogs, and actionable errors may use "you" or "your".
  Titles/menu names omit possessives: "Settings", not "My settings".
- Use American English unless the project specifies otherwise. Present tense, active
  voice, natural contractions, and serial commas. Front-load the object/result
  (front-loading): "Export ready", not "Your export is complete and available".
- Complete sentences take periods; labels/short status phrases do not. Real confirmation
  questions can use question marks. Keep parallel items grammatically consistent.
- Use "and", not "&", except in proper names or exact external labels. Replace "and/or"
  with the intended "and", "or", or "A, B, or both". Put conditions before their effects.
- No exclamation points, emoji, idioms, slang, or emphasis through bold, italics, or all caps.
  Do not add code font as decoration. Identify technical terms by role when needed.
- Em dashes: avoid in UI copy. Use commas, parentheses, or separate sentences. Do not
  replace one rhetorical punctuation pattern with another.
- Courtesy words (please, sorry, thank you) acknowledge real inconvenience, not routine actions.
  Calm precision also applies to onboarding; the UI does not need to cheerlead.

## Product naming and terminology

One term per concept across UI, API, and docs. Use the project's canonical product names
and glossary. The bundled [GLOSSARY.md](GLOSSARY.md) is product-specific, not a universal
vocabulary. Surface contradictions rather than silently renaming API concepts or changing
domain behavior. Product naming should reveal purpose or scope; avoid cute names for
security, billing, destructive actions, and recovery.

## Button labels and controls

Name the action, not the component event: "Save changes", "Create topic", "Export report".
Use "Delete cluster", not "Yes"; "Cancel", not an ambiguous "No". Avoid generic
"Submit", "OK", and "Done" when a specific action fits. Omit unnecessary articles and
trailing ellipses.
Toggle/checkbox labels are the noun-label exception: "Require TLS", "Enable audit logging".
Do not rename controls without checking the action they actually trigger.

## Help, tooltips, and placeholders

Keep contextual help next to its control. A label, helper, placeholder, tooltip, and error
each do different work; essential instructions cannot live only in a disappearing
placeholder or hover-only tooltip. Keep validation rules and their errors near the input.
Tooltips contain no links, buttons, or other interactive elements and do not repeat labels.

In UI instructions, give conditions and warnings before the action they guard. Use one
action per sentence. Number steps when order matters; use bullets for independent choices.
Describe settings as facts instead of turning them into a walkthrough.

An input placeholder shows realistic format, without "Example" or "e.g.". For template
identifiers in instructions, use meaningful angle-bracket tokens: `<topic-name>`,
`<cluster-id>`, not `<value>` or `<my-cluster>`. Replace explanatory placeholders before
shipping; never render `<permission>` in a real error.

## Empty states

Distinguish no resources, no filter matches, loading, missing access, and failed loading.
"No matching providers" with an existing "Clear filters" control is enough for a filtered
list. "No agents" can accompany "Create agent" only if creation is available and allowed.
Do not invent controls, make loading failures look empty, or repeat control text as advice.
No humor, reassurance, taglines, or "Try again shortly" without an established recovery.

## Error messages

State the known problem without blame. Give a supported correction or action; use visible
help or a descriptive documentation link if recovery needs several steps.

| Context | Copy |
|---|---|
| Verified minimum length | Choose a password with at least 8 characters. |
| Verified missing permission | Access to this policy requires the policies.read permission. |
| Save failed; cause unavailable | Could not save changes. |

The permission name above is illustrative. Use the actual identifier from the contract.
Do not infer a permission, network failure, retry interval, administrator role, or successful
retry from generic failure text. If needed, flag missing error metadata outside the UI draft.
Preserve request/error IDs when useful for support, without exposing secrets. Offer retry
only when supported and safe; a retried non-idempotent action may duplicate work.

## Confirmations and destructive language

Use explicit verbs for irreversible loss: "Delete", "Revoke", not euphemistic "Clear".
Name the target, scope, permanent effect, dependencies, and recovery limit when established.
Keep critical facts even if that exceeds normal length budgets. "Delete cluster" is not
a substitute for explaining permanent loss of its data. Do not claim deletion is reversible
or permanent without checking. A factual safety distinction is not a rhetorical violation.

## Toast messages

Completed tasks: subject + past-tense verb. Include the differentiating object name when
helpful: "Client payments-etl deleted". Prefer "Topic created" to "Topic has been created".
Remove "has been" and "successfully".
Long-running tasks: actual progress, such as "Creating cluster". Accepted/queued does not
mean completed. Do not emit completion copy for an operation still running or a failed call.

## Numbers, measurements, dates, and times

- Use numerals, including 0-9. Follow the user's locale/preferences for rendered numbers
  and dates; do not hardcode English separators or 12-hour time over those settings.
- Exact values stay exact: 1,024 partitions in US English. Use K/M/B without a space only
  for deliberately rounded summaries, such as 33K. Never round a limit, price, or ID silently.
- Separate number and unit: 10 MB, 75 MBps. Preserve precision and distinguish MB from MiB,
  bits from bytes, and amounts from rates. Do not change units as a copy edit.
- Static US-English examples may use May 19, 2023 and 2:30 PM. Include an unambiguous time
  zone when needed; do not guess it. Dynamic dates follow the existing locale formatter.

## Links and directional language

Use descriptive destinations/actions, not "click here" or bare "here". A Learn more link
can follow related explanatory text, not interrupt a sentence or live in a tooltip.
Place nothing after the link within its related help block. Give
repeated generic links distinct accessible names. For external sources, name the source;
link an external-link icon with its text. Prefer at most one link per sentence.

Directional language: name the control or section, not "above", "below", "on the right",
or "click". Layout, input method, and reading order vary.

## Inclusive, plain language

Use gender-neutral, non-ableist wording. Replace exclusionary terminology when it is not
an exact external identifier: allowlist/denylist; leader/follower or primary/secondary.
Use "for example", "that is", and "through/using" instead of Latin abbreviations. Prefer
"configuration" over "config" in ordinary UI, and meaningful examples over foo/bar/baz.
Do not rewrite literal API fields or user data to match a style preference.

## Redundant UX writing: whole-view review

Read the heading, subtitle, label, helper, placeholder, tooltip, and error together.
Keep each fact in the place it is needed; remove duplicated definitions, "configuration
and settings", and "manage and configure" when they describe one action. Preserve
accessible names and repeated warnings needed in separate task contexts.

Report `location | "exact string" | pattern | rewrite/removal`. Say where a retained fact
moves. Example: `PolicyEditor.tsx: mode help | "Best kept in Observe" | Advice instead of
facts | "Observe records firings. Enforce engages the kill switch."` That rewrite is valid
only after verifying both mode behaviors. Quote deletion candidates too.

A clean review states files read, distinct strings checked, and context coverage. Pasted
excerpts count as excerpts, not files read. Never invent counts or claim rendered/visual
verification from source alone.

## Stress-test copy

Check German titles, long names/IDs, huge prices, zero counts, 500s, offline and loading
states, missing permissions, destructive actions, and narrow widths. Check plural forms
and interpolation; keep existing translation keys and placeholders unless a migration is
requested. Decide truncation deliberately: keep differentiating identifier text accessible;
never truncate an essential warning or rely on color alone to convey an error.

## Hook boundary and escape hatch

`ux-copy-check.sh`, when installed, checks selected TS/TSX patterns, not tone.
[setup-ux-copy](../setup-ux-copy/SKILL.md) owns its block/warn behavior. Review JSX and translation catalogs manually;
generic JSON is intentionally not linted as UI. Installation/host activation must be verified
separately. Do not promise an upstream review bot will read this skill merely because it exists.

`// allow: ux-copy [reason]` anywhere in a file exempts the file; legacy
`// allow-ux-copy: [reason]` is also supported. Keep a specific reason and use only when
needed (for example, an exact external message). File-wide exemption does not waive review
of other strings. Markdown has `<!-- allow: prose-style [reason] -->` for the prose hook.

## Writing source

Adapted for UI from [Cursor's technical-writing skill](https://github.com/cursor/plugins/blob/main/pstack/skills/technical-writing/SKILL.md):
plain wording, task/concept distinctions, instruction order, and unambiguous syntax.
Its documentation modes, formatting conventions, and `unslop` dependency do not apply to
this skill. Product copy keeps the scope, terminology, and safety rules above.
