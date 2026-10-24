# Tone evaluation

Use when changing the skill or assessing whether it improves real UI copy. This suite
covers core decisions, safety/context cases, and sentence clarity. It is not part of the
shell hook suite and does not claim a measured tone improvement until candidate outputs
are graded.

## Run and record

- Use [cases.json](cases.json). Give the candidate the skill, its reference, and **only one
  case's prompt**, in a fresh context per case. Keep IDs, this rubric, expected outcomes,
  prior answers, and baseline results out of candidate context. No repository edits needed.
- Use the same prompts/model/settings for a before/after comparison. Pin the skill revision.
  Candidate requests are organic tasks, not instructions to please a grader. Follow the
  host's authorization requirements before launching models or delegating evaluation.
- Preserve raw answers. A separate reviewer grades them against the facts supplied in the
  prompt and the criteria below. Accept equivalent accurate wording, not exact-string or
  banned-word matching. Do not count an author's own dry run as independent evaluation.
- Record revision, model/settings, case ID, raw output, pass/fail, quoted evidence, and
  reason. Report per-case failures and safety regressions; an average must not hide them.
  Hook pass counts are separate. Source inspection is not a rendered UI check.

## Shared bar

A pass completes the requested task, fits the element, preserves supplied facts, and uses
neutral language. Each sentence makes a useful point directly, without filler, repetition,
redundant advice, or praise. Review findings quote originals,
name the pattern, and provide a rewrite/removal. Moving a fact preserves it at a named
location. Missing context is explicit; file/string counts match actual evidence.

Invented causes, permissions, product behavior, controls, human approval, or recovery are
failures regardless of style. Losing a safety-critical fact also fails. Do not demand
additional human approval as part of these cases, or equate compliance with an AI detector.

## Core cases

| ID | Pass evidence | Failure evidence |
|---|---|---|
| headings | Four short noun headings corresponding to Input, Sensitivity, Backtest, Action; sentence case, no periods. | Question/instruction headings, changed concepts, or extra prose despite the requested format. |
| card-fact | Removes the card subtitle; places both per-key scope and 45-second reset in body/help. | Keeps a subtitle because it adds a fact, or deletes scope/interval. |
| mode-description | Describes Preview recording matches without traffic changes and Apply blocking matching requests. | Advice to start/promote, reassurance, or invented effects. |
| descriptive-person | Quotes the original, names descriptive-person or redundant-tooltip issue, gives factual supplemental help about the owner's failure notifications. | Merely swaps pronouns while losing assignment/notification meaning, or approves without review. |
| filler-and-domain-noun | Removes praise and generic benefit claims; states policy checks on every request; preserves the label API key. | Synonym-only cleanup, invented guarantees, or removes "key" as a legitimate domain noun. |
| filtered-empty | Brief condition such as No matching jobs; retains the available Clear filters control without repeating instructions. | Missing next control, extra advice, or invented search/create behavior. |
| neutral-empty | Rejects the joke; uses a neutral no-jobs condition with the existing Create job action. | Defers to alleged design approval, adds encouragement, or invents permissions. |
| known-permission | Names reports.read exactly in a short permission error. | Invents another permission, renders a placeholder, or adds nonexistent request-access workflow. |
| sentence-concision | States download expiry 24 hours after backup creation and possible email delay for backups larger than 2 GB, each once. Leads with the facts and uses natural sentences. | Keeps preambles, roundabout phrases, or repeated conclusions; drops the time anchor or size threshold; turns possible delay into certainty; uses cryptic fragments. |
| prose-boundary | Explains UI scope and routes to project documentation guidance; says contents were not read. | Applies UI noun-heading rules to unseen prose or fabricates findings/access. |

## Safety and context cases

| ID | Pass evidence | Failure evidence |
|---|---|---|
| unknown-error | States that payment could not be confirmed, without asserting it failed or succeeded; flags missing outcome/cause and retry-safety information outside UI copy. | Invented cause, permission, retry timing, double-payment risk dismissed, or claims payment failed. |
| destructive-warning | Names production-logs, permanent event deletion, retained exports, and inability to restore; controls identify Delete cluster and Cancel. | Cuts any consequence to meet a word budget, euphemizes deletion, or changes verified behavior. |
| instructions-and-labels | Keeps persistent ID token label, useful visible task instruction, example placeholder, and verb-first checkbox. Explains the descriptive-text exception. | Converts every string into nouns, removes the label, moves essential help into placeholder, or bans useful "your". |
| chat-boundary | Limits review to surrounding UI; renames sidebar to a noun heading such as Conversations; leaves conversational message out of scope. | Rewrites assistant response to third person or excludes all chat-screen UI. |
| locale-and-precision | Retains exact quota and existing de-DE/24-hour formatting; rejects rounding and locale overrides. | Hardcoded US formatting, silent rounding, unit/time-zone changes, or claims visual verification. |
| whole-view-review | Quotes subtitle and duplicate tooltip, names their patterns, removes both while retaining visible help. Reports ExportsPanel excerpt's three strings checked, no findings, and source-only excerpt coverage. | Isolated-string approval, deletes essential help, claims files were read from disk or rendered, invents counts, or edits despite review-only. |

## Sentence clarity cases

| ID | Pass evidence | Failure evidence |
|---|---|---|
| task-title | Uses a task title such as Create backup, noun-based navigation such as Backups, a noun section such as Schedule, and a specific Create backup button. | Applies the noun-heading rule to the task title, uses question headings, or changes the operation. |
| modifier-scope | Quotes the original in review, identifies ambiguous scope, and makes admins the only role allowed to rotate signing keys. | Says rotation is the only admin action, invents a permission, or mechanically removes only and loses the access restriction. |
| permission-grouping | Makes both the role requirement and billing.read mandatory for either export type. Preserves role and permission spelling. | Allows owners to bypass billing.read, requires both roles together, changes and/or semantics, or drops either export type. |
| instruction-order | States permanent overwrite and checks the destination before directing the user to Replace file. Uses natural instructions, with one action per sentence. | Puts the warning/check after the destructive action, replaces visible help with a tooltip, or cuts permanent loss to meet a length budget. |

## Regression use

When a real failure appears, add the smallest organic prompt that distinguishes it from an
allowed case. Keep candidate facts separate from grader criteria. Avoid cases that merely
ask for the guide's word list or memorized example. Report unevaluated cases as not run;
static fixture validation proves packaging, not tone.
