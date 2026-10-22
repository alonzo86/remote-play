#!/bin/sh
# Runs the headless tests (a quick local run, without coverage).
# Usage: GODOT=/path/to/godot tests/run_all.sh [unit|scenario|all]   (default: all)
# unit = the suites that the CI runs; scenario = the suites of screens, layouts, texts and flows (tests/suites.txt).
# CI runs tools/coverage.sh instead: the same suites (tests/suites.txt) with the coverage check.
set -eu
cd "$(dirname "$0")/.."
SUITE_TIER="${1:-${SUITE_TIER:-all}}"
export SUITE_TIER
GODOT="${GODOT:-godot}" tests/run_suites.sh
echo "== CI scripts (what runs when)"
tests/ci_scripts.sh
echo "== design tokens (CSS)"
python3 tools/design_tokens_css.py --check
