#!/bin/sh
# One-time setup for building and running on macOS. Safe to run again.
# Usage: tools/setup.sh
#   - finds Godot (GODOT env var, /Applications/Godot.app, or PATH)
#   - sets the JDK 17 path in the Godot editor settings
#   - installs the Android build template (same as "Project > Install Android Build Template")
#   - runs tools/patch_android_manifest.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-}"
[ -z "$GODOT" ] && [ -x /Applications/Godot.app/Contents/MacOS/Godot ] && GODOT=/Applications/Godot.app/Contents/MacOS/Godot
[ -z "$GODOT" ] && GODOT="$(command -v godot || true)"
[ -n "$GODOT" ] || { echo "Godot not found. Install Godot 4.7 or set GODOT=/path/to/godot." >&2; exit 1; }
VERSION="$("$GODOT" --version | sed 's/\.official.*//')"   # e.g. 4.7.2.stable
echo "Godot: $GODOT ($VERSION)"

JDK17=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
[ -x "$JDK17/bin/java" ] || JDK17="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
case "$("$JDK17/bin/java" -version 2>&1 | head -1)" in *'"17.'*) ;; *) JDK17="" ;; esac
[ -n "$JDK17" ] || { echo "JDK 17 not found. Run: brew install openjdk@17" >&2; exit 1; }
echo "JDK 17: $JDK17"

SETTINGS="$HOME/Library/Application Support/Godot/editor_settings-4.7.tres"
if [ -f "$SETTINGS" ]; then
	sed -i '' "s|^export/android/java_sdk_path = .*|export/android/java_sdk_path = \"$JDK17\"|" "$SETTINGS"
	echo "editor settings: java_sdk_path set"
else
	echo "Open the Godot editor once, then run this script again (no editor settings yet)." >&2
	exit 1
fi

TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/${VERSION}"
[ -f "$TEMPLATES/android_source.zip" ] || { echo "Export templates for $VERSION missing. Editor > Manage Export Templates." >&2; exit 1; }
if [ "$(cat android/.build_version 2>/dev/null || true)" != "$VERSION" ]; then
	rm -rf android/build
	mkdir -p android/build
	unzip -q "$TEMPLATES/android_source.zip" -d android/build
	touch android/build/.gdignore
	printf '%s' "$VERSION" > android/.build_version
	echo "android build template: installed"
else
	echo "android build template: already installed"
fi

tools/patch_android_manifest.sh
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo "Setup done. Next: tools/build.sh run-tv | run-controller | test | apk"
