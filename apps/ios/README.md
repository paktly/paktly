# Paktly iOS

The native client targets iOS 17 and talks to the persisted `/api/v1` service. Its Plans, Activity, and Balances tabs are functional. Expense creation supports equal, exact, percentage, shares, and simple itemized allocation; failed expense submissions are stored atomically under Application Support and replayed with their original idempotency key.

Device, simulator, Debug, and Release builds use `https://api.paktly.io/api/v1`. Generate the project with `xcodegen generate`, then run the `Paktly` scheme. The checked-in adapter still calls the non-production session route after the local passkey preview; that route is deliberately unavailable on the production API. Authenticated device testing therefore requires the approved SocketFi/identity-provider adapter and backend verifier.

The generated application Info.plist explicitly supplies the production API URL so device and test-host builds cannot silently fall back to localhost.

Native SwiftUI shell targeting iOS 17 and later. Xcode project files are generated from `project.yml` so project settings remain reviewable.

```bash
brew install xcodegen
cd apps/ios
xcodegen generate
open Paktly.xcodeproj
```

Local development uses `PreviewSmartAccountService` only in debug/demo composition. Production account calls require SocketFi's supported interfaces and relying-party configuration.
