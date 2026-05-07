import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

const storeFiles = [
  "src/stores/auth-store.ts",
  "src/stores/theme-store.ts",
  "src/stores/cart-store.ts",
];

describe("violation-nudge: agent adjusts after repeated blocks", () => {
  it("should create all store files", () => {
    for (const file of storeFiles) {
      expect(existsSync(file)).toBe(true);
    }
  });

  it("should create the dashboard component", () => {
    expect(existsSync("src/components/Dashboard.tsx")).toBe(true);
  });

  for (const file of storeFiles) {
    it(`should use double-parens pattern in ${file}`, () => {
      const content = readFileSync(file, "utf-8");
      expect(content).toMatch(/create[^)]*\)\s*\(/);
    });

    it(`should NOT use direct localStorage in ${file}`, () => {
      const content = readFileSync(file, "utf-8");
      expect(content).not.toMatch(/\blocalStorage\b/);
    });

    it(`should use persist middleware in ${file}`, () => {
      const content = readFileSync(file, "utf-8");
      expect(content).toMatch(/persist/);
    });
  }

  it("should use useShallow in dashboard component", () => {
    const content = readFileSync("src/components/Dashboard.tsx", "utf-8");
    expect(content).toMatch(/useShallow/);
  });

  it("should NOT have inline object selectors without useShallow", () => {
    const content = readFileSync("src/components/Dashboard.tsx", "utf-8");
    const hasInlineObject = /\(state\)\s*=>\s*\(\{/.test(content);
    const hasUseShallow = /useShallow/.test(content);
    expect(hasInlineObject && !hasUseShallow).toBe(false);
  });
});
