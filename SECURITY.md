# Security

Milestone 1 establishes secure defaults but does not handle real money.

- Secrets are environment-provided and never committed.
- API responses include request IDs and conservative security headers.
- Logs are structured and must not contain credentials, passkey assertions, private keys, card data, or KYC documents.
- Runtime configuration is validated at startup.
- Dependency, static-analysis, and test checks run in CI.
- Passkey private keys remain in platform authenticators; servers retain only public credential material required for verification.
- SocketFi and every financial provider will be isolated behind narrow adapters.

Before stored-value features, complete the threat model, ledger invariants, webhook replay protection, reconciliation jobs, contract review, and jurisdiction-specific legal review.
