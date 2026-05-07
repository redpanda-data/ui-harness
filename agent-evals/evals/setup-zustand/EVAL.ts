import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

describe("setup-zustand: LLM respects zustand best practices", () => {
  it("should create the store file", () => {
    expect(existsSync("src/stores/settings-store.ts")).toBe(true);
  });

  it("should create the component file", () => {
    expect(existsSync("src/components/SettingsPanel.tsx")).toBe(true);
  });

  it("should use double-parens create pattern", () => {
    const content = readFileSync("src/stores/settings-store.ts", "utf-8");
    // Should have )() — double invocation
    expect(content).toMatch(/create[^)]*\)\s*\(/);
  });

  it("should NOT use direct localStorage in store", () => {
    const content = readFileSync("src/stores/settings-store.ts", "utf-8");
    expect(content).not.toMatch(/\blocalStorage\b/);
  });

  it("should use persist middleware", () => {
    const content = readFileSync("src/stores/settings-store.ts", "utf-8");
    expect(content).toMatch(/persist/);
  });

  it("should use useShallow in component", () => {
    const content = readFileSync("src/components/SettingsPanel.tsx", "utf-8");
    expect(content).toMatch(/useShallow/);
  });

  it("should NOT use inline object selector without useShallow", () => {
    const content = readFileSync("src/components/SettingsPanel.tsx", "utf-8");
    // Check for the anti-pattern: (state) => ({ key: state.key })
    const hasInlineObject = /\(state\)\s*=>\s*\(\{/.test(content);
    const hasUseShallow = /useShallow/.test(content);
    expect(hasInlineObject && !hasUseShallow).toBe(false);
  });

  it("should NOT use raw <button> element", () => {
    const content = readFileSync("src/components/SettingsPanel.tsx", "utf-8");
    expect(content).not.toMatch(/<button[\s>]/);
  });
});
