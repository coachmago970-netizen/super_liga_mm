import { describe, expect, it } from "vitest";
import { isMuteStillActive } from "../src/lib/mute-policy.js";

describe("isMuteStillActive", () => {
  it("keeps indefinite mute active", () => {
    expect(isMuteStillActive(null)).toBe(true);
  });

  it("returns false for invalid date", () => {
    expect(isMuteStillActive("not-a-date")).toBe(false);
  });

  it("returns false for past mute", () => {
    expect(isMuteStillActive("2020-01-01T00:00:00Z", Date.parse("2026-01-01T00:00:00Z"))).toBe(false);
  });

  it("returns true for future mute", () => {
    expect(isMuteStillActive("2027-01-01T00:00:00Z", Date.parse("2026-01-01T00:00:00Z"))).toBe(true);
  });
});
