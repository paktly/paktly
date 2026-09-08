# Paktly Smart interest

The You tab now presents a coming-soon card instead of offering wallet activation.
“I’m interested” saves an account-level preference. Users can remove their interest.
This is not a marketing subscription, a wallet deployment, or a promise of a launch
notification. No push permission is requested and notification preferences are unchanged.

Deploy the API and migration `014_smart_interest.sql` before releasing the iOS update.
Authenticated `GET /api/v1/me/smart-interest` returns `{ interested: boolean }`.
Authenticated `PUT` to the same path accepts that shape, rejects extra fields, and
upserts only the authenticated user's row. Repeated writes do not create duplicates.
Rows are removed when their user is deleted. API failures offer retry in the card.

The card uses the existing Paktly brand mark. After a confirmed opt-in it collapses
to a tappable status row. Returning users also see the compact row, based on their
server-saved interest. Expanding reveals features and the removal action; removing
interest restores the full card. Failed saves preserve the current presentation.
Expansion respects Reduce Motion and exposes its state to VoiceOver.

The prior ProfileView is preserved verbatim in
`archive/paktly-smart/ProfileView.before-coming-soon.swift.txt`, outside the iOS build.
The original activation view, AppSession activation method, SocketFi adapter, and
backend linking routes are retained. There is no activation entry point in the
You tab; existing linked smart-account addresses remain accessible.

Before restoring activation, review financial availability and re-test the full
passkey/account-linking flow. This change only hides the consumer entry point;
it does not disable the existing backend wallet-linking API.
