#!/bin/bash
# Unit tests for PostToolUse pattern-check hooks.
# Tests each hook's block/warn/allow paths.

source "$(dirname "$0")/hook-test-helpers.sh"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         PostToolUse Pattern-Check Hook Tests             ║"
echo "╚═══════════════════════════════════════════════════════════╝"

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ react-rules-check.sh (37 checks) ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  Check 2 — raw <button> (warn):"
_f="/tmp/hook-test-rr-$$.tsx"
_setup_test_file "$_f" 'const X = () => <button onClick={fn}>click</button>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "raw <button> is a warn not block"
_assert_stderr_contains "Button.*button|button.*Button" "warns about <Button>"
_cleanup_test_file "$_f"

echo "  Check 2 — raw <input> (block):"
_setup_test_file "$_f" 'const X = () => <input type="text" />;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "raw <input> blocked"
_assert_stderr_contains "Input" "suggests <Input>"
_cleanup_test_file "$_f"

echo "  Check 6 — onClick+navigate (block):"
_setup_test_file "$_f" 'const X = () => <div onClick={() => navigate("/home")}>go</div>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "onClick+navigate blocked"
_assert_stderr_contains "Link" "suggests <Link>"
_cleanup_test_file "$_f"

echo "  Check 7 — Button without handler (block):"
_setup_test_file "$_f" 'const X = () => <Button>click</Button>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "Button without purpose blocked"
_cleanup_test_file "$_f"

echo "  Check 7 — Button with onClick (pass):"
_setup_test_file "$_f" 'const X = () => <Button onClick={fn}>click</Button>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "Button with onClick passes"
_cleanup_test_file "$_f"

echo "  Check 11 — icon-only Button without aria-label (block):"
_setup_test_file "$_f" 'const X = () => <Button onClick={fn}><TrashIcon /></Button>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "icon-only Button blocked"
_assert_stderr_contains "aria-label" "mentions aria-label"
_cleanup_test_file "$_f"

echo "  Check 11 — icon-only Button with aria-label (pass):"
_setup_test_file "$_f" 'const X = () => <Button onClick={fn} aria-label="Delete"><TrashIcon /></Button>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "icon-only Button with aria-label passes"
_cleanup_test_file "$_f"

echo "  Check 12 — outline:none without focus-visible (block):"
_setup_test_file "$_f" 'const X = () => <div className="outline-none">x</div>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "outline-none blocked"
_cleanup_test_file "$_f"

echo "  Check 12 — outline:none with focus-visible:ring (pass):"
_setup_test_file "$_f" 'const X = () => <div className="outline-none focus-visible:ring-2">x</div>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "outline-none + focus-visible passes"
_cleanup_test_file "$_f"

echo "  Check 14 — dangerouslySetInnerHTML (block):"
_setup_test_file "$_f" 'const X = () => <div dangerouslySetInnerHTML={{__html: data}} />;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "dangerouslySetInnerHTML blocked"
_cleanup_test_file "$_f"

echo "  Check 14 — dangerouslySetInnerHTML with escape (pass):"
_setup_test_file "$_f" '// allow: dangerouslySetInnerHTML sanitized with DOMPurify
const X = () => <div dangerouslySetInnerHTML={{__html: clean}} />;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "dangerouslySetInnerHTML with escape passes"
_cleanup_test_file "$_f"

echo "  Check 15 — eval() (block):"
_setup_test_file "$_f" 'const result = eval("1+1");'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "eval() blocked"
_cleanup_test_file "$_f"

echo "  Check 16 — innerHTML assignment (block):"
_setup_test_file "$_f" 'const X = () => { ref.current.innerHTML = data; };'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 ".innerHTML blocked"
_cleanup_test_file "$_f"

echo "  Check 17 — inline style={{}} (warn):"
_setup_test_file "$_f" 'const X = () => <div style={{color: "red"}}>x</div>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "inline style is warn not block"
_assert_stderr_contains "Tailwind|style" "warns about inline style"
_cleanup_test_file "$_f"

echo "  Check 18 — class component (block):"
_setup_test_file "$_f" 'class MyComp extends React.Component { render() { return <div/>; } }'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "class component blocked"
_cleanup_test_file "$_f"

echo "  Check 20 — addEventListener without passive (block):"
_setup_test_file "$_f" "addEventListener('scroll', handler);"
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "scroll listener without passive blocked"
_cleanup_test_file "$_f"

echo "  Check 20 — addEventListener with passive (pass):"
_setup_test_file "$_f" "addEventListener('scroll', handler, { passive: true });"
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "scroll listener with passive passes"
_cleanup_test_file "$_f"

echo "  Check 22 — handleSubmit without error callback (warn):"
_setup_test_file "$_f" 'const X = () => <form onSubmit={handleSubmit(onSubmit)}>x</form>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "handleSubmit no error is warn"
_assert_stderr_contains "onError|error callback" "warns about error callback"
_cleanup_test_file "$_f"

echo "  Check 22 — handleSubmit with error callback (pass):"
_setup_test_file "$_f" 'const X = () => <form onSubmit={handleSubmit(onSubmit, onError)}>x</form>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_stderr_not_contains "error callback|onError" "no warn with error callback"
_cleanup_test_file "$_f"

