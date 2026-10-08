#!/bin/sh
# Build and run helper. Usage: tools/build.sh <run-tv|run-controller|test|apk|install>
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-}"
[ -z "$GODOT" ] && [ -x /Applications/Godot.app/Contents/MacOS/Godot ] && GODOT=/Applications/Godot.app/Contents/MacOS/Godot
[ -z "$GODOT" ] && GODOT="$(command -v godot)"
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

# Run and test need the imported-asset cache (.godot/, not in git). Without it fonts and images fail to load.
import_assets() { "$GODOT" --headless --path . --import >/dev/null 2>&1 || true; }

case "${1:-}" in
	run-tv)         import_assets; exec caffeinate -dis "$GODOT" --path . -- --role=tv ;;  # caffeinate: no App Nap throttling
	run-controller) import_assets; exec "$GODOT" --path . -- --role=controller --auto-join ;;
	test)           GODOT="$GODOT" exec tests/run_all.sh ;;
	apk)
		mkdir -p build
		"$GODOT" --headless --path . --export-debug tv build/remote-play-tv.apk
		"$GODOT" --headless --path . --export-debug controller build/remote-play-controller.apk
		ls -l build/*.apk ;;
	install)
		adb install -r build/remote-play-controller.apk
		[ -n "${TV_IP:-}" ] && adb connect "$TV_IP:5555" && adb -s "$TV_IP:5555" install -r build/remote-play-tv.apk ;;
	*) echo "Usage: $0 run-tv|run-controller|test|apk|install (TV_IP=x.x.x.x to also install the TV app)" >&2; exit 1 ;;
esac
