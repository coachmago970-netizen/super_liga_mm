import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import Fastify from "fastify";
import { pathToFileURL } from "node:url";
import { env } from "./lib/env.js";
import { errorHandler } from "./middleware/error-handler.js";
import { healthRoutes } from "./routes/health.js";
import { adminRoutes } from "./routes/admin.js";
import { channelRoutes } from "./routes/channels.js";
import { inviteRoutes } from "./routes/invites.js";
import { livekitRoutes } from "./routes/livekit.js";
import { serverRoutes } from "./routes/servers.js";

export async function buildServer() {
  const app = Fastify({
    logger: {
      level: env.NODE_ENV === "production" ? "info" : "debug"
    }
  });

  app.decorate("config", {
    LIVEKIT_API_KEY: env.LIVEKIT_API_KEY,
    LIVEKIT_API_SECRET: env.LIVEKIT_API_SECRET,
    LIVEKIT_URL: env.LIVEKIT_URL
  });

  await app.register(helmet);
  await app.register(cors, {
    origin: env.CORS_ORIGINS,
    credentials: true
  });
  await app.register(rateLimit, {
    max: 120,
    timeWindow: "1 minute"
  });

  app.setErrorHandler(errorHandler);

  await app.register(healthRoutes);
  await app.register(serverRoutes);
  await app.register(channelRoutes);
  await app.register(livekitRoutes);
  await app.register(inviteRoutes);
  await app.register(adminRoutes);

  return app;
}

const isMainModule =
  typeof process.argv[1] === "string" && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMainModule) {
  const app = await buildServer();
  try {
    await app.listen({ host: "0.0.0.0", port: env.PORT });
    app.log.info(`Server listening on :${env.PORT}`);
  } catch (error) {
    app.log.error({ error }, "Server failed to start.");
    process.exit(1);
  }
}
