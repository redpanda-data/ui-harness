import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

const results = JSON.parse(
  readFileSync("__agent_eval__/results.json", "utf-8")
);
const shellCommands: { command: string; success?: boolean }[] =
  results.o11y?.shellCommands || [];

const COMMIT_REGEX =
  /^(feat|fix|refactor|style|test|docs|chore|perf|ci|build|revert)\([a-z][a-z0-9-]*\): [a-z].{4,71}$/;

describe("setup-conventional-commits: LLM uses correct commit format", () => {
  it("should create format.ts", () => {
    expect(existsSync("src/utils/format.ts")).toBe(true);
  });

  it("should create validate.ts", () => {
    expect(existsSync("src/utils/validate.ts")).toBe(true);
  });

  it("should make at least one git commit", () => {
    const commits = shellCommands.filter((c) =>
      /\bgit\s+commit\b/.test(c.command)
    );
    expect(commits.length).toBeGreaterThan(0);
  });

  it("should use conventional commit format in all commits", () => {
    const commits = shellCommands.filter(
      (c) => /\bgit\s+commit\b/.test(c.command) && c.success === true
    );
    for (const cmd of commits) {
      const msgMatch = cmd.command.match(/-m\s+["']([^"']+)["']/);
      if (msgMatch) {
        const firstLine = msgMatch[1].split("\n")[0];
        expect(firstLine).toMatch(COMMIT_REGEX);
      }
    }
  });

  it("should include a scope in commit messages", () => {
    const commits = shellCommands.filter(
      (c) => /\bgit\s+commit\b/.test(c.command) && c.success === true
    );
    for (const cmd of commits) {
      expect(cmd.command).toMatch(/\([a-z][a-z0-9-]*\):/);
    }
  });
});
