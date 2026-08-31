# ADR 0003: Separate Paktly identity from SocketFi wallets

- Status: Superseded onboarding decision; account boundary retained
- Date: 2026-08-31

## Decision

An ordinary Paktly account is independent from a SocketFi smart account. Email OTP is the initial low-friction identity path and creates no wallet. A user explicitly activates Paktly Smart when stored-value features are needed; that transition uses SocketFi's native passkey flow and links the resulting wallet to the existing Paktly user. Existing wallet users retain passkey sign-in. Apple and Google can be added as Paktly identity providers without changing the wallet boundary.

Paktly uses SocketFi's registered native-app protocol and Apple's `AuthenticationServices` UI directly; it does not need to open hosted authentication. Hosted SocketFi remains available to other clients. SocketFi stays behind app-owned `SmartAccountService` interfaces. TripVault remains a distinct group contract.

## Constraints

No seed phrase in normal onboarding, no custom cryptography, no backend-only ability to forge group authorization, and no SocketFi wire types outside the adapter layer. RP IDs and expected origins come only from SocketFi's reviewed project registry. The iOS app contains no SocketFi project secret.

## Implementation

Paktly is registered with SocketFi, uses `socket.fi` as the RP ID, and begins on TESTNET. The SocketFi RP domain must associate the signed Paktly Apple application ID. Wallet activation exchanges the short-lived SocketFi access token at authenticated `POST /api/v1/me/smart-wallet/socketfi`. Passkey sign-in for a linked account uses `POST /api/v1/auth/socketfi`. The API verifies RS256 signature, issuer, audience, client, native origin, network, subject, and expiry.

Native transaction authorization uses SocketFi's prepared Soroban challenge and contract/function allowlist. It remains distinct from login authentication.
