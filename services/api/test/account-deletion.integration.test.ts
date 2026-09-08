import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { randomUUID } from "node:crypto";
import { createApp } from "../src/app.js";
import { loadEnvironment } from "../src/config/environment.js";

const databaseUrl = process.env.TEST_ACCOUNT_DELETION_DATABASE_URL;
type Session = { accessToken: string; user: { id: string } };
describe.skipIf(!databaseUrl)("account deletion (isolated database)", () => {
  let app: Awaited<ReturnType<typeof createApp>>;
  beforeAll(async () => {
    app = await createApp(loadEnvironment({ NODE_ENV: "test", DATABASE_URL: databaseUrl!, LOG_LEVEL: "error" }));
  });
  afterAll(async () => { await app.close(); });

  it("erases personal data, preserves balances, transfers ownership and rejects stale writes", async () => {
    const email = `${randomUUID()}@example.com`;
    const signup = async (address: string) => (await app.inject({ method: "POST", url: "/api/v1/auth/dev-session", payload: { email: address, displayName: "Test person" } })).json<Session>();
    const owner = await signup(email);
    const memberEmail = `${randomUUID()}@example.com`;
    const member = await signup(memberEmail);
    const headers = { authorization: `Bearer ${owner.accessToken}` };
    const created = await app.inject({ method: "POST", url: "/api/v1/groups", headers, payload: { name: "Private description", defaultCurrency: "USD" } });
    expect(created.statusCode).toBe(201);
    const groupId = created.json<{ group: { id: string } }>().group.id;
    const invite = await app.inject({ method: "POST", url: `/api/v1/groups/${groupId}/invitations`, headers, payload: { identifier: memberEmail } });
    expect(invite.statusCode).toBe(201);
    const accepted = await app.inject({ method: "POST", url: "/api/v1/invitations/accept", headers: { authorization: `Bearer ${member.accessToken}` }, payload: { token: invite.json<{ invitation: { token: string } }>().invitation.token } });
    expect(accepted.statusCode).toBe(200);
    await app.db`INSERT INTO smart_interest (user_id) VALUES (${owner.user.id})`;
    await app.db`INSERT INTO friends (id,user_id,name,email,linked_user_id) VALUES (${randomUUID()},${member.user.id},'My contact',${email},${owner.user.id})`;
    await app.db`INSERT INTO friends (id,user_id,name,email) VALUES (${randomUUID()},${owner.user.id},'Friend',${memberEmail})`;
    const expense = await app.inject({ method: "POST", url: `/api/v1/groups/${groupId}/expenses`, headers, payload: {
      clientOperationId: randomUUID(), description: "Private dinner", category: "Food", amountMinor: 12000,
      currency: "USD", paidBy: owner.user.id, expenseDate: new Date().toISOString(),
      split: { method: "EQUAL", participantIds: [owner.user.id, member.user.id] }
    } });
    expect(expense.statusCode, expense.body).toBe(201);
    const before = await app.db`SELECT * FROM journal_lines ORDER BY id`;
    expect(before.length).toBeGreaterThan(0);
    expect((await app.inject({ method: "POST", url: "/api/v1/me/account-deletion", payload: { confirmation: "DELETE" } })).statusCode).toBe(401);
    expect((await app.inject({ method: "POST", url: "/api/v1/me/account-deletion", headers, payload: {} })).statusCode).toBe(400);
    const options = await app.inject({ method: "GET", url: "/api/v1/me/account-deletion", headers });
    expect(options.json()).toEqual({ available: true, requiresApple: false });
    const deleted = await app.inject({ method: "POST", url: "/api/v1/me/account-deletion", headers, payload: { confirmation: "DELETE" } });
    expect(deleted.statusCode, deleted.body).toBe(200);
    expect(deleted.json()).toEqual({ deleted: true });
    expect((await app.inject({ method: "GET", url: "/api/v1/me", headers })).statusCode).toBe(401);
    const [user] = await app.db`SELECT u.email,u.status,p.display_name FROM users u JOIN user_profiles p ON p.user_id=u.id WHERE u.id=${owner.user.id}`;
    expect(user).toMatchObject({ status: "DELETED", display_name: "Deleted member", email: `deleted-${owner.user.id}@users.paktly.invalid` });
    expect(await app.db`SELECT * FROM auth_sessions WHERE user_id=${owner.user.id}`).toHaveLength(0);
    expect(await app.db`SELECT * FROM smart_interest WHERE user_id=${owner.user.id}`).toHaveLength(0);
    expect(await app.db`SELECT * FROM friends WHERE user_id=${owner.user.id}`).toHaveLength(0);
    const [contact] = await app.db`SELECT linked_user_id FROM friends WHERE user_id=${member.user.id} AND email=${email}`;
    expect(contact?.linked_user_id).toBeNull();
    const balances = await app.inject({ method: "GET", url: `/api/v1/groups/${groupId}/balances`, headers: { authorization: `Bearer ${member.accessToken}` } });
    expect(balances.statusCode).toBe(200);
    expect(balances.json<{ balances: { userId: string; netMinor: number; displayName: string }[] }>().balances).toContainEqual({ userId: owner.user.id, displayName: "Deleted member", netMinor: 6000 });
    expect(await app.db`SELECT * FROM journal_lines ORDER BY id`).toEqual(before);
    const [remaining] = await app.db`SELECT role FROM group_members WHERE group_id=${groupId} AND user_id=${member.user.id}`;
    expect(remaining?.role).toBe("OWNER");
    await expect(app.db`INSERT INTO smart_interest (user_id) VALUES (${owner.user.id})`).rejects.toMatchObject({ code: "23514" });
    await expect(app.db`UPDATE user_profiles SET display_name='Resurrected' WHERE user_id=${owner.user.id}`).rejects.toMatchObject({ code: "23514" });
    expect((await signup(email)).user.id).not.toBe(owner.user.id);
  });

  it("does not delete an Apple-linked account when revocation is unconfigured", async () => {
    const session = (await app.inject({ method: "POST", url: "/api/v1/auth/dev-session", payload: { email: `${randomUUID()}@example.com`, displayName: "Apple test" } })).json<Session>();
    await app.db`INSERT INTO auth_identities (id,user_id,provider,provider_subject) VALUES (${randomUUID()},${session.user.id},'APPLE',${randomUUID()})`;
    const headers = { authorization: `Bearer ${session.accessToken}` };
    expect((await app.inject({ method: "GET", url: "/api/v1/me/account-deletion", headers })).json()).toEqual({ available: false, requiresApple: true });
    expect((await app.inject({ method: "POST", url: "/api/v1/me/account-deletion", headers, payload: { confirmation: "DELETE" } })).statusCode).toBe(503);
    expect((await app.inject({ method: "GET", url: "/api/v1/me", headers })).statusCode).toBe(200);
  });
});
