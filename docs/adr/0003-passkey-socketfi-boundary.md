# ADR 0003: Default to passkeys and isolate SocketFi

- Status: Accepted in principle; SDK details pending verification
- Date: 2026-08-27

## Decision

Passkeys are the primary consumer authentication path. SocketFi will provide user smart-account infrastructure through app-owned `SmartAccountService` interfaces. TripVault remains a distinct group contract.

## Constraints

No seed phrase in normal onboarding, no custom cryptography, no backend-only ability to forge group authorization, and no SDK types outside the adapter layer.

## Follow-up

Verify SocketFi's current iOS, backend verification, session, recovery, and Stellar authorization APIs before Milestone 2 implementation.
