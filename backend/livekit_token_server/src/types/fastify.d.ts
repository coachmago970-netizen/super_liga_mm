import "fastify";
import type { JWTPayload } from "jose";

declare module "fastify" {
  interface FastifyInstance {
    config: {
      LIVEKIT_API_KEY: string;
      LIVEKIT_API_SECRET: string;
      LIVEKIT_URL: string;
    };
  }

  interface FastifyRequest {
    authUser: {
      id: string;
      claims: JWTPayload;
      rawToken: string;
    };
  }
}
