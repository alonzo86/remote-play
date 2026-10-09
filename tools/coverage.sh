#!/bin/sh
# Line coverage of the GDScript code in scripts/, from the headless tests.
# Usage: GODOT=/path/to/godot tools/coverage.sh [output dir] [report.py options]
# The default rule: every module (script file) has 80% line coverage, except the modules in
# tools/coverage/exclusions.txt. The exit code is 1 when a module is below. Output (default build/coverage):
# summary.md, summary.json, lcov.info.
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
rm -rf "$OUT"
mkdir -p "$OUT/hits"
python3 tools/coverage/instrument.py . "$WORK"
COVERAGE_OUT="$(cd "$OUT/hits" && pwd)"
export COVERAGE_OUT
(
	cd "$WORK"
	GODOT="$GODOT" tests/run_suites.sh
)
python3 tools/coverage/report.py "$WORK/coverage_manifest.json" "$COVERAGE_OUT" "$OUT" \
	--min-file 80 --exclusions tools/coverage/exclusions.txt "$@"
