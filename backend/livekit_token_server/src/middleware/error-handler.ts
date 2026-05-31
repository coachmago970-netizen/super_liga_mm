import type { FastifyReply, FastifyRequest } from "fastify";
import { ZodError } from "zod";

export function errorHandler(error: unknown, request: FastifyRequest, reply: FastifyReply): void {
  if (error instanceof ZodError) {
    reply.code(400).send({
      error: "Validation failed.",
      issues: error.issues.map((issue) => ({
        path: issue.path.join("."),
        message: issue.message
      }))
    });
    return;
  }

  request.log.error({ error }, "Unhandled request error.");
  reply.code(500).send({ error: "Unexpected server error." });
}
