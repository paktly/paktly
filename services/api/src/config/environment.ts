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
  SOCKETFI_API_URL: z.string().url().default("https://api.socket.fi"),
  SOCKETFI_CLIENT_ID: z
    .string()
    .min(3)
    .default("sf_client_live_mq2aa2w2ofwynne6gkftyendov8k"),
  SOCKETFI_CLIENT_SECRET: z.string().min(16).default("development-only-socketfi-secret"),
  SOCKETFI_ISSUER: z.string().url().default("https://socket.fi"),
  SOCKETFI_ORIGIN: z.string().url().default("https://socket.fi"),
  SOCKETFI_NETWORK: z.enum(["TESTNET", "PUBLIC"]).default("TESTNET"),
  EMAIL_AUTH_ENABLED: z.enum(["true", "false"]).default("false").transform((value) => value === "true"),
  EMAIL_OTP_SECRET: z.string().min(32).optional(),
  SMTP_HOST: z.string().min(1).optional(),
  SMTP_PORT: z.coerce.number().int().min(1).max(65_535).default(465),
  SMTP_SECURE: z.enum(["true", "false"]).default("true").transform((value) => value === "true"),
  SMTP_USERNAME: z.string().min(1).optional(),
  SMTP_PASSWORD: z.string().min(1).optional(),
  EMAIL_FROM: z.string().default("Paktly <hello@paktly.io>"),
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
  socketFi: {
    apiUrl: string;
    clientId: string;
    clientSecret: string;
    issuer: string;
    origin: string;
    network: "TESTNET" | "PUBLIC";
  };
  emailAuth?: {
    enabled: boolean;
    otpSecret?: string;
    from: string;
    smtp?: {
      host: string;
      port: number;
      secure: boolean;
      username: string;
      password: string;
    };
  };
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
    if (!source.SOCKETFI_CLIENT_ID || !source.SOCKETFI_CLIENT_SECRET) {
      throw new Error(
        "Invalid environment configuration: SOCKETFI_CLIENT_ID and SOCKETFI_CLIENT_SECRET are required in production"
      );
    }
  }

  if (parsed.data.EMAIL_AUTH_ENABLED && (
    !source.EMAIL_OTP_SECRET ||
    !source.SMTP_HOST ||
    !source.SMTP_USERNAME ||
    !source.SMTP_PASSWORD
  )) {
    throw new Error(
      "Invalid environment configuration: EMAIL_OTP_SECRET, SMTP_HOST, SMTP_USERNAME, and SMTP_PASSWORD are required when email authentication is enabled"
    );
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
    trustedProxies,
    socketFi: {
      apiUrl: parsed.data.SOCKETFI_API_URL,
      clientId: parsed.data.SOCKETFI_CLIENT_ID,
      clientSecret: parsed.data.SOCKETFI_CLIENT_SECRET,
      issuer: parsed.data.SOCKETFI_ISSUER,
      origin: parsed.data.SOCKETFI_ORIGIN,
      network: parsed.data.SOCKETFI_NETWORK
    },
    emailAuth: {
      enabled: parsed.data.EMAIL_AUTH_ENABLED,
      ...(parsed.data.EMAIL_OTP_SECRET ? { otpSecret: parsed.data.EMAIL_OTP_SECRET } : {}),
      from: parsed.data.EMAIL_FROM,
      ...(parsed.data.SMTP_HOST && parsed.data.SMTP_USERNAME && parsed.data.SMTP_PASSWORD
        ? {
            smtp: {
              host: parsed.data.SMTP_HOST,
              port: parsed.data.SMTP_PORT,
              secure: parsed.data.SMTP_SECURE,
              username: parsed.data.SMTP_USERNAME,
              password: parsed.data.SMTP_PASSWORD
            }
          }
        : {})
    }
  };
}
