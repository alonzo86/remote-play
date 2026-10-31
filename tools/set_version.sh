#!/bin/sh
# The app version lives in three places of export_presets.cfg (tv, controller, controller-ios). This script writes or checks all of them.
# Usage: tools/set_version.sh <name> <code>     e.g. tools/set_version.sh 0.2.0 2
#        tools/set_version.sh --check           exits 1 when the places differ (tests/ci_scripts.sh runs this)
# <name> is the visible version (x.y.z). <code> is one whole number, higher than the one of the last release you uploaded
# (Google Play rejects a repeated or lower versionCode; the TV and the controller are two listings, and both use the same number
# so there is one rule). The iOS build number is the same <code>. The protocol VERSION (scripts/core/protocol.gd) is a separate
# number: it changes only with the wire format (docs/PROTOCOL.md) and has no link to the app version.
# FILE can be set to another presets file (used by the test). Works on macOS and Linux.
set -eu
FILE="${FILE:-$(cd "$(dirname "$0")/.." && pwd)/export_presets.cfg}"

values() { # prints the six values in a fixed order, one per line
	sed -n \
		-e 's/^version\/name="\(.*\)"$/name \1/p' \
		-e 's/^version\/code=\(.*\)$/code \1/p' \
		-e 's/^application\/short_version="\(.*\)"$/name \1/p' \
		-e 's/^application\/version="\(.*\)"$/code \1/p' "$FILE"
}

if [ "${1:-}" = "--check" ]; then
	N="$(values | wc -l | tr -d ' ')"
	NAMES="$(values | sed -n 's/^name //p' | sort -u | wc -l | tr -d ' ')"
	CODES="$(values | sed -n 's/^code //p' | sort -u | wc -l | tr -d ' ')"
	if [ "$N" -ne 6 ] || [ "$NAMES" -ne 1 ] || [ "$CODES" -ne 1 ]; then
		echo "Version mismatch in $FILE (found $N values, $NAMES different names, $CODES different codes):" >&2
		values >&2
		exit 1
	fi
	echo "Version $(values | sed -n 's/^name //p' | head -1), code $(values | sed -n 's/^code //p' | head -1): the 3 places agree."
	exit 0
fi

NAME="${1:-}"; CODE="${2:-}"
case "$NAME" in [0-9]*.[0-9]*.[0-9]*) ;; *) echo "Usage: $0 <x.y.z> <code> | --check" >&2; exit 1 ;; esac
case "$CODE" in ''|*[!0-9]*) echo "The code must be a whole number." >&2; exit 1 ;; esac
case "$NAME" in *[!0-9.]*) echo "The name must be digits and dots (x.y.z)." >&2; exit 1 ;; esac
TMP="$(mktemp)"
sed \
	-e "s/^version\/name=.*/version\/name=\"$NAME\"/" \
	-e "s/^version\/code=.*/version\/code=$CODE/" \
	-e "s/^application\/short_version=.*/application\/short_version=\"$NAME\"/" \
	-e "s/^application\/version=.*/application\/version=\"$CODE\"/" \
	"$FILE" > "$TMP"
cat "$TMP" > "$FILE"
rm -f "$TMP"
FILE="$FILE" "$0" --check
