#!/bin/sh
# Line coverage of the GDScript code in scripts/, from the headless tests.
# Usage: GODOT=/path/to/godot tools/coverage.sh [output dir] [report.py options]
# COVERAGE_STEP picks a part (CI runs the two parts in two jobs): `run` makes the instrumented copy and runs the suites of
# tests/suites.txt on it (the hits are written to <output dir>/hits); `report` reads the hits and the manifest of the
# output dir, writes the reports and checks the 80% rule; `all` (the default) does both.
# The default rule: every module (script file) has 80% line coverage, except the modules in
# tools/coverage/exclusions.txt. The exit code is 1 when a module is below. Output (default build/coverage):
# summary.md, summary.json, lcov.info. COVERAGE_REPORT_ONLY=1 makes the reports but never fails (for a run of one tier of the suites).
# It needs python3 and gdtoolkit (pip install "gdtoolkit==4.*"). See tools/coverage/instrument.py.
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="build/coverage"
if [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; then
	OUT="$1"
	shift
fi
WORK="$OUT/instrumented"
STEP="${COVERAGE_STEP:-all}"
case "$STEP" in run | report | all) ;; *) echo "COVERAGE_STEP must be run, report or all" >&2; exit 2 ;; esac
if [ "$STEP" != report ]; then
	rm -rf "$OUT"
	mkdir -p "$OUT/hits"
	python3 tools/coverage/instrument.py . "$WORK"
	COVERAGE_OUT="$(cd "$OUT/hits" && pwd)"
	export COVERAGE_OUT
	(
		cd "$WORK"
		GODOT="$GODOT" tests/run_suites.sh
	)
fi
if [ "$STEP" != run ]; then
	MIN_FILE="--min-file 80"
	# COVERAGE_REPORT_ONLY=1: make the reports, but do not fail on a module below 80% (a run of one tier of the suites)
	[ "${COVERAGE_REPORT_ONLY:-0}" = 1 ] && MIN_FILE=""
	# shellcheck disable=SC2086
	python3 tools/coverage/report.py "$WORK/coverage_manifest.json" "$OUT/hits" "$OUT" \
		$MIN_FILE --exclusions tools/coverage/exclusions.txt "$@"
fi
