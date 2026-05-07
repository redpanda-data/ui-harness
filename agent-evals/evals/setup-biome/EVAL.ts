import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

const results = JSON.parse(
  readFileSync("__agent_eval__/results.json", "utf-8")
);
const shellCommands: { command: string; success?: boolean }[] =
  results.o11y?.shellCommands || [];

describe("setup-biome: LLM handles lint rules correctly", () => {
  it("should create the component file", () => {
    expect(existsSync("src/Counter.tsx")).toBe(true);
  });

  it("should not use console.log (banned by noConsole)", () => {
    const content = readFileSync("src/Counter.tsx", "utf-8");
    expect(content).not.toMatch(/console\.log/);
  });

  it("should not import moment (restricted import)", () => {
    const content = readFileSync("src/Counter.tsx", "utf-8");
    expect(content).not.toMatch(/from\s+['"]moment['"]/);
  });

  it("should not import classnames (restricted import)", () => {
    const content = readFileSync("src/Counter.tsx", "utf-8");
    expect(content).not.toMatch(/from\s+['"]classnames['"]/);
  });

  it("should not run bunx biome directly", () => {
    const directBiome = shellCommands.filter(
      (c) => /bunx\s+(biome|@biomejs)/.test(c.command) && c.success === true
    );
    expect(directBiome).toHaveLength(0);
  });
});
