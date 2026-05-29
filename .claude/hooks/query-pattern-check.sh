#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

hook_parse_edit_write
hook_filter_extensions "ts|tsx"
hook_skip_generated
hook_skip_tests
hook_get_added_lines

file_content=$(cat "$file_path" 2>/dev/null || true)

# Source material: @tanstack/eslint-plugin-query v5.100.14 rules inspected:
# exhaustive-deps, stable-query-client, no-rest-destructuring,
# no-unstable-deps, no-void-query-fn, property order, prefer-query-options.
# Vendored here as lightweight project hooks; no ESLint runtime dependency.

# ── Existing project checks ──────────────────────────────────────

if echo "$added_lines" | grep -qE '\.refetchQueries\('; then
  if ! hook_has_escape "refetch-queries"; then
    hook_warn "Prefer invalidateQueries() over refetchQueries(). Invalidation lets React Query decide optimal refetch timing. Escape: // allow: refetch-queries [reason]" "query-pattern-refetch"
  fi
fi

no_await=$(echo "$added_lines" | grep -E 'invalidateQueries\(' | grep -vE 'await|return' || true)
if [ -n "$no_await" ]; then
  if ! hook_has_escape "await-invalidate"; then
    hook_warn "Always await invalidateQueries() — without await, subsequent code may see stale cache. Escape: // allow: await-invalidate [reason]" "query-pattern-await"
  fi
fi

# ── TanStack ESLint intent: stable-query-client ───────────────────
# A QueryClient created during render is unstable and can wipe cache.

if echo "$added_lines" | grep -qE 'new[[:space:]]+QueryClient[[:space:]]*\('; then
  if hook_has_escape "unstable-query-client"; then
    :
  elif ! echo "$added_lines" | grep -qE 'useState[[:space:]]*\([^\n]*new[[:space:]]+QueryClient|useMemo[[:space:]]*\([^\n]*new[[:space:]]+QueryClient'; then
    if echo "$file_content" | grep -qE 'function[[:space:]]+[A-Z][A-Za-z0-9_]*[[:space:]]*\(|const[[:space:]]+[A-Z][A-Za-z0-9_]*[[:space:]]*=.*=>|<[A-Za-z][A-Za-z0-9.]*'; then
      hook_block "TanStack Query: QueryClient must be stable. Create it outside components or via React.useState(() => new QueryClient()). Escape: // allow: unstable-query-client [reason]"
    fi
  fi
fi

# ── TanStack ESLint intent: no-rest-destructuring ─────────────────
# Rest destructuring observes every query result property → excess renders.

if echo "$added_lines" | grep -qE '\{[^}\n]*\.\.\.[A-Za-z_$][A-Za-z0-9_$]*[^}\n]*\}[[:space:]]*=[[:space:]]*(use(Query|InfiniteQuery|SuspenseQuery|SuspenseInfiniteQuery)|[A-Za-z_$][A-Za-z0-9_$]*Query\b)'; then
  if ! hook_has_escape "query-rest-destructure"; then
    hook_warn "TanStack Query: avoid rest destructuring query results; it subscribes to all result changes. Destructure only fields used. Escape: // allow: query-rest-destructure [reason]" "query-pattern-rest"
  fi
fi

# ── TanStack ESLint intent: no-unstable-deps ──────────────────────
# Query hook return object is not referentially stable. Dependency arrays
# should contain destructured fields, not the whole query object.

query_vars=$(printf '%s\n%s' "$file_content" "$added_lines" | grep -oE '[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*=[[:space:]]*use(Query|InfiniteQuery|SuspenseQuery|SuspenseInfiniteQuery)[[:space:]]*\(' | sed -E 's/[[:space:]]*=.*//' | sort -u || true)
if [ -n "$query_vars" ]; then
  while IFS= read -r qv; do
    [ -z "$qv" ] && continue
    if echo "$added_lines" | grep -qE '\[[^]]*\b'"$qv"'\b[^]]*\]'; then
      if ! hook_has_escape "unstable-query-deps"; then
        hook_block "TanStack Query: '$qv' query result is not stable. Destructure fields and put those fields in hook dependency arrays. Escape: // allow: unstable-query-deps [reason]"
      fi
    fi
  done <<< "$query_vars"
fi

# ── TanStack ESLint intent: no-void-query-fn ──────────────────────
# queryFn must return data; block common block-body forms with no return.

