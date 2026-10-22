#!/bin/sh
# Decides what the CI has to run, from the files that a change touches. Usage: tools/ci_changes.sh [<base rev>]  (for example origin/main)
# Prints two lines for $GITHUB_OUTPUT:
#   code=true|false    something other than documentation changed (Markdown, docs/, .claude/; the design tokens in docs/ count as code)
#   render=true|false  something that can change a drawn frame changed (the job `pixels` checks frames)
# With no base rev (a manual run, or a new branch) both are true. When git cannot list the changes (the base is not in the
# history, for example after a force-push) both are true too: it is better to run too much than too little.
set -eu
BASE="${1:-}"
case "$BASE" in "" | 0000000*) BASE="" ;; esac
if [ -z "$BASE" ]; then
	echo "code=true"
	echo "render=true"
	exit 0
fi
if ! FILES="$(git -c core.quotepath=off diff --name-only "${BASE}...HEAD" 2>/dev/null)"; then
	echo "code=true"
	echo "render=true"
	exit 0
fi
CODE=false
RENDER=false
while IFS= read -r F; do
	[ -n "$F" ] || continue
	case "$F" in
		docs/design-system/tokens.json | docs/design-system/tokens.css) CODE=true ;;
		*.md | docs/* | .claude/*) continue ;;
		*) CODE=true ;;
	esac
	case "$F" in
		scenes/* | assets/* | scripts/ui/* | scripts/game/* | scripts/core/* | scripts/input/* | scripts/app.gd | project.godot | \
			tests/pixel_* | tools/make_tiles.gd | docs/design-system/tokens.* | .github/workflows/ci.yml | .circleci/config.yml | \
			tools/ci_changes.sh | tools/ci_plan_circleci.sh) RENDER=true ;;
	esac
done <<EOF2
$FILES
EOF2
echo "code=${CODE}"
echo "render=${RENDER}"
