---
name: visual-review
description: Browser-based frontend review for changed UI. Use before PRs with React/route/CSS changes to inspect screenshots, states, a11y, console errors, and cross-browser/mobile regressions.
---

# Visual Review

Browser QA for changed UI. Hooks catch static smells; this catches composed UI bugs that need seeing + interaction. See [REFERENCE.md](REFERENCE.md) for environment fingerprint, platform risk map, ecosystem wiring.

## Run
Standalone trigger OK: `/visual-review`. Also run before `/commit-push-pr` when diff touches rendered UI: `*.tsx`, `*.jsx`, `*.css`, `*.scss`, `*.html`; `src/routes/`, `src/pages/`, `src/app/`, `src/components/`, `components/ui/`; Tailwind/theme/config files that affect visuals. Skip only docs-only, test-only, type-only, backend-only, or explicit skip reason.

## Inputs
Accept route/component hints. If omitted: inspect `git diff --name-only HEAD`; map route files to URLs when obvious; map component edits to nearest affected route/story/test; if route cannot be inferred, ask one concise question.

## Review matrix
Minimum:
- Chromium desktop; Chromium mobile viewport; keyboard-only pass: Tab, Shift+Tab, Enter, Space, Escape.
- console/network error scan; loading, empty, error, dense-data state where reachable.
- form submit path when form UI changed; notification/toast path when feedback UI changed.

Prefer when feasible:
- Firefox desktop; WebKit/mobile Safari equivalent.
- reduced motion; dark/light mode; high contrast or forced colors.
- text zoom or larger default font when typography/layout changed.
- RTL or localized-long-text sample when copy/layout changed.
- back/forward navigation when route/search/theme/storage changed.
- slow network/media throttling when images/video/loading changed.

Use project scripts first: `scripts/skills-browser.sh`, Playwright, `bun run dev`. Never ask user to verify visual UI manually when tools can.

## Inspect
### Layout/polish
- horizontal overflow; clipped popovers; sticky/fixed overlap; safe-area issues on mobile bottom/top UI.
- viewport unit bugs: `100vh`, virtual keyboard, scrollbars, writing mode.
- layout shift from skeletons, images, lazy video, fonts, accordions, tabs.
- broken dense tables/cards/lists; captions/headers still explain tables.
- dark/light contrast and token consistency; text scaling, zoom, system font and OS default font behaviour.
- CSS shorthand/complex layout edits remain readable and intentional.

### A11y/semantics
- accessible names match visible intent; native semantics first; ARIA only when needed.
- `aria-label` not used on static/generic elements and not hiding visible text.
- labels connect to inputs; password managers/autofill still work.
- disabled vs `aria-disabled` behaviour clear and keyboard-safe.
- focus order, focus trap, Escape/close paths, no surprise autofocus.
- buttons/links do not nest; links look and behave like links.
- dialogs, popovers, custom selects, tabs, tables, forms.
- forms submit correctly via Enter, buttons, and `requestSubmit()`-style paths.
- toasts/notifications announced, persistent enough, not sole carrier for critical actions.
- text effects, transforms, uppercase, strikethrough, emoji, generated content do not harm screen-reader output.
- SVG/icons/images have meaningful names or are hidden decoratively.

### Browser/platform
- Firefox/Safari differences, not just Chromium; in-app browser/WebView quirks when relevant.
- viewport/virtual-keyboard issues on mobile forms; bfcache/back-forward state for theme/auth/search params.
- smooth scrolling, scroll snapping, `scrollIntoView`, overscroll, and scrollbar-gutter side effects.
- view-transition/reduced-motion behaviour and interaction blocking.
- popover/dialog/select/native-control behaviour across browsers.
- unsupported Baseline/new platform features have fallback or feature detection.

### Perf-sensitive UI
- responsive images dimensions/sizes/lazy/preload rules.
- responsive video/media has controls, captions where needed, and stable aspect ratio.
- important images not hidden as CSS backgrounds when they need priority/alt.
- large data URLs/assets, render-blocking additions, third-party embeds/scripts.
- obvious Core Web Vitals risks: LCP image, CLS, INP/long interaction.
- animation cost: transform/opacity preferred, no motion that ignores reduced-motion.
- font loading: fallback, size-adjust/layout shift, oversized custom fonts.

## Heuristics
HTML first. User agents vary. State beats happy path. Motion is interaction. Content stress wins. Accessibility automation is partial. Performance is visual. If seen twice, automate.

## Output
Return concise report:

```markdown
## Visual review
Status: ready | needs fixes | blocked
Changed UI: <routes/components>
Checked: <browser/viewport/state list>
Findings: | Severity | Area | Finding | Evidence | Fix |
Screenshots: | View | Browser | Path | Notes |
PR notes: <rows usable in /commit-push-pr screenshot table>
Automation candidates: <repeatable misses worth hook/eval/docs>
```

Severity: P0 blocks use/security/data loss. P1 fix before PR. P2 fix if low-risk else note. P3 advisory.

## Finish
P0/P1 fixed or user accepted. Screenshot evidence captured for visual changes when app runnable. Skip reasons recorded for unrun matrix items. Recurring deterministic issue suggested as hook/eval follow-up.
