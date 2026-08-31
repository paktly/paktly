# Expense-sharing API

All endpoints are under `/api/v1`. Authenticated calls use `Authorization: Bearer <token>`. Email OTP creates an ordinary Paktly account without creating a wallet. The non-production `POST /auth/dev-session` endpoint supplies a complete local testing session.

Authentication routes:

- `POST /auth/email/request` sends a six-digit, ten-minute email code.
- `POST /auth/email/verify` consumes the code and issues a Paktly session.
- `POST /auth/socketfi` signs in an existing SocketFi-linked user with a passkey.
- `POST /me/smart-wallet/socketfi` links a newly activated SocketFi wallet to the authenticated Paktly account.

`POST /auth/socketfi` accepts a SocketFi access token from the native passkey flow and returns a Paktly access token. The backend verifies the SocketFi RS256 signature and its issuer, audience, client ID, native origin, network, subject, and expiration. SocketFi identities are stored separately from Paktly sessions; wallet addresses are network-specific. Never send `SOCKETFI_CLIENT_SECRET` to the iOS app.

Paktly profile identity is independent from SocketFi's internal username. `GET /me` returns the user's Paktly display name, optional Paktly username, and the active network's linked SocketFi smart-account address. `PATCH /me` owns Paktly username changes and accepts lowercase letters, numbers, and underscores only.

Core routes:

- `GET/PATCH /me`
- `POST /auth/email/request`
- `POST /auth/email/verify`
- `POST /auth/socketfi`
- `POST /me/smart-wallet/socketfi`
- `GET/POST /groups`
- `GET /groups/:groupId`
- `POST /groups/:groupId/invitations`
- `POST /invitations/accept`
- `GET/POST /groups/:groupId/expenses`
- `GET/PATCH/DELETE /expenses/:expenseId`
- `GET /groups/:groupId/balances`
- `POST /groups/:groupId/settlements`
- `GET /groups/:groupId/activity`
- `GET /notifications`
- `POST /notifications/:notificationId/read`

Expense mutations accept UUID `clientOperationId` values. Retrying a create with the same ID returns the original expense. Updates require `expectedVersion` and fail with `409` after a concurrent edit. Amounts are integer minor units. Percentage weights are integer basis points totaling `10000`.

For a currency different from the plan currency, the request must include `exchangeRate` with positive integer `numerator` and `denominator`, provider, and timestamp. That snapshot is never recomputed.
