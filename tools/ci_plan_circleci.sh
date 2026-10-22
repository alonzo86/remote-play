#!/bin/sh
# What a CircleCI job has to run. Usage: tools/ci_plan_circleci.sh [tests parameter] [pixels parameter]  (use "" and false for none)
# CircleCI has no labels and no draft state, so the plan comes from the branch and the pipeline parameters:
#   main: the unit suites, pixels on; the base is the parent commit, so a documentation-only merge runs nothing.
#   Another branch: the unit suites, pixels when something drawn changed; the base is where the branch left main.
#   The parameter `tests` (unit, scenario, all) and the parameter `pixels` (true) from "Trigger Pipeline" override that, also for a
#   documentation-only change.
# When git cannot find the base, everything runs. Prints three lines: tier=, pixels=true|false, code=true|false.
set -eu
TESTS="${1:-}"
PIXELS_PARAM="${2:-false}"
BRANCH="${CIRCLE_BRANCH:-}"
BASE=""
if [ "$BRANCH" = main ]; then
	TIER=unit
	PIXELS=true
	BASE="$(git rev-parse -q --verify HEAD~1 2>/dev/null || true)"
else
	TIER=unit
	PIXELS=false
	if git fetch -q origin main 2>/dev/null; then
		BASE="$(git merge-base FETCH_HEAD HEAD 2>/dev/null || true)"
	fi
fi
CHANGES="$(tools/ci_changes.sh "$BASE")"
CODE="$(echo "$CHANGES" | sed -n 's/^code=//p')"
RENDER="$(echo "$CHANGES" | sed -n 's/^render=//p')"
[ "$RENDER" = true ] && PIXELS=true
if [ -n "$TESTS" ]; then
	TIER="$TESTS"
	CODE=true
fi
if [ "$PIXELS_PARAM" = true ]; then
	PIXELS=true
	CODE=true
fi
echo "tier=${TIER}"
echo "pixels=${PIXELS}"
echo "code=${CODE}"
