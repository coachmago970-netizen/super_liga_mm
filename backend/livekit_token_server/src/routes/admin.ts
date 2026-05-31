import type { FastifyInstance } from "fastify";
import { z } from "zod";
import {
  canAssignRole,
  canBanMembers,
  canChangeRoles,
  canKickMembers,
  canMuteMembers,
  canTargetRole,
  canViewLogs,
  canViewMembers,
  getMembership,
  type ServerRole
} from "../lib/access.js";
import { supabaseAdmin } from "../lib/supabase.js";
import { uuidLikeSchema } from "../lib/validation.js";
import { requireAuth } from "../middleware/auth.js";

const serverIdSchema = z.object({
  serverId: uuidLikeSchema
});

const roleSchema = z.enum(["owner", "admin", "moderator", "member"]);

const setRoleSchema = z.object({
  serverId: uuidLikeSchema,
  targetUserId: uuidLikeSchema,
  role: roleSchema
});

const moderationSchema = z.object({
  serverId: uuidLikeSchema,
  targetUserId: uuidLikeSchema,
  reason: z.string().trim().max(500).optional().nullable()
});

const muteSchema = z.object({
  serverId: uuidLikeSchema,
  targetUserId: uuidLikeSchema,
  reason: z.string().trim().max(500).optional().nullable(),
  expiresAt: z.string().datetime().optional().nullable()
});

const logListSchema = z.object({
  serverId: uuidLikeSchema,
  limit: z.number().int().min(1).max(500).optional()
});

async function fetchTargetMembership(params: { serverId: string; userId: string }) {
  const { data, error } = await supabaseAdmin
    .from("server_members")
    .select("server_id, user_id, role")
    .eq("server_id", params.serverId)
    .eq("user_id", params.userId)
    .maybeSingle();

  if (error) throw new Error(`Failed to fetch target membership: ${error.message}`);
  if (!data) return null;
  return {
    serverId: data.server_id,
    userId: data.user_id,
    role: (data.role as ServerRole) ?? "member"
  };
}

async function writeAdminLog(params: {
  serverId: string;
  actorId: string;
  action: string;
  targetUserId?: string;
  metadata?: Record<string, unknown>;
}) {
  const { error } = await supabaseAdmin.from("admin_logs").insert({
    server_id: params.serverId,
    actor_id: params.actorId,
    target_user_id: params.targetUserId ?? null,
    action: params.action,
    metadata: params.metadata ?? {}
  });

  if (error) {
    throw new Error(`Failed to write admin log: ${error.message}`);
  }
}

