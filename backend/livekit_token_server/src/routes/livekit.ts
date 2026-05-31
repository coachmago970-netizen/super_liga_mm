import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { getActiveMute, getMembership, isUserBanned } from "../lib/access.js";
import { buildLiveKitToken } from "../lib/livekit.js";
import { enforceInMemoryRateLimit } from "../lib/rate-window.js";
import { supabaseAdmin } from "../lib/supabase.js";
import { uuidLikeSchema } from "../lib/validation.js";
import { requireAuth } from "../middleware/auth.js";

const liveKitTokenSchema = z.object({
  serverId: uuidLikeSchema,
  channelId: uuidLikeSchema.optional()
});

export async function livekitRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    "/livekit/token",
    {
      preHandler: requireAuth
    },
    async (request, reply) => {
      const rate = enforceInMemoryRateLimit({
        key: `livekit:user:${request.authUser.id}`,
        limit: 10,
        windowMs: 60_000
      });
      if (!rate.ok) {
        reply.code(429).send({
          error: "Too many token requests.",
          retryInMs: rate.retryInMs
        });
        return;
      }

      const parsed = liveKitTokenSchema.parse(request.body);

      const membership = await getMembership({
        userId: request.authUser.id,
        serverId: parsed.serverId
      });
      if (!membership) {
        reply.code(403).send({ error: "You are not a member of this server." });
        return;
      }

      const banned = await isUserBanned({
        userId: request.authUser.id,
        serverId: parsed.serverId
      });
      if (banned) {
        reply.code(403).send({ error: "Access denied." });
        return;
      }

      const activeMute = await getActiveMute({
        userId: request.authUser.id,
        serverId: parsed.serverId
      });
      const canPublishVoice = activeMute == null;

      let channelId = parsed.channelId ?? null;
      let channelName = "voz";
      if (channelId != null) {
        const { data: selectedChannel, error: selectedChannelError } = await supabaseAdmin
          .from("channels")
          .select("id, name, type")
          .eq("id", channelId)
          .eq("server_id", parsed.serverId)
          .maybeSingle();

        if (selectedChannelError) {
          throw new Error(`Failed to query selected voice channel: ${selectedChannelError.message}`);
        }
        if (!selectedChannel || selectedChannel.type !== "voice") {
          reply.code(404).send({ error: "Voice channel not found." });
          return;
        }

        channelName = selectedChannel.name;
      } else {
        const { data: fallbackChannel, error: fallbackChannelError } = await supabaseAdmin
          .from("channels")
          .select("id, name, type")
          .eq("server_id", parsed.serverId)
          .eq("type", "voice")
          .order("created_at", { ascending: true })
          .limit(1)
          .maybeSingle();

        if (fallbackChannelError) {
          throw new Error(`Failed to query fallback voice channel: ${fallbackChannelError.message}`);
        }
        if (!fallbackChannel) {
          reply.code(404).send({ error: "No voice channels available in this server." });
          return;
        }

        channelId = fallbackChannel.id;
        channelName = fallbackChannel.name;
      }

      const { data: profile, error: profileError } = await supabaseAdmin
        .from("profiles")
        .select("display_name")
        .eq("id", request.authUser.id)
        .maybeSingle();

      if (profileError) {
        request.log.warn({ err: profileError }, "Failed to fetch display name.");
      }

      const roomName = `server_${parsed.serverId}_voice_${channelId}`;
      const token = await buildLiveKitToken({
        apiKey: app.config.LIVEKIT_API_KEY,
        apiSecret: app.config.LIVEKIT_API_SECRET,
        userId: request.authUser.id,
        displayName: profile?.display_name ?? null,
        roomName,
        canPublish: canPublishVoice,
        allowScreenShare: canPublishVoice
      });

      reply.send({
        token,
        url: app.config.LIVEKIT_URL,
        room: roomName,
        channelId,
        channelName,
        expiresInSeconds: 3600,
        voicePermission: {
          canPublish: canPublishVoice,
          muted: !canPublishVoice,
          mutedReason: activeMute?.reason ?? null,
          mutedUntil: activeMute?.expiresAt ?? null
        }
      });
    }
  );
}
