# ADR 0003: Default to passkeys and isolate SocketFi

- Status: Accepted and implemented for TESTNET
- Date: 2026-08-27

## Decision

Passkeys are the primary consumer authentication path. Paktly uses SocketFi's registered native-app protocol and Apple's `AuthenticationServices` UI directly; it does not need to open hosted authentication. Hosted SocketFi remains available to other clients. SocketFi provides user smart-account infrastructure through app-owned `SmartAccountService` interfaces. TripVault remains a distinct group contract.

## Constraints

No seed phrase in normal onboarding, no custom cryptography, no backend-only ability to forge group authorization, and no SocketFi wire types outside the adapter layer. RP IDs and expected origins come only from SocketFi's reviewed project registry. The iOS app contains no SocketFi project secret.

## Implementation

Paktly is registered as `paktly`, uses `socket.fi` as the RP ID, and begins on TESTNET. The SocketFi RP domain must associate the signed Paktly Apple application ID. Paktly exchanges the short-lived SocketFi access token at `POST /api/v1/auth/socketfi`; its API verifies RS256 signature, issuer, audience, client, native origin, network, subject, and expiry before issuing an independent Paktly session.

Native transaction authorization uses SocketFi's prepared Soroban challenge and contract/function allowlist. It remains distinct from login authentication.