echo "  Check 28 — JSON.parse(JSON.stringify()) (warn):"
_setup_test_file "$_f" 'const copy = JSON.parse(JSON.stringify(obj));'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "JSON roundtrip is warn"
_assert_stderr_contains "structuredClone" "suggests structuredClone"
_cleanup_test_file "$_f"

echo "  Check 31 — parseInt without radix (warn):"
_setup_test_file "$_f" 'const n = parseInt(str);'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "parseInt no radix is warn"
_assert_stderr_contains "radix|parseInt.*10|Number" "warns about radix"
_cleanup_test_file "$_f"

echo "  Check 33 — setTimeout with string (block):"
_setup_test_file "$_f" "setTimeout('alert(1)', 100);"
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "setTimeout string blocked"
_cleanup_test_file "$_f"

echo "  Check 34 — === NaN (block):"
_setup_test_file "$_f" 'if (x === NaN) return;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "=== NaN blocked"
_assert_stderr_contains "Number.isNaN" "suggests Number.isNaN"
_cleanup_test_file "$_f"

echo "  Check 36 — node:assert in test file (block):"
_tf="/tmp/hook-test-rr-$$.test.ts"
_setup_test_file "$_tf" "import { strict } from 'node:assert';"
_run_hook "react-rules-check.sh" "$(_edit_json "$_tf")"
_assert_exit 2 "node:assert in test blocked"
_cleanup_test_file "$_tf"

echo "  clean .tsx file (all pass):"
_setup_test_file "$_f" 'import { Button } from "@/components/ui/button";
const X = () => <Button onClick={fn}>click</Button>;'
_run_hook "react-rules-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "clean file passes all checks"
_cleanup_test_file "$_f"

echo "  .ts file (non-TSX checks only):"
_tsf="/tmp/hook-test-rr-$$.ts"
_setup_test_file "$_tsf" 'const copy = structuredClone(obj);
const n = Number(str);'
_run_hook "react-rules-check.sh" "$(_edit_json "$_tsf")"
_assert_exit 0 "clean .ts passes"
_cleanup_test_file "$_tsf"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ tailwind-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-tw-$$.tsx"

echo "  !important in TSX (block):"
_setup_test_file "$_f" 'const X = () => <div className="bg-red-500 !important">x</div>;'
_run_hook "tailwind-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "!important blocked"
_cleanup_test_file "$_f"

echo "  100vh in CSS file (warn):"
_css="/tmp/hook-test-tw-$$.css"
_setup_test_file "$_css" 'body { height: 100vh; }'
_run_hook "tailwind-check.sh" "$(_edit_json "$_css")"
_assert_exit 0 "100vh is warn"
_assert_stderr_contains "100dvh" "suggests 100dvh"
_cleanup_test_file "$_css"

echo "  100dvh in CSS file (pass):"
_setup_test_file "$_css" 'body { height: 100dvh; }'
_run_hook "tailwind-check.sh" "$(_edit_json "$_css")"
_assert_exit 0 "100dvh passes"
_cleanup_test_file "$_css"

echo "  user-scalable=no (block):"
_setup_test_file "$_f" '<meta name="viewport" content="width=device-width, user-scalable=no" />'
_run_hook "tailwind-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "user-scalable=no blocked"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ accessibility-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-a11y-$$.tsx"

echo "  img without alt (block):"
_setup_test_file "$_f" 'const X = () => <img src="pic.png" />;'
_run_hook "accessibility-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "img without alt blocked"
_cleanup_test_file "$_f"

echo "  img with alt (pass):"
_setup_test_file "$_f" 'const X = () => <img src="pic.png" alt="Photo" />;'
_run_hook "accessibility-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "img with alt passes"
_cleanup_test_file "$_f"

echo "  clickable div without keyboard (block):"
_setup_test_file "$_f" 'const X = () => <div onClick={fn}>click me</div>;'
_run_hook "accessibility-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "clickable div blocked"
_assert_stderr_contains "role.*tabIndex.*onKeyDown|WCAG" "mentions WCAG/kbd"
_cleanup_test_file "$_f"

echo "  clickable div with full a11y (pass):"
_setup_test_file "$_f" 'const X = () => <div onClick={fn} onKeyDown={fn} role="button" tabIndex={0}>click</div>;'
_run_hook "accessibility-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "accessible clickable div passes"
_cleanup_test_file "$_f"

echo "  role=dialog without aria-label (block):"
_setup_test_file "$_f" 'const X = () => <div role="dialog"><p>content</p></div>;'
_run_hook "accessibility-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "dialog without label blocked"
_cleanup_test_file "$_f"

echo "  aria-invalid without aria-describedby (warn):"
_setup_test_file "$_f" 'const X = () => <input aria-invalid={true} />;'
_run_hook "accessibility-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "aria-invalid without describedby is warn"
_assert_stderr_contains "aria-describedby" "mentions aria-describedby"
_cleanup_test_file "$_f"

echo "  a11y-skip escape hatch (pass):"
_setup_test_file "$_f" '// allow: a11y-skip custom widget
const X = () => <img src="x.png" />;'
_run_hook "accessibility-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "a11y-skip escape allows through"
_cleanup_test_file "$_f"

