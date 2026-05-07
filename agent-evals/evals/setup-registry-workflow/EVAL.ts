import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

// ── StatusBadge (Atom) ──────────────────────────────────────────

describe("setup-registry-workflow: Atom — StatusBadge", () => {
  it("should create StatusBadge.tsx", () => {
    expect(existsSync("src/components/StatusBadge.tsx")).toBe(true);
  });

  it("should export prop interface", () => {
    const content = readFileSync("src/components/StatusBadge.tsx", "utf-8");
    expect(content).toMatch(
      /export\s+(interface|type)\s+StatusBadge(Props|Type)/
    );
  });

  it("should use discriminated union for variant props", () => {
    const content = readFileSync("src/components/StatusBadge.tsx", "utf-8");
    // Should have union type with variant-specific props
    expect(content).toMatch(/variant:\s*['"]error['"]/);
    expect(content).toMatch(/onRetry/);
  });

  it("should use cva for variants", () => {
    const content = readFileSync("src/components/StatusBadge.tsx", "utf-8");
    expect(content).toMatch(/\bcva\b/);
  });

  it("should forward ref", () => {
    const content = readFileSync("src/components/StatusBadge.tsx", "utf-8");
    expect(content).toMatch(/forwardRef|ref/);
  });

  it("should have ZERO useState (atom requirement)", () => {
    const content = readFileSync("src/components/StatusBadge.tsx", "utf-8");
    expect(content).not.toMatch(/\buseState\b/);
  });

  it("should have NO side effects in component body", () => {
    const content = readFileSync("src/components/StatusBadge.tsx", "utf-8");
    expect(content).not.toMatch(/\buseEffect\b/);
    expect(content).not.toMatch(
      /\b(localStorage|sessionStorage)\.(setItem|removeItem)/
    );
  });

  it("should spread remaining props", () => {
    const content = readFileSync("src/components/StatusBadge.tsx", "utf-8");
    expect(content).toMatch(/\.\.\.props/);
  });
});

// ── StatusFilter (Molecule) ─────────────────────────────────────

describe("setup-registry-workflow: Molecule — StatusFilter", () => {
  it("should create StatusFilter.tsx", () => {
    expect(existsSync("src/components/StatusFilter.tsx")).toBe(true);
  });

  it("should compose StatusBadge from registry", () => {
    const content = readFileSync("src/components/StatusFilter.tsx", "utf-8");
    expect(content).toMatch(/import.*StatusBadge/);
  });

  it("should have exactly 2 useState (molecule range)", () => {
    const content = readFileSync("src/components/StatusFilter.tsx", "utf-8");
    const matches = content.match(/\buseState\b/g) || [];
    expect(matches.length).toBe(2);
  });

  it("should derive filtered items with useMemo not useState+useEffect", () => {
    const content = readFileSync("src/components/StatusFilter.tsx", "utf-8");
    expect(content).toMatch(/\buseMemo\b/);
    // Should NOT have the anti-pattern: useEffect setting derived state
    const hasUseEffect = /\buseEffect\b/.test(content);
    const hasDerivedSetter = /useEffect\(.*set[A-Z]/.test(content);
    expect(hasUseEffect && hasDerivedSetter).toBe(false);
  });

  it("should use generic type parameter", () => {
    const content = readFileSync("src/components/StatusFilter.tsx", "utf-8");
    expect(content).toMatch(/<T\s*(extends|,)/);
  });

  it("should use immutable state updates only", () => {
    const content = readFileSync("src/components/StatusFilter.tsx", "utf-8");
    expect(content).not.toMatch(
      /\.(push|splice|unshift|pop|shift|reverse|sort)\(/
    );
  });
});

// ── StatusDashboard (Organism) ──────────────────────────────────

describe("setup-registry-workflow: Organism — StatusDashboard", () => {
  it("should create StatusDashboard.tsx", () => {
    expect(existsSync("src/components/StatusDashboard.tsx")).toBe(true);
  });

  it("should compose multiple registry components (3+)", () => {
    const content = readFileSync("src/components/StatusDashboard.tsx", "utf-8");
    const imports = content.match(/import.*from/g) || [];
    // Should import at least StatusFilter, StatusBadge, and Dialog/Card
    expect(imports.length).toBeGreaterThanOrEqual(3);
  });

  it("should use useReducer not 3+ useState", () => {
    const content = readFileSync("src/components/StatusDashboard.tsx", "utf-8");
    expect(content).toMatch(/\buseReducer\b/);
    // Should NOT have 3+ useState
    const useStateCount = (content.match(/\buseState\b/g) || []).length;
    expect(useStateCount).toBeLessThan(3);
  });

  it("should define reducer OUTSIDE component", () => {
    const content = readFileSync("src/components/StatusDashboard.tsx", "utf-8");
    // Reducer should be defined before the component function
    const reducerIndex = content.search(
      /const\s+\w*[Rr]educer\s*=|function\s+\w*[Rr]educer/
    );
    const componentIndex = content.search(
      /export\s+(default\s+)?function\s+StatusDashboard|export\s+const\s+StatusDashboard/
    );
    expect(reducerIndex).toBeGreaterThanOrEqual(0);
    expect(componentIndex).toBeGreaterThan(reducerIndex);
  });

  it("should have keyboard handler for Escape", () => {
    const content = readFileSync("src/components/StatusDashboard.tsx", "utf-8");
    expect(content).toMatch(/Escape|onKeyDown|handleKeyDown/);
  });

  it("should render Dialog (portal component)", () => {
    const content = readFileSync("src/components/StatusDashboard.tsx", "utf-8");
    expect(content).toMatch(/<Dialog|<AlertDialog/);
  });

  it("should extract groupByStatus as named pure function", () => {
    const content = readFileSync("src/components/StatusDashboard.tsx", "utf-8");
    expect(content).toMatch(/groupByStatus/);
    // Should be defined outside component
    const fnIndex = content.search(/groupByStatus/);
    const componentIndex = content.search(
      /export\s+(default\s+)?function\s+StatusDashboard|export\s+const\s+StatusDashboard/
    );
    expect(fnIndex).toBeLessThan(componentIndex);
  });

  it("should NOT mutate state directly", () => {
    const content = readFileSync("src/components/StatusDashboard.tsx", "utf-8");
    expect(content).not.toMatch(
      /\.(push|splice|unshift|pop|shift|reverse|sort)\(/
    );
    expect(content).not.toMatch(/\bdelete\s+\w+\[/);
  });

  it("should NOT use useState+useEffect sync pattern", () => {
    const content = readFileSync("src/components/StatusDashboard.tsx", "utf-8");
    const hasUseEffect = /\buseEffect\b/.test(content);
    if (hasUseEffect) {
      // If useEffect exists, it should NOT be setting state from derived values
      const effectSetsState =
        /useEffect\([^]*?set[A-Z][a-zA-Z]*\([^]*?\}\s*,\s*\[/.test(content);
      expect(effectSetsState).toBe(false);
    }
  });
});
