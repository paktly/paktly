# Paktly project audit — September 16, 2026

**Release assessment: changes are ready for review, but resubmission is not yet verified.** The two rejected onboarding/permission flows have been corrected. Account deletion has been hardened and its local tests pass; the exact September 15 production failure remains unconfirmed without production logs and a real Apple account deletion test. Financial correctness findings below also need attention before claiming broad currency support.

Scope: native iOS app, API authentication/authorization and account deletion, database migrations, expense ledger and offline synchronization, voice/receipt data flows, notifications, public website/waitlist, shared API package, CI, deployment scripts, privacy manifest and review documentation. The admin and contract directories are documented future work, not deployed implementations. This was a repository review plus local builds/tests and a production dependency advisory scan, not a production penetration test or legal certification.

## App Store findings and changes

| Review issue | Evidence | Change | Remaining verification |
| --- | --- | --- | --- |
| 4 — Apple users asked for name/email again | `issues/Screenshot-0916-111509.png`; `AppSession.authenticateFederated` previously forced every new user into profile setup | Apple sign-in now enters the app directly. The API returns a profile-setup flag; restored Apple accounts also skip setup even when Apple omits the name. Supplied names fill unfinished profiles without overwriting customized names. Username/profile editing remains optional in You. | Real first authorization, returning authorization, Hide My Email, deletion/recreation, and app relaunch. Deploy API before the iOS update. |
| 5.1.1(iv) — coercive/dismissible microphone pre-permission screen | `issues/Screenshot-0916-110848.png`; `AIDataConsentView` preceded iOS permission with Allow and continue / Not now / Close | The native microphone prompt is requested directly, without a custom pre-alert. After access is granted, a separate AI data-sharing screen offers Continue and Don’t use AI. No recording or upload occurs before AI consent. Denial shows Settings/Close. Cancellation is checked after awaiting permission. | On a clean installation, verify ordering, Deny, Settings return, AI refusal, and no recording/network upload before AI consent. |
| 2.1(a) — deletion error | `issues/Screenshot-0916-110710.png`; client discarded API details and labeled every failure a connection issue | Client now displays safe API messages and a support request ID. Server records sanitized Apple failure stages/protocol reasons. A verified access token is supported when a refresh token is absent. Database cleanup runs before external revocation within the uncommitted transaction; Apple failure rolls it back. Wrong-account confirmation has a distinct response. | Retrieve review-time logs if retained; verify deployed migrations, Sign in with Apple key association/client ID and outbound Apple access. Delete a real disposable Apple account against the deployed API. Local success does not establish that production configuration is correct. |

Apple's token exchange, signature/issuer/audience/subject/nonce validation, and successful revocation remain required. No bypass reports successful deletion when Apple rejects the operation. A database commit failure after successful external revocation is still a distributed transaction limitation; retry with fresh Apple authorization. A lost success response can lead to an expired-session response on retry; the app does not claim the account necessarily remains intact after a network timeout.