echo "  .ts file (not .tsx — skip):"
_tsf="/tmp/hook-test-a11y-$$.ts"
_setup_test_file "$_tsf" 'const X = () => ({ img: "no alt" });'
_run_hook "accessibility-check.sh" "$(_edit_json "$_tsf")"
_assert_exit 0 ".ts file skipped"
_cleanup_test_file "$_tsf"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ zustand-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-zus-$$.ts"

echo "  single-parens create (block):"
_setup_test_file "$_f" "import { create } from 'zustand';
const useStore = create<State>((set) => ({ count: 0 }));"
_run_hook "zustand-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "single-parens create blocked"
_cleanup_test_file "$_f"

echo "  double-parens create (pass):"
_setup_test_file "$_f" "import { create } from 'zustand';
const useStore = create<State>()(
  (set) => ({ count: 0 })
);"
_run_hook "zustand-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "double-parens create passes"
_cleanup_test_file "$_f"

echo "  inline object selector (block):"
_setup_test_file "$_f" "import { create } from 'zustand';
const { count, name } = useAppStore((state) => ({ count: state.count, name: state.name }));"
_run_hook "zustand-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "inline object selector blocked"
_assert_stderr_contains "useShallow" "suggests useShallow"
_cleanup_test_file "$_f"

echo "  localStorage in store (block):"
_setup_test_file "$_f" "import { create } from 'zustand';
const useStore = create<State>()((set) => ({
  save: () => localStorage.setItem('key', 'val'),
}));"
_run_hook "zustand-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "localStorage blocked"
_assert_stderr_contains "persist" "suggests persist middleware"
_cleanup_test_file "$_f"

echo "  non-zustand file (skip):"
_setup_test_file "$_f" "const x = localStorage.getItem('key');"
_run_hook "zustand-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "non-zustand file passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ env-validation-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-env-$$.ts"

echo "  raw process.env.CUSTOM (block):"
_setup_test_file "$_f" 'const apiUrl = process.env.API_URL;'
_run_hook "env-validation-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "raw process.env blocked"
_assert_stderr_contains "@/env|t3-env" "suggests @/env"
_cleanup_test_file "$_f"

echo "  process.env.NODE_ENV (allowed):"
_setup_test_file "$_f" 'const isDev = process.env.NODE_ENV === "development";'
_run_hook "env-validation-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "NODE_ENV allowed"
_cleanup_test_file "$_f"

echo "  test file (skip):"
_tf="/tmp/hook-test-env-$$.test.ts"
_setup_test_file "$_tf" 'const url = process.env.API_URL;'
_run_hook "env-validation-check.sh" "$(_edit_json "$_tf")"
_assert_exit 0 "test files skipped"
_cleanup_test_file "$_tf"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ biome-ignore-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-biome-$$.ts"

echo "  biome-ignore noExplicitAny (block):"
_setup_test_file "$_f" '// biome-ignore lint/suspicious/noExplicitAny: legacy
const x: any = {};'
_run_hook "biome-ignore-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "noExplicitAny biome-ignore blocked"
_cleanup_test_file "$_f"

echo "  other biome-ignore (warn):"
_setup_test_file "$_f" '// biome-ignore lint/correctness/noUnusedImports: needed
import { x } from "y";'
_run_hook "biome-ignore-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "other biome-ignore is warn"
_assert_stderr_contains "biome-ignore" "warns about biome-ignore"
_cleanup_test_file "$_f"

echo "  biome-ignore with escape (pass):"
_setup_test_file "$_f" '// allow: lint-ignore temporary workaround
// biome-ignore lint/correctness/noUnusedImports: needed
import { x } from "y";'
_run_hook "biome-ignore-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "lint-ignore escape passes"
_cleanup_test_file "$_f"

echo "  no biome-ignore (pass):"
_setup_test_file "$_f" 'import { x } from "y";
export const z = x;'
_run_hook "biome-ignore-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "clean file passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ ux-copy-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-ux-$$.tsx"

echo "  'successfully' in string (block):"
_setup_test_file "$_f" "const msg = \"Topic successfully created\";"
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "successfully blocked"
_assert_stderr_contains "successfully|Past-tense" "mentions successfully"
_cleanup_test_file "$_f"

echo "  exclamation in string literal (block):"
_setup_test_file "$_f" "const msg = \"Action completed!\";"
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "exclamation blocked"
_cleanup_test_file "$_f"

echo "  'click here' link text (block):"
_setup_test_file "$_f" 'const X = () => <a href="/docs">Click here</a>;'
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "click here blocked"
_cleanup_test_file "$_f"

echo "  Yes/No button labels (block):"
_setup_test_file "$_f" 'const X = () => <Button onClick={fn}>Yes</Button>;'
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "Yes/No labels blocked"
_cleanup_test_file "$_f"

echo "  blame language — oops (block):"
_setup_test_file "$_f" "const msg = \"Oops! Something went wrong\";"
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "blame language blocked"
_cleanup_test_file "$_f"

echo "  non-inclusive term — whitelist (block):"
_setup_test_file "$_f" "const label = \"Add to whitelist\";"
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "whitelist blocked"
_cleanup_test_file "$_f"

echo "  Please prefix (warn):"
_setup_test_file "$_f" "const hint = \"Please enter your email\";"
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "Please prefix is warn"
_assert_stderr_contains "Please|direct" "warns about Please"
_cleanup_test_file "$_f"

