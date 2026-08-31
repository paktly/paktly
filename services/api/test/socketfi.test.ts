import { exportSPKI, generateKeyPair, SignJWT } from "jose";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import type { Environment } from "../src/config/environment.js";
import {
  clearSocketFiKeyCache,
  verifySocketFiToken
} from "../src/modules/auth/socketfi.js";

const config: Environment["socketFi"] = {
  apiUrl: "https://api.socket.fi",
  clientId: "paktly",
  clientSecret: "test-socketfi-secret",
  issuer: "https://socket.fi",
  origin: "https://socket.fi",
  network: "TESTNET"
};

let privateKey: CryptoKey;
let publicKeyPem: string;

beforeAll(async () => {
  const pair = await generateKeyPair("RS256", { extractable: true });
  privateKey = pair.privateKey;
  publicKeyPem = await exportSPKI(pair.publicKey);
});

afterEach(() => {
  clearSocketFiKeyCache();
  vi.restoreAllMocks();
});

async function token(overrides: Record<string, unknown> = {}) {
  return new SignJWT({
    type: "access",
    clientId: "paktly",
    origin: "https://socket.fi",
    network: "TESTNET",
    username: "socketfi-user",
    wallet: { TESTNET: "CEXAMPLE" },
    ...overrides
  })
    .setProtectedHeader({ alg: "RS256", kid: "key-1" })
    .setSubject("socketfi-subject")
    .setIssuer("https://socket.fi")
    .setAudience("paktly")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(privateKey);
}

function mockKey(status = 200, body: Record<string, unknown> = {}) {
  const fetchMock = vi.fn().mockResolvedValue(
    new Response(
      JSON.stringify({ kid: "key-1", alg: "RS256", publicKey: publicKeyPem, ...body }),
      { status, headers: { "content-type": "application/json" } }
    )
  );
  vi.stubGlobal("fetch", fetchMock);
  return fetchMock;
}

describe("SocketFi token verification", () => {
  it("verifies issuer, audience, project, native origin, network, subject, and wallet", async () => {
    const fetchMock = mockKey();
    const result = await verifySocketFiToken(await token(), config);
    expect(result).toEqual({
      subject: "socketfi-subject",
      username: "socketfi-user",
      wallets: { TESTNET: "CEXAMPLE" },
      network: "TESTNET"
    });
    expect(fetchMock).toHaveBeenCalledWith(
      new URL("https://api.socket.fi/.well-known/socketfi-public-key"),
      expect.objectContaining({
        headers: {
          "x-socketfi-client-id": "paktly",
          "x-socketfi-client-secret": "test-socketfi-secret"
        }
      })
    );
  });

  it("exposes the project-scoped username separately from SocketFi's internal username", async () => {
    mockKey();
    const result = await verifySocketFiToken(
      await token({ username: "paktly-alex--internal-id", projectUsername: "paktly_alex" }),
      config
    );
    expect(result.username).toBe("paktly-alex--internal-id");
    expect(result.projectUsername).toBe("paktly_alex");
  });

  it.each([
    ["type", "socketfi_auth"],
    ["clientId", "other"],
    ["origin", "https://evil.example"],
    ["network", "PUBLIC"]
  ])("rejects a mismatched %s binding", async (field, value) => {
    mockKey();
    await expect(verifySocketFiToken(await token({ [field]: value }), config)).rejects.toThrow();
  });

  it("rejects missing subjects and malformed wallet values", async () => {
    mockKey();
    const withoutSubject = new SignJWT({
      type: "access",
      clientId: "paktly",
      origin: "https://socket.fi",
      network: "TESTNET",
      wallet: "invalid"
    })
      .setProtectedHeader({ alg: "RS256" })
      .setIssuer("https://socket.fi")
      .setAudience("paktly")
      .setExpirationTime("5m")
      .sign(privateKey);
    await expect(verifySocketFiToken(await withoutSubject, config)).rejects.toThrow();
  });

  it("rejects unavailable or incompatible public keys", async () => {
    mockKey(503, { publicKey: undefined });
    await expect(verifySocketFiToken(await token(), config)).rejects.toThrow(
      "SocketFi public key is unavailable"
    );

    clearSocketFiKeyCache();
    mockKey(200, { alg: "ES256" });
    await expect(verifySocketFiToken(await token(), config)).rejects.toThrow(
      "SocketFi public key is unavailable"
    );
  });
});
