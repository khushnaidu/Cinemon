#!/usr/bin/env bash
# Build a TestFlight-ready IPA.
#
# Why the PATH override: Xcode's exportArchive shells out to rsync, and
# MacPorts' rsync 3.2.7 at /opt/local/bin shadows Apple's openrsync. The
# newer rsync is incompatible with exportArchive and fails with the useless
# message "error: exportArchive Copy failed". Forcing /usr/bin first fixes it.
#
# Remember to bump `version:` in pubspec.yaml first — App Store Connect
# permanently rejects a build number it has already seen.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/development/flutter/bin:$PATH"

flutter build ipa --release --export-options-plist=ios/ExportOptions.plist \
  || {
    echo ""
    echo "flutter build ipa failed at export; retrying export with Apple rsync..."
    env PATH="/usr/bin:/bin:/usr/sbin:/sbin" xcodebuild -exportArchive \
      -archivePath build/ios/archive/Runner.xcarchive \
      -exportOptionsPlist ios/ExportOptions.plist \
      -exportPath build/ios/ipa \
      -allowProvisioningUpdates
  }

echo ""
echo "IPA: $(ls build/ios/ipa/*.ipa)"
