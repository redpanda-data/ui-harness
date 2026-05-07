import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

describe("setup-code-organization: LLM respects code organization rules", () => {
  // ── File existence ─────────────────────────────────────────────

  it("should create hooks file in src/hooks/", () => {
    expect(existsSync("src/hooks/use-connections.ts")).toBe(true);
  });

  it("should create route file", () => {
    expect(existsSync("src/routes/connections.tsx")).toBe(true);
  });

  // ── Hook location: no custom hooks in route files ──────────────

  it("should NOT define custom hooks in route file", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    // No function use* definitions in route files
    expect(content).not.toMatch(
      /(?:export\s+)?function\s+use[A-Z][a-zA-Z]*\s*\(/
    );
  });

  it("should import hooks from hooks directory", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    expect(content).toMatch(/from\s+['"].*hooks\/use-connections['"]/);
  });

  // ── Route file size ────────────────────────────────────────────

  it("should keep route file under 300 lines", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    const lineCount = content.split("\n").length;
    expect(lineCount).toBeLessThanOrEqual(300);
  });

  // ── Mutation pattern: useMutation for side effects ─────────────

  it("should use useMutation in hooks file for disconnect", () => {
    const content = readFileSync("src/hooks/use-connections.ts", "utf-8");
    expect(content).toMatch(/useMutation/);
  });

  it("should NOT have raw fetch with DELETE method in route file", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    expect(content).not.toMatch(/method:\s*['"]DELETE['"]/);
  });

  it("should NOT have raw fetch with POST method in route file handlers", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    // fetch + POST in the same file (outside of hook) = bad pattern
    const hasFetch = /\bfetch\s*\(/.test(content);
    const hasPost = /method:\s*['"]POST['"]/.test(content);
    expect(hasFetch && hasPost).toBe(false);
  });

  // ── Form mode: onChange required ───────────────────────────────

  it("should NOT use form mode onBlur", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    expect(content).not.toMatch(/mode:\s*['"]onBlur['"]/);
  });

  it("should NOT use form mode onSubmit", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    expect(content).not.toMatch(/mode:\s*['"]onSubmit['"]/);
  });

  // ── biome-ignore noExplicitAny ban ─────────────────────────────

  it("should NOT use biome-ignore noExplicitAny in hooks file", () => {
    const content = readFileSync("src/hooks/use-connections.ts", "utf-8");
    expect(content).not.toMatch(
      /biome-ignore\s+lint\/suspicious\/noExplicitAny/
    );
  });

  it("should NOT use biome-ignore noExplicitAny in route file", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    expect(content).not.toMatch(
      /biome-ignore\s+lint\/suspicious\/noExplicitAny/
    );
  });

  // ── No window.location reads ──────────────────────────────────

  it("should NOT use window.location in route file", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    expect(content).not.toMatch(
      /window\.location\.(href|assign|replace|search|pathname|hash|origin)/
    );
  });

  // ── No type escape hatches ──────────────────────────────────────

  it("should NOT use type escape hatches in hooks file", () => {
    const content = readFileSync("src/hooks/use-connections.ts", "utf-8");
    const pattern = new RegExp("\\bas\\s+" + "any\\b");
    expect(pattern.test(content)).toBe(false);
  });

  it("should NOT use type escape hatches in route file", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    const pattern = new RegExp("\\bas\\s+" + "any\\b");
    expect(pattern.test(content)).toBe(false);
  });

  // ── Error boundary: route with loader needs errorComponent ─────

  it("should have errorComponent when route has loader", () => {
    const content = readFileSync("src/routes/connections.tsx", "utf-8");
    const hasLoader = /\bloader\s*:/.test(content);
    if (hasLoader) {
      expect(content).toMatch(/\berrorComponent\s*:/);
    }
  });

  // ── TDD: new files should have test files ──────────────────────

  it("should have test file for hooks", () => {
    const hasTest =
      existsSync("src/hooks/use-connections.test.ts") ||
      existsSync("src/hooks/use-connections.test.tsx") ||
      existsSync("src/hooks/use-connections.spec.ts");
    // Soft check: test file SHOULD exist for new hooks
    expect(hasTest).toBe(true);
  });
});
