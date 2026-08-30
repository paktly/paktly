# Expense-sharing API

All endpoints are under `/api/v1`. Authenticated calls use `Authorization: Bearer <token>`. The non-production `POST /auth/dev-session` endpoint supplies a complete local testing session; production identity providers plug into the same session model.

Core routes:

- `GET/PATCH /me`
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
