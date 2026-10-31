#!/bin/sh
# shellcheck shell=sh
# Shared by tools/build.sh, deploy.sh, deploy-ios.sh and setup.sh. Source it (". tools/env.sh"), do not run it.
# It sets GODOT, JAVA_HOME and ANDROID_HOME when they are not set already, and never replaces a value the user gave.
# Works on macOS and Linux. Order for Godot: $GODOT, then `godot` on PATH, then /Applications/Godot.app (macOS).
# After it: SYS (Darwin or Linux), GODOT_CONFIG_DIR (editor settings) and GODOT_DATA_DIR (export templates) are set.

SYS="$(uname -s)"
if [ "$SYS" = Darwin ]; then
	GODOT_CONFIG_DIR="$HOME/Library/Application Support/Godot"
	GODOT_DATA_DIR="$HOME/Library/Application Support/Godot"
	DEFAULT_ANDROID_HOME="$HOME/Library/Android/sdk"
else
	GODOT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
	GODOT_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot"
	DEFAULT_ANDROID_HOME="$HOME/Android/Sdk"
fi

GODOT="${GODOT:-}"
[ -n "$GODOT" ] || GODOT="$(command -v godot || true)"
[ -n "$GODOT" ] || { [ -x /Applications/Godot.app/Contents/MacOS/Godot ] && GODOT=/Applications/Godot.app/Contents/MacOS/Godot; }
[ -n "$GODOT" ] || { echo "Godot not found. Install Godot 4.7 or set GODOT=/path/to/godot." >&2; exit 1; }

# The JDK 17 that Homebrew installs (Apple Silicon, then Intel). A JAVA_HOME that is set already is kept.
if [ -z "${JAVA_HOME:-}" ]; then
	for DIR in /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home; do
		if [ -x "$DIR/bin/java" ]; then JAVA_HOME="$DIR"; break; fi
	done
fi
[ -z "${JAVA_HOME:-}" ] || export JAVA_HOME
: "${ANDROID_HOME:=$DEFAULT_ANDROID_HOME}"
export ANDROID_HOME
