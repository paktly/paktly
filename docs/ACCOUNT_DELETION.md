# Account deletion

You → Delete account opens a confirmation sheet with consequences and a privacy link. Users may delete with outstanding balances. Apple-linked users confirm with the same Apple identity. Success clears local queued expenses, pending navigation, cached account data and credentials, then signs out after acknowledgement. Every Paktly session is invalidated in the database transaction.

`GET /api/v1/me/account-deletion` returns `requiresApple` and `available`. `POST` requires `{ "confirmation": "DELETE" }`; Apple-linked accounts additionally send `apple: { authorizationCode, nonce }`. Both require authentication; POST is rate-limited. The caller cannot supply another account's ID.

## Server configuration

Configure a **Sign in with Apple** key associated with the app's primary App ID. An APNs-only key cannot revoke Apple authorization. Set all three in `/opt/paktly/.env`:

```dotenv
APPLE_TEAM_ID=GC29BX444D
APPLE_KEY_ID=YOUR_SIGN_IN_WITH_APPLE_KEY_ID
APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_CONTENT\n-----END PRIVATE KEY-----"
```

Keep `APPLE_CLIENT_ID=io.paktly.app`. Partial key configuration fails startup. Without revocation configuration, Apple-linked users cannot complete automatic deletion; configure and test before release. The server exchanges a fresh authorization code, verifies the token signature, issuer, audience, subject and nonce, then revokes the refresh token. Verification/revocation failures leave Paktly data unchanged. Tokens are not logged or persisted. Apple and PostgreSQL cannot form an atomic transaction: if cleanup fails after revocation, repeat Apple confirmation.

Deploy from the repo root with `./scripts/deploy-production.sh`; migration 015 guards against stale writes recreating deleted account data. Rebuild the iOS app too.

## Data boundaries and release gates

Private tables are erased, email/profile fields replaced, and authored shared descriptions redacted. Monetary amounts, journal lines, payer and participant UUID references are retained without the original profile. This is pseudonymization, not absolute anonymization or debt forgiveness. Ownership transfers to a remaining active member where available. Independent contact lists, delivered emails/notifications on other devices, blockchain data, logs and backups are outside the synchronous deletion transaction. No wallet funds move; independently controlled wallets and device passkeys are not deleted.

Before release, approve the lawful basis and retention schedule for shared records, logs and backups, finalize legal-page operator details, and verify the support mailbox. Backup restoration must reapply deletions before customer access is restored. Never restore an old database directly to production.

If the response is lost after commit, retry returns unauthorized because the session is gone. The client must not promise the account remains intact after a timeout. In-app success is shown only after a confirmed response.

## Tests

Use a dedicated disposable database, apply migrations, then run:

```sh
TEST_ACCOUNT_DELETION_DATABASE_URL=postgres://... pnpm --filter @pakt/api exec vitest run test/account-deletion.integration.test.ts
pnpm --filter @pakt/api exec vitest run test/apple-revocation.test.ts
```

Never use production data. Device release checks: email/Google deletion; Apple confirmation/cancel/wrong identity; server and offline failures; repeated taps; another member's balances; session rejection on another phone; fresh signup with the same email; local queue clearing; VoiceOver and large text. Swift compilation and real Apple token exchange require Xcode/device testing.
