# RFC: Browser Daemon (v4.0) -- Replacing claude-in-chrome MCP

**Author:** Beniamin Malinski
**Status:** Draft for review
**Date:** 2026-04-18
**Target release:** skills v4.0
**Supersedes:** `mcp__claude-in-chrome__*` tool surface

## 1. Motivation

Every `read_page` call through `mcp__claude-in-chrome__*` returns a full accessibility tree as JSON on the wire. A 50-action QA session on an authenticated SaaS app routinely burns 200-400k tokens on redundant DOM dumps. We also cold-start Chrome on every MCP session, re-auth on every repo switch, and serialize commands one-per-turn. gstack solved this with a persistent local daemon; we should adopt the same shape.

Per gstack [BROWSER.md](https://github.com/garrytan/gstack/blob/main/BROWSER.md): *"gstack's browser is a compiled CLI binary that talks to a persistent local Chromium daemon over HTTP."* First call ~3s, subsequent ~100-200ms.

## 2. Architecture

**Daemon process:** Bun HTTP server wrapping Playwright (headless Chromium default, `--headed` flag supported). Bun chosen over Node for startup latency and over Rust for maintainer velocity -- Playwright bindings are first-class in JS.

**Port assignment:** random in `10000-60000`. State file: `~/.cache/skills/browser-daemon/state.json` with `{ pid, port, token, startedAt }`. Bearer token is 256-bit URL-safe; every HTTP request must carry `Authorization: Bearer <token>`.

**Lifecycle:**
- CLI reads state file; if missing or `/health` fails, spawns new server.
- Idle shutdown: 30 min no commands -> server exits and unlinks state.
- Crash recovery: daemon does **not** self-heal. Chromium crash -> process exits, CLI respawns on next command.

## 3. Interface

Commands: `navigate`, `click`, `type`, `read`, `screenshot`, `batch`, `eval`, `back`, `forward`, `wait_for`. Elements are addressed by accessibility-tree refs (`@e1`, `@e2`) produced by the snapshot parser -- no raw DOM selectors cross the wire.

```
$ skills-browser navigate https://app.redpanda.com/clusters
{ "url": "...", "title": "Clusters", "ref_count": 47 }

$ skills-browser read
# Clusters (region: us-west-2) @e1
  nav @e2
    link "Overview" @e3
    link "Topics" @e4
  button "Create cluster" @e5
  table "Active clusters" @e6

$ skills-browser click @e5
{ "ok": true, "nav": "https://app.redpanda.com/clusters/new" }

$ skills-browser type @e12 "qa-scratch-01"
$ skills-browser screenshot --out /tmp/s.png
$ skills-browser batch < ops.json
{ "results": [...], "ms": 2380, "n": 42 }
```

Batch endpoint: max 50 commands, per-command error isolation. 20 pages in ~2-3s batched vs 40-100s serial.

## 4. MCP Compatibility Shim

Ship `@skills/browser-mcp-shim` -- a tiny MCP server that re-exports the legacy `mcp__claude-in-chrome__*` tool names and translates to daemon HTTP calls. Existing skills keep working; no skill edits required for v4.0 cut-over.

- `mcp__claude-in-chrome__navigate(url)` -> `POST /cmd {cmd:"navigate",args:[url]}`
- `mcp__claude-in-chrome__read_page()` -> `POST /cmd {cmd:"read"}` -- returns **ref-annotated tree**, not JSON DOM. **Primary token win.**
- `mcp__claude-in-chrome__find(query)` -> `POST /cmd {cmd:"find",args:[query]}` returning `@eN` list
- `mcp__claude-in-chrome__form_input(ref, value)` -> `POST /cmd {cmd:"type",args:[ref,value]}`
- `mcp__claude-in-chrome__get_page_text()` -> `POST /cmd {cmd:"read",args:["text-only"]}`

Shim speaks MCP to Claude, HTTP to daemon. Zero persistent connection to daemon -- stateless shim per MCP call.

## 5. Auth Flow

Cookie import via SQLite read of `~/Library/Application Support/Google/Chrome/Default/Cookies` and Safari's `Cookies.binarycookies`. Decrypt with macOS Keychain safe-storage key. Keychain password + derived AES key cached in-memory for server lifetime only.

- **Login-once-persist:** first run triggers interactive `--headed` login; Playwright `storageState` snapshot lands in `~/.cache/skills/browser-daemon/sessions/<host>.json`. Subsequent runs load it.
- **SSO:** works via cookie import -- the IdP session cookie rides along.
- **2FA:** interactive prompt during initial login only; TOTP codes never stored.
- **OAuth:** reuse the user's browser session via cookie import rather than running a separate OAuth dance.

## 6. Token Math

50-action authenticated QA session, back-of-envelope:

| | Current MCP | Proposed daemon |
|---|---|---|
| Per-action DOM payload | ~5k tokens (full a11y tree JSON) | ~400 tokens (ref-annotated diff) |
| Per-action overhead | ~300 | ~80 |
| 50 actions | **265k tokens** | **24k tokens** |
| Auth bootstrap | ~8k (re-login tree dump) | ~0 (cookies preserved) |
| **Total** | **~273k** | **~24k** |

~91% reduction. At Sonnet input pricing this is material per-session; multiplier over a week of QA is a full-context-window/day savings.

## 7. Migration Path

- **v3.x -> v4.0:** install `@skills/browser-daemon`. Shim is enabled by default and aliases the legacy MCP names, so existing skills keep running unchanged.
- **First invocation** triggers daemon cold-start (~3s) + one-time cookie import.
- **Opt-in direct CLI:** new skills should prefer `skills-browser` directly for batch ops.
- **Deprecation:** legacy MCP names stay aliased through v4.x; removed in v5.0.

## 8. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Daemon crash mid-session | CLI auto-respawns on next command; last command returns error, not hang |
| Port conflict | Retry up to 5 times with fresh port; fail loud with actionable error |
| Bearer token leakage | Token lives in state file at `0600`, never on argv |
| Cookie leakage across repos | One daemon per user, not per repo; `storageState` namespaced by host |
| Cross-repo stale session | `/health` response includes `storageStateHash`; CLI warns on mismatch |
| Keychain prompt fatigue | Cache decrypted key in-daemon memory only; never persisted |
| Playwright version drift | Pin in `skills-lock.json`; CI smoke-tests daemon spin-up |

## 9. Non-Goals

- No WebSocket streaming. HTTP request/response only.
- No MCP as the daemon's native protocol. MCP is a thin shim on top; daemon stays HTTP.
- No multi-user support. One daemon per workstation.
- No Windows/Linux cookie decryption in v4.0. macOS Keychain only.
- No iframe auto-discovery. Explicit `enter_frame @eN` required.
- No PDF rendering, no video capture, no GIF output.
- No cluster/pool mode. Single Chromium instance per daemon.
- No daemon-level retry policies. Caller owns retries.

## 10. Open Questions for Review

1. **Bun vs Node**: Bun gives ~3x startup speed but is less battle-tested on long-running servers. Acceptable risk?
2. **Shim as default**: enabled-by-default means existing skills keep working with zero changes, but users may not realize they're going through an extra layer. Log daemon calls somewhere visible?
3. **Linux/Windows support in v4.1**: punted for v4.0. Is that acceptable given ~80% Mac user base?
4. **Headed-mode opt-in**: `/qa` and `/design-review` probably want `--headed` by default. Separate daemon instance or toggle?

---

### Files this RFC affects (when implemented)

- `docs/rfc/browser-daemon.md` (this file)
- New: `packages/browser-daemon/` (Bun server + Playwright wrapper)
- New: `packages/browser-mcp-shim/` (MCP tool definitions routing to HTTP)
- `qa/SKILL.md` -- point to new CLI
- `skill-manifest.json` -- register shim MCP server
- `skills-lock.json` -- pin Playwright version
