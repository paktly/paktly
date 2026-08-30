# Paktly iOS

The native client targets iOS 17 and talks to the persisted `/api/v1` service. Its Plans, Activity, and Balances tabs are functional. Expense creation supports equal, exact, percentage, shares, and simple itemized allocation; failed expense submissions are stored atomically under Application Support and replayed with their original idempotency key.

For simulator development, run the API on `http://localhost:4000`, generate the project with `xcodegen generate`, then run the `Paktly` scheme. The checked-in adapter uses the API's non-production session route after the local passkey preview. Production builds must replace that adapter with approved SocketFi/identity provider credentials.

`PAKTLY_API_BASE_URL` is supplied only for Debug. A Release archive intentionally fails fast unless CI or the production xcconfig supplies an HTTPS API URL; localhost cannot silently ship in a production build.

Native SwiftUI shell targeting iOS 17 and later. Xcode project files are generated from `project.yml` so project settings remain reviewable.

```bash
brew install xcodegen
cd apps/ios
xcodegen generate
open Paktly.xcodeproj
```

Local development uses `PreviewSmartAccountService` only in debug/demo composition. Production account calls require SocketFi's supported interfaces and relying-party configuration.
