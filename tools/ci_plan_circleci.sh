#!/bin/sh
# What a CircleCI job has to run. Usage: tools/ci_plan_circleci.sh [tests parameter] [pixels parameter]  (use "" and false for none)
# CircleCI has no labels and no draft state, so the plan comes from the branch and the pipeline parameters:
#   main: all suites (coverage rule on), pixels on. Another branch: fast suites, pixels when something drawn changed.
#   The parameter `tests` (fast, slow, all) and the parameter `pixels` (true) from "Trigger Pipeline" override that.
# Prints three lines: tier=, pixels=true|false, code=true|false (code=false: only documentation changed, nothing to run).
set -eu
TESTS="${1:-}"
PIXELS_PARAM="${2:-false}"
BRANCH="${CIRCLE_BRANCH:-}"
if [ "$BRANCH" = main ]; then
	BASE=""
	TIER=all
	PIXELS=true
else
	git fetch -q origin main
	BASE="$(git merge-base origin/main HEAD)"
	TIER=fast
	PIXELS=false
fi
CHANGES="$(tools/ci_changes.sh "$BASE")"
CODE="$(echo "$CHANGES" | sed -n 's/^code=//p')"
RENDER="$(echo "$CHANGES" | sed -n 's/^render=//p')"
[ "$RENDER" = true ] && PIXELS=true
[ -n "$TESTS" ] && TIER="$TESTS"
[ "$PIXELS_PARAM" = true ] && PIXELS=true
echo "tier=${TIER}"
echo "pixels=${PIXELS}"
echo "code=${CODE}"
