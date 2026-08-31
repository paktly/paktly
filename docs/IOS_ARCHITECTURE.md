# iOS Architecture

The iOS client is native SwiftUI with feature folders, a small app-session state machine, and dependency inversion for accounts and providers.

- Views render state and send user intents; they do not make API or provider calls directly.
- `AppSession` owns Paktly authentication and the explicit transition into optional Smart Wallet activation.
- `SmartAccountService` separates product flows from SocketFi details. `SocketFiNativeSmartAccountService` uses `ASAuthorizationPlatformPublicKeyCredentialProvider` for sign-in, signup, wallet proof, and transaction approval without a hosted browser.
- Money models use integer minor units and locale-aware formatters.
- Expense capture will gain an offline operation queue; money-moving actions will require connectivity.
- Strings use Apple's localization system, layouts use semantic leading/trailing alignment, and views support Dynamic Type and reduced motion.

Ordinary onboarding provides native Sign in with Apple, the official Google Sign-In SDK, and email OTP; none creates a wallet. Apple requests a per-attempt SHA-256 nonce and forwards the raw nonce plus identity token to the API. Google requests an ID token for the separately configured web/server OAuth client. Passkey sign-in is not presented during onboarding. A signed-in user activates Paktly Smart from the profile when they want stored-value features; only that action invokes SocketFi's native passkey flow and links the resulting smart account.

The app is configured for `socket.fi` web credentials and TESTNET. SocketFi's Apple App Site Association file must contain the exact Apple Team ID plus `io.paktly.app`. SocketFi access tokens and Paktly access tokens use separate Keychain records.
