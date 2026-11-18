#!/bin/sh
# Prepares the generated Gradle projects. There are two, so that the TV app has no Google code scanner (the TV does not scan,
# and then it has no ML Kit data to declare in the Play Data safety form):
#   - android/build (preset "controller"): Android TV banner and hardware flags, and the QR scanner plugin
#     (android/plugin/QrScannerPlugin.java, Google code scanner)
#   - android-tv/build (preset "tv", `gradle_build/gradle_build_directory="android-tv"`): the banner and the flags, no scanner
# Run once, after tools/setup.sh (or "Project > Install Android Build Template" in the Godot editor, which only makes android/build).
# Safe to run again. Works on macOS and Linux.
# Usage: tools/patch_android_manifest.sh [controller|tv]   (no argument: every project that is installed)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
	"")
		[ -d "$ROOT/android/build" ] && "$0" controller
		[ -d "$ROOT/android-tv/build" ] && "$0" tv
		exit 0 ;;
	controller) BUILD="$ROOT/android/build"; WITH_QR=1 ;;
	tv)         BUILD="$ROOT/android-tv/build"; WITH_QR=0 ;;
	*) echo "Usage: $0 [controller|tv]" >&2; exit 1 ;;
esac
echo "== $1: $BUILD"
MANIFEST="$BUILD/src/main/AndroidManifest.xml"
[ -f "$MANIFEST" ] || MANIFEST="$BUILD/AndroidManifest.xml"   # older templates
GRADLE="$BUILD/build.gradle"

if [ ! -f "$MANIFEST" ]; then
	echo "Not found: $MANIFEST" >&2
	echo "Run tools/setup.sh first (or Project > Install Android Build Template in the Godot editor)." >&2
	exit 1
fi

# A build template made before the rename to Sababi (FD-26) has the plugin under an old package (Remote Play, Wobble).
# Remove it, so the app cannot load an old copy of the plugin.
rm -rf "$BUILD/src/main/java/com/example"

# Banner image (320x180) for the Android TV home screen, and the plugin source.
mkdir -p "$BUILD/res/drawable-xhdpi" "$BUILD/src/main/java/io/github/alonzo86/sababi"
cp "$ROOT/assets/icons/banner.png" "$BUILD/res/drawable-xhdpi/banner.png"
if [ "$WITH_QR" = 1 ]; then
	cp "$ROOT/android/plugin/QrScannerPlugin.java" "$BUILD/src/main/java/io/github/alonzo86/sababi/QrScannerPlugin.java"
else
	rm -f "$BUILD/src/main/java/io/github/alonzo86/sababi/QrScannerPlugin.java"
fi

python3 - "$MANIFEST" "$GRADLE" "$WITH_QR" <<'PY'
import sys
manifest, gradle, with_qr = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
# The TV app is for TVs only (owner, 2026-11-19): Google Play offers it only to devices with the leanback feature. The phone app
# (the one with the scanner) is not limited, so a TV box can still run it.
tv_only = not with_qr

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
feat = "".join('    <uses-feature android:name="%s" android:required="%s" />\n' % (n, "true" if (tv_only and n == "android.software.leanback") else "false") for n in (
    "android.software.leanback", "android.hardware.touchscreen",
    "android.hardware.sensor.gyroscope", "android.hardware.sensor.accelerometer"))
patch(manifest, "android.software.leanback",
      lambda s: s.replace("    <application", feat + "\n    <application", 1),
      "uses-feature flags")
# A manifest patched before this rule has the flag as false: make it true for the TV app.
if tv_only:
    old = '<uses-feature android:name="android.software.leanback" android:required="false" />'
    s = open(manifest).read()
    if old in s:
        open(manifest, "w").write(s.replace(old, old.replace('"false"', '"true"')))
        print("leanback required: set to true (TV app only)")

# Android TV lists only apps with the leanback launcher category, and `monkey` needs it to find the activity.
patch(manifest, "category.LEANBACK_LAUNCHER",
      lambda s: s.replace('<category android:name="android.intent.category.LAUNCHER" />',
                          '<category android:name="android.intent.category.LAUNCHER" />\n                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />', 1),
      "leanback launcher category")

if with_qr:
    # A manifest patched before the rename names an old plugin class: point it to the new one.
    s = open(manifest).read()
    for old in ("com.example.remoteplay.QrScannerPlugin", "com.example.wobble.QrScannerPlugin", "com.example.sababi.QrScannerPlugin"):
        if old in s:
            s = s.replace(old, "io.github.alonzo86.sababi.QrScannerPlugin")
            open(manifest, "w").write(s)
            print("QR plugin class: renamed to io.github.alonzo86.sababi")

    meta = ('        <meta-data android:name="org.godotengine.plugin.v2.QrScanner" android:value="io.github.alonzo86.sababi.QrScannerPlugin" />\n'
            '        <meta-data android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="barcode_ui" />\n')
    patch(manifest, "org.godotengine.plugin.v2.QrScanner",
          lambda s: s.replace("    </application>", meta + "    </application>", 1),
          "QR manifest entries")

    patch(gradle, "play-services-code-scanner",
          lambda s: s.replace("dependencies {", 'dependencies {\n    implementation "com.google.android.gms:play-services-code-scanner:16.1.0"', 1),
          "QR dependency")
else:
    # A TV project made when the scanner was shared: take the scanner out.
    s = open(manifest).read()
    kept = [l for l in s.split("\n") if "org.godotengine.plugin.v2.QrScanner" not in l and "com.google.mlkit.vision.DEPENDENCIES" not in l]
    if len(kept) != len(s.split("\n")):
        open(manifest, "w").write("\n".join(kept))
        print("QR manifest entries: removed")
    g = open(gradle).read()
    kept = [l for l in g.split("\n") if "play-services-code-scanner" not in l]
    if len(kept) != len(g.split("\n")):
        open(gradle, "w").write("\n".join(kept))
        print("QR dependency: removed")
PY
