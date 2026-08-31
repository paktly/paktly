import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import type { Environment } from "../src/config/environment.js";

const databaseUrl = process.env.TEST_DATABASE_URL;
const suite = databaseUrl ? describe : describe.skip;

suite("expense-sharing MVP end to end", () => {
  const environment: Environment = { apiHost: "127.0.0.1", apiPort: 4000, corsOrigins: ["http://localhost:3000"], databaseUrl: databaseUrl!, logLevel: "silent", nodeEnvironment: "test", rateLimitMax: 300, rateLimitWindowMs: 60_000, trustedProxies: ["loopback", "linklocal", "uniquelocal"], socketFi: { apiUrl: "https://api.socket.fi", clientId: "paktly", clientSecret: "test-socketfi-secret", issuer: "https://socket.fi", origin: "https://socket.fi", network: "TESTNET" } };
  let app: Awaited<ReturnType<typeof createApp>>;
  const sessions = new Map<string, { token: string; id: string }>();
  let groupId = "";

  beforeAll(async () => {
    app = await createApp(environment);
    await app.db.unsafe("TRUNCATE users CASCADE");
    for (const name of ["alice", "bob", "charlie", "dave"]) {
      const response = await app.inject({ method: "POST", url: "/api/v1/auth/dev-session", payload: { email: `${name}@example.com`, displayName: name[0]!.toUpperCase() + name.slice(1) } });
      expect(response.statusCode).toBe(200);
      const data = response.json(); sessions.set(name, { token: data.accessToken, id: data.user.id });
    }
  });
  afterAll(async () => { await app.close(); });

  function auth(name: string) { return { authorization: `Bearer ${sessions.get(name)!.token}` }; }

  it("creates profiles, plans, invitations and memberships", async () => {
    const initiallyAvailable = await app.inject({ method: "POST", url: "/api/v1/me/username-availability", headers: auth("alice"), payload: { username: "Alice On Tour" } });
    expect(initiallyAvailable.json()).toEqual({ username: "alice_on_tour", available: true, reason: null });
    const profile = await app.inject({ method: "PATCH", url: "/api/v1/me", headers: auth("alice"), payload: { username: "Alice On Tour", defaultCurrency: "usd" } });
    expect(profile.statusCode).toBe(200);
    expect(profile.json().profile.username).toBe("alice_on_tour");
    const taken = await app.inject({ method: "POST", url: "/api/v1/me/username-availability", headers: auth("bob"), payload: { username: "alice on tour" } });
    expect(taken.json()).toEqual({ username: "alice_on_tour", available: false, reason: "TAKEN" });
    const bobProfile = await app.inject({ method: "PATCH", url: "/api/v1/me", headers: auth("bob"), payload: { username: "bob_builder" } });
    expect(bobProfile.statusCode).toBe(200);
    const created = await app.inject({ method: "POST", url: "/api/v1/groups", headers: auth("alice"), payload: { name: "Shared summer", description: "Not only a trip", defaultCurrency: "USD" } });
    expect(created.statusCode).toBe(201); groupId = created.json().group.id;
    for (const name of ["bob", "charlie"]) {
      const identifier = name === "bob" ? "@bob_builder" : `${name}@example.com`;
      const invited = await app.inject({ method: "POST", url: `/api/v1/groups/${groupId}/invitations`, headers: auth("alice"), payload: { identifier } });
      expect(invited.statusCode).toBe(201);
      expect(invited.json().invitation.email).toBe(`${name}@example.com`);
      const inbox = await app.inject({ method: "GET", url: "/api/v1/invitations", headers: auth(name) });
      expect(inbox.statusCode).toBe(200);
      expect(inbox.json().invitations).toHaveLength(1);
      const resolved = await app.inject({ method: "POST", url: "/api/v1/invitations/resolve", headers: auth(name), payload: { token: invited.json().invitation.token } });
      expect(resolved.json().invitation.group_name).toBe("Shared summer");
      const accepted = await app.inject({ method: "POST", url: "/api/v1/invitations/accept", headers: auth(name), payload: { token: invited.json().invitation.token } });
      expect(accepted.statusCode).toBe(200);
    }
    const daveInvite = await app.inject({ method: "POST", url: `/api/v1/groups/${groupId}/invitations`, headers: auth("alice"), payload: { identifier: "dave@example.com" } });
    expect(daveInvite.statusCode).toBe(201);
    const declined = await app.inject({ method: "POST", url: `/api/v1/invitations/${daveInvite.json().invitation.id}/decline`, headers: auth("dave") });
    expect(declined.statusCode).toBe(200);
    expect(declined.json().invitation.status).toBe("DECLINED");
    const emptyInbox = await app.inject({ method: "GET", url: "/api/v1/invitations", headers: auth("dave") });
    expect(emptyInbox.json().invitations).toHaveLength(0);
    const detail = await app.inject({ method: "GET", url: `/api/v1/groups/${groupId}`, headers: auth("alice") });
    expect(detail.json().members).toHaveLength(3);
  });

  it("creates every split type, snapshots FX, edits, deletes and replays safely", async () => {
    const [alice, bob, charlie] = [sessions.get("alice")!.id, sessions.get("bob")!.id, sessions.get("charlie")!.id];
    const base = { description: "Dinner", category: "Food", amountMinor: 12000, currency: "USD", paidBy: alice, expenseDate: new Date().toISOString(), notes: null };
    const definitions = [
      { method: "EQUAL", participantIds: [alice, bob, charlie] },
      { method: "EXACT", shares: [{ userId: alice, value: 5000 }, { userId: bob, value: 4000 }, { userId: charlie, value: 3000 }] },
      { method: "PERCENTAGE", shares: [{ userId: alice, value: 5000 }, { userId: bob, value: 2500 }, { userId: charlie, value: 2500 }] },
      { method: "SHARES", shares: [{ userId: alice, value: 2 }, { userId: bob, value: 1 }, { userId: charlie, value: 1 }] },
      { method: "ITEMIZED", items: [{ amountMinor: 6000, participantIds: [alice, bob] }, { amountMinor: 6000, participantIds: [charlie] }] }
    ];
    const ids: string[] = [];
    for (const split of definitions) {
      const operation = randomUUID();
      const response = await app.inject({ method: "POST", url: `/api/v1/groups/${groupId}/expenses`, headers: auth("alice"), payload: { ...base, clientOperationId: operation, split } });
      expect(response.statusCode).toBe(201); ids.push(response.json<{ expense: { id: string } }>().expense.id);
      const replay = await app.inject({ method: "POST", url: `/api/v1/groups/${groupId}/expenses`, headers: auth("alice"), payload: { ...base, clientOperationId: operation, split } });
      expect(replay.json().expense.idempotentReplay).toBe(true);
    }
    const foreign = await app.inject({ method: "POST", url: `/api/v1/groups/${groupId}/expenses`, headers: auth("bob"), payload: { ...base, description: "Cafe", amountMinor: 1000, currency: "EUR", paidBy: bob, clientOperationId: randomUUID(), split: definitions[0], exchangeRate: { numerator: 110, denominator: 100, provider: "TEST", timestamp: new Date().toISOString() } } });
    expect(foreign.json().expense.convertedAmountMinor).toBe(1100);
    const edited = await app.inject({ method: "PATCH", url: `/api/v1/expenses/${ids[0]}`, headers: auth("alice"), payload: { ...base, description: "Dinner corrected", expectedVersion: 1, split: definitions[0] } });
    expect(edited.json().expense.version).toBe(2);
    const deleted = await app.inject({ method: "DELETE", url: `/api/v1/expenses/${ids[1]}`, headers: auth("alice") });
    expect(deleted.statusCode).toBe(204);
    const listing = await app.inject({ method: "GET", url: `/api/v1/groups/${groupId}/expenses`, headers: auth("bob") });
    expect(listing.json().expenses).toHaveLength(5);
  });

  it("calculates balances, simplifies debt, records settlement, activity and notifications", async () => {
    const balances = await app.inject({ method: "GET", url: `/api/v1/groups/${groupId}/balances`, headers: auth("alice") });
    expect(balances.statusCode).toBe(200);
    const balancePayload = balances.json<{ balances: { netMinor: number }[]; suggestedSettlements: { fromUserId: string; toUserId: string; amountMinor: number }[] }>();
    expect(balancePayload.balances.reduce((sum, item) => sum + item.netMinor, 0)).toBe(0);
    const invariantRows = await app.db`
      SELECT je.id,sum(jl.debit_minor)::bigint debits,sum(jl.credit_minor)::bigint credits
      FROM journal_entries je JOIN journal_lines jl ON jl.journal_entry_id=je.id
      WHERE je.group_id=${groupId} GROUP BY je.id
    `;
    expect(invariantRows.every((row) => Number(row.debits) === Number(row.credits))).toBe(true);
    const suggestion = balancePayload.suggestedSettlements[0]!;
    const operation = randomUUID();
    const payload = { fromUserId: suggestion.fromUserId, toUserId: suggestion.toUserId, amountMinor: suggestion.amountMinor, method: "MARKED_PAID", clientOperationId: operation };
    const settled = await app.inject({ method: "POST", url: `/api/v1/groups/${groupId}/settlements`, headers: auth("alice"), payload });
    expect(settled.statusCode).toBe(201);
    const replay = await app.inject({ method: "POST", url: `/api/v1/groups/${groupId}/settlements`, headers: auth("alice"), payload });
    expect(replay.json().idempotentReplay).toBe(true);
    const activity = await app.inject({ method: "GET", url: `/api/v1/groups/${groupId}/activity`, headers: auth("bob") });
    expect(activity.json().events.length).toBeGreaterThan(5);
    const notifications = await app.inject({ method: "GET", url: "/api/v1/notifications", headers: auth("bob") });
    expect(notifications.json().notifications.length).toBeGreaterThan(0);
  });
});
