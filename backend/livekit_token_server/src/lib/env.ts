import { z } from "zod";

const nodeProcess = process as NodeJS.Process & {
  loadEnvFile?: (path?: string) => void;
};

// Node.js 20+ can load .env natively. This keeps local dev simple.
try {
  nodeProcess.loadEnvFile?.(".env");
} catch (error) {
  const maybeErr = error as NodeJS.ErrnoException;
  if (maybeErr.code !== "ENOENT") {
    throw error;
  }
}

const envSchema = z
  .object({
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
    PORT: z.coerce.number().int().positive().default(8080),
    SUPABASE_URL: z.url(),
    SUPABASE_PUBLISHABLE_KEY: z.string().min(1),
    SUPABASE_SECRET_KEY: z.string().min(1),
    SUPABASE_JWKS_URL: z.url().optional(),
    SUPABASE_JWT_SECRET: z.string().optional(),
    LIVEKIT_API_KEY: z.string().min(1),
    LIVEKIT_API_SECRET: z.string().min(1),
    LIVEKIT_URL: z.string().min(1),
    APP_BASE_URL: z.url(),
    CORS_ORIGIN: z.string().min(1),
    HASH_PEPPER: z.string().min(16)
  })
  .superRefine((value, ctx) => {
    if (!value.SUPABASE_JWKS_URL && !value.SUPABASE_JWT_SECRET) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["SUPABASE_JWKS_URL"],
        message: "SUPABASE_JWKS_URL or SUPABASE_JWT_SECRET must be set."
      });
    }
  });

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  const details = parsed.error.issues
    .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
    .join("; ");
  throw new Error(`Invalid environment configuration: ${details}`);
}

const corsOrigins = parsed.data.CORS_ORIGIN.split(",")
  .map((entry) => entry.trim())
  .filter(Boolean);

export const env = {
  ...parsed.data,
  CORS_ORIGINS: corsOrigins
};

export type AppEnv = typeof env;
