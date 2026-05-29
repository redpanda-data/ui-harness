# Visual Review Reference

Use this reference when `/visual-review` runs standalone or as part of `/go`, `/commit-push`, `/commit-push-pr`, `self-reviewer`, or `code-reviewer`.

## Frontend-change detection

Treat a diff as visual/frontend-related when it touches rendered UI or browser behaviour:

- `*.tsx`, `*.jsx`, `*.css`, `*.scss`, `*.html`, `*.mdx`
- `src/routes/`, `src/pages/`, `src/app/`, `src/components/`, `components/ui/`
- design tokens, Tailwind/theme files, registry components, typography, icons
- form, dialog, popover, table, notification/toast, media, navigation, animation, scroll code
- browser/platform branches using user agent, viewport, media queries, feature detection, or `window`/`document`

Not visual by default: docs-only, test-only, generated files, type-only edits with no rendered behaviour.

## Environment fingerprint

Capture enough context to reproduce visual/browser-specific behaviour:

| Field | How | Why |
|---|---|---|
| Browser | Playwright project, browser name/version, or browser UI | rendering/layout/native controls differ |
| User agent | `navigator.userAgent` | diagnose UA branches and in-app browser quirks |
| Platform | `navigator.platform`, `navigator.userAgentData?.platform` | macOS/Windows/Linux/iOS/Android control/font differences |
| Viewport | `window.innerWidth`, `innerHeight`, `visualViewport?.width/height/scale` | mobile keyboard, zoom, dynamic viewport units |
| DPR | `window.devicePixelRatio` | image sharpness and canvas/SVG issues |
| Color scheme | `matchMedia('(prefers-color-scheme: dark)')` | dark/light token bugs |
| Reduced motion | `matchMedia('(prefers-reduced-motion: reduce)')` | transition and animation safety |
| Contrast/forced colors | `matchMedia('(forced-colors: active)')` | high-contrast accessibility |
| Locale/direction | `navigator.language`, `document.dir` | long strings, RTL, quotes, formatting |
| Network | Playwright route/throttle or DevTools profile | lazy media/loading and skeleton states |

Useful browser snippet:

```js
JSON.stringify({
  userAgent: navigator.userAgent,
  platform: navigator.userAgentData?.platform ?? navigator.platform,
  language: navigator.language,
  viewport: {
    innerWidth,
    innerHeight,
    visualWidth: visualViewport?.width,
    visualHeight: visualViewport?.height,
    scale: visualViewport?.scale,
    dpr: devicePixelRatio,
  },
  media: {
    dark: matchMedia('(prefers-color-scheme: dark)').matches,
    reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
    forcedColors: matchMedia('(forced-colors: active)').matches,
  },
  dir: document.dir,
}, null, 2)
```

## Platform risk map

| Change area | Platform/browser risks to inspect |
|---|---|
| Sticky/fixed UI | iOS safe area, Android browser chrome, `visualViewport`, `100vh` vs `100dvh` |
| Forms | mobile keyboard resize, Enter submit, autofill/password managers, input type keyboards |
| Dialog/popover/select | Safari/Firefox native-control differences, Escape/back gesture, focus return |
| Tables/dense data | horizontal overflow, headers/captions, zoom, scrollbar-gutter |
| Animations/transitions | reduced motion, interaction blocking, transform order, INP |
| Scroll UI | smooth scroll side effects, scroll snapping, `scrollIntoView`, overscroll chaining |
| Images/video/media | LCP, CLS, DPR sharpness, lazy/preload, captions/controls, aspect ratio |
| Typography/icons | system font fallback, custom font shift, text zoom, SVG accessible names |
| Dark/high contrast | token coverage, `forced-colors`, color-only state, focus visibility |
| Feature-detected APIs | Baseline/browser support, fallback path, no UA sniff when feature detect works |
| In-app browsers/WebViews | UA quirks, blocked APIs, viewport differences, navigation limitations |

## Visual-review-specific checks

These belong in visual review even when hooks already exist:

- Screenshot comparison for changed views and important states.
- Browser matrix evidence: Chromium plus Firefox/WebKit when feasible.
- Mobile viewport and virtual-keyboard behaviour.
- Real focus order and keyboard interaction, including Escape/close paths.
- Accessible names matching visible intent, not merely presence of ARIA.
- Toast/notification announcement and persistence.
- Dense/empty/error/loading states that require mocked or seeded data.
- Overflow, clipping, z-index, portal, sticky/fixed, and safe-area bugs.
- Scroll behaviour and transition/motion interaction bugs.
- Core Web Vitals risks visible to users: LCP, CLS, INP.
- Platform-specific branches based on user agent, viewport, media queries, or feature detection.

## Ecosystem wiring

- `/visual-review` can run standalone any time the user asks.
- `/go` runs it automatically for frontend diffs before PR creation.
- `/commit-push-pr` requires its result or an explicit skip reason for frontend PRs.
- `/commit-push` requires it before pushing frontend changes, unless skipped with reason.
- `self-reviewer` and `code-reviewer` should flag missing `/visual-review` evidence when reviewing frontend diffs.
- `route-visual-test-check.sh` and browser/e2e tests remain complementary; passing tests do not replace visual review for visual changes.

## PR evidence contract

Every frontend PR should carry or link this `/visual-review` evidence:

- Environment fingerprint: browser, user agent, platform, viewport, visualViewport, DPR, media prefs, locale/direction.
- Checked matrix: browsers, viewports, states, keyboard path, console/network scan, a11y checks.
- Screenshots: changed views/states, with path or attachment reference.
- Findings: P0/P1 fixed or explicitly accepted; P2/P3 noted.
- Skip reasons: every unrun matrix item gets a concrete reason.
- Automation candidates: repeatable misses worth hook/eval/docs follow-up.