echo "  and/or (warn):"
_setup_test_file "$_f" "const desc = \"Select topics and/or partitions\";"
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "and/or is warn"
_cleanup_test_file "$_f"

echo "  etc. (warn):"
_setup_test_file "$_f" "const desc = \"Configure brokers, topics, etc.\";"
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "etc. is warn"
_cleanup_test_file "$_f"

echo "  ux-copy escape (pass):"
_setup_test_file "$_f" '// allow: ux-copy product requirement
const X = () => <p>Click here to continue!</p>;'
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "ux-copy escape passes"
_cleanup_test_file "$_f"

echo "  clean UX copy (pass):"
_setup_test_file "$_f" "const msg = \"Topic created\";"
_run_hook "ux-copy-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "clean copy passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ form-mode-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-form-mode-$$.tsx"

echo "  mode: 'onBlur' (warn):"
_setup_test_file "$_f" "import { useForm } from 'react-hook-form';
const MyForm = () => {
  const form = useForm({ mode: 'onBlur' });
  return <form />;
};"
_run_hook "form-mode-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "onBlur is warn"
_assert_stderr_contains "onChange" "suggests onChange"
_cleanup_test_file "$_f"

echo "  no useForm (skip):"
_setup_test_file "$_f" "const X = () => <form>hello</form>;"
_run_hook "form-mode-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "non-form file passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ tanstack-router-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-router-$$.tsx"

echo "  react-router-dom import (block):"
_setup_test_file "$_f" "import { useNavigate } from 'react-router-dom';"
_run_hook "tanstack-router-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "react-router-dom blocked"
_assert_stderr_contains "TanStack" "suggests TanStack Router"
_cleanup_test_file "$_f"

echo "  window.location.href assignment (block):"
_setup_test_file "$_f" 'window.location.href = "/dashboard";'
_run_hook "tanstack-router-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "window.location.href blocked"
_cleanup_test_file "$_f"

echo "  URLSearchParams in client file (block):"
_setup_test_file "$_f" "import { useSearch } from '@tanstack/react-router';
const params = new URLSearchParams(window.location.search);"
_run_hook "tanstack-router-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "URLSearchParams blocked"
_cleanup_test_file "$_f"

echo "  useParams without from (block):"
_setup_test_file "$_f" "import { useParams } from '@tanstack/react-router';
const params = useParams();"
_run_hook "tanstack-router-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "empty useParams blocked"
_cleanup_test_file "$_f"

echo "  useParams with from (pass):"
_setup_test_file "$_f" "import { useParams } from '@tanstack/react-router';
const params = useParams({ from: '/users/\$userId' });"
_run_hook "tanstack-router-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "useParams with from passes"
_cleanup_test_file "$_f"

echo "  clean TanStack file (pass):"
_setup_test_file "$_f" "import { Link } from '@tanstack/react-router';
const X = () => <Link to='/dashboard'>Go</Link>;"
_run_hook "tanstack-router-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "clean TanStack usage passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ test-convention-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-conv-$$.test.ts"

echo "  it() instead of test() (warn):"
_setup_test_file "$_f" "import { describe, it } from 'vitest';
describe('suite', () => {
  it('should work', () => { expect(1).toBe(1); });
});"
_run_hook "test-convention-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "it() is warn"
_assert_stderr_contains "test()" "suggests test()"
_cleanup_test_file "$_f"

echo "  jest.fn() (warn):"
_setup_test_file "$_f" "const mock = jest.fn();"
_run_hook "test-convention-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "jest.fn() is warn"
_assert_stderr_contains "vi.fn" "suggests vi.fn()"
_cleanup_test_file "$_f"

echo "  toBeInTheDocument (warn):"
_setup_test_file "$_f" "expect(el).toBeInTheDocument();"
_run_hook "test-convention-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "toBeInTheDocument is warn"
_assert_stderr_contains "toBeVisible" "suggests toBeVisible()"
_cleanup_test_file "$_f"

echo "  clean test file (pass):"
_setup_test_file "$_f" "import { test, expect, vi } from 'vitest';
test('works', () => { expect(1).toBe(1); });"
_run_hook "test-convention-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "clean test passes"
_cleanup_test_file "$_f"

echo "  non-test file (skip):"
_nf="/tmp/hook-test-conv-$$.ts"
_setup_test_file "$_nf" "const mock = jest.fn();"
_run_hook "test-convention-check.sh" "$(_edit_json "$_nf")"
_assert_exit 0 "non-test file skipped"
_cleanup_test_file "$_nf"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ legacy-import-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-legacy-$$.tsx"

echo "  @redpanda-data/ui import (warn):"
_setup_test_file "$_f" "import { Button } from '@redpanda-data/ui';"
_run_hook "legacy-import-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "@redpanda-data/ui is warn"
_assert_stderr_contains "redpanda-ui|registry" "suggests registry"
_cleanup_test_file "$_f"

echo "  direct lucide-react — no icons barrel (skip):"
_setup_test_file "$_f" "import { Trash } from 'lucide-react';"
_run_hook "legacy-import-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "lucide without icons barrel → no warn (correct)"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ mutation-naming-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-mutname-$$.tsx"

