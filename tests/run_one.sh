#!/bin/sh
# Runs ONE suite of tests/suites.txt the way tests/run_suites.sh does: it imports the project when `.godot/imported` is missing
# (a fresh checkout) and a SCRIPT ERROR fails the suite even when it ends with "0 failed" (issue #291).
# Usage: GODOT=/path/to/godot tests/run_one.sh tests/<x>.gd     (the role comes from tests/suites.txt)
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 1
[ $# -eq 1 ] || { echo "usage: tests/run_one.sh tests/<x>.gd" >&2; exit 2; }
SUITE="$1"
ROLE="$(awk -F'|' -v s="$SUITE" '$1 == s { print $2; exit }' tests/suites.txt)"
[ -n "$ROLE" ] || { echo "$SUITE is not in tests/suites.txt" >&2; exit 2; }
[ -d .godot/imported ] || "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
. tests/suite_lib.sh
run_suite "$SUITE" "$ROLE"
