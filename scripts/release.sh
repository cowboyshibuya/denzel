#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# Cuts a Denzel release: version bump -> archive -> Developer ID codesign ->
# local verify -> package. Stops there unless --publish is passed, in which
# case it also notarizes, staples, and creates a public GitHub Release.
#
# Usage: scripts/release.sh <version, e.g. 0.2.0> [--publish]
#
# --publish requires AC_API_KEY_PATH (path to the App Store Connect .p8 key
# — its location isn't discoverable from the keychain, so this script won't
# guess it) and uses this Mac's keychain for the Developer ID identity and
# the app.denzel.desktop.apple-api-{issuer,key-id} items. Nothing here reads
# those secret values into the script itself — they're passed by reference
# to codesign/notarytool, which read the keychain directly.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version, e.g. 0.2.0> [--publish]}"
PUBLISH=false
[[ "${2:-}" == "--publish" ]] && PUBLISH=true

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
BUILD_DIR="build"

echo "==> Preflight"
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree not clean. Commit or stash first." >&2
  exit 1
fi
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || { echo "No Developer ID Application identity in keychain." >&2; exit 1; }

echo "==> Bumping version to $VERSION"
sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$VERSION\"/" App/project.yml
BUILD_NUMBER=$(git rev-list --count HEAD)
sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$BUILD_NUMBER\"/" App/project.yml

if [ -n "$(git status --porcelain App/project.yml)" ]; then
  git add App/project.yml
  git commit -m "Release v$VERSION"
fi
git tag "v$VERSION" 2>/dev/null || echo "tag v$VERSION already exists, leaving it as-is"

echo "==> Regenerating Xcode project"
(cd App && xcodegen generate)

echo "==> Archiving (Release config — Developer ID signing happens here, via xcodebuild, not a manual codesign chain)"
rm -rf "$BUILD_DIR"
xcodebuild -project App/Denzel.xcodeproj -scheme Denzel -configuration Release \
  archive -archivePath "$BUILD_DIR/Denzel.xcarchive"

echo "==> Exporting"
xcodebuild -exportArchive -archivePath "$BUILD_DIR/Denzel.xcarchive" \
  -exportPath "$BUILD_DIR/export" -exportOptionsPlist scripts/ExportOptions.plist

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$BUILD_DIR/export/Denzel.app"

echo "==> Packaging zip (this is also Sparkle's update payload format)"
ditto -c -k --keepParent "$BUILD_DIR/export/Denzel.app" "$BUILD_DIR/Denzel-$VERSION.zip"
echo "Built $BUILD_DIR/Denzel-$VERSION.zip"

echo "==> Packaging DMG (drag-to-Applications installer)"
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$BUILD_DIR/export/Denzel.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
rm -f "$BUILD_DIR/Denzel-$VERSION.dmg"
hdiutil create -volname "Denzel" -srcfolder "$DMG_STAGING" -ov -format UDZO "$BUILD_DIR/Denzel-$VERSION.dmg" >/dev/null
rm -rf "$DMG_STAGING"
echo "Built $BUILD_DIR/Denzel-$VERSION.dmg"
# Note: a DMG distributed publicly needs its own notarize+staple pass,
# separate from the .app inside it — not done here since --publish only
# notarizes the zip. Add it if the DMG becomes the public download format;
# today it's a local convenience artifact.

if [ "$PUBLISH" = false ]; then
  echo "==> Stopping here. Re-run with --publish to notarize and create a public GitHub Release."
  exit 0
fi

echo "==> Notarizing"
: "${AC_API_KEY_PATH:?set AC_API_KEY_PATH to the .p8 file path}"
KEY_ID=$(security find-generic-password -w -s app.denzel.desktop.apple-api-key-id -a cowboy)
ISSUER=$(security find-generic-password -w -s app.denzel.desktop.apple-api-issuer -a cowboy)
SUBMIT_ZIP="$BUILD_DIR/Denzel-submit.zip"
ditto -c -k --keepParent "$BUILD_DIR/export/Denzel.app" "$SUBMIT_ZIP"
if ! xcrun notarytool submit "$SUBMIT_ZIP" --key "$AC_API_KEY_PATH" --key-id "$KEY_ID" --issuer "$ISSUER" --wait; then
  echo "Notarization failed; see log above." >&2
  exit 1
fi

echo "==> Stapling"
xcrun stapler staple "$BUILD_DIR/export/Denzel.app"

echo "==> Re-packaging stapled build"
rm -f "$BUILD_DIR/Denzel-$VERSION.zip"
ditto -c -k --keepParent "$BUILD_DIR/export/Denzel.app" "$BUILD_DIR/Denzel-$VERSION.zip"

echo "==> Publishing"
git push && git push --tags
gh release create "v$VERSION" "$BUILD_DIR/Denzel-$VERSION.zip" --title "v$VERSION" --generate-notes

echo "==> Sparkle update signing + appcast (manual step)"
echo "    Confirm sign_update/generate_appcast flags against your installed Sparkle version's --help,"
echo "    then: sign_update \"$BUILD_DIR/Denzel-$VERSION.zip\""
echo "          generate_appcast <releases-folder>/"
echo "    and publish the resulting appcast.xml to the host set in INFOPLIST_KEY_SUFeedURL."
