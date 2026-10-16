import { describe, expect, it } from "vitest";
import { totalsByCurrency } from "./finance";

describe("totalsByCurrency", () => {
  it("keeps currencies separate", () => {
    const t = totalsByCurrency([
      { kind: "income", amount: 1000, currency: "UZS" },
      { kind: "expense", amount: "400", currency: "UZS" },
      { kind: "income", amount: 50, currency: "USD" },
    ]);
    expect(t.UZS).toEqual({ inc: 1000, exp: 400 });
    expect(t.USD).toEqual({ inc: 50, exp: 0 });
  });
  it("ignores planned entries", () => {
    expect(totalsByCurrency([{ kind: "expense", amount: 99, currency: "UZS", planned: true }])).toEqual({});
  });
  it("returns empty object for no data", () => {
    expect(totalsByCurrency([])).toEqual({});
  });
});
