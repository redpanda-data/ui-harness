import { readFileSync } from "fs";
import { describe, it, expect } from "vitest";

const results = JSON.parse(
  readFileSync("__agent_eval__/results.json", "utf-8")
);
const shellCommands: { command: string; success?: boolean }[] =
  results.o11y?.shellCommands || [];

describe("setup-llm-optimization: LLM avoids verbose test output", () => {
  it("should NOT use --verbose flag on test runners", () => {
    const verboseTests = shellCommands.filter(
      (c) =>
        /(vitest|bun test|jest).*--verbose/.test(c.command) &&
        c.success === true
    );
    expect(verboseTests).toHaveLength(0);
  });
});
