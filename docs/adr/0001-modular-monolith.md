# ADR 0001: Begin with a modular monolith

- Status: Accepted
- Date: 2026-08-27

## Context

The product spans social trip planning, accounting, and eventually regulated money movement. Separating these into network services now would add failure modes before their operational boundaries are understood.

## Decision

Use one Fastify deployment with independently composed domain modules. Use PostgreSQL as the source of truth, Redis for coordination, and an outbox-backed domain event model when persistence is introduced.

## Consequences

Transactions can remain atomic across early domains, local development stays straightforward, and modules can later be extracted based on measured scaling or compliance needs.
