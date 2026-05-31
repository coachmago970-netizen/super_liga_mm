export type InviteRow = {
  id: string;
  code: string;
  server_id: string;
  created_by: string;
  expires_at: string | null;
  max_uses: number | null;
  current_uses: number;
  is_active: boolean;
};

export type InviteValidationResult =
  | { valid: true; invite: InviteRow }
  | {
      valid: false;
      reason: "not_found" | "inactive" | "expired" | "max_uses_reached";
    };

export function validateInvite(invite: InviteRow | null): InviteValidationResult {
  if (!invite) return { valid: false, reason: "not_found" };
  if (!invite.is_active) return { valid: false, reason: "inactive" };

  if (invite.expires_at) {
    const expiresAt = new Date(invite.expires_at);
    if (!Number.isNaN(expiresAt.getTime()) && expiresAt.getTime() < Date.now()) {
      return { valid: false, reason: "expired" };
    }
  }

  if (invite.max_uses !== null && invite.current_uses >= invite.max_uses) {
    return { valid: false, reason: "max_uses_reached" };
  }

  return { valid: true, invite };
}
