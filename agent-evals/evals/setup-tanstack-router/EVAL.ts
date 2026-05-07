import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

const results = JSON.parse(
  readFileSync("__agent_eval__/results.json", "utf-8")
);
const shellCommands: { command: string; success?: boolean }[] =
  results.o11y?.shellCommands || [];

describe("setup-tanstack-router: LLM creates route correctly", () => {
  it("should create the route file", () => {
    expect(existsSync("src/routes/settings.tsx")).toBe(true);
  });

  it("should not use bunx tsr directly", () => {
    const directTsr = shellCommands.filter(
      (c) =>
        /bunx\s+(tsr|@tanstack\/router-cli)/.test(c.command) &&
        c.success === true
    );
    expect(directTsr).toHaveLength(0);
  });

  it("should NOT use window.location reads", () => {
    const content = readFileSync("src/routes/settings.tsx", "utf-8");
    expect(content).not.toMatch(
      /window\.location\.(search|pathname|hash|origin)\b/
    );
  });

  it("should NOT use window.location.href for navigation", () => {
    const content = readFileSync("src/routes/settings.tsx", "utf-8");
    expect(content).not.toMatch(
      /window\.location\.(href|assign|replace)\s*[=(]/
    );
  });
});
