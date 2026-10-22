#!/bin/sh
# Decides what the CI has to run, from the files that a change touches. Usage: tools/ci_changes.sh [<base rev>]  (for example origin/main)
# Prints two lines for $GITHUB_OUTPUT:
#   code=true|false    something other than documentation changed (Markdown, docs/, .claude/; the design tokens in docs/ count as code)
#   render=true|false  something that can change a drawn frame changed (the job `pixels` checks frames)
# With no base rev (a manual run, or a new branch) both are true.
set -eu
BASE="${1:-}"
case "$BASE" in "" | 0000000*) BASE="" ;; esac
if [ -z "$BASE" ]; then
	echo "code=true"
	echo "render=true"
	exit 0
fi
FILES="$(git diff --name-only "${BASE}...HEAD")"
CODE=false
RENDER=false
for F in $FILES; do
	case "$F" in
		docs/design-system/tokens.json | docs/design-system/tokens.css) CODE=true ;;
		*.md | docs/* | .claude/*) continue ;;
		*) CODE=true ;;
	esac
	case "$F" in
		scenes/* | assets/* | scripts/ui/* | scripts/game/* | scripts/core/lang.gd | project.godot | tests/pixel_* | tools/make_tiles.gd | \
			docs/design-system/tokens.* | .github/workflows/ci.yml | tools/ci_changes.sh) RENDER=true ;;
	esac
done
echo "code=${CODE}"
echo "render=${RENDER}"
