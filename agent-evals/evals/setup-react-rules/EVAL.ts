import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

describe("setup-react-rules: LLM respects React enforcement rules", () => {
  // ── File existence ─────────────────────────────────────────────

  it("should create UserProfile.tsx", () => {
    expect(existsSync("src/UserProfile.tsx")).toBe(true);
  });

  it("should create UserProfilePage.tsx", () => {
    expect(existsSync("src/UserProfilePage.tsx")).toBe(true);
  });

  it("should create OnlineStatus.tsx", () => {
    expect(existsSync("src/components/OnlineStatus.tsx")).toBe(true);
  });

  // ── UserProfile.tsx checks ─────────────────────────────────────

  it("should NOT use useEffect for data fetching", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    const hasUseEffect = /\buseEffect\b/.test(content);
    const hasAllowComment = /\/\/\s*allow-useEffect:/.test(content);
    expect(hasUseEffect && !hasAllowComment).toBe(false);
  });

  it("should use React Query or TanStack Query", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).toMatch(/useQuery|useMutation|@tanstack\/react-query/);
  });

  it("should NOT use raw <button> element", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).not.toMatch(/<button[\s>]/);
  });

  it("should NOT use raw <input> element", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).not.toMatch(/<input[\s/>]/);
  });

  it("should NOT use raw <form> element", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).not.toMatch(/<form[\s>]/);
  });

  it("should NOT use type escape hatches", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    const pattern = new RegExp("\\bas\\s+" + "any\\b");
    expect(pattern.test(content)).toBe(false);
  });

  it("should NOT use @ts-ignore", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).not.toContain("@ts-ignore");
  });

  it("should NOT use @ts-expect-error", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).not.toContain("@ts-expect-error");
  });

  it("should NOT use inline style={{}}", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).not.toMatch(/style=\{\{/);
  });

  it("should NOT use React.FC", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).not.toMatch(/\bReact\.FC\b|\bReact\.FunctionComponent\b/);
  });

  it("should NOT use class components", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).not.toMatch(
      /extends\s+(React\.)?(Component|PureComponent)\b/
    );
  });

  // ── Form-level validate (react-hook-form v7.72+) ──────────────

  it("should use form-level validate for cross-field validation", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    // Should have validate property in useForm options
    expect(content).toMatch(/validate\s*:/);
  });

  it("should pass error callback to handleSubmit", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    // handleSubmit(onSubmit, onError) — must have a comma (second arg)
    const hasHandleSubmit = /handleSubmit\(/.test(content);
    if (hasHandleSubmit) {
      expect(content).toMatch(/handleSubmit\([^)]+,/);
    }
  });

  // ── UserProfilePage.tsx — key prop for state reset ─────────────

  it("should use key prop on UserProfile for state reset", () => {
    const content = readFileSync("src/UserProfilePage.tsx", "utf-8");
    // Should have key={userId} or key={...userId...} on UserProfile
    expect(content).toMatch(/key=\{.*[uU]ser[iI]d.*\}/);
  });

  it("should NOT use useEffect to reset state in page component", () => {
    const content = readFileSync("src/UserProfilePage.tsx", "utf-8");
    const hasUseEffect = /\buseEffect\b/.test(content);
    const hasAllowComment = /\/\/\s*allow-useEffect:/.test(content);
    expect(hasUseEffect && !hasAllowComment).toBe(false);
  });

  // ── OnlineStatus.tsx — useSyncExternalStore ────────────────────

  it("should use useSyncExternalStore for online status", () => {
    const content = readFileSync("src/components/OnlineStatus.tsx", "utf-8");
    expect(content).toMatch(/useSyncExternalStore/);
  });

  it("should NOT use useEffect + addEventListener for online status", () => {
    const content = readFileSync("src/components/OnlineStatus.tsx", "utf-8");
    const hasUseEffect = /\buseEffect\b/.test(content);
    const hasAddEventListener = /addEventListener/.test(content);
    // useEffect + addEventListener together is the anti-pattern
    expect(hasUseEffect && hasAddEventListener).toBe(false);
  });

  it("should reference navigator.onLine", () => {
    const content = readFileSync("src/components/OnlineStatus.tsx", "utf-8");
    expect(content).toMatch(/navigator\.onLine/);
  });

  // ── biome-ignore noExplicitAny ban ──────────────────────────────

  it("should NOT use biome-ignore for noExplicitAny", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    expect(content).not.toMatch(
      /biome-ignore\s+lint\/suspicious\/noExplicitAny/
    );
  });

  // ── Form mode must be onChange ────────────────────────────────────

  it("should use mode onChange not onBlur or onSubmit", () => {
    const content = readFileSync("src/UserProfile.tsx", "utf-8");
    const hasOnBlur = /mode:\s*['"]onBlur['"]/.test(content);
    const hasOnSubmit = /mode:\s*['"]onSubmit['"]/.test(content);
    expect(hasOnBlur || hasOnSubmit).toBe(false);
  });
});
