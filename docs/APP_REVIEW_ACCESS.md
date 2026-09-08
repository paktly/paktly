# App Store review access

Paktly supports the dedicated login `app-review@paktly.io` through **Continue with email**.
This is an application login, not a Zoho mailbox. When explicitly enabled, no email is
sent for this address: reviewers enter the fixed six-digit PIN supplied privately in
App Store Connect. All other addresses retain the normal emailed OTP flow.

## Enable on the API

In `/opt/paktly/.env`, keep the existing email/SMTP settings and add:

```dotenv
APP_REVIEW_AUTH_ENABLED=true
APP_REVIEW_PIN=YOUR_SIX_DIGIT_REVIEW_PIN
APP_REVIEW_EXPIRES_AT=2026-10-07T23:59:59Z
```

Replace the PIN placeholder with the agreed review PIN. Choose an expiry covering
the review period; extend it before resubmission if necessary. Do not commit secrets.

```sh
cd ~/paktly
git pull --ff-only
./scripts/deploy-production.sh
```

Deployment applies migration `016_app_review_auth.sql`. On first successful login,
the API creates an ordinary, unprivileged account marked for review. Complete the
profile and optionally create fictional sample plans. Existing normal accounts are
never converted to review accounts; a collision fails closed and needs investigation.
No actual customer data or real money should be shared with this account. Anyone
with the shared PIN can access its data while review access is enabled.

## App Store Connect → App Review Information

- Sign-in required: checked.
- Username: `app-review@paktly.io`.
- Password: the configured six-digit PIN.
- Notes: “Choose Continue with email, enter the reviewer email, then enter the
  supplied six-digit PIN on the code screen. This dedicated review account does
  not require mailbox access. If prompted, complete the short profile setup.”

Verify these instructions on a physical device with the exact submitted build.
Account deletion remains available. Deleting the reviewer account removes its data;
another successful reviewer login can create a fresh account while enabled.

## Disable after review

Set `APP_REVIEW_AUTH_ENABLED=false`, remove the PIN and expiry, and redeploy.
Existing reviewer sessions are rejected while disabled; their expiry is also capped
to the configured window. Re-enabling within that original window can allow existing
sessions again, so revoke them if rotating access after suspected exposure.

Challenges expire within ten minutes, are bound to email and challenge ID, allow
five incorrect attempts, and are single-use. Existing endpoint rate limits apply.
Changing the configured PIN invalidates outstanding review challenges, not existing
sessions. Failed normal OTP attempts now persist even when verification is rejected.

The reviewer account has normal membership-based permissions, not admin powers and
not an isolated copy of the service. Only use fictional demo contacts and plans.
