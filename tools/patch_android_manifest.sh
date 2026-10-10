#!/bin/sh
# Prepares the generated Gradle project (android/build):
#   - Android TV banner and hardware flags
#   - the QR scanner plugin (android/plugin/QrScannerPlugin.java, Google code scanner)
# Run once, after tools/setup.sh (or "Project > Install Android Build Template" in the Godot editor).
# Safe to run again. Works on macOS and Linux. Usage: tools/patch_android_manifest.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/android/build"
MANIFEST="$BUILD/src/main/AndroidManifest.xml"
[ -f "$MANIFEST" ] || MANIFEST="$BUILD/AndroidManifest.xml"   # older templates
GRADLE="$BUILD/build.gradle"

if [ ! -f "$MANIFEST" ]; then
	echo "Not found: $MANIFEST" >&2
	echo "Run tools/setup.sh first (or Project > Install Android Build Template in the Godot editor)." >&2
	exit 1
fi

# Banner image (320x180) for the Android TV home screen, and the plugin source.
mkdir -p "$BUILD/res/drawable-xhdpi" "$BUILD/src/main/java/com/example/wobble"
cp "$ROOT/assets/icons/banner.png" "$BUILD/res/drawable-xhdpi/banner.png"
cp "$ROOT/android/plugin/QrScannerPlugin.java" "$BUILD/src/main/java/com/example/wobble/QrScannerPlugin.java"

python3 - "$MANIFEST" "$GRADLE" <<'PY'
import sys
manifest, gradle = sys.argv[1:3]

def patch(path, marker, edit, label):
    s = open(path).read()
    if marker in s:
        print(label + ": already set")
        return
    new = edit(s)
    if new == s:
        sys.exit("cannot patch " + label + " in " + path)
    open(path, "w").write(new)
    print(label + ": added")

patch(manifest, "android:banner=",
      lambda s: s.replace('android:icon="@mipmap/icon"', 'android:icon="@mipmap/icon"\n        android:banner="@drawable/banner"', 1),
      "banner attribute")

# A TV has no touchscreen or gyroscope and uses the leanback UI.
feat = "".join('    <uses-feature android:name="%s" android:required="false" />\n' % n for n in (
    "android.software.leanback", "android.hardware.touchscreen",
    "android.hardware.sensor.gyroscope", "android.hardware.sensor.accelerometer"))
patch(manifest, "android.software.leanback",
      lambda s: s.replace("    <application", feat + "\n    <application", 1),
      "uses-feature flags")

patch(manifest, "CHANGE_WIFI_MULTICAST_STATE",
      lambda s: s.replace("    <application", '    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />\n\n    <application', 1),
      "multicast permission")

meta = ('        <meta-data android:name="org.godotengine.plugin.v2.QrScanner" android:value="com.example.wobble.QrScannerPlugin" />\n'
        '        <meta-data android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="barcode_ui" />\n')
patch(manifest, "org.godotengine.plugin.v2.QrScanner",
      lambda s: s.replace("    </application>", meta + "    </application>", 1),
      "QR manifest entries")

patch(gradle, "play-services-code-scanner",
      lambda s: s.replace("dependencies {", 'dependencies {\n    implementation "com.google.android.gms:play-services-code-scanner:16.1.0"', 1),
      "QR dependency")
PY
