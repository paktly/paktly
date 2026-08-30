import { z } from "zod";

const environmentSchema = z.object({
  API_HOST: z.string().min(1).default("0.0.0.0"),
  API_PORT: z.coerce.number().int().min(1).max(65_535).default(4000),
  CORS_ORIGINS: z.string().default("http://localhost:3000"),
  DATABASE_URL: z
    .string()
    .url()
    .default("postgres://pakt:pakt_local_only@localhost:56432/pakt"),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(300),
  RATE_LIMIT_WINDOW_MS: z.coerce.number().int().min(1_000).default(60_000),
  TRUST_PROXY: z.string().default("loopback,linklocal,uniquelocal"),
  LOG_LEVEL: z
    .enum(["fatal", "error", "warn", "info", "debug", "trace", "silent"])
    .default("info"),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development")
});

export type Environment = {
  apiHost: string;
  apiPort: number;
  corsOrigins: string[];
  databaseUrl: string;
  logLevel: z.infer<typeof environmentSchema>["LOG_LEVEL"];
  nodeEnvironment: z.infer<typeof environmentSchema>["NODE_ENV"];
  rateLimitMax: number;
  rateLimitWindowMs: number;
  trustedProxies: string[];
};

export function loadEnvironment(
  source: NodeJS.ProcessEnv = process.env
): Environment {
  const parsed = environmentSchema.safeParse(source);

  if (!parsed.success) {
    const issues = parsed.error.issues
      .map((issue) => `${issue.path.join(".")}: ${issue.message}`)
      .join("; ");
    throw new Error(`Invalid environment configuration: ${issues}`);
  }

  const corsOrigins = parsed.data.CORS_ORIGINS.split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (corsOrigins.length === 0) {
    throw new Error("Invalid environment configuration: CORS_ORIGINS is empty");
  }

  if (parsed.data.NODE_ENV === "production") {
    if (!source.DATABASE_URL) {
      throw new Error(
        "Invalid environment configuration: DATABASE_URL is required in production"
      );
    }
    if (!source.CORS_ORIGINS) {
      throw new Error(
        "Invalid environment configuration: CORS_ORIGINS is required in production"
      );
    }
    if (corsOrigins.some((origin) => !origin.startsWith("https://"))) {
      throw new Error(
        "Invalid environment configuration: production CORS_ORIGINS must use HTTPS"
      );
    }
  }

  const trustedProxies = parsed.data.TRUST_PROXY.split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  if (trustedProxies.length === 0) {
    throw new Error("Invalid environment configuration: TRUST_PROXY is empty");
  }

  return {
    apiHost: parsed.data.API_HOST,
    apiPort: parsed.data.API_PORT,
    corsOrigins,
    databaseUrl: parsed.data.DATABASE_URL,
    logLevel: parsed.data.LOG_LEVEL,
    nodeEnvironment: parsed.data.NODE_ENV,
    rateLimitMax: parsed.data.RATE_LIMIT_MAX,
    rateLimitWindowMs: parsed.data.RATE_LIMIT_WINDOW_MS,
    trustedProxies
  };
}
