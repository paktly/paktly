# Paktly public website

The website includes the product narrative, prelaunch availability and pricing, FAQ, security and accessibility pages, support contacts, legal policies, SEO assets, a custom error experience, and a consented PostgreSQL waitlist.

## Local setup

```bash
docker compose up -d postgres
DATABASE_URL=postgres://pakt:pakt_local_only@localhost:56432/pakt pnpm --filter @pakt/web migrate:waitlist
pnpm --filter @pakt/web dev
```

## Quality gates

```bash
pnpm --filter @pakt/web lint
pnpm --filter @pakt/web typecheck
pnpm --filter @pakt/web test
pnpm --filter @pakt/web build
pnpm --filter @pakt/web lighthouse
```

The legal documents are implementation-aligned prelaunch drafts, not a substitute for counsel. Before public launch, replace the provisional operator description with the actual legal entity, postal address, governing terms, supported regions, and verified provider disclosures.
