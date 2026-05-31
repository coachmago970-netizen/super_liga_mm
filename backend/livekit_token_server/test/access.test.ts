import { describe, expect, it } from "vitest";
import {
  canAssignRole,
  canBanMembers,
  canKickMembers,
  canManageInvites,
  canTargetRole
} from "../src/lib/permissions.js";

describe("access helpers", () => {
  it("allows invites only for owner/admin", () => {
    expect(canManageInvites("owner")).toBe(true);
    expect(canManageInvites("admin")).toBe(true);
    expect(canManageInvites("moderator")).toBe(false);
    expect(canManageInvites("member")).toBe(false);
  });

  it("allows bans only for owner/admin", () => {
    expect(canBanMembers("owner")).toBe(true);
    expect(canBanMembers("admin")).toBe(true);
    expect(canBanMembers("moderator")).toBe(false);
  });

  it("allows kick for moderator and above", () => {
    expect(canKickMembers("owner")).toBe(true);
    expect(canKickMembers("admin")).toBe(true);
    expect(canKickMembers("moderator")).toBe(true);
    expect(canKickMembers("member")).toBe(false);
  });

  it("prevents targeting same or higher role", () => {
    expect(canTargetRole("admin", "moderator")).toBe(true);
    expect(canTargetRole("admin", "admin")).toBe(false);
    expect(canTargetRole("moderator", "admin")).toBe(false);
  });

  it("restricts role assignment by actor role", () => {
    expect(canAssignRole("owner", "owner")).toBe(true);
    expect(canAssignRole("admin", "moderator")).toBe(true);
    expect(canAssignRole("admin", "admin")).toBe(false);
    expect(canAssignRole("moderator", "member")).toBe(false);
  });
});
