import { readFileSync, existsSync } from "fs";
import { describe, it, expect } from "vitest";

describe("setup-accessibility: LLM respects ARIA accessibility rules", () => {
  it("should create the component file", () => {
    expect(existsSync("src/SearchPanel.tsx")).toBe(true);
  });

  it("should have alt attribute on img elements", () => {
    const content = readFileSync("src/SearchPanel.tsx", "utf-8");
    const imgTags = content.match(/<img[\s\S]*?\/?>|<img[\s\S]*?>/g) || [];
    for (const img of imgTags) {
      expect(img).toMatch(/alt=/);
    }
  });

  it("should have aria-expanded on combobox", () => {
    const content = readFileSync("src/SearchPanel.tsx", "utf-8");
    expect(content).toMatch(/role=["']combobox["']/);
    expect(content).toMatch(/aria-expanded/);
  });

  it("should have aria-controls on combobox", () => {
    const content = readFileSync("src/SearchPanel.tsx", "utf-8");
    expect(content).toMatch(/aria-controls/);
  });

  it("should have keyboard handler on clickable div", () => {
    const content = readFileSync("src/SearchPanel.tsx", "utf-8");
    expect(content).toMatch(/onKeyDown|onKeyUp/);
  });

  it("should have tabIndex on interactive non-button elements", () => {
    const content = readFileSync("src/SearchPanel.tsx", "utf-8");
    expect(content).toMatch(/tabIndex/);
  });

  it("should have aria-label or aria-labelledby on dialog", () => {
    const content = readFileSync("src/SearchPanel.tsx", "utf-8");
    expect(content).toMatch(/role=["']dialog["']/);
    expect(content).toMatch(/aria-label|aria-labelledby/);
  });

  it("should NOT have clickable div without keyboard support", () => {
    const content = readFileSync("src/SearchPanel.tsx", "utf-8");
    const clickableDivs =
      content.match(/<div[^>]*onClick[^>]*>/g) || [];
    for (const div of clickableDivs) {
      expect(div).toMatch(/onKeyDown|onKeyUp/);
    }
  });
});