echo "  unnamed mutation result (warn):"
_setup_test_file "$_f" "import { useMutation } from '@tanstack/react-query';
const doDelete = useMutation({ mutationFn: deleteItem });"
_run_hook "mutation-naming-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "unnamed mutation is warn"
_assert_stderr_contains "Mutation" "suggests *Mutation suffix"
_cleanup_test_file "$_f"

echo "  properly named mutation (pass):"
_setup_test_file "$_f" "import { useMutation } from '@tanstack/react-query';
const deleteMutation = useMutation({ mutationFn: deleteItem });"
_run_hook "mutation-naming-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "named mutation passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ query-pattern-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-query-$$.ts"

echo "  refetchQueries (warn):"
_setup_test_file "$_f" "queryClient.refetchQueries({ queryKey: ['users'] });"
_run_hook "query-pattern-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "refetchQueries is warn"
_assert_stderr_contains "invalidateQueries" "suggests invalidateQueries"
_cleanup_test_file "$_f"

echo "  invalidateQueries without await (warn):"
_setup_test_file "$_f" "queryClient.invalidateQueries({ queryKey: ['users'] });"
_run_hook "query-pattern-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "no-await invalidate is warn"
_assert_stderr_contains "await|invalidateQueries" "warns about await"
_cleanup_test_file "$_f"

echo "  await invalidateQueries (pass):"
_setup_test_file "$_f" "await queryClient.invalidateQueries({ queryKey: ['users'] });"
_run_hook "query-pattern-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "await invalidateQueries passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ disabled-button-tooltip-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-disbtn-$$.tsx"

echo "  disabled Button without Tooltip (warn):"
_setup_test_file "$_f" "const X = () => <Button disabled onClick={fn}>Submit</Button>;"
_run_hook "disabled-button-tooltip-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "disabled without Tooltip is warn"
_assert_stderr_contains "[Tt]ooltip" "suggests Tooltip"
_cleanup_test_file "$_f"

echo "  disabled Button with Tooltip import (pass):"
_setup_test_file "$_f" "import { Tooltip } from '@/components/ui/tooltip';
const X = () => <Tooltip><Button disabled>Submit</Button></Tooltip>;"
_run_hook "disabled-button-tooltip-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "disabled with Tooltip passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ field-mask-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-fm-$$.ts"

echo "  hardcoded FieldMask paths (warn):"
_setup_test_file "$_f" "import { FieldMask } from '@bufbuild/protobuf';
const mask = { paths: ['name', 'description', 'config'] };"
_run_hook "field-mask-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "hardcoded FieldMask is warn"
_assert_stderr_contains "dirty" "suggests dirtyFields"
_cleanup_test_file "$_f"

echo "  no FieldMask (skip):"
_setup_test_file "$_f" "const paths = ['a', 'b', 'c'];"
_run_hook "field-mask-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "non-FieldMask passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ unhappy-path-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-unhappy-$$.tsx"

echo "  silent empty catch (warn):"
_setup_test_file "$_f" 'try { await api.fetch(); } catch (e) { }'
_run_hook "unhappy-path-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "empty catch is warn"
_assert_stderr_contains "swallow|silent|Catch|catch" "warns about silent catch"
_cleanup_test_file "$_f"

echo "  catch with error state (pass):"
_setup_test_file "$_f" 'const fn = async () => {
  try { await api.fetch(); }
  catch (e) { setError(e.message); }
};'
_run_hook "unhappy-path-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "catch with setError passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ magic-number-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-magic-$$.ts"

echo "  inline staleTime (warn):"
_setup_test_file "$_f" "const query = useQuery({ queryKey: ['x'], staleTime: 30000 });"
_run_hook "magic-number-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "inline staleTime is warn"
_assert_stderr_contains "named constant|stale" "suggests named constant"
_cleanup_test_file "$_f"

echo "  staleTime with escape (pass):"
_setup_test_file "$_f" "// allow: stale-time tuned for this query
const query = useQuery({ queryKey: ['x'], staleTime: 30000 });"
_run_hook "magic-number-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "stale-time escape passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ error-boundary-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-errbnd-$$.tsx"

echo "  route with loader but no errorComponent (block):"
_setup_test_file "$_f" "import { createFileRoute } from '@tanstack/react-router';
export const Route = createFileRoute('/users')({
  loader: () => fetchUsers(),
  component: UsersPage,
});"
_run_hook "error-boundary-check.sh" "$(_edit_json "$_f")"
_assert_exit 2 "missing errorComponent blocked"
_assert_stderr_contains "errorComponent" "suggests errorComponent"
_cleanup_test_file "$_f"

echo "  route with loader + errorComponent (pass):"
_setup_test_file "$_f" "import { createFileRoute } from '@tanstack/react-router';
export const Route = createFileRoute('/users')({
  loader: () => fetchUsers(),
  component: UsersPage,
  errorComponent: UsersError,
});"
_run_hook "error-boundary-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "route with errorComponent passes"
_cleanup_test_file "$_f"

echo "  non-route file (skip):"
_setup_test_file "$_f" "const X = () => <div>component</div>;"
_run_hook "error-boundary-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "non-route file skipped"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ test-perf-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-perf-$$.test.tsx"