export async function adminRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    "/admin/members/list",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = serverIdSchema.parse(request.body);
      const actorMembership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });

      if (!actorMembership || !canViewMembers(actorMembership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const { data: membersData, error: membersError } = await supabaseAdmin
        .from("server_members")
        .select("user_id, role, joined_at")
        .eq("server_id", parsed.serverId)
        .order("joined_at", { ascending: true });

      if (membersError) {
        throw new Error(`Failed to list members: ${membersError.message}`);
      }

      const members = membersData ?? [];
      if (members.length == 0) {
        reply.send({ members: [] });
        return;
      }

      const userIds = members.map((member) => member.user_id);
      const { data: profilesData, error: profilesError } = await supabaseAdmin
        .from("profiles")
        .select("id, display_name, avatar_url, is_banned")
        .in("id", userIds);

      if (profilesError) {
        throw new Error(`Failed to list profiles: ${profilesError.message}`);
      }

      const profileById = new Map<string, (typeof profilesData)[number]>();
      for (const profile of profilesData ?? []) {
        profileById.set(profile.id, profile);
      }

      const responseMembers = members.map((member) => {
        const profile = profileById.get(member.user_id) ?? null;
        return {
          user_id: member.user_id,
          role: member.role,
          joined_at: member.joined_at,
          profile
        };
      });

      reply.send({ members: responseMembers });
    }
  );

  app.post(
    "/admin/members/set-role",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = setRoleSchema.parse(request.body);
      const actorMembership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });
      if (!actorMembership || !canChangeRoles(actorMembership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const targetMembership = await fetchTargetMembership({
        serverId: parsed.serverId,
        userId: parsed.targetUserId
      });
      if (!targetMembership) {
        reply.code(404).send({ error: "Target member not found." });
        return;
      }

      if (!canTargetRole(actorMembership.role, targetMembership.role)) {
        reply.code(403).send({ error: "Cannot change this member role." });
        return;
      }

      if (!canAssignRole(actorMembership.role, parsed.role)) {
        reply.code(403).send({ error: "You cannot assign this role." });
        return;
      }

      const { error } = await supabaseAdmin
        .from("server_members")
        .update({ role: parsed.role })
        .eq("server_id", parsed.serverId)
        .eq("user_id", parsed.targetUserId);

      if (error) throw new Error(`Failed to update member role: ${error.message}`);

      await writeAdminLog({
        serverId: parsed.serverId,
        actorId: request.authUser.id,
        action: "member.role_update",
        targetUserId: parsed.targetUserId,
        metadata: {
          new_role: parsed.role
        }
      });

      reply.send({ ok: true });
    }
  );

  app.post(
    "/admin/members/ban",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = moderationSchema.parse(request.body);
      const actorMembership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });
      if (!actorMembership || !canBanMembers(actorMembership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const targetMembership = await fetchTargetMembership({
        serverId: parsed.serverId,
        userId: parsed.targetUserId
      });
      if (!targetMembership) {
        reply.code(404).send({ error: "Target member not found." });
        return;
      }

      if (!canTargetRole(actorMembership.role, targetMembership.role)) {
        reply.code(403).send({ error: "Cannot ban this member." });
        return;
      }

      const { error: banError } = await supabaseAdmin.from("bans").upsert({
        server_id: parsed.serverId,
        user_id: parsed.targetUserId,
        banned_by: request.authUser.id,
        reason: parsed.reason ?? null
      });
      if (banError) throw new Error(`Failed to ban member: ${banError.message}`);

      const { error: profileError } = await supabaseAdmin
        .from("profiles")
        .update({ is_banned: true })
        .eq("id", parsed.targetUserId);
      if (profileError) throw new Error(`Failed to mark profile as banned: ${profileError.message}`);

      await writeAdminLog({
        serverId: parsed.serverId,
        actorId: request.authUser.id,
        action: "member.ban",
        targetUserId: parsed.targetUserId,
        metadata: {
          reason: parsed.reason ?? null
        }
      });

      reply.send({ ok: true });
    }
  );

  app.post(
    "/admin/members/unban",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = moderationSchema.parse(request.body);
      const actorMembership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });
      if (!actorMembership || !canBanMembers(actorMembership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const { error: deleteError } = await supabaseAdmin
        .from("bans")
        .delete()
        .eq("server_id", parsed.serverId)
        .eq("user_id", parsed.targetUserId);
      if (deleteError) throw new Error(`Failed to remove ban: ${deleteError.message}`);

      const { data: remainingBans, error: remainingBansError } = await supabaseAdmin
        .from("bans")
        .select("id")
        .eq("user_id", parsed.targetUserId)
        .limit(1);
      if (remainingBansError) throw new Error(`Failed to verify remaining bans: ${remainingBansError.message}`);

      if (!remainingBans || remainingBans.length === 0) {
        const { error: profileError } = await supabaseAdmin
          .from("profiles")
          .update({ is_banned: false })
          .eq("id", parsed.targetUserId);
        if (profileError) {
          throw new Error(`Failed to mark profile as unbanned: ${profileError.message}`);
        }
      }

      await writeAdminLog({
        serverId: parsed.serverId,
        actorId: request.authUser.id,
        action: "member.unban",
        targetUserId: parsed.targetUserId,
        metadata: {
          reason: parsed.reason ?? null
        }
      });

      reply.send({ ok: true });
    }
  );

  app.post(
    "/admin/members/kick",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = moderationSchema.parse(request.body);
      const actorMembership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });
      if (!actorMembership || !canKickMembers(actorMembership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const targetMembership = await fetchTargetMembership({
        serverId: parsed.serverId,
        userId: parsed.targetUserId
      });
      if (!targetMembership) {
        reply.code(404).send({ error: "Target member not found." });
        return;
      }

      if (!canTargetRole(actorMembership.role, targetMembership.role)) {
        reply.code(403).send({ error: "Cannot kick this member." });
        return;
      }

      const { error } = await supabaseAdmin
        .from("server_members")
        .delete()
        .eq("server_id", parsed.serverId)
        .eq("user_id", parsed.targetUserId);
      if (error) throw new Error(`Failed to kick member: ${error.message}`);

      await writeAdminLog({
        serverId: parsed.serverId,
        actorId: request.authUser.id,
        action: "member.kick",
        targetUserId: parsed.targetUserId,
        metadata: {
          reason: parsed.reason ?? null
        }
      });

      reply.send({ ok: true });
    }
  );

  app.post(
    "/admin/members/mute",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = muteSchema.parse(request.body);
      const actorMembership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });
      if (!actorMembership || !canMuteMembers(actorMembership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const targetMembership = await fetchTargetMembership({
        serverId: parsed.serverId,
        userId: parsed.targetUserId
      });
      if (!targetMembership) {
        reply.code(404).send({ error: "Target member not found." });
        return;
      }

      if (!canTargetRole(actorMembership.role, targetMembership.role)) {
        reply.code(403).send({ error: "Cannot mute this member." });
        return;
      }

      const { error } = await supabaseAdmin.from("mutes").insert({
        server_id: parsed.serverId,
        user_id: parsed.targetUserId,
        muted_by: request.authUser.id,
        reason: parsed.reason ?? null,
        expires_at: parsed.expiresAt ?? null
      });
      if (error) throw new Error(`Failed to mute member: ${error.message}`);

      await writeAdminLog({
        serverId: parsed.serverId,
        actorId: request.authUser.id,
        action: "member.mute",
        targetUserId: parsed.targetUserId,
        metadata: {
          reason: parsed.reason ?? null,
          expires_at: parsed.expiresAt ?? null
        }
      });

      reply.send({ ok: true });
    }
  );

  app.post(
    "/admin/members/unmute",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = moderationSchema.parse(request.body);
      const actorMembership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });
      if (!actorMembership || !canMuteMembers(actorMembership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const { error } = await supabaseAdmin
        .from("mutes")
        .delete()
        .eq("server_id", parsed.serverId)
        .eq("user_id", parsed.targetUserId);
      if (error) throw new Error(`Failed to unmute member: ${error.message}`);

      await writeAdminLog({
        serverId: parsed.serverId,
        actorId: request.authUser.id,
        action: "member.unmute",
        targetUserId: parsed.targetUserId,
        metadata: {
          reason: parsed.reason ?? null
        }
      });

      reply.send({ ok: true });
    }
  );

  app.post(
    "/admin/logs/list",
    { preHandler: requireAuth },
    async (request, reply) => {
      const parsed = logListSchema.parse(request.body);
      const actorMembership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });
      if (!actorMembership || !canViewLogs(actorMembership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const limit = parsed.limit ?? 100;
      const { data, error } = await supabaseAdmin
        .from("admin_logs")
        .select("id, actor_id, target_user_id, action, metadata, created_at")
        .eq("server_id", parsed.serverId)
        .order("created_at", { ascending: false })
        .limit(limit);

      if (error) throw new Error(`Failed to list admin logs: ${error.message}`);

      reply.send({ logs: data ?? [] });
    }
  );
}
