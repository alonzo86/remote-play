#!/bin/sh
# macOS only (Xcode). Builds the iPhone QR scanner plugin (ios/plugin/qr_scanner) into ios/plugins/ (issue #299).
# Usage: tools/build_ios_plugin.sh [--force]
#   The output (QrScanner.gdip and qr_scanner.xcframework) is NOT committed (.gitignore). It is rebuilt only when
#   the source is newer, or with --force. Godot finds it in res://ios/plugins/ and lists it in the iOS export preset.
#   Needs: Xcode (xcode-select -s /Applications/Xcode.app), git, python3 and scons (pip3 install scons).
#   GODOT_SRC   optional. A Godot source checkout at the tag of the export templates. Without it the script clones
#               GODOT_TAG (default 4.7.2-stable) into build/ios-plugin/godot. The headers must match the templates.
#   STATUS: written on Linux, never run. The first run builds the engine headers (scons, long). If a step fails, save the
#   last 50 lines of the log (Manual test 33 step 1a).
set -eu
cd "$(dirname "$0")/.."

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

[ "$(uname -s)" = "Darwin" ] || { echo "The iOS plugin builds on macOS only." >&2; exit 1; }
xcodebuild -version >/dev/null 2>&1 || { echo "Xcode is not active. Install Xcode, then: sudo xcode-select -s /Applications/Xcode.app" >&2; exit 1; }

SRC=ios/plugin/qr_scanner
OUT=ios/plugins
WORK=build/ios-plugin
MIN_IOS=15.0
mkdir -p "$WORK" "$OUT"

# Rebuild only when a source file is newer than the output.
if [ "$FORCE" -eq 0 ] && [ -d "$OUT/qr_scanner.xcframework" ] && [ -f "$OUT/QrScanner.gdip" ] \
	&& [ -z "$(find "$SRC" tools/build_ios_plugin.sh -type f -newer "$OUT/qr_scanner.xcframework" 2>/dev/null | head -n 1)" ]; then
	echo "ios/plugins/qr_scanner.xcframework is up to date."
	exit 0
fi

# 1. The Godot headers of the same version as the export templates (4.7.2).
if [ -n "${GODOT_SRC:-}" ]; then
	GODOT_DIR="$GODOT_SRC"
else
	GODOT_DIR="$WORK/godot"
	if [ ! -d "$GODOT_DIR/.git" ]; then
		git clone --depth 1 --branch "${GODOT_TAG:-4.7.2-stable}" https://github.com/godotengine/godot.git "$GODOT_DIR"
	fi
fi
command -v scons >/dev/null 2>&1 || { echo "scons not found. Install it: pip3 install scons" >&2; exit 1; }
# scons writes the generated headers (core/*.gen.h). One run is enough; the marker file keeps the result.
if [ ! -f "$WORK/.headers-done" ]; then
	(cd "$GODOT_DIR" && scons platform=ios target=template_debug arch=arm64 generate_bundle=no -j"$(sysctl -n hw.ncpu)")
	touch "$WORK/.headers-done"
fi

# 2. Compile for the device and for the simulator, one static library each.
build_slice() { # $1 sdk, $2 target triple suffix, $3 name
	SDK="$1"; SUFFIX="$2"; NAME="$3"
	OBJ="$WORK/$NAME"
	rm -rf "$OBJ"; mkdir -p "$OBJ"
	for FILE in qr_scanner qr_scan_view_controller qr_scanner_module; do
		xcrun --sdk "$SDK" clang++ -x objective-c++ -std=c++17 -fobjc-arc -fmodules -fcxx-modules -Os -arch arm64 \
			-target "arm64-apple-ios${MIN_IOS}${SUFFIX}" \
			-DIOS_ENABLED -DUNIX_ENABLED -DPTRCALL_ENABLED -DTYPED_METHOD_BIND -DDEBUG_ENABLED -DDISABLE_FORCED_INLINE \
			-I"$GODOT_DIR" -I"$GODOT_DIR/platform/ios" -I"$SRC" \
			-c "$SRC/$FILE.mm" -o "$OBJ/$FILE.o"
	done
	xcrun --sdk "$SDK" libtool -static -o "$OBJ/libqr_scanner.a" "$OBJ"/*.o
}
build_slice iphoneos "" device
build_slice iphonesimulator "-simulator" simulator

# 3. One xcframework with both slices. Then the .gdip next to it.
rm -rf "$OUT/qr_scanner.xcframework"
xcodebuild -create-xcframework \
	-library "$WORK/device/libqr_scanner.a" \
	-library "$WORK/simulator/libqr_scanner.a" \
	-output "$OUT/qr_scanner.xcframework"
cp "$SRC/QrScanner.gdip" "$OUT/QrScanner.gdip"
echo "Built $OUT/qr_scanner.xcframework and $OUT/QrScanner.gdip."
