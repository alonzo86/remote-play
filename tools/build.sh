#!/bin/sh
# Build and run helper (macOS and Linux; the Android and iOS parts need the SDK, JDK 17 and the export templates). Usage: tools/build.sh <run-tv|run-controller|test|apk|aab|install>
set -eu
cd "$(dirname "$0")/.."
# shellcheck source=tools/env.sh
. tools/env.sh

# Run and test need the imported-asset cache (.godot/, not in git). Without it fonts and images fail to load.
import_assets() { "$GODOT" --headless --path . --import >/dev/null 2>&1 || true; }

case "${1:-}" in
	run-tv)         import_assets;
		# caffeinate (macOS only) stops App Nap from throttling the window
		if command -v caffeinate >/dev/null 2>&1; then exec caffeinate -dis "$GODOT" --path . -- --role=tv; fi
		exec "$GODOT" --path . -- --role=tv ;;
	run-controller) import_assets; exec "$GODOT" --path . -- --role=controller --join=127.0.0.1 ;;
	test)           GODOT="$GODOT" exec tests/run_all.sh ;;
	apk)
		mkdir -p build
		"$GODOT" --headless --path . --export-debug tv build/sababi-tv.apk
		"$GODOT" --headless --path . --export-debug controller build/sababi-controller.apk
		ls -l build/*.apk ;;
	aab)
		# Store bundles (issue #289). The upload keystore is never in the repo: the three variables name it (docs/EXPORT.md, "Keys").
		[ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ] && [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-}" ] \
			&& [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-}" ] \
			|| { echo "Set GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER and _PASSWORD (the upload keystore, docs/EXPORT.md \"Keys\")." >&2; exit 1; }
		mkdir -p build
		"$GODOT" --headless --path . --export-release tv-release build/sababi-tv.aab
		"$GODOT" --headless --path . --export-release controller-release build/sababi-controller.aab
		ls -l build/*.aab ;;
	install)
		adb install -r build/sababi-controller.apk
		[ -n "${TV_IP:-}" ] && adb connect "$TV_IP:5555" && adb -s "$TV_IP:5555" install -r build/sababi-tv.apk ;;
	*) echo "Usage: $0 run-tv|run-controller|test|apk|aab|install (TV_IP=x.x.x.x to also install the TV app)" >&2; exit 1 ;;
esac
