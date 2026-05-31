import { supabaseAdmin } from "./supabase.js";
import { isMuteStillActive } from "./mute-policy.js";
import {
  type ServerRole,
  canAssignRole,
  canBanMembers,
  canChangeRoles,
  canManageChannels,
  canKickMembers,
  canManageInvites,
  canMuteMembers,
  canTargetRole,
  canViewLogs,
  canViewMembers
} from "./permissions.js";

export {
  canAssignRole,
  canBanMembers,
  canChangeRoles,
  canManageChannels,
  canKickMembers,
  canManageInvites,
  canMuteMembers,
  canTargetRole,
  canViewLogs,
  canViewMembers,
  type ServerRole
};

export type Membership = {
  userId: string;
  serverId: string;
  role: ServerRole;
};

export async function getMembership(params: {
  serverId: string;
  userId: string;
}): Promise<Membership | null> {
  const { data, error } = await supabaseAdmin
    .from("server_members")
    .select("server_id, user_id, role")
    .eq("server_id", params.serverId)
    .eq("user_id", params.userId)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to query membership: ${error.message}`);
  }
  if (!data) return null;

  return {
    serverId: data.server_id,
    userId: data.user_id,
    role: (data.role as ServerRole) ?? "member"
  };
}

export async function ensureMembership(params: {
  serverId: string;
  userId: string;
}): Promise<Membership> {
  const existing = await getMembership(params);
  if (existing) return existing;

  const { data: server, error: serverError } = await supabaseAdmin
    .from("servers")
    .select("id")
    .eq("id", params.serverId)
    .maybeSingle();
  if (serverError) {
    throw new Error(`Failed to query server: ${serverError.message}`);
  }
  if (!server) {
    throw new Error("Server not found.");
  }

  const { count, error: countError } = await supabaseAdmin
    .from("server_members")
    .select("user_id", {
      count: "exact",
      head: true
    })
    .eq("server_id", params.serverId);
  if (countError) {
    throw new Error(`Failed to count existing server members: ${countError.message}`);
  }

  const role: ServerRole = (count ?? 0) === 0 ? "owner" : "member";
  const { error: insertError } = await supabaseAdmin.from("server_members").insert({
    server_id: params.serverId,
    user_id: params.userId,
    role
  });

  if (insertError) {
    // Handles race condition if another request inserted membership first.
    const refetched = await getMembership(params);
    if (refetched) return refetched;
    throw new Error(`Failed to create membership: ${insertError.message}`);
  }

  return {
    serverId: params.serverId,
    userId: params.userId,
    role
  };
}

export async function isUserBanned(params: {
  serverId: string;
  userId: string;
}): Promise<boolean> {
  const [{ data: profile, error: profileError }, { data: banRow, error: banError }] =
    await Promise.all([
      supabaseAdmin.from("profiles").select("is_banned").eq("id", params.userId).maybeSingle(),
      supabaseAdmin
        .from("bans")
        .select("id")
        .eq("server_id", params.serverId)
        .eq("user_id", params.userId)
        .maybeSingle()
    ]);

  if (profileError) throw new Error(`Failed to query profile ban status: ${profileError.message}`);
  if (banError) throw new Error(`Failed to query bans table: ${banError.message}`);

  return Boolean(profile?.is_banned || banRow);
}

export type ActiveMute = {
  id: string;
  reason: string | null;
  expiresAt: string | null;
};

export async function getActiveMute(params: {
  serverId: string;
  userId: string;
}): Promise<ActiveMute | null> {
  const { data, error } = await supabaseAdmin
    .from("mutes")
    .select("id, reason, expires_at, created_at")
    .eq("server_id", params.serverId)
    .eq("user_id", params.userId)
    .order("created_at", { ascending: false })
    .limit(20);

  if (error) {
    throw new Error(`Failed to query active mute: ${error.message}`);
  }

  for (const mute of data ?? []) {
    if (isMuteStillActive(mute.expires_at)) {
      return {
        id: mute.id,
        reason: mute.reason ?? null,
        expiresAt: mute.expires_at ?? null
      };
    }
  }

  return null;
}
