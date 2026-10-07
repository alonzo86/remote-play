#!/bin/sh
# Prepares the generated Gradle project (android/build):
#   - Android TV banner and hardware flags
#   - the QR scanner plugin (android/plugin/QrScannerPlugin.java, Google code scanner)
# Run once, after "Project > Install Android Build Template" in the Godot editor.
# Safe to run again. Usage: tools/patch_android_manifest.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/android/build"
MANIFEST="$BUILD/src/main/AndroidManifest.xml"
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

# 4. QR scanner plugin: source file, Gradle dependency, and manifest entries.
PLUGIN_SRC="$ROOT/android/plugin/QrScannerPlugin.java"
GRADLE="$BUILD/build.gradle"
PLUGIN_DIR="$BUILD/src/main/java/com/example/remoteplay"
mkdir -p "$PLUGIN_DIR"
cp "$PLUGIN_SRC" "$PLUGIN_DIR/QrScannerPlugin.java"
if [ ! -f "$GRADLE" ]; then
	echo "Not found: $GRADLE" >&2
	exit 1
fi
if grep -q 'play-services-code-scanner' "$GRADLE"; then
	echo "QR dependency: already set"
else
	sed -i '0,/^dependencies {/s//dependencies {\n    implementation "com.google.android.gms:play-services-code-scanner:16.1.0"/' "$GRADLE"
	grep -q 'play-services-code-scanner' "$GRADLE" || { echo "Cannot find the dependencies block in $GRADLE" >&2; exit 1; }
	echo "QR dependency: added"
fi
if grep -q 'org.godotengine.plugin.v2.QrScanner' "$MANIFEST"; then
	echo "QR manifest entries: already set"
else
	sed -i 's|^\( *\)</application>|        <meta-data android:name="org.godotengine.plugin.v2.QrScanner" android:value="com.example.remoteplay.QrScannerPlugin" />\n        <meta-data android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="barcode_ui" />\n\1</application>|' "$MANIFEST"
	echo "QR manifest entries: added"
fi

grep -n 'banner\|uses-feature\|QrScanner\|DEPENDENCIES' "$MANIFEST"
grep -n 'code-scanner' "$GRADLE"
