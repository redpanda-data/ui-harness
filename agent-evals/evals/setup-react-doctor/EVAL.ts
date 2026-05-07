import { readFileSync } from "fs";
import { describe, it, expect } from "vitest";

const results = JSON.parse(
  readFileSync("__agent_eval__/results.json", "utf-8")
);
const shellCommands: { command: string; success?: boolean }[] =
  results.o11y?.shellCommands || [];

describe("setup-react-doctor: LLM uses package.json script", () => {
  it("should not run bunx react-doctor directly", () => {
    const directDoctor = shellCommands.filter(
      (c) => /bunx\s+react-doctor/.test(c.command) && c.success === true
    );
    expect(directDoctor).toHaveLength(0);
  });
});
