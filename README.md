# Paktly

Paktly is an iOS-first shared-finance platform: plan, budget, spend, split, reconcile, and settle together across trips, homes, events, projects, and everyday groups.

This repository is a pnpm-orchestrated monorepo. Swift and Rust retain their native toolchains and are not packaged as JavaScript workspaces.

## Expense-sharing MVP

- `services/api`: persisted accounts, profiles, shared plans, invitations, five split modes, immutable ledger, balances, settlements, activity, and notifications
- `apps/web`: responsive Next.js public-product shell
- `apps/ios`: native SwiftUI client with plan, expense, balance, settlement, activity, notification, and offline-sync flows
- `apps/admin`: reserved for the internal operations app
- `contracts`: reserved for audited Stellar contracts in later milestones
- `packages`: shared TypeScript configuration and API types
- `infrastructure`: local containers and deployment assets
- `docs`: architecture, security, and decision records

## Requirements

- Node.js 22 or newer
- pnpm 11.20.0
- Docker (for local PostgreSQL and Redis)
- macOS with current Xcode for iOS development

## Start locally

```bash
cp .env.example .env
pnpm install
docker compose up -d postgres redis
export DATABASE_URL=postgres://pakt:pakt_local_only@localhost:56432/pakt
pnpm --filter @pakt/api migrate
pnpm --filter @pakt/web migrate:waitlist
pnpm dev
```

The web app runs at `http://localhost:3000`; the API runs at `http://localhost:4000` and exposes `GET /api/v1/health`.

## Validate

```bash
pnpm validate
```

Run the real-database workflow test with:

```bash
TEST_DATABASE_URL=postgres://pakt:pakt_local_only@localhost:56432/pakt pnpm --filter @pakt/api test:integration
```

The iOS project is generated with XcodeGen from `apps/ios/project.yml` and must be built on macOS. The expense-sharing MVP moves no custodial money; blockchain and provider features remain disabled.

## Product boundaries

- Ordinary shared-expense accounting remains private and off-chain.
- Only stored-value movements will use Stellar.
- Passkeys are the default consumer authentication experience.
- SocketFi remains behind the `SmartAccountService` boundary; the checked-in local build uses a development passkey/account adapter and development API session.
- The consumer brand is **Paktly** and the canonical public domain is **paktly.io**. Complete trademark and legal-entity review before commercial launch.
