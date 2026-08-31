import { importSPKI, jwtVerify, type JWTPayload } from "jose";
import type { Environment } from "../../config/environment.js";

type CachedKey = { key: CryptoKey; expiresAt: number; kid?: string };

export type VerifiedSocketFiIdentity = {
  subject: string;
  username?: string;
  projectUsername?: string;
  wallets: Partial<Record<"TESTNET" | "PUBLIC", string>>;
  network: "TESTNET" | "PUBLIC";
};

let cachedKey: CachedKey | undefined;

async function fetchPublicKey(config: Environment["socketFi"]): Promise<CachedKey> {
  const response = await fetch(
    new URL("/.well-known/socketfi-public-key", config.apiUrl),
    {
      headers: {
        "x-socketfi-client-id": config.clientId,
        "x-socketfi-client-secret": config.clientSecret
      },
      signal: AbortSignal.timeout(8_000)
    }
  );
  const body = (await response.json()) as {
    kid?: string;
    alg?: string;
    publicKey?: string;
  };
  if (!response.ok || !body.publicKey || (body.alg && body.alg !== "RS256")) {
    throw new Error("SocketFi public key is unavailable.");
  }
  return {
    key: await importSPKI(body.publicKey, "RS256"),
    expiresAt: Date.now() + 60 * 60 * 1_000,
    ...(body.kid ? { kid: body.kid } : {})
  };
}

async function publicKey(config: Environment["socketFi"], force = false): Promise<CachedKey> {
  if (!force && cachedKey && cachedKey.expiresAt > Date.now()) return cachedKey;
  cachedKey = await fetchPublicKey(config);
  return cachedKey;
}

function normalize(payload: JWTPayload, config: Environment["socketFi"]): VerifiedSocketFiIdentity {
  if (
    payload.type !== "access" ||
    payload.clientId !== config.clientId ||
    payload.origin !== config.origin ||
    payload.network !== config.network ||
    typeof payload.sub !== "string"
  ) {
    throw new Error("SocketFi token binding is invalid.");
  }
  const rawWallets = payload.wallet;
  const wallets: VerifiedSocketFiIdentity["wallets"] = {};
  if (rawWallets && typeof rawWallets === "object") {
    for (const network of ["TESTNET", "PUBLIC"] as const) {
      const address = (rawWallets as Record<string, unknown>)[network];
      if (typeof address === "string" && address.length > 0) wallets[network] = address;
    }
  }
  return {
    subject: payload.sub,
    ...(typeof payload.username === "string" ? { username: payload.username } : {}),
    ...(typeof payload.projectUsername === "string"
      ? { projectUsername: payload.projectUsername }
      : {}),
    wallets,
    network: config.network
  };
}

export async function verifySocketFiToken(
  token: string,
  config: Environment["socketFi"]
): Promise<VerifiedSocketFiIdentity> {
  let key = await publicKey(config);
  let payload: JWTPayload;
  try {
    const result = await jwtVerify(token, key.key, {
      algorithms: ["RS256"],
      issuer: config.issuer,
      audience: config.clientId
    });
    payload = result.payload;
  } catch {
    key = await publicKey(config, true);
    const result = await jwtVerify(token, key.key, {
      algorithms: ["RS256"],
      issuer: config.issuer,
      audience: config.clientId
    });
    payload = result.payload;
  }
  return normalize(payload, config);
}

export function clearSocketFiKeyCache(): void {
  cachedKey = undefined;
}
