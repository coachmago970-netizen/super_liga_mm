import { describe, expect, it } from "vitest";
import { validateInvite, type InviteRow } from "../src/lib/invite-validation.js";

function buildInvite(overrides?: Partial<InviteRow>): InviteRow {
  return {
    id: "00000000-0000-0000-0000-000000000001",
    code: "ABC123",
    server_id: "00000000-0000-0000-0000-000000000010",
    created_by: "00000000-0000-0000-0000-000000000020",
    expires_at: null,
    max_uses: null,
    current_uses: 0,
    is_active: true,
    ...overrides
  };
}

describe("validateInvite", () => {
  it("returns not_found for missing invite", () => {
    const result = validateInvite(null);
    expect(result).toEqual({ valid: false, reason: "not_found" });
  });

  it("returns inactive when invite is disabled", () => {
    const result = validateInvite(buildInvite({ is_active: false }));
    expect(result).toEqual({ valid: false, reason: "inactive" });
  });

  it("returns expired when invite date has passed", () => {
    const result = validateInvite(
      buildInvite({ expires_at: new Date(Date.now() - 60_000).toISOString() })
    );
    expect(result).toEqual({ valid: false, reason: "expired" });
  });

  it("returns max_uses_reached when limit was hit", () => {
    const result = validateInvite(buildInvite({ max_uses: 2, current_uses: 2 }));
    expect(result).toEqual({ valid: false, reason: "max_uses_reached" });
  });

  it("returns valid invite when all checks pass", () => {
    const result = validateInvite(buildInvite({ max_uses: 5, current_uses: 1 }));
    expect(result.valid).toBe(true);
  });
});
