import { readFileSync } from "fs";
import { describe, it, expect } from "vitest";

const results = JSON.parse(
  readFileSync("__agent_eval__/results.json", "utf-8")
);
const shellCommands: { command: string; success?: boolean }[] =
  results.o11y?.shellCommands || [];

describe("setup-quality-gate: LLM uses quality:gate correctly", () => {
  it("should not run biome directly via bunx", () => {
    const directBiome = shellCommands.filter(
      (c) => /bunx\s+biome/.test(c.command) && c.success === true
    );
    expect(directBiome).toHaveLength(0);
  });

  it("should not run tsc directly", () => {
    const directTsc = shellCommands.filter(
      (c) => /\btsc(\s|$)/.test(c.command) && c.success === true
    );
    expect(directTsc).toHaveLength(0);
  });
});
