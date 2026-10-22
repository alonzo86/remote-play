#!/bin/sh
# Runs the headless test suites of tests/suites.txt, one after the other, in the project that holds this script.
# Usage: GODOT=/path/to/godot tests/run_suites.sh. It runs ALL suites, also after one fails (a known bug is a failure, so
# several suites can be red at once), and then lists the failed suites and exits with 1.
# SUITE_TIER picks the suites: `fast` (the lines with no tier), `slow` (the lines with the tier slow) or `all` (the default).
# Used by tests/run_all.sh and by tools/coverage.sh (which runs it in an instrumented copy of the project).
set -u
GODOT="${GODOT:-godot}"
TIER="${SUITE_TIER:-all}"
case "$TIER" in fast | slow | all) ;; *) echo "SUITE_TIER must be fast, slow or all" >&2; exit 2 ;; esac
cd "$(dirname "$0")/.." || exit 1
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
FAILED=""
while IFS="|" read -r script role title tier; do
	case "$script" in ''|'#'*) continue ;; esac
	[ "$TIER" = all ] || [ "${tier:-fast}" = "$TIER" ] || continue
	echo "== $title"
	if ! "$GODOT" --headless --path . --script "$script" -- --role="$role"; then
		FAILED="$FAILED
  $script ($title)"
	fi
done < tests/suites.txt
if [ -n "$FAILED" ]; then
	echo "FAILED SUITES:$FAILED"
	exit 1
fi