References: [Apple privacy guidance](https://developer.apple.com/design/human-interface-guidelines/privacy), [Sign in with Apple design guidance](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple), and [Apple account-deletion technical note](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple).

## Additional issues fixed

- **Account data persisted across sign-out.** Profile sign-out now clears cached groups, notifications, invitations, balances and navigation. Offline expenses are tagged with their owning user and only replay after `/me` identifies that user. Drafts are retained for their owner across ordinary sign-out. Legacy queue entries with no owner are retained but are not automatically replayed; ownership cannot safely be inferred from the payer field.
- **Queue synchronization could erase newly added drafts.** Previously it saved its original snapshot after awaiting uploads. It now removes acknowledged entries from the latest persisted queue and serializes synchronization. Clear/cancel generation checks prevent a finishing request from restoring a cleared queue. Persistence failure no longer reports an expense as successfully queued.
- **Temporary network failure erased the login.** Session restoration now clears credentials only on HTTP 401. Other failures display a retry screen while preserving the token.
- **Dependency security.** Production audit found one high and three moderate advisories in Nodemailer 9.0.6. Updated to pinned 9.1.1 and refreshed the lockfile; the subsequent production dependency scan reports zero known advisories. This does not establish exploitability of each old advisory in Paktly or guarantee absence of undisclosed issues. See the [maintainer's 9.1.1 release](https://github.com/nodemailer/nodemailer/releases/tag/v9.1.1) and [advisory](https://github.com/advisories/GHSA-8m3c-c648-2xjj).
- **Integration coverage.** CI now runs the federated/session integration suite in addition to the MVP suite. Database-backed test files run serially because the MVP fixture truncates the shared disposable database. An initial parallel test invocation caused one reviewer-session failure; a clean serialized run passed.
- **Release metadata/documentation.** Default build number is 3, following reviewed build 2. Check that 3 has not already been uploaded. Updated obsolete permission-flow instructions and deletion diagnostics.

## Remaining findings, ordered by severity

These are audit findings, not silently resolved by the App Store changes. Do not reinterpret existing money records without an explicit migration and reconciliation plan.

### P1 — Currency precision is inconsistent with advertised currency support

`ExpenseEditorView.swift:103`, `MoneyFormatter.swift:9`, `AskPaktlyView.swift:414`, `BalancesOverviewView.swift:55`, and `services/api/src/modules/savings/routes.ts:84` assume 100 minor units per currency. The currency catalog/API admit currencies with other exponents. Manual entry of KWD 1.234 truncates to 123 stored units; true KWD minor units would be 1234. JPY entries are multiplied by 100 despite JPY having no fractional minor units. AI amounts are described to the model as integer minor units, making manual/AI results potentially inconsistent. The receipt parser also primarily expects two fractional digits.

Required: one explicit currency-unit contract across input, OCR review, AI, formatting, savings, settlement and exchange-rate conversion. Inventory any existing non-two-decimal records before migration. Add KWD/BHD (3), JPY (0), USD (2), cross-exponent conversion and locale-specific decimal tests. Alternatively restrict new currencies to the supported precision while designing a migration; do not simply change display divisors over existing data.

### P1 — Concurrent expense edit/delete can corrupt balances

`services/api/src/modules/expenses/routes.ts:88` reads the expense version outside the deletion transaction. An edit can commit between that read and reversal creation, so deletion reverses an obsolete version. The edit update at approximately line 203 checks `current_version` but not active status, allowing a stale edit to run after deletion. Double-entry totals can still sum to zero while the resulting member balances are wrong.

Required: acquire the expense row lock within both mutation transactions, recheck status/version, and reverse the locked current version. Test simultaneous edit/delete and duplicate deletion against PostgreSQL. Review existing deleted expenses for unreversed current versions if concurrent use has occurred. This finding is based on transaction ordering in source; the App Store deletion tests cover account deletion, not this expense-mutation race.

### P2 — Money arithmetic can exceed exact JavaScript integer precision

`split-engine.ts:59` multiplies the total by a weight using Number, and `expenses/routes.ts:185` multiplies amounts by exchange-rate numerators before division. Accepting safe integer inputs does not make the product safe. Use checked BigInt/rational arithmetic or validated tighter limits and test values near accepted bounds.

### P2 — Dashboard and balance-error states can misrepresent debt

`AppModel.swift` derives the home totals from only the first plan. `BalancesOverviewView.swift:141` drops failed requests with `try?`, and an empty result displays All settled. A user with debt in another plan, or a failed balance fetch, can see a misleading summary. Aggregate separately by currency, clearly label the scope, and distinguish loading/error/empty/zero states. Do not add unrelated currencies together.

### P2 — Ordinary sign-out does not revoke the API session

`AppSession.swift:135` deletes the local token but does not invalidate its server-side row. Account deletion does invalidate all sessions and is tested. Add a current-session revocation endpoint for ordinary online sign-out; define expected behavior when offline, and test that a previously copied bearer token is rejected after online logout.

### P2 — Waitlist abuse controls depend on deployment assumptions

`apps/web/app/api/waitlist/route.ts:9` uses a process-local Map with no eviction of distinct expired keys and trusts the first forwarded IP. Limits reset across instances/restarts and may be bypassed if the hosting proxy does not sanitize that header. Use a bounded/shared limiter and the hosting provider's verified client-IP mechanism. Confirm the deployed website database migration and proxy behavior; they were not accessible in this audit.

### Release operations still need evidence

- No production logs/configuration were supplied during this audit. Presence of Apple key environment variables alone does not prove the key supports Sign in with Apple or is associated with this App ID.
- Local PostgreSQL was version 16; production configuration specifies version 18. Run CI's PostgreSQL 18 integration job before deployment.
- Local simulator runtimes are iOS/iPadOS 26.5. Apple reviewed iOS/iPadOS 27.0, including iPad Air M3. Subsequent physical iPhone testing verified development signing and microphone permission flows on iOS 18.7.8; Apple/Google authentication, APNs, microphone recording hardware, and actual Apple revocation still need testing. See the [connected-device report](DEVICE_TEST_2026-09-16.md).
- The app continues to target iPhone only. It can still run in iPhone compatibility mode on iPad; that does not exempt it from iPad review.
- Existing release documentation still lists public operator contact/launch-country and retention decisions. Confirm those with the owner; this audit does not make legal determinations or alter App Store privacy answers.
- API readiness currently checks database connectivity, not Apple revocation, SMTP delivery, migration completeness, or provider health. Run functional staging smoke tests in addition to `/ready`.

## Validation

Subsequent connected iPhone 12 Pro testing installed version 1.0 (3), preserving iPhone-only targeting: 16 tests passed and 1 signed-out test was skipped. The device run also uncovered and fixed hard-coded bundle-version metadata and test-bundle signing configuration. Scope and remaining live-service checks are recorded in the [device report](DEVICE_TEST_2026-09-16.md).

- Node 22 and repository-pinned pnpm 11.20.0, installed in an isolated temporary tool directory.
- Final workspace validation passed after the dependency update: lint, TypeScript checking, 25 web tests, 99 API unit tests with the configured coverage gate, and production web/API builds.
- Final fresh PostgreSQL run with migrations 001–016: all 115 API tests passed (99 unit + 16 integration), including real SQL account cleanup, financial-history preservation, Apple rollback/retry/session invalidation, Apple onboarding/restoration, reviewer authentication, public-error handling and MVP flows.
- Xcode 26.6: iPhone 17 Pro Max, iOS 26.5 — 9 tests passed; iPad Air 11-inch M4, iPadOS 26.5 — 9 tests passed. Native builds succeeded with signing disabled, including the final Release configuration for physical iOS devices. These are unit tests hosted by the app, not end-to-end UI or real Apple authentication tests.
- Deployment/archive shell syntax checks, production Docker Compose configuration (base and Caddy variant), and plist/privacy-manifest/entitlement syntax checks passed. No Docker images were built or deployed.
- No production data was changed, no messages were sent to Apple, and no build was uploaded.

Local diagnostic files from this run are in `/private/tmp/paktly-audit-*` (temporary, not durable release evidence). Keep CI output and device test records with the release before resubmission.

## Resubmission sequence

1. Resolve the remaining financial correctness findings or explicitly narrow supported behavior, with data migration decisions where necessary.
2. Review changes and run CI on PostgreSQL 18; deploy the API and verify migration/key configuration. Deploy the iOS client only after the API profile flag is available.
3. On disposable accounts, test Apple first/repeat sign-in, Hide My Email, app relaunch and account deletion through the production API. Capture the support request ID and sanitized server failure stage if deletion fails.
4. Test a clean installation and an update from build 2 on supported iPhone and iPad configurations, including iOS/iPadOS 27. Test microphone denial, AI refusal and Settings return.
5. Archive an unused build number (repository default 3), validate the signed archive and privacy report, upload, and select the replacement build in App Store Connect.
6. Use the draft below only after those checks pass.

## App Store Connect reply draft — send after verification

Hello App Review,

Thank you for the feedback. In version 1.0, build [verified replacement build]:

- Sign in with Apple uses the supplied account information and no longer requires users to enter their name or email afterward. Returning users can also enter the app when Apple does not return a name again.
- Speak to Paktly requests microphone permission directly through the system prompt. AI data-sharing consent is separate and appears after microphone access is granted; no audio is recorded or shared before AI consent.
- We have verified account deletion using [tested sign-in methods] on [devices and OS versions]. Apple-linked deletion revokes Apple authorization and removes the Paktly account data; completion returns the user to sign-in after acknowledgement.

The deletion option is under You → Privacy & support → Delete account. We tested both a clean installation and an update from the previously reviewed build.

Thank you.

Do not send the deletion/device-testing statements until they are true. Keep reviewer access live for the review period and provide credentials only through App Store Connect's private review fields.
