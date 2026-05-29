# HTML Report Format

The architectural review is rendered as a single self-contained HTML file in the OS temp directory. Tailwind and Mermaid both come from CDNs. Mermaid handles graph-shaped diagrams reliably; hand-built divs and inline SVG handle editorial visuals such as mass diagrams and cross-sections. Mix them. Do not lean on Mermaid for everything.

## Scaffold

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Architecture review -- {{repo name}}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
      mermaid.initialize({ startOnLoad: true, theme: "neutral", securityLevel: "loose" });
    </script>
    <style>
      .seam { stroke-dasharray: 4 4; }
      .leak { stroke: #dc2626; }
      .deep { background: linear-gradient(135deg, #0f172a, #1e293b); }
    </style>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans">
    <main class="max-w-5xl mx-auto px-6 py-12 space-y-12">
      <header>...</header>
      <section id="candidates" class="space-y-10">...</section>
      <section id="top-recommendation">...</section>
    </main>
  </body>
</html>
```

## Header

Repo name, date, and compact legend: solid box = module, dashed line = seam, red arrow = leakage, thick dark box = deep module. No intro paragraph. Go straight into candidates.

## Candidate card

Diagrams carry the weight. Prose is sparse, plain, and uses [LANGUAGE.md](LANGUAGE.md) terms.

Each candidate is one `<article>`:

- **Title**: short, names the deepening, for example "Collapse the Order intake pipeline".
- **Badge row**: recommendation strength (`Strong` = emerald, `Worth exploring` = amber, `Speculative` = slate), plus dependency category (`in-process`, `local-substitutable`, `ports & adapters`, `mock`).
- **Files**: monospaced list, `font-mono text-sm`.
- **Before / After diagram**: centrepiece. Two columns, side by side.
- **Problem**: one sentence. What hurts.
- **Solution**: one sentence. What changes.
- **Wins**: bullets, 6 words or fewer.
- **ADR callout**: if applicable, one line in an amber-tinted box.

No paragraphs of explanation. If the diagram needs a paragraph to be understood, redraw it.

## Diagram patterns

Pick the pattern that fits the candidate. Vary the diagrams.

### Mermaid graph

Use a Mermaid `flowchart` or `graph` when the point is call/dependency shape. Wrap it in a Tailwind-styled card. Style leakage red and deep modules dark.

```html
<div class="rounded-lg border border-slate-200 bg-white p-4">
  <pre class="mermaid">
    flowchart LR
      A[OrderHandler] --> B[OrderValidator]
      B --> C[OrderRepo]
      C -.leak.-> D[PricingClient]
      classDef leak stroke:#dc2626,stroke-width:2px;
      class C,D leak
  </pre>
</div>
```

### Hand-built boxes and arrows

Use `<div>` modules with borders and labels. Use inline SVG lines or paths positioned over a relative container. Good when the after state should feel like one thick-bordered deep module with greyed-out internals.

### Cross-section

Stack horizontal bands (`h-12 border-l-4`) to show layers a call passes through. Before: many thin layers doing little. After: one thick band labelled with the consolidated responsibility.

### Mass diagram

Two rectangles per module: one for interface surface area, one for implementation. Before: interface nearly as tall as implementation. After: interface short, implementation tall.

### Call-graph collapse

Before: tree of function calls as nested boxes. After: same tree collapsed into one box, with internal calls faded inside.

## Style guidance

- Lean editorial, not corporate dashboard. Generous whitespace.
- Colour sparingly: one accent plus red for leakage and amber for warnings.
- Keep diagrams about 320px tall so before/after fits side by side.
- Use `text-xs uppercase tracking-wider` for module labels.
- Only scripts: Tailwind CDN and Mermaid ESM import. Otherwise static.

## Top recommendation

One larger card. Candidate name, one sentence on why, anchor link to its card.

## Tone

Plain English. Concise. Architectural nouns and verbs come from [LANGUAGE.md](LANGUAGE.md).

**Use exactly:** module, interface, implementation, depth, deep, shallow, seam, adapter, leverage, locality.

**Never substitute:** component, service, unit for module; API or signature for interface; boundary for seam; layer or wrapper when you mean module.

Good phrasing:

- "Order intake module is shallow: interface nearly matches the implementation."
- "Pricing leaks across the seam."
- "Deepen: one interface, one place to test."
- "Two adapters justify the seam: HTTP in prod, in-memory in tests."

Wins bullets name gains in glossary terms:

- "locality: bugs concentrate in one module"
- "leverage: one interface, N call sites"
- "interface shrinks; implementation absorbs wrappers"

No hedging. No throat-clearing. If a sentence could be a bullet, make it a bullet. If a bullet could be cut, cut it.
