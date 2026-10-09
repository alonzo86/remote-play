#!/bin/sh
# Runs all headless tests (a quick local run, without coverage). Usage: GODOT=/path/to/godot tests/run_all.sh
# CI runs tools/coverage.sh instead: the same suites (tests/suites.txt) with the coverage check.
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}" tests/run_suites.sh
echo "== design tokens (CSS)"
python3 tools/design_tokens_css.py --check
