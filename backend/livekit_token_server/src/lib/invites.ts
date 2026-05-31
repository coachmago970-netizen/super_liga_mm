import { supabaseAdmin } from "./supabase.js";
import { type InviteRow, type InviteValidationResult, validateInvite } from "./invite-validation.js";
export { type InviteRow, type InviteValidationResult, validateInvite };

export async function getInviteByCode(code: string): Promise<InviteRow | null> {
  const { data, error } = await supabaseAdmin
    .from("invites")
    .select("id, code, server_id, created_by, expires_at, max_uses, current_uses, is_active")
    .eq("code", code)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to fetch invite: ${error.message}`);
  }
  return data as InviteRow | null;
}

export async function incrementInviteUses(invite: InviteRow): Promise<void> {
  const { data, error } = await supabaseAdmin
    .from("invites")
    .update({ current_uses: invite.current_uses + 1 })
    .eq("id", invite.id)
    .eq("current_uses", invite.current_uses)
    .select("id")
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to update invite usage count: ${error.message}`);
  }
  if (!data) {
    throw new Error("Invite usage count changed concurrently. Retry the request.");
  }
}