echo "  userEvent.type() in integration test (warn):"
_setup_test_file "$_f" "import userEvent from '@testing-library/user-event';
test('input', async () => {
  const user = userEvent.setup();
  await user.type(input, 'hello');
});"
_run_hook "test-perf-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "userEvent.type() is warn"
_assert_stderr_contains "type|clear|paste|50ms" "warns about type perf"
_cleanup_test_file "$_f"

echo "  non-test file (skip):"
_nf="/tmp/hook-test-perf-$$.tsx"
_setup_test_file "$_nf" "await user.type(input, 'hello');"
_run_hook "test-perf-check.sh" "$(_edit_json "$_nf")"
_assert_exit 0 "non-test file skipped"
_cleanup_test_file "$_nf"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ bundle-guard.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  non-package.json file (skip):"
_f="/tmp/hook-test-bundle-$$.ts"
_setup_test_file "$_f" 'import moment from "moment";'
_run_hook "bundle-guard.sh" "$(_edit_json "$_f")"
_assert_exit 0 "non-package.json skipped"
_cleanup_test_file "$_f"

echo "  package.json with moment (block):"
_pf="/tmp/hook-test-bundle-pkg-$$/package.json"
mkdir -p "$(dirname "$_pf")"
_setup_test_file "$_pf" '{"dependencies":{"moment":"^2.30.0","react":"^18"}}'
_run_hook "bundle-guard.sh" "$(_edit_json "$_pf")"
_assert_exit 2 "moment in deps blocked"
_assert_stderr_contains "date-fns" "suggests date-fns"
_cleanup_test_file "$_pf"
_cleanup_test_dir "$(dirname "$_pf")"

echo "  package.json with lodash (block):"
_pf2="/tmp/hook-test-bundle-pkg2-$$/package.json"
mkdir -p "$(dirname "$_pf2")"
_setup_test_file "$_pf2" '{"dependencies":{"lodash":"^4.17.0"}}'
_run_hook "bundle-guard.sh" "$(_edit_json "$_pf2")"
_assert_exit 2 "lodash blocked"
_assert_stderr_contains "lodash-es" "suggests lodash-es"
_cleanup_test_file "$_pf2"
_cleanup_test_dir "$(dirname "$_pf2")"

echo "  package.json with classnames (block):"
_pf3="/tmp/hook-test-bundle-pkg3-$$/package.json"
mkdir -p "$(dirname "$_pf3")"
_setup_test_file "$_pf3" '{"dependencies":{"classnames":"^2.0.0"}}'
_run_hook "bundle-guard.sh" "$(_edit_json "$_pf3")"
_assert_exit 2 "classnames blocked"
_assert_stderr_contains "clsx" "suggests clsx"
_cleanup_test_file "$_pf3"
_cleanup_test_dir "$(dirname "$_pf3")"

echo "  clean package.json (pass):"
_pf4="/tmp/hook-test-bundle-pkg4-$$/package.json"
mkdir -p "$(dirname "$_pf4")"
_setup_test_file "$_pf4" '{"dependencies":{"react":"^18","date-fns":"^3.0.0"}}'
_run_hook "bundle-guard.sh" "$(_edit_json "$_pf4")"
_assert_exit 0 "clean deps pass"
_cleanup_test_file "$_pf4"
_cleanup_test_dir "$(dirname "$_pf4")"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ file-size-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  route file >300 LOC (warn):"
_f="/tmp/hook-test-routes/users-$$.tsx"
mkdir -p "$(dirname "$_f")"
# Generate a file with 301 lines that looks like a route
{
  echo "import { createFileRoute } from '@tanstack/react-router';"
  for i in $(seq 1 300); do
    echo "const line$i = $i;"
  done
} > "$_f"
_run_hook "file-size-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "large route file is warn (not block)"
_assert_stderr_contains "300|split|refactor" "warns about file size"
_cleanup_test_file "$_f"
_cleanup_test_dir "/tmp/hook-test-routes"

echo "  small file (pass):"
_f2="/tmp/hook-test-small-$$.tsx"
_setup_test_file "$_f2" "import { createFileRoute } from '@tanstack/react-router';
const X = () => <div>small</div>;"
_run_hook "file-size-check.sh" "$(_edit_json "$_f2")"
_assert_exit 0 "small file passes"
_cleanup_test_file "$_f2"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ hook-location-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  custom hook in route file (warn):"
_f="/tmp/hook-test-routes/hookroute-$$.tsx"
mkdir -p "$(dirname "$_f")"
_setup_test_file "$_f" "import { createFileRoute } from '@tanstack/react-router';
function useCustomData() { return useState(null); }
const Page = () => { const data = useCustomData(); return <div>{data}</div>; };"
_run_hook "hook-location-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "inline hook is warn"
_assert_stderr_contains "hooks/" "suggests /hooks/"
_cleanup_test_file "$_f"
_cleanup_test_dir "/tmp/hook-test-routes"

echo "  hook in hooks dir (pass):"
_f2="/tmp/hook-test-hooks-$$.ts"
_setup_test_file "$_f2" "export function useCustomData() { return useState(null); }"
_run_hook "hook-location-check.sh" "$(_edit_json "$_f2")"
_assert_exit 0 "hook in hooks dir passes"
_cleanup_test_file "$_f2"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ connect-error-format-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-cerr-$$.tsx"

