# Architecture

Paktly begins as a modular monolith with native clients. This reduces operational complexity while preserving clear domain boundaries.

```text
SwiftUI app          Next.js web
      \                 /
       \               /
        Fastify API (modular monolith)
          |        |         |
      PostgreSQL  Redis   provider adapters
          |
   immutable double-entry ledger

Future stored value only:
SocketFi smart account -> TripVault -> Stellar USDC
```

## Boundaries

- `apps/ios` owns native presentation, local state, offline expense capture, and secure system authentication prompts.
- `apps/web` owns public marketing and product education.
- `services/api` owns authorization, domains, workflows, ledger posting, and provider orchestration.
- PostgreSQL is authoritative for off-chain product and ledger data.
- Redis supports ephemeral coordination and durable job queues; it is never the financial source of truth.
- Provider and blockchain code enters through interfaces so domain logic does not depend on a particular issuer, funding provider, or smart-account SDK.

## Account model

Passkeys are the default user-facing sign-in mechanism. SocketFi is intended to be the canonical Stellar smart-account layer. The app will not create a parallel wallet system or expose seed phrases. Personal smart accounts and group TripVault contracts remain separate concepts.

## Expense and balance model

Expenses are logical records with append-only versions. Editing posts an equal-and-opposite reversal for the previous version before posting the replacement. Deleting is a status transition plus a reversal; history is never rewritten.

Each shared plan has one member-balance ledger account per active member and default currency. A participant share debits that member and credits the payer. A settlement debits the creditor and credits the debtor. Balance recommendations are simplified from net positions without changing journal history. Foreign expenses store their original value and an immutable rational exchange-rate snapshot.

## Environments

`local`, `development`, `test`, `staging`, and `production` are distinct. Stellar testnet and mainnet configuration must use separate validated environment groups. Financial capabilities default off and will be controlled by explicit feature flags.

See `docs/adr` for consequential decisions.
