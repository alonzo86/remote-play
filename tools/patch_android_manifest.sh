#!/bin/sh
# Adds the Android TV banner and the TV/phone hardware flags to the Gradle project.
# Run once, after "Project > Install Android Build Template" in the Godot editor.
# Safe to run again. Usage: tools/patch_android_manifest.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/android/build"
MANIFEST="$BUILD/AndroidManifest.xml"
BANNER="$ROOT/assets/icons/banner.png"

if [ ! -f "$MANIFEST" ]; then
	echo "Not found: $MANIFEST" >&2
	echo "In the Godot editor, use Project > Install Android Build Template first." >&2
	exit 1
fi

# 1. Banner image (320x180) for the Android TV home screen.
mkdir -p "$BUILD/res/drawable-xhdpi"
cp "$BANNER" "$BUILD/res/drawable-xhdpi/banner.png"

# 2. android:banner on <application>.
if grep -q 'android:banner=' "$MANIFEST"; then
	echo "banner attribute: already set"
else
	sed -i 's|android:icon="@mipmap/icon"|android:icon="@mipmap/icon"\n        android:banner="@drawable/banner"|' "$MANIFEST"
	echo "banner attribute: added"
fi

# 3. Hardware flags. A TV has no touchscreen, no gyroscope, and uses the leanback UI.
if grep -q 'android.software.leanback' "$MANIFEST"; then
	echo "uses-feature flags: already set"
else
	sed -i '/<application/i\
    <uses-feature android:name="android.software.leanback" android:required="false" />\
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />\
    <uses-feature android:name="android.hardware.sensor.gyroscope" android:required="false" />\
    <uses-feature android:name="android.hardware.sensor.accelerometer" android:required="false" />\
' "$MANIFEST"
	echo "uses-feature flags: added"
fi

grep -n 'banner\|uses-feature' "$MANIFEST"
