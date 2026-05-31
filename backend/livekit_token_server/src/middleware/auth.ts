import type { FastifyReply, FastifyRequest } from "fastify";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { createSecretKey } from "node:crypto";
import { env } from "../lib/env.js";

const issuer = `${env.SUPABASE_URL.replace(/\/$/, "")}/auth/v1`;
const jwks = env.SUPABASE_JWKS_URL ? createRemoteJWKSet(new URL(env.SUPABASE_JWKS_URL)) : null;
const jwtSecret = env.SUPABASE_JWT_SECRET
  ? createSecretKey(Buffer.from(env.SUPABASE_JWT_SECRET, "utf8"))
  : null;

export async function requireAuth(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const header = request.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    reply.code(401).send({ error: "Missing bearer token." });
    return;
  }

  const token = header.slice("Bearer ".length).trim();
  if (!token) {
    reply.code(401).send({ error: "Missing bearer token." });
    return;
  }

  try {
    const result = jwks
      ? await jwtVerify(token, jwks, { issuer, audience: "authenticated" })
      : await jwtVerify(token, jwtSecret!, { issuer, audience: "authenticated" });

    const userId = typeof result.payload.sub === "string" ? result.payload.sub : null;
    if (!userId) {
      reply.code(401).send({ error: "Invalid token payload." });
      return;
    }

    request.authUser = {
      id: userId,
      claims: result.payload,
      rawToken: token
    };
  } catch {
    reply.code(401).send({ error: "Invalid or expired token." });
  }
}
