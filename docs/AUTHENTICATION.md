# Authentication

Paktly identity is separate from the optional SocketFi Smart Wallet. Creating an account through Apple, Google, or email does not create a wallet.

## Sign in with Apple

1. Enable Sign in with Apple for the `io.paktly.app` App ID in the Apple Developer portal.
2. Keep the entitlement in `Paktly.entitlements` and use automatic signing or a provisioning profile containing the capability.
3. Set `APPLE_AUTH_ENABLED=true` and `APPLE_CLIENT_ID=io.paktly.app` on the API.
4. The client creates a cryptographically random nonce, sends its SHA-256 digest to Apple, and sends the raw nonce with Apple's identity token to Paktly.
5. The API verifies Apple's signature, issuer, audience, expiration, and nonce before consuming the assertion once.

## Google

1. Create an OAuth iOS client for bundle ID `io.paktly.app` in Google Cloud.
2. Create a separate OAuth web client used as the backend/server audience.
3. The registered Paktly iOS client ID, backend client ID, and reversed URL scheme are configured in `apps/ios/project.yml`.
4. Set `GOOGLE_AUTH_ENABLED=true` and set `GOOGLE_SERVER_CLIENT_ID=41146548867-jof7pg8sm1gjddi8fq657s9esft7qi34.apps.googleusercontent.com` on the API.
5. Regenerate the Xcode project. The app uses Google's official SDK and sends only the ID token to Paktly; the API verifies signature, issuer, audience, expiration, and verified email before consuming the assertion once.

## Account matching

Provider subjects are immutable login identifiers. A new verified provider identity links to an existing Paktly user only when its normalized verified email matches. Provider assertions are hashed and recorded as single-use. Provider credentials never create or authorize a SocketFi wallet.

## Onboarding layout

The provider and email controls use a 54-point row height, while every nested action preserves at least Apple's 44-point touch target. The screen is vertically scrollable for smaller phones and Dynamic Type, and its content is capped at 520 points wide on larger devices.