echo "  catch without ConnectError.from (warn):"
_setup_test_file "$_f" "import { useMutation } from '@connectrpc/connect-query';
try { await fetchData(); }
catch (error) { toast.error(error.message); }"
_run_hook "connect-error-format-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "missing ConnectError.from is warn"
_assert_stderr_contains "ConnectError" "suggests ConnectError.from"
_cleanup_test_file "$_f"

echo "  non-connect file (skip):"
_setup_test_file "$_f" "try { await fetchData(); }
catch (error) { toast.error(error.message); }"
_run_hook "connect-error-format-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "non-connect file skipped"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ zustand-subscription-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-zussub-$$.tsx"

echo "  direct api.property read (warn):"
_setup_test_file "$_f" "import { api } from '../store';
const X = () => <div>{api.getState().count}</div>;"
_run_hook "zustand-subscription-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "api.getState in component is warn"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ url-state-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  useState for pagination in route (warn):"
_f="/tmp/hook-test-src/routes/urlstate-$$.tsx"
mkdir -p "$(dirname "$_f")"
_setup_test_file "$_f" "import { createFileRoute } from '@tanstack/react-router';
const [page, setPage] = useState(0);
const [sortBy, setSortBy] = useState('asc');"
_run_hook "url-state-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "url-state is warn"
_assert_stderr_contains "useSearch|validateSearch|URL" "suggests URL state"
_cleanup_test_file "$_f"
_cleanup_test_dir "/tmp/hook-test-src"

echo "  non-route file (skip):"
_f2="/tmp/hook-test-urlstate-$$.tsx"
_setup_test_file "$_f2" "const [page, setPage] = useState(1);"
_run_hook "url-state-check.sh" "$(_edit_json "$_f2")"
_assert_exit 0 "non-route file skipped"
_cleanup_test_file "$_f2"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ vendor-file-check.sh (verify existing + new) ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  node_modules .d.ts (not in blocked dirs — passes):"
_run_hook "vendor-file-check.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/project/node_modules/@types/react/index.d.ts","old_string":"x","new_string":"y"}}'
_assert_exit 0 "node_modules not in vendor block list"

echo "  fumadocs dir (block):"
_run_hook "vendor-file-check.sh" '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/project/fumadocs/utils.tsx","old_string":"x","new_string":"y"}}'
_assert_exit 2 "fumadocs dir blocked"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ llm-test-flags.sh (PreToolUse) ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  vitest with --verbose (rewrite, exit 0 with updatedInput):"
_run_hook "llm-test-flags.sh" '{"tool_name":"Bash","tool_input":{"command":"vitest run --verbose src/"}}'
_assert_exit 0 "--verbose rewritten (allow with updated input)"
_assert_stderr_contains "updatedInput" "provides updatedInput"

echo "  non-test command (pass):"
_run_hook "llm-test-flags.sh" '{"tool_name":"Bash","tool_input":{"command":"bun run build"}}'
_assert_exit 0 "non-test command passes"

echo "  non-Bash tool (pass):"
_run_hook "llm-test-flags.sh" '{"tool_name":"Edit","tool_input":{"file_path":"x.ts"}}'
_assert_exit 0 "non-Bash tool passes"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ llm-truncate.sh (PostToolUse Bash) ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

echo "  short output (no truncation):"
_run_hook "llm-truncate.sh" '{"tool_name":"Bash","tool_input":{"command":"ls"},"tool_result":{"stdout":"file1\nfile2\nfile3"}}'
_assert_exit 0 "short output passes through"

echo "  non-Bash tool (skip):"
_run_hook "llm-truncate.sh" '{"tool_name":"Edit","tool_input":{"file_path":"x.ts"}}'
_assert_exit 0 "non-Bash tool skipped"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ connect-error-fieldmap-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-fieldmap-$$.tsx"

echo "  toast-only ConnectError on proto form (warn):"
_setup_test_file "$_f" "import { useProtoForm } from '@/lib/forms';
import { formatConnectError } from '@/lib/errors';
const X = () => {
  const form = useProtoForm({ schema: S });
  return <form onSubmit={form.handleSubmit(() => {
    try { doIt() } catch (e) { toast.error(formatConnectError(e)) }
  })} />;
};"
_run_hook "connect-error-fieldmap-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "toast-only is warn"
_assert_stderr_contains "FieldViolation|setError" "suggests setError mapping"
_cleanup_test_file "$_f"

echo "  setError present (pass):"
_setup_test_file "$_f" "import { useProtoForm } from '@/lib/forms';
import { ConnectError } from '@connectrpc/connect';
const X = () => {
  const form = useProtoForm({ schema: S });
  return <form onSubmit={form.handleSubmit(() => {
    const ce = ConnectError.from(e);
    ce.findDetails(BadRequestSchema).forEach(d => d.fieldViolations.forEach(v => form.setError(v.field, { type: 'server' })));
  })} />;
};"
_run_hook "connect-error-fieldmap-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "mapped fields pass"
_assert_stderr_not_contains "FieldViolation" "no warning when mapped"
_cleanup_test_file "$_f"

echo "  no form handler (skip):"
_setup_test_file "$_f" "const X = formatConnectError(err);"
_run_hook "connect-error-fieldmap-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "non-form file passes"
_assert_stderr_not_contains "FieldViolation" "no warning"
_cleanup_test_file "$_f"

