#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$ROOT_DIR/mdreader/Info.plist"
PRIVACY_PLIST="$ROOT_DIR/mdreader/PrivacyInfo.xcprivacy"
PROJECT_FILE="$ROOT_DIR/mdreader.xcodeproj/project.pbxproj"
APP_ICON="$ROOT_DIR/mdreader/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "Missing file: $1"
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

require_file "$INFO_PLIST"
require_file "$PRIVACY_PLIST"
require_file "$PROJECT_FILE"
require_file "$APP_ICON"

plutil -lint "$INFO_PLIST" "$PRIVACY_PLIST" "$PROJECT_FILE" >/dev/null

[[ "$(plist_value "$INFO_PLIST" CFBundleDisplayName)" == "MD阅读器" ]] || fail "CFBundleDisplayName must be MD阅读器"
[[ "$(plist_value "$INFO_PLIST" CFBundleName)" == "MD阅读器" ]] || fail "CFBundleName must be MD阅读器"
[[ "$(plist_value "$INFO_PLIST" LSApplicationCategoryType)" == "public.app-category.productivity" ]] || fail "App category must be Productivity"
[[ "$(plist_value "$INFO_PLIST" LSSupportsOpeningDocumentsInPlace)" == "true" ]] || fail "Documents must open in place"
[[ "$(plist_value "$INFO_PLIST" UIRequiresFullScreen)" == "true" ]] || fail "UIRequiresFullScreen should remain true for current layout"

for type_index in 0 1 2; do
  rank="$(/usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:$type_index:LSHandlerRank" "$INFO_PLIST" 2>/dev/null)"
  [[ "$rank" == "Alternate" ]] || fail "CFBundleDocumentTypes[$type_index] LSHandlerRank must be Alternate"
done

grep -q "PRODUCT_BUNDLE_IDENTIFIER = com.tommy.mdreader;" "$PROJECT_FILE" || fail "Main bundle identifier must be com.tommy.mdreader"
grep -q "PRODUCT_BUNDLE_IDENTIFIER = com.tommy.mdreader.tests;" "$PROJECT_FILE" || fail "Test bundle identifier must be com.tommy.mdreader.tests"
grep -q "MARKETING_VERSION = 1.0;" "$PROJECT_FILE" || fail "Marketing version must be 1.0"
grep -q "CURRENT_PROJECT_VERSION = 1;" "$PROJECT_FILE" || fail "Build number must be 1"
grep -q "IPHONEOS_DEPLOYMENT_TARGET = 17.0;" "$PROJECT_FILE" || fail "Minimum iOS target must be 17.0"
grep -q "TARGETED_DEVICE_FAMILY = \"1,2\";" "$PROJECT_FILE" || fail "Targeted device family must include iPhone and iPad"
grep -q "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" "$PROJECT_FILE" || fail "AppIcon asset catalog must be configured"

[[ "$(plist_value "$PRIVACY_PLIST" NSPrivacyTracking)" == "false" ]] || fail "Privacy manifest must declare no tracking"
[[ "$(plist_value "$PRIVACY_PLIST" NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType)" == "NSPrivacyAccessedAPICategoryUserDefaults" ]] || fail "Privacy manifest must declare UserDefaults accessed API"
[[ "$(plist_value "$PRIVACY_PLIST" NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0)" == "CA92.1" ]] || fail "UserDefaults reason must be CA92.1"

icon_width="$(sips -g pixelWidth "$APP_ICON" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
icon_height="$(sips -g pixelHeight "$APP_ICON" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
icon_alpha="$(sips -g hasAlpha "$APP_ICON" 2>/dev/null | awk '/hasAlpha/ { print $2 }')"
[[ "$icon_width" == "1024" ]] || fail "App icon width must be 1024"
[[ "$icon_height" == "1024" ]] || fail "App icon height must be 1024"
[[ "$icon_alpha" == "no" ]] || fail "App icon must not contain alpha"

echo "App Store static readiness checks passed."
