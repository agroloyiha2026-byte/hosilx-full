import { describe, expect, it } from "vitest";
import { dict, LANGS } from "./i18n";

describe("i18n", () => {
  const base = Object.keys(dict.uz).sort();
  for (const l of LANGS) {
    it(`${l} has exactly the same keys as uz`, () => {
      expect(Object.keys(dict[l]).sort()).toEqual(base);
    });
    it(`${l} has no empty strings`, () => {
      for (const [k, v] of Object.entries(dict[l])) expect(v.trim(), k).not.toBe("");
    });
  }
});
