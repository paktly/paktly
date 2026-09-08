#!/usr/bin/env bash
# Build a signed archive only. This script never uploads or publishes an app.
set -Eeuo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo "Run this on your Mac with Xcode installed." >&2; exit 1; }
version="${1:-}"
build="${2:-}"
[[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ && "$build" =~ ^[1-9][0-9]*$ ]] || {
  echo "Usage: bash scripts/archive-ios.sh VERSION BUILD (example: 1.0 12). Choose an unused build number." >&2; exit 1;
}
command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen" >&2; exit 1; }
xcode_major="$(xcodebuild -version | awk '/^Xcode / {split($2,v,"."); print v[1]}')"
sdk_major="$(xcrun --sdk iphoneos --show-sdk-version | cut -d. -f1)"
[[ "$xcode_major" -ge 26 && "$sdk_major" -ge 26 ]] || {
  echo "App Store uploads require Xcode 26+ and the iOS 26+ SDK. Select the correct Xcode in Settings > Locations." >&2; exit 1;
}
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root/apps/ios"
archive_path="$PWD/build/Paktly-$version-$build.xcarchive"
[[ ! -e "$archive_path" ]] || { echo "Archive already exists: $archive_path. Choose another build number." >&2; exit 1; }
xcodegen generate
plutil -lint Paktly/PrivacyInfo.xcprivacy Paktly/Paktly.entitlements
xcodebuild -project Paktly.xcodeproj -scheme Paktly -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive_path" \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" archive
echo "Archive created: $archive_path"
echo "Open this archive in Xcode Organizer, validate, then Distribute App > App Store Connect. This has NOT uploaded or published it."
