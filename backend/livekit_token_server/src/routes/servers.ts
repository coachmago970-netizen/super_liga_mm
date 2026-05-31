import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { ensureMembership, getMembership, isUserBanned } from "../lib/access.js";
import { appendMemberJoinedMessage } from "../lib/server-events.js";
import { uuidLikeSchema } from "../lib/validation.js";
import { requireAuth } from "../middleware/auth.js";

const joinServerSchema = z.object({
  serverId: uuidLikeSchema
});

export async function serverRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    "/servers/join",
    {
      preHandler: requireAuth
    },
    async (request, reply) => {
      const parsed = joinServerSchema.parse(request.body);

      const banned = await isUserBanned({
        userId: request.authUser.id,
        serverId: parsed.serverId
      });
      if (banned) {
        reply.code(403).send({ error: "Access denied." });
        return;
      }

      const existingMembership = await getMembership({
        userId: request.authUser.id,
        serverId: parsed.serverId
      });

      if (existingMembership) {
        reply.send({
          ok: true,
          serverId: parsed.serverId,
          role: existingMembership.role,
          alreadyMember: true
        });
        return;
      }

      try {
        const membership = await ensureMembership({
          userId: request.authUser.id,
          serverId: parsed.serverId
        });

        try {
          await appendMemberJoinedMessage({
            serverId: parsed.serverId,
            userId: request.authUser.id
          });
        } catch (joinEventError) {
          request.log.warn({ err: joinEventError }, "Failed to append join event message");
        }

        reply.code(201).send({
          ok: true,
          serverId: parsed.serverId,
          role: membership.role,
          alreadyMember: false
        });
      } catch (error) {
        const message = error instanceof Error ? error.message : "Failed to join server.";
        if (message === "Server not found.") {
          reply.code(404).send({ error: message });
          return;
        }
        throw error;
      }
    }
  );
}
