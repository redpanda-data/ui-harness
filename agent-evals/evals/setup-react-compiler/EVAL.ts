import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

describe("setup-react-compiler: LLM avoids manual memoization", () => {
  it("should create the component file", () => {
    expect(existsSync("src/Dashboard.tsx")).toBe(true);
  });

  it("should NOT use useMemo (React Compiler handles it)", () => {
    const content = readFileSync("src/Dashboard.tsx", "utf-8");
    const hasUseMemo = /\buseMemo\b/.test(content);
    const hasUseNoMemo = /['"]use no memo['"]/.test(content);
    expect(hasUseMemo && !hasUseNoMemo).toBe(false);
  });

  it("should NOT use useCallback (React Compiler handles it)", () => {
    const content = readFileSync("src/Dashboard.tsx", "utf-8");
    const hasUseCallback = /\buseCallback\b/.test(content);
    const hasUseNoMemo = /['"]use no memo['"]/.test(content);
    expect(hasUseCallback && !hasUseNoMemo).toBe(false);
  });

  it("should NOT use React.memo (React Compiler handles it)", () => {
    const content = readFileSync("src/Dashboard.tsx", "utf-8");
    const hasReactMemo = /\bReact\.memo\b|\bmemo\(/.test(content);
    const hasUseNoMemo = /['"]use no memo['"]/.test(content);
    expect(hasReactMemo && !hasUseNoMemo).toBe(false);
  });
});
