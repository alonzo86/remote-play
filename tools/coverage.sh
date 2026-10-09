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
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
	echo "== unit and network tests"
	"$GODOT" --headless --path . --script tests/run_tests.gd -- --role=controller
	echo "== button states and the wait screen Leave"
	"$GODOT" --headless --path . --script tests/ui_states.gd -- --role=controller
	echo "== game rules"
	"$GODOT" --headless --path . --script tests/game_rules.gd -- --role=controller
	echo "== lost phones (network)"
	"$GODOT" --headless --path . --script tests/net_loss.gd -- --role=controller
	echo "== game helpers"
	"$GODOT" --headless --path . --script tests/game_helpers.gd -- --role=controller
	echo "== TV smoke test"
	"$GODOT" --headless --path . --script tests/smoke_tv.gd -- --role=tv
	echo "== settings view"
	"$GODOT" --headless --path . --script tests/smoke_settings.gd -- --role=tv
	echo "== Paint Grab"
	"$GODOT" --headless --path . --script tests/smoke_paint.gd -- --role=tv
)
python3 tools/coverage/report.py "$WORK/coverage_manifest.json" "$COVERAGE_OUT" "$OUT" \
	--min-file 80 --exclusions tools/coverage/exclusions.txt "$@"