if echo "$added_lines" | tr '\n' ' ' | grep -qE 'queryFn[[:space:]]*:[[:space:]]*(async[[:space:]]*)?\([^)]*\)[[:space:]]*=>[[:space:]]*\{[^}]*\}'; then
  query_fn_blocks=$(echo "$added_lines" | tr '\n' ' ' | grep -oE 'queryFn[[:space:]]*:[[:space:]]*(async[[:space:]]*)?\([^)]*\)[[:space:]]*=>[[:space:]]*\{[^}]*\}' || true)
  if [ -n "$query_fn_blocks" ] && ! echo "$query_fn_blocks" | grep -qE '\breturn\b'; then
    hook_block "TanStack Query: queryFn must return a value. Add return/implicit expression; undefined query data breaks cache semantics."
  fi
fi

# ── TanStack ESLint intent: exhaustive-deps (low-noise subset) ───
# Warn only when we can see a direct queryFn call argument that is missing
# from a literal queryKey in the same edited chunk. Ambiguous cases pass.

compact_added=$(echo "$added_lines" | tr '\n' ' ')
if echo "$compact_added" | grep -qE 'queryKey[[:space:]]*:[[:space:]]*\[[^]]*\].*queryFn[[:space:]]*:'; then
  if ! hook_has_escape "query-key-deps"; then
    query_key_literal=$(echo "$compact_added" | sed -nE 's/.*queryKey[[:space:]]*:[[:space:]]*\[([^]]*)\].*/\1/p' | head -1)
    query_fn_args=$(echo "$compact_added" | sed -nE 's/.*queryFn[[:space:]]*:[^=]*=>[[:space:]]*(return[[:space:]]+)?[A-Za-z_$][A-Za-z0-9_$]*[[:space:]]*\(([^)]*)\).*/\2/p' | head -1)
    if [ -n "$query_fn_args" ]; then
      missing_deps=""
      candidates=$(echo "$query_fn_args" | tr ',' '\n' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g' | grep -E '^[A-Za-z_$][A-Za-z0-9_$]*$' | grep -Ev '^(signal|pageParam|meta|context|ctx|client|queryClient)$' || true)
      while IFS= read -r dep; do
        [ -z "$dep" ] && continue
        if ! echo "$query_key_literal" | grep -qE '(^|[^A-Za-z0-9_$])'"$dep"'([^A-Za-z0-9_$]|$)'; then
          missing_deps="${missing_deps}${missing_deps:+, }$dep"
        fi
      done <<< "$candidates"
      if [ -n "$missing_deps" ]; then
        hook_warn "TanStack Query: queryFn uses $missing_deps but queryKey does not include it. Add it to queryKey or escape: // allow: query-key-deps [reason]" "query-pattern-key-deps"
      fi
    fi
  fi
fi

# ── TanStack ESLint intent: inference-sensitive property order ────
# Type inference is better when mutation callbacks and infinite query fns
# appear in the order TanStack expects.

if echo "$added_lines" | tr '\n' ' ' | grep -qE 'useMutation\([^{]*\{[^}]*on(Error|Settled)[^}]*onMutate'; then
  hook_warn "TanStack Query: put onMutate before onError/onSettled in useMutation options for reliable inference." "query-pattern-mutation-order"
fi

if echo "$added_lines" | tr '\n' ' ' | grep -qE '(useInfiniteQuery|useSuspenseInfiniteQuery|infiniteQueryOptions)\([^{]*\{[^}]*get(Next|Previous)PageParam[^}]*queryFn'; then
  hook_warn "TanStack Query: put queryFn before getPreviousPageParam/getNextPageParam in infinite query options for reliable inference." "query-pattern-infinite-order"
fi

# ── TanStack ESLint intent: prefer-query-options (strict) ─────────
# High-value subset only: nudge duplicated queryKey/queryFn object literals.

if echo "$added_lines" | grep -qE 'use(Query|InfiniteQuery|SuspenseQuery|SuspenseInfiniteQuery)\([[:space:]]*\{' && echo "$added_lines" | grep -qE 'queryKey[[:space:]]*:.*queryFn[[:space:]]*:|queryFn[[:space:]]*:.*queryKey[[:space:]]*:'; then
  if ! hook_has_escape "inline-query-options"; then
    hook_warn "TanStack Query: consider queryOptions()/infiniteQueryOptions() to co-locate queryKey and queryFn for reuse. Escape: // allow: inline-query-options [reason]" "query-pattern-options"
  fi
fi

exit 0
