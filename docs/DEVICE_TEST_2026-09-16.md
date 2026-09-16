# Connected iPhone verification — September 16, 2026

## Installation

- Physical device: iPhone 12 Pro, iOS 18.7.8.
- Installed application: `io.paktly.app`, version 1.0, build 3. Verified using CoreDevice's installed-app metadata.
- Development-signed Debug build, connected to `https://api.paktly.io/api/v1`.
- Updated the existing installation and retained the existing authenticated account. No uninstall or account deletion was performed.
- iPhone restriction preserved: compiled `UIDeviceFamily` contains only `1`.

Device preparation exposed two configuration problems that simulator builds had not caught: the test bundles lacked signing team/generated Info.plist settings, and the generated application Info.plist hard-coded build 1. `project.yml` now supplies test signing metadata and binds the application version/build to `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`.

## Results

Across the three physical-device runs: **16 tests passed, 1 skipped, 0 failures** (9 native unit tests and 7 UI tests passed).

The existing account was Apple-linked. Its session restored after upgrade and repeated app relaunch. This is not a fresh Apple authorization test.

| Check | Result |
| --- | --- |
| Native unit suite | 9 passed: email suggestions, USD formatting, offline queue persistence/account isolation/concurrent enqueue, receipt-total parsing |
| App launch and repeated relaunch | Passed; authenticated screen restored |
| Home, Plans, Activity, You tabs | Passed; screens opened and screenshots captured |
| Create-plan screen | Passed; opened and canceled without saving |
| Account-deletion options | Passed; live options loaded, confirmation remained off, canceled successfully. Final Apple authorization/revocation/deletion was not attempted |
| Voice entry with existing microphone grant | Passed; showed separate AI data-sharing disclosure with Continue/Don’t use AI; closed without recording |
| Empty expense validation | Passed; Save stayed disabled without required fields/amount; canceled without saving |
| Receipt entry | Passed; scanner entry and on-device-processing disclosure displayed; canceled without accessing camera/photos |
| Signed-out email validation | Skipped because the phone was already signed in; existing session was preserved |
| Fresh microphone denial/approval | Passed; system prompt appeared before AI consent. Denial showed Settings/Close; approval showed AI disclosure. AI sharing was declined without recording |

Automated UI tests are in `apps/ios/PaktlyUITests/DeviceSmokeTests.swift`. They avoid saving plans/expenses, sending invitations, signing out, recording audio, and deleting accounts. The explicit fresh-permission test resets Paktly's microphone permission and finishes with access granted; it declines AI sharing.

## Not yet verified end to end

- First/returning Apple and Google authorization, Hide My Email, and email OTP delivery/sign-in. A disposable account and user interaction with provider authentication are needed.
- Final account deletion, Apple revocation, re-signup and cross-device session rejection against the updated deployed API. Backend changes from the audit have not been deployed in this session.
- Saved plan/expense mutations, all split methods, settlements, invitations, membership/role changes and persistence across accounts. A disposable account/group is needed to avoid altering existing shared financial records or contacting real people.
- Live voice transcription/AI execution, camera/selected-photo OCR, APNs delivery, Settings-return flow, offline/cellular transitions, calls/Bluetooth interruptions, and device accessibility/rotation coverage. Screen entry and parser unit tests do not verify these hardware/service flows.
- iOS 27 behavior. This connected device runs iOS 18.7.8.
- The unresolved currency-precision and concurrent expense-mutation findings in `APP_STORE_AUDIT_2026-09-16.md` remain open.

## Local evidence

These local result bundles contain device screenshots and logs, potentially including existing account information. They were not committed or published:

- `/private/tmp/paktly-device-tests.xcresult` — native suite plus initial UI smoke tests.
- `/private/tmp/paktly-device-editor-tests.xcresult` — expense/receipt cancellation checks.
- `/private/tmp/paktly-device-permission-tests.xcresult` — fresh microphone permission checks.
- `/private/tmp/paktly-device-evidence` — screenshots exported from the initial UI run.

No production account data was intentionally created, edited or deleted, no invitations were sent, and no backend deployment or App Store upload was performed. Normal authenticated reads/session restoration and app device-registration behavior still use the configured live service.
