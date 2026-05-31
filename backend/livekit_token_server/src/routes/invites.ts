import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { randomBytes } from "node:crypto";
import { canManageInvites, getMembership, isUserBanned } from "../lib/access.js";
import { env } from "../lib/env.js";
import { hmacSha256 } from "../lib/hash.js";
import {
  getInviteByCode,
  incrementInviteUses,
  validateInvite
} from "../lib/invites.js";
import { enforceInMemoryRateLimit } from "../lib/rate-window.js";
import { appendMemberJoinedMessage } from "../lib/server-events.js";
import { supabaseAdmin } from "../lib/supabase.js";
import { uuidLikeSchema } from "../lib/validation.js";
import { requireAuth } from "../middleware/auth.js";

const inviteSchema = z.object({
  code: z
    .string()
    .trim()
    .min(3)
    .max(64)
    .regex(/^[A-Za-z0-9_-]+$/)
});

const createInviteSchema = z.object({
  serverId: uuidLikeSchema,
  expiresAt: z.string().datetime().optional().nullable(),
  maxUses: z.number().int().positive().max(100_000).optional().nullable()
});

const serverIdSchema = z.object({
  serverId: uuidLikeSchema
});

const deactivateInviteSchema = z.object({
  serverId: uuidLikeSchema,
  inviteId: uuidLikeSchema
});

