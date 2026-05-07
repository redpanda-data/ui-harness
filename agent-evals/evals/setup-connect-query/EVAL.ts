import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

describe("setup-connect-query: LLM respects ConnectRPC patterns", () => {
  it("should create the component file", () => {
    expect(existsSync("src/TopicList.tsx")).toBe(true);
  });

  it("should NOT import useQuery from @tanstack/react-query", () => {
    const content = readFileSync("src/TopicList.tsx", "utf-8");
    const tanstackImport = content.match(
      /import\s+\{[^}]*\buse(?:Query|Mutation)\b[^}]*\}\s+from\s+['"]@tanstack\/react-query['"]/
    );
    expect(tanstackImport).toBeNull();
  });

  it("should use Connect Query hooks", () => {
    const content = readFileSync("src/TopicList.tsx", "utf-8");
    expect(content).toMatch(
      /@connectrpc\/connect-query|useQuery.*connectquery|useMutation.*connectquery/
    );
  });

  it("should NOT call invalidateQueries with no args", () => {
    const content = readFileSync("src/TopicList.tsx", "utf-8");
    expect(content).not.toMatch(/invalidateQueries\(\s*\)/);
  });

  it("should use create() for message construction (not new Message)", () => {
    const content = readFileSync("src/TopicList.tsx", "utf-8");
    expect(content).not.toMatch(
      /\bnew\s+[A-Z][a-zA-Z]*(Request|Response|Message)\s*\(/
    );
  });

  it("should NOT use PlainMessage or PartialMessage", () => {
    const content = readFileSync("src/TopicList.tsx", "utf-8");
    expect(content).not.toMatch(/\bPlainMessage\b/);
    expect(content).not.toMatch(/\bPartialMessage\b/);
  });

  it("should NOT import from axios", () => {
    const content = readFileSync("src/TopicList.tsx", "utf-8");
    expect(content).not.toMatch(/from\s+['"]axios['"]/);
  });

  it("should NOT use raw fetch() in ConnectRPC file", () => {
    const content = readFileSync("src/TopicList.tsx", "utf-8");
    const hasFetch = /\bfetch\s*\(/.test(content);
    const hasEscape = /\/\/\s*allow:\s*direct-query/.test(content);
    expect(hasFetch && !hasEscape).toBe(false);
  });

  it("should use ConnectError.from() not throw new Error() for error handling", () => {
    const content = readFileSync("src/TopicList.tsx", "utf-8");
    const hasThrowNewError = /throw\s+new\s+Error\(/.test(content);
    const hasEscape = /\/\/\s*allow:\s*connect-error/.test(content);
    // If it throws errors in a ConnectRPC context, should use ConnectError
    if (hasThrowNewError && !hasEscape) {
      expect(content).toMatch(/ConnectError/);
    }
  });
});