echo "  escape hatch (pass):"
_setup_test_file "$_f" "// allow: connect-error-fieldmap legacy toast-only flow
import { useProtoForm } from '@/lib/forms';
const X = () => {
  const form = useProtoForm({ schema: S });
  return <form onSubmit={form.handleSubmit(() => toast.error(formatConnectError(e)))} />;
};"
_run_hook "connect-error-fieldmap-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "escape hatch passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ proto-form-parallel-state-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-parallel-$$.tsx"

echo "  parallel useState<*Config> beside useProtoForm (warn):"
_setup_test_file "$_f" "import { useProtoForm } from '@/lib/forms';
import { useState } from 'react';
const X = () => {
  const form = useProtoForm({ schema: S });
  const [authConfig, setAuthConfig] = useState<McpAuthConfig>({});
  return <form />;
};"
_run_hook "proto-form-parallel-state-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "parallel Config state is warn"
_assert_stderr_contains "drift|parallel|useProtoForm" "mentions drift"
_cleanup_test_file "$_f"

echo "  useState for UI state (pass):"
_setup_test_file "$_f" "import { useProtoForm } from '@/lib/forms';
import { useState } from 'react';
const X = () => {
  const form = useProtoForm({ schema: S });
  const [open, setOpen] = useState<boolean>(false);
  return <form />;
};"
_run_hook "proto-form-parallel-state-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "UI state passes"
_assert_stderr_not_contains "drift" "no warning"
_cleanup_test_file "$_f"

echo "  non-proto form (skip):"
_setup_test_file "$_f" "import { useState } from 'react';
const X = () => {
  const [cfg, setCfg] = useState<FooConfig>({});
  return <div />;
};"
_run_hook "proto-form-parallel-state-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "no useProtoForm, passes"
_assert_stderr_not_contains "drift" "no warning"
_cleanup_test_file "$_f"

echo "  escape hatch (pass):"
_setup_test_file "$_f" "// allow: proto-form-parallel-state transient wizard state
import { useProtoForm } from '@/lib/forms';
import { useState } from 'react';
const X = () => {
  const form = useProtoForm({ schema: S });
  const [wizard, setWizard] = useState<WizardConfig>({});
  return <form />;
};"
_run_hook "proto-form-parallel-state-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "escape hatch passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ form-setvalue-options-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-setvalue-$$.tsx"

echo "  setValue without options (warn):"
_setup_test_file "$_f" "const handler = () => { form.setValue('name', 'x'); };"
_run_hook "form-setvalue-options-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "no-options setValue is warn"
_assert_stderr_contains "shouldDirty|shouldValidate" "mentions options"
_cleanup_test_file "$_f"

echo "  setValue with options (pass):"
_setup_test_file "$_f" "const handler = () => { form.setValue('name', 'x', { shouldDirty: true, shouldValidate: true }); };"
_run_hook "form-setvalue-options-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "options-provided passes"
_assert_stderr_not_contains "shouldDirty" "no warning"
_cleanup_test_file "$_f"

echo "  no setValue (skip):"
_setup_test_file "$_f" "const X = () => <div />;"
_run_hook "form-setvalue-options-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "no setValue passes"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════
echo ""
echo "━━━ form-error-summary-check.sh ━━━"
# ═══════════════════════════════════════════════════════════════

_setup_session

_f="/tmp/hook-test-summary-$$.tsx"

echo "  multi-field proto form without summary (warn):"
_setup_test_file "$_f" "import { useProtoForm } from '@/lib/forms';
const X = () => {
  const form = useProtoForm({ schema: S });
  return <form onSubmit={form.handleSubmit(onOk)}>
    <ProtoField name=\"a\" />
    <ProtoField name=\"b\" />
  </form>;
};"
_run_hook "form-error-summary-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "missing summary is warn"
_assert_stderr_contains "FormErrorSummary|aria-live|role" "mentions summary primitive"
_cleanup_test_file "$_f"

echo "  form with FormErrorSummary (pass):"
_setup_test_file "$_f" "import { useProtoForm } from '@/lib/forms';
const X = () => {
  const form = useProtoForm({ schema: S });
  return <form onSubmit={form.handleSubmit(onOk)}>
    <FormErrorSummary form={form} />
    <ProtoField name=\"a\" />
    <ProtoField name=\"b\" />
  </form>;
};"
_run_hook "form-error-summary-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "summary present passes"
_assert_stderr_not_contains "FormErrorSummary" "no warning"
_cleanup_test_file "$_f"

echo "  single-field form (skip):"
_setup_test_file "$_f" "import { useProtoForm } from '@/lib/forms';
const X = () => {
  const form = useProtoForm({ schema: S });
  return <form onSubmit={form.handleSubmit(onOk)}>
    <ProtoField name=\"q\" />
  </form>;
};"
_run_hook "form-error-summary-check.sh" "$(_edit_json "$_f")"
_assert_exit 0 "tiny form skipped"
_assert_stderr_not_contains "FormErrorSummary" "no warning"
_cleanup_test_file "$_f"

_teardown_session

# ═══════════════════════════════════════════════════════════════

_report_results "Pattern-Check Hooks"
