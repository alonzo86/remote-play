#!/bin/sh
# Runs the headless test suites of tests/suites.txt, one after the other, in the project that holds this script.
# Usage: GODOT=/path/to/godot tests/run_suites.sh. It stops at the first suite that fails.
# Used by tests/run_all.sh and by tools/coverage.sh (which runs it in an instrumented copy of the project).
set -eu
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
while IFS='|' read -r script role title; do
	case "$script" in ''|'#'*) continue ;; esac
	echo "== $title"
	"$GODOT" --headless --path . --script "$script" -- --role="$role"
done < tests/suites.txt
