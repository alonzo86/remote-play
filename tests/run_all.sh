#!/bin/sh
# Runs all headless tests. Usage: GODOT=/path/to/godot tests/run_all.sh
set -eu
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo "== unit and network tests"
"$GODOT" --headless --path . --script tests/run_tests.gd -- --role=controller
echo "== button states and the wait screen Leave"
"$GODOT" --headless --path . --script tests/ui_states.gd -- --role=controller
echo "== lost phones (network)"
"$GODOT" --headless --path . --script tests/net_loss.gd -- --role=controller
echo "== game helpers"
"$GODOT" --headless --path . --script tests/game_helpers.gd -- --role=controller
echo "== game rules"
"$GODOT" --headless --path . --script tests/game_rules.gd -- --role=controller
echo "== design tokens"
"$GODOT" --headless --path . --script tests/design_tokens.gd -- --role=controller
python3 tools/design_tokens_css.py --check
echo "== TV smoke test"
"$GODOT" --headless --path . --script tests/smoke_tv.gd -- --role=tv