export async function inviteRoutes(app: FastifyInstance): Promise<void> {
  app.post("/invites/validate", async (request, reply) => {
    const rate = enforceInMemoryRateLimit({
      key: `invite-validate:ip:${request.ip}`,
      limit: 30,
      windowMs: 60_000
    });
    if (!rate.ok) {
      reply.code(429).send({ valid: false, reason: "rate_limited", retryInMs: rate.retryInMs });
      return;
    }

    const parsed = inviteSchema.parse(request.body);
    const invite = await getInviteByCode(parsed.code.toUpperCase());
    const result = validateInvite(invite);

    if (!result.valid) {
      reply.send({ valid: false, reason: result.reason });
      return;
    }

    reply.send({ valid: true });
  });

  app.post(
    "/invites/use",
    {
      preHandler: requireAuth
    },
    async (request, reply) => {
      const rate = enforceInMemoryRateLimit({
        key: `invite-use:user:${request.authUser.id}`,
        limit: 15,
        windowMs: 60_000
      });
      if (!rate.ok) {
        reply.code(429).send({ error: "Too many requests.", retryInMs: rate.retryInMs });
        return;
      }

      const parsed = inviteSchema.parse(request.body);
      const invite = await getInviteByCode(parsed.code.toUpperCase());
      const validation = validateInvite(invite);
      if (!validation.valid) {
        reply.code(400).send({ error: "Invalid invite.", reason: validation.reason });
        return;
      }

      const serverId = validation.invite.server_id;
      const banned = await isUserBanned({ userId: request.authUser.id, serverId });
      if (banned) {
        reply.code(403).send({ error: "Access denied." });
        return;
      }

      const existingMember = await getMembership({
        serverId,
        userId: request.authUser.id
      });

      if (!existingMember) {
        const { error: insertMemberError } = await supabaseAdmin.from("server_members").insert({
          server_id: serverId,
          user_id: request.authUser.id,
          role: "member",
          invited_by: validation.invite.created_by
        });

        if (insertMemberError) {
          throw new Error(`Failed to add user to server: ${insertMemberError.message}`);
        }
      }

      if (!existingMember) {
        const userAgent =
          typeof request.headers["user-agent"] === "string" ? request.headers["user-agent"] : "n/a";
        const { error: inviteUseError } = await supabaseAdmin.from("invite_uses").insert({
          invite_id: validation.invite.id,
          user_id: request.authUser.id,
          ip_hash: hmacSha256(request.ip, env.HASH_PEPPER),
          user_agent_hash: hmacSha256(userAgent, env.HASH_PEPPER)
        });
        if (inviteUseError) {
          throw new Error(`Failed to insert invite usage record: ${inviteUseError.message}`);
        }

        await incrementInviteUses(validation.invite);
      }

      if (!existingMember) {
        try {
          await appendMemberJoinedMessage({
            serverId,
            userId: request.authUser.id
          });
        } catch (joinEventError) {
          request.log.warn({ err: joinEventError }, "Failed to append join event message");
        }
      }

      reply.send({
        ok: true,
        serverId,
        alreadyMember: Boolean(existingMember)
      });
    }
  );

  app.post(
    "/admin/invites/create",
    {
      preHandler: requireAuth
    },
    async (request, reply) => {
      const parsed = createInviteSchema.parse(request.body);
      const membership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });

      if (!membership || !canManageInvites(membership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      let code = "";
      for (let attempts = 0; attempts < 6; attempts += 1) {
        const generated = randomBytes(5).toString("hex").toUpperCase();
        const exists = await getInviteByCode(generated);
        if (!exists) {
          code = generated;
          break;
        }
      }

      if (!code) {
        throw new Error("Failed to generate invite code.");
      }

      const { data: invite, error: createInviteError } = await supabaseAdmin
        .from("invites")
        .insert({
          code,
          server_id: parsed.serverId,
          created_by: request.authUser.id,
          expires_at: parsed.expiresAt ?? null,
          max_uses: parsed.maxUses ?? null
        })
        .select("id, code, server_id, expires_at, max_uses, current_uses, is_active, created_at")
        .single();

      if (createInviteError) {
        throw new Error(`Failed to create invite: ${createInviteError.message}`);
      }

      const { error: logError } = await supabaseAdmin.from("admin_logs").insert({
        server_id: parsed.serverId,
        actor_id: request.authUser.id,
        action: "invite.create",
        metadata: {
          invite_code: code,
          max_uses: parsed.maxUses ?? null,
          expires_at: parsed.expiresAt ?? null
        }
      });

      if (logError) {
        request.log.warn({ err: logError }, "Failed to log invite.create");
      }

      reply.code(201).send({ invite });
    }
  );

  app.post(
    "/admin/invites/list",
    {
      preHandler: requireAuth
    },
    async (request, reply) => {
      const parsed = serverIdSchema.parse(request.body);
      const membership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });

      if (!membership || !canManageInvites(membership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const { data, error } = await supabaseAdmin
        .from("invites")
        .select("id, code, expires_at, max_uses, current_uses, is_active, created_at")
        .eq("server_id", parsed.serverId)
        .order("created_at", { ascending: false })
        .limit(100);

      if (error) {
        throw new Error(`Failed to list invites: ${error.message}`);
      }

      reply.send({ invites: data ?? [] });
    }
  );

  app.post(
    "/admin/invites/deactivate",
    {
      preHandler: requireAuth
    },
    async (request, reply) => {
      const parsed = deactivateInviteSchema.parse(request.body);
      const membership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });

      if (!membership || !canManageInvites(membership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const { data: updatedInvite, error: updateError } = await supabaseAdmin
        .from("invites")
        .update({ is_active: false })
        .eq("id", parsed.inviteId)
        .eq("server_id", parsed.serverId)
        .select("id, code, is_active")
        .maybeSingle();

      if (updateError) {
        throw new Error(`Failed to deactivate invite: ${updateError.message}`);
      }
      if (!updatedInvite) {
        reply.code(404).send({ error: "Invite not found." });
        return;
      }

      const { error: logError } = await supabaseAdmin.from("admin_logs").insert({
        server_id: parsed.serverId,
        actor_id: request.authUser.id,
        action: "invite.deactivate",
        metadata: {
          invite_id: parsed.inviteId,
          invite_code: updatedInvite.code
        }
      });

      if (logError) {
        request.log.warn({ err: logError }, "Failed to log invite.deactivate");
      }

      reply.send({ ok: true, invite: updatedInvite });
    }
  );
}
