import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

describe("setup-env-validation: LLM respects env validation rules", () => {
  it("should create src/env.ts", () => {
    expect(existsSync("src/env.ts")).toBe(true);
  });

  it("should create src/config.ts", () => {
    expect(existsSync("src/config.ts")).toBe(true);
  });

  it("should use t3-env or zod in env.ts", () => {
    const content = readFileSync("src/env.ts", "utf-8");
    expect(content).toMatch(/t3-env|createEnv|zod|z\./);
  });

  it("should declare DATABASE_URL in env.ts", () => {
    const content = readFileSync("src/env.ts", "utf-8");
    expect(content).toMatch(/DATABASE_URL/);
  });

  it("should declare API_KEY in env.ts", () => {
    const content = readFileSync("src/env.ts", "utf-8");
    expect(content).toMatch(/API_KEY/);
  });

  it("should NOT access process.env directly in config.ts", () => {
    const content = readFileSync("src/config.ts", "utf-8");
    expect(content).not.toMatch(/process\.env\.\w+/);
  });

  it("should import from env module in config.ts", () => {
    const content = readFileSync("src/config.ts", "utf-8");
    expect(content).toMatch(/from\s+['"].*env['"]/);
  });
});
