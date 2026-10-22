#!/bin/sh
# Runs the headless tests (a quick local run, without coverage).
# Usage: GODOT=/path/to/godot tests/run_all.sh [fast|slow|all]   (default: all)
# fast = the suites that the pull request CI runs; slow = the suites with the tier `slow` in tests/suites.txt.
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
