# ADR 0002: Keep expense accounting off-chain

- Status: Accepted
- Date: 2026-08-27

## Decision

Shared expenses, splits, balances, and recommended settlement paths are recorded in an immutable PostgreSQL double-entry ledger. Stellar is used only when stored value actually moves.

## Consequences

Expense data stays private, correction workflows remain practical, and blockchain latency and attack surface are limited to cases that benefit from programmable ownership and authorization.
