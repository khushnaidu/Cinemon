#!/usr/bin/env bash
# Build a TestFlight-ready IPA.
#
# Remember to bump `version:` in pubspec.yaml first — App Store Connect
# permanently rejects a build number it has already seen.
#
# Usage:  ./scripts_build_ipa.sh [dart_defines.json]
#
# Why the export is done by hand:
#   Xcode's exportArchive shells out to rsync, and MacPorts' rsync 3.2.7 in
#   /opt/local/bin shadows Apple's openrsync. The newer rsync is incompatible
#   and fails with the useless message "error: exportArchive Copy failed"; the
#   real error ("rsync error: syntax or usage error (code 1)") only appears in
#   the .xcdistributionlogs bundle. Forcing /usr/bin first fixes it.
#
#   `flutter build ipa` also exits 0 even when its export step fails, so its
#   status cannot be trusted — this script verifies the IPA is actually newer
#   than the archive instead.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/development/flutter/bin:$PATH"

DEFINES="${1:-dart_defines.json}"
if [ ! -f "$DEFINES" ]; then
  echo "Missing $DEFINES — copy dart_defines.example.json and fill it in." >&2
  exit 1
fi

ARCHIVE="build/ios/archive/Runner.xcarchive"
OUT="build/ios/ipa"

# Archive. Its own export attempt is expected to fail on the rsync issue;
# we only need the .xcarchive it produces, so don't let it abort the script.
flutter build ipa --release \
  --dart-define-from-file="$DEFINES" \
  --export-options-plist=ios/ExportOptions.plist || true

[ -d "$ARCHIVE" ] || { echo "Archive was not produced — build failed." >&2; exit 1; }

# Export for real, with Apple's rsync ahead of MacPorts'.
rm -rf "$OUT"
env PATH="/usr/bin:/bin:/usr/sbin:/sbin" xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath "$OUT" \
  -allowProvisioningUpdates

IPA=$(ls "$OUT"/*.ipa 2>/dev/null | head -1) || true
[ -n "${IPA:-}" ] || { echo "Export reported success but produced no IPA." >&2; exit 1; }
[ "$IPA" -nt "$ARCHIVE" ] || { echo "IPA is older than the archive — stale artifact." >&2; exit 1; }

echo ""
echo "IPA:     $IPA"
echo "Version: $(unzip -p "$IPA" 'Payload/Runner.app/Info.plist' | plutil -extract CFBundleShortVersionString raw -) ($(unzip -p "$IPA" 'Payload/Runner.app/Info.plist' | plutil -extract CFBundleVersion raw -))"
echo "Name:    $(unzip -p "$IPA" 'Payload/Runner.app/Info.plist' | plutil -extract CFBundleDisplayName raw -)"
