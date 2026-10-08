#!/bin/sh
# Runs all headless tests. Usage: GODOT=/path/to/godot tests/run_all.sh
set -eu
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo "== unit and network tests"
"$GODOT" --headless --path . --script tests/run_tests.gd -- --role=controller
echo "== design tokens"
"$GODOT" --headless --path . --script tests/design_tokens.gd -- --role=controller
echo "== TV smoke test"
"$GODOT" --headless --path . --script tests/smoke_tv.gd -- --role=tv
