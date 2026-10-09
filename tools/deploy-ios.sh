#!/bin/sh
# Builds (unless --no-build) and installs the controller app on a connected iPhone, then launches it.
# Usage: tools/deploy-ios.sh [--no-build] [-d <device-id>]
#   Needs Xcode (xcode-select -s /Applications/Xcode.app), the Godot iOS export templates, Developer Mode on the phone,
#   and an Apple ID signed in under Xcode > Settings > Accounts.
#   IOS_TEAM_ID  your 10-character Apple Team ID (Xcode > Signing & Capabilities). Required for a build. It is not an e-mail address.
#   IOS_BUNDLE_ID  optional. Change it when com.example.remoteplay.controller is taken (free accounts need a unique one).
#   Device: -d <id> or IOS_DEVICE. With one iPhone attached it is picked automatically (`xcrun devicectl list devices`).
set -eu
cd "$(dirname "$0")/.."

BUILD=1
DEVICE="${IOS_DEVICE:-}"
while [ $# -gt 0 ]; do
	case "$1" in
		--no-build) BUILD=0 ;;
		-d) shift; DEVICE="${1:?-d needs a device id}" ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
	shift
done

xcodebuild -version >/dev/null 2>&1 || { echo "Xcode is not active. Install Xcode, then: sudo xcode-select -s /Applications/Xcode.app" >&2; exit 1; }
BUNDLE_ID="${IOS_BUNDLE_ID:-com.example.remoteplay.controller}"
PROJECT=build/ios/remote-play-controller.xcodeproj
DERIVED=build/ios/derived

if [ -z "$DEVICE" ]; then
	DEVICES="$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /connected|available/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9A-F-]{25,}$/) print $i}')"
	COUNT="$(printf '%s\n' "$DEVICES" | grep -c . || true)"
	if [ "$COUNT" -eq 0 ]; then
		echo "No iPhone connected. Connect it by cable, unlock it, trust this Mac, and turn on Developer Mode." >&2; exit 1
	elif [ "$COUNT" -gt 1 ]; then
		echo "Several iPhones connected. Pick one with -d <id>:" >&2; echo "$DEVICES" >&2; exit 1
	fi
	DEVICE="$DEVICES"
fi
echo "Device: $DEVICE"

if [ "$BUILD" -eq 1 ]; then
	[ -n "${IOS_TEAM_ID:-}" ] || { echo "Set IOS_TEAM_ID to your Apple Team ID (10 characters, in Xcode > Signing & Capabilities)." >&2; exit 1; }
	GODOT="${GODOT:-}"
	[ -z "$GODOT" ] && [ -x /Applications/Godot.app/Contents/MacOS/Godot ] && GODOT=/Applications/Godot.app/Contents/MacOS/Godot
	[ -z "$GODOT" ] && GODOT="$(command -v godot)"
	mkdir -p build/ios
	# The Team ID in the preset is a placeholder (Godot needs a value). The preset only exports the Xcode project;
	# xcodebuild below signs it. It builds for this device, so Xcode can register the phone in the team.
	"$GODOT" --headless --path . --export-debug controller-ios "$PROJECT"
	# The controller is a portrait app. Godot writes landscape into Info.plist from the project setting, which the
	# Android TV app needs, so patch only this export. Without it iOS blocks the portrait request in scripts/app.gd.
	PLIST="$(find build/ios/remote-play-controller -maxdepth 1 -name '*-Info.plist' | head -n 1)"
	[ -n "$PLIST" ] || { echo "Info.plist not found in the export." >&2; exit 1; }
	for KEY in UISupportedInterfaceOrientations UISupportedInterfaceOrientations~ipad; do
		/usr/libexec/PlistBuddy -c "Delete :$KEY" "$PLIST" 2>/dev/null || true
		/usr/libexec/PlistBuddy -c "Add :$KEY array" -c "Add :$KEY:0 string UIInterfaceOrientationPortrait" "$PLIST"
	done
	xcodebuild -project "$PROJECT" -scheme remote-play-controller -configuration Debug \
		-destination "id=$DEVICE" -derivedDataPath "$DERIVED" -allowProvisioningUpdates \
		DEVELOPMENT_TEAM="$IOS_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CODE_SIGN_STYLE=Automatic build
fi

APP="$(find "$DERIVED/Build/Products/Debug-iphoneos" -maxdepth 1 -name '*.app' 2>/dev/null | head -n 1)"
[ -n "$APP" ] || { echo "No .app in $DERIVED. Run without --no-build." >&2; exit 1; }

xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID"
echo "Installed and launched $BUNDLE_ID."
