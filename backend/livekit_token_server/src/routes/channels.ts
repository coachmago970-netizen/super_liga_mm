import type { FastifyInstance } from "fastify";
import { z } from "zod";
import {
  canManageChannels,
  getMembership,
  isUserBanned
} from "../lib/access.js";
import { supabaseAdmin } from "../lib/supabase.js";
import { uuidLikeSchema } from "../lib/validation.js";
import { requireAuth } from "../middleware/auth.js";

const listChannelsSchema = z.object({
  serverId: uuidLikeSchema,
  type: z.enum(["text", "voice"]).optional()
});

const createChannelSchema = z.object({
  serverId: uuidLikeSchema,
  name: z.string().trim().min(2).max(48),
  type: z.enum(["text", "voice"]).default("voice")
});

export async function channelRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    "/channels/list",
    {
      preHandler: requireAuth
    },
    async (request, reply) => {
      const parsed = listChannelsSchema.parse(request.body);
      const membership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });

      if (!membership) {
        reply.code(403).send({ error: "You are not a member of this server." });
        return;
      }

      const banned = await isUserBanned({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });
      if (banned) {
        reply.code(403).send({ error: "Access denied." });
        return;
      }

      let query = supabaseAdmin
        .from("channels")
        .select("id, server_id, name, type, created_at")
        .eq("server_id", parsed.serverId);

      if (parsed.type) {
        query = query.eq("type", parsed.type);
      }

      const { data, error } = await query.order("created_at", { ascending: true });
      if (error) {
        throw new Error(`Failed to list channels: ${error.message}`);
      }

      reply.send({ channels: data ?? [] });
    }
  );

  app.post(
    "/channels/create",
    {
      preHandler: requireAuth
    },
    async (request, reply) => {
      const parsed = createChannelSchema.parse(request.body);
      const membership = await getMembership({
        serverId: parsed.serverId,
        userId: request.authUser.id
      });
      if (!membership || !canManageChannels(membership.role)) {
        reply.code(403).send({ error: "Insufficient permission." });
        return;
      }

      const { data, error } = await supabaseAdmin
        .from("channels")
        .insert({
          server_id: parsed.serverId,
          name: parsed.name,
          type: parsed.type
        })
        .select("id, server_id, name, type, created_at")
        .single();

      if (error) {
        throw new Error(`Failed to create channel: ${error.message}`);
      }

      reply.code(201).send({ channel: data });
    }
  );
}
