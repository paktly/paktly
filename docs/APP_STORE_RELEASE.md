# Paktly App Store release

This is a handoff checklist, not certification of launch readiness.

## Blocking owner decisions

- Legal operator confirmed by the owner: TINKERPAL LLC. Public contact address and launch countries remain pending. Finalize jurisdiction wording and contact details in `/privacy`, `/terms`, `/contact` with legal review before public submission.
- Verify hello@paktly.io, privacy@paktly.io, legal@paktly.io and security@paktly.io are monitored.
- Approve actual retention for shared financial records, AI drafts, provider processing, access logs and backups. Backup script defaults to 14 days, but deployed settings/offsite copies must be verified. Reapply deletions after any restore; see ACCOUNT_DELETION.md.
- Choose the App Store version and unused build number; repository 0.1.0 / 1 does not reflect previously uploaded builds.
- Complete agreements, availability, age rating, export compliance and EU trader status if applicable. Do not guess legal answers from use of HTTPS alone.

## Implemented preparation

Voice asks explicit OpenAI permission before recording/transcription; Not now cancels and manual forms remain available. Permission is per screen visit. Receipt OCR is on-device Apple Vision, not an OpenAI upload. You includes privacy, terms, support and account deletion. The manifest now covers account/contact/financial/content/audio/device/usage information and the app-local UserDefaults reason. Debug/Release APNs environment and entitlement match. CI includes deletion integration tests. Git ignores Apple private keys and archives.

## Deploy after commit/push

VPS:

```sh
cd ~/paktly
git pull --ff-only
./scripts/deploy-production.sh
curl --fail https://api.paktly.io/api/v1/ready
```

Configure the Apple revocation credentials from ACCOUNT_DELETION.md. Deploy the website with its existing hosting pipeline too; the API script does not deploy web. Verify `/privacy`, `/terms`, `/term`, `/support`, `/account-deletion` over HTTPS.

Mac, from the Paktly repo:

```sh
git pull --ff-only
cd apps/ios
xcodegen generate
open Paktly.xcodeproj
```

Use Xcode 26+ and iOS 26+ SDK for uploads; minimum supported iOS stays 17. Run Product → Test and device checks below. From repository root, create a signed archive using your chosen version and unused build number:

```sh
bash scripts/archive-ios.sh 0.1.0 12
```

The numbers are examples. The script validates tools, overrides version/build for this archive, refuses to overwrite an archive, and never uploads or publishes. Alternatively change project.yml before generating and use Product → Archive. In Organizer: Validate App → Distribute App → App Store Connect. Do not choose TestFlight Internal Only for external/public candidates. Inspect archived production APNs entitlement and privacy report, including GoogleSignIn SDK disclosures.

## Physical-device release gate

Record build/device/OS, expected and actual results. No device tests were run in this Linux workspace.

1. Email OTP/Google/Apple signup and returning login; cancel and offline errors.
2. Plans, existing/new email invitations, accept/decline in app and via links; non-members denied access.
3. All split methods, different payer, edits/deletion, currency conversion, balances, recorded settlements.
4. Voice: Not now must make no AI/microphone request. Allow, microphone denial, Settings return, cancel/background/network loss, confirmation retry without duplicate saves.
5. Receipt: denied camera, canceled picker, unreadable image, correct total/currency, manual corrections, plan context, exactly one saved expense.
6. Delete disposable email/Google and real Apple accounts; cancel/failure, outstanding balances, another member’s unchanged amounts, old sessions rejected, fresh signup with same email, local queued expenses discarded.
7. TestFlight production push, preferences, unread count and deep links.
8. Small iPhone, large text, VoiceOver, reduced motion, dark appearance, keyboard, rotation; iPad if included in supported devices.

## App Privacy worksheet

Review these proposed categories against actual deployed services and the archive. Linked to user, App Functionality, not tracking:

| Category | App use |
| --- | --- |
| Name / Email Address | Profiles, login and invitations |
| User ID / Device ID | Account UUID, provider subject, push installation |
| Contacts | Manually saved friends and invited emails, not full device address book |
| Other Financial Info / Purchase History | Expenses, balances, tracked savings and settlements |
| Other User Content | Plan descriptions, notes and AI action drafts |
| Audio Data | Optional voice sent to OpenAI; verify provider retention against Apple's collection definition |
| Product Interaction | Account-linked AI usage limits and Smart interest |

Receipt images remain on-device. Inspect SDK diagnostics separately; a manifest is not the App Store Connect privacy form. Do not claim zero provider retention or automatically answer No to every data type.

## Listing draft

Name: Paktly

Subtitle: Shared plans. Clear expenses.

Description: Plan together and keep shared expenses clear. Paktly helps friends organize trips, household plans, and shared goals in one place. Create a plan, invite people, add expenses, choose how to split them, and see who owes what. Save friends for your next plan, track savings held elsewhere, and record settlements. Speak to Paktly to prepare an action for review, or scan a receipt on your device and check its details before saving. Optional notifications keep you up to date. Paktly Smart is coming soon; recording savings or settlements does not move money.

Do not advertise cards, custody, yield, live payments or production wallet activation as available. Review existing screenshots against the submitted build; this pass did not fabricate new screenshots.

URLs: https://paktly.io/support, https://paktly.io/privacy, https://paktly.io/terms, https://paktly.io.

Review notes: Explain planning/tracking vs money movement. Provide a tested reviewer login method privately in App Store Connect, never commit credentials. Describe Apple/Google/email OTP access, You → Delete account, + → Speak to Paktly → Allow and continue, AI confirmation, on-device receipt OCR, and Smart coming soon. Keep backend and reviewer access live during review.

TestFlight: external group → add processed build → test/review details → Beta App Review → invite after approval. Public release is separate: select the tested build on an app version, complete listing/screenshots/privacy/age rating/review details, choose manual release for control, and submit App Review. Publish only after approval and the gates above.

Sources checked September 7, 2026: [SDK requirements](https://developer.apple.com/news/upcoming-requirements/?id=02032026a), [Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [App Privacy](https://developer.apple.com/app-store/app-privacy-details/), [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).
