#!/bin/sh
# Builds (unless --no-build) and installs an app on a connected Android device, then launches it.
# Usage: tools/deploy.sh <tv|controller> [--no-build] [-s <adb-serial>]
#   Device: -s <serial> or ANDROID_SERIAL. With one device attached it is picked automatically.
#   For a TV over Wi-Fi: adb connect <tv-ip>:5555, then -s <tv-ip>:5555.
set -eu
cd "$(dirname "$0")/.."

ROLE="${1:-}"
case "$ROLE" in tv|controller) shift ;; *) echo "Usage: $0 <tv|controller> [--no-build] [-s <serial>]" >&2; exit 1 ;; esac

BUILD=1
SERIAL="${ANDROID_SERIAL:-}"
while [ $# -gt 0 ]; do
	case "$1" in
		--no-build) BUILD=0 ;;
		-s) shift; SERIAL="${1:?-s needs a serial}" ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
	shift
done

ADB="${ADB:-$(command -v adb || echo "$HOME/Library/Android/sdk/platform-tools/adb")}"
[ -x "$ADB" ] || { echo "adb not found. Install the Android SDK platform-tools or set ADB=." >&2; exit 1; }

if [ -z "$SERIAL" ]; then
	DEVICES="$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')"
	COUNT="$(printf '%s\n' "$DEVICES" | grep -c . || true)"
	if [ "$COUNT" -eq 0 ]; then
		echo "No device connected. Check USB debugging, or run: adb connect <ip>:5555" >&2; exit 1
	elif [ "$COUNT" -gt 1 ]; then
		echo "Several devices connected. Pick one with -s <serial>:" >&2; echo "$DEVICES" >&2; exit 1
	fi
	SERIAL="$DEVICES"
fi
echo "Device: $SERIAL"

if [ "$BUILD" -eq 1 ]; then
	GODOT="${GODOT:-}"
	[ -z "$GODOT" ] && [ -x /Applications/Godot.app/Contents/MacOS/Godot ] && GODOT=/Applications/Godot.app/Contents/MacOS/Godot
	[ -z "$GODOT" ] && GODOT="$(command -v godot)"
	export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
	export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
	mkdir -p build
	"$GODOT" --headless --path . --export-debug "$ROLE" "build/sababi-$ROLE.apk"
fi

APK="build/sababi-$ROLE.apk"
[ -f "$APK" ] || { echo "Missing $APK. Run without --no-build." >&2; exit 1; }
PKG="com.example.sababi.$ROLE"

"$ADB" -s "$SERIAL" install -r "$APK"
"$ADB" -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
	|| "$ADB" -s "$SERIAL" shell monkey -p "$PKG" -c android.intent.category.LEANBACK_LAUNCHER 1 >/dev/null
echo "Installed and launched $PKG."
