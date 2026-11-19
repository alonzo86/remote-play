#!/bin/sh
# The app version lives in five presets of export_presets.cfg: the TV app (tv, tv-release: 4 lines) and the controller app
# (controller, controller-release, controller-ios: 6 lines). This script writes or checks them.
# Usage: tools/set_version.sh <name> <code>              both apps, e.g. tools/set_version.sh 1.0.0 2
#        tools/set_version.sh <name> <code> tv           only the TV app
#        tools/set_version.sh <name> <code> controller   only the controller app (Android and iOS)
#        tools/set_version.sh --check                    exits 1 when the places of ONE app differ (tests/ci_scripts.sh runs this)
# <name> is the visible version (x.y.z). <code> is one whole number, higher than the one of the last release of THAT app that you
# uploaded (Google Play rejects a repeated or lower versionCode of an app). The TV and the controller are two listings, so each can
# have its own name and code; inside one app every preset has the same name and code. The iOS build number is the code of the
# controller. The protocol VERSION (scripts/core/protocol.gd) is a separate number: it changes only with the wire format
# (docs/PROTOCOL.md) and has no link to the app version.
# FILE can be set to another presets file (used by the test). Works on macOS and Linux.
set -eu
FILE="${FILE:-$(cd "$(dirname "$0")/.." && pwd)/export_presets.cfg}"

# Prints "<app> name|code <value>" for every version line of the file. The app is tv for the presets whose name starts with tv and
# controller for the others (the name of a preset is the line name="..." that comes before its [preset.N.options] section).
values() {
	awk '
		/^name="/ { cur = ($0 ~ /^name="tv/) ? "tv" : "controller"; next }
		/^version\/name="/ { v = $0; sub(/^version\/name="/, "", v); sub(/"$/, "", v); print cur, "name", v }
		/^version\/code=/ { v = $0; sub(/^version\/code=/, "", v); print cur, "code", v }
		/^application\/short_version="/ { v = $0; sub(/^application\/short_version="/, "", v); sub(/"$/, "", v); print cur, "name", v }
		/^application\/version="/ { v = $0; sub(/^application\/version="/, "", v); sub(/"$/, "", v); print cur, "code", v }
	' "$FILE"
}

check() {
	BAD=0
	for APP in tv controller; do
		WANT=4; [ "$APP" = controller ] && WANT=6
		N="$(values | grep -c "^$APP ")"
		NAMES="$(values | sed -n "s/^$APP name //p" | sort -u | wc -l | tr -d ' ')"
		CODES="$(values | sed -n "s/^$APP code //p" | sort -u | wc -l | tr -d ' ')"
		if [ "$N" -ne "$WANT" ] || [ "$NAMES" -ne 1 ] || [ "$CODES" -ne 1 ]; then
			echo "Version mismatch of the $APP app in $FILE (found $N values, expected $WANT; $NAMES different names, $CODES different codes):" >&2
			values | grep "^$APP " >&2
			BAD=1
		fi
	done
	[ "$BAD" -eq 0 ] || exit 1
	echo "TV app: version $(values | sed -n 's/^tv name //p' | head -1), code $(values | sed -n 's/^tv code //p' | head -1)."
	echo "Controller app: version $(values | sed -n 's/^controller name //p' | head -1), code $(values | sed -n 's/^controller code //p' | head -1)."
	echo "Each app agrees in all its presets."
}

if [ "${1:-}" = "--check" ]; then
	check
	exit 0
fi

NAME="${1:-}"; CODE="${2:-}"; TARGET="${3:-all}"
case "$NAME" in [0-9]*.[0-9]*.[0-9]*) ;; *) echo "Usage: $0 <x.y.z> <code> [tv|controller] | --check" >&2; exit 1 ;; esac
case "$CODE" in ''|*[!0-9]*) echo "The code must be a whole number." >&2; exit 1 ;; esac
case "$NAME" in *[!0-9.]*) echo "The name must be digits and dots (x.y.z)." >&2; exit 1 ;; esac
case "$TARGET" in all|tv|controller) ;; *) echo "The app must be tv or controller (or nothing for both)." >&2; exit 1 ;; esac
TMP="$(mktemp)"
awk -v target="$TARGET" -v name="$NAME" -v code="$CODE" '
	/^name="/ { cur = ($0 ~ /^name="tv/) ? "tv" : "controller" }
	{
		hit = (target == "all" || target == cur)
		if (hit && $0 ~ /^version\/name=/) { print "version/name=\"" name "\""; next }
		if (hit && $0 ~ /^version\/code=/) { print "version/code=" code; next }
		if (hit && $0 ~ /^application\/short_version=/) { print "application/short_version=\"" name "\""; next }
		if (hit && $0 ~ /^application\/version=/) { print "application/version=\"" code "\""; next }
		print
	}
' "$FILE" > "$TMP"
cat "$TMP" > "$FILE"
rm -f "$TMP"
FILE="$FILE" "$0" --check
