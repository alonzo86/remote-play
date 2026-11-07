#!/bin/sh
# One-time setup for building and running on macOS and Linux. Safe to run again.
# Usage: tools/setup.sh
#   - finds Godot (GODOT env var, PATH, or /Applications/Godot.app)
#   - sets the JDK 17 path in the Godot editor settings
#   - installs the Android build templates, one for the controller and one for the TV (see tools/patch_android_manifest.sh)
#   - runs tools/patch_android_manifest.sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=tools/env.sh
. tools/env.sh
VERSION="$("$GODOT" --version | sed 's/\.official.*//')"   # e.g. 4.7.2.stable
echo "Godot: $GODOT ($VERSION)"

# JDK 17: JAVA_HOME when it is a 17, then the Homebrew one (tools/env.sh sets JAVA_HOME from it), then /usr/libexec/java_home (macOS).
JDK17="${JAVA_HOME:-}"
# `java -version` prints a "Picked up JAVA_TOOL_OPTIONS" line first when that variable is set: read the line that has the version.
case "$("$JDK17/bin/java" -version 2>&1 | grep -m1 ' version "')" in *'"17.'*) ;; *) JDK17="" ;; esac
if [ -z "$JDK17" ] && [ -x /usr/libexec/java_home ]; then JDK17="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"; fi
[ -n "$JDK17" ] || { echo "JDK 17 not found. Set JAVA_HOME to a JDK 17 (macOS: brew install openjdk@17; Linux: your package manager, e.g. openjdk-17-jdk)." >&2; exit 1; }
echo "JDK 17: $JDK17"

# The editor settings file is named after major.minor of Godot (editor_settings-4.7.tres).
MINOR="$(printf '%s' "$VERSION" | cut -d. -f1,2)"
SETTINGS="$GODOT_CONFIG_DIR/editor_settings-${MINOR}.tres"
if [ -f "$SETTINGS" ]; then
	# Portable edit (BSD and GNU sed differ on -i): write a copy, then put it back.
	TMP="$(mktemp)"
	sed "s|^export/android/java_sdk_path = .*|export/android/java_sdk_path = \"$JDK17\"|" "$SETTINGS" > "$TMP"
	cat "$TMP" > "$SETTINGS"
	rm -f "$TMP"
	echo "editor settings: java_sdk_path set"
else
	echo "Open the Godot editor once, then run this script again (no editor settings yet: $SETTINGS)." >&2
	exit 1
fi

TEMPLATES="$GODOT_DATA_DIR/export_templates/${VERSION}"
[ -f "$TEMPLATES/android_source.zip" ] || { echo "Export templates for $VERSION missing. Editor > Manage Export Templates." >&2; exit 1; }
# Two projects: android (preset "controller", with the QR scanner) and android-tv (preset "tv", without it).
for DIR in android android-tv; do
	if [ "$(cat $DIR/.build_version 2>/dev/null || true)" != "$VERSION" ]; then
		rm -rf $DIR/build
		mkdir -p $DIR/build
		unzip -q "$TEMPLATES/android_source.zip" -d $DIR/build
		touch $DIR/build/.gdignore
		printf '%s' "$VERSION" > $DIR/.build_version
		echo "$DIR build template: installed"
	else
		echo "$DIR build template: already installed"
	fi
done

tools/patch_android_manifest.sh
# On a Mac with Xcode: the iPhone QR scanner plugin (issue #299). The script is a no-op when it is up to date.
if [ "$(uname -s)" = "Darwin" ] && xcodebuild -version >/dev/null 2>&1; then tools/build_ios_plugin.sh; fi
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo "Setup done. Next: tools/build.sh run-tv | run-controller | test | apk"
