#!/bin/sh
# Tests of the CI scripts that decide what runs: tools/ci_changes.sh, tools/ci_plan_circleci.sh and the tier filter of
# tests/run_suites.sh. Each case makes a small git repository in a temporary folder. Usage: tests/ci_scripts.sh
# It needs only git and sh (no Godot). Prints ok or FAIL for each check and exits 1 when a check fails.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0
CHECKS=0

check() { # check <title> <expected> <got>
	CHECKS=$((CHECKS + 1))
	if [ "$2" = "$3" ]; then
		echo "  ok   $1"
	else
		echo "  FAIL $1: expected '$2', got '$3'"
		FAILS=$((FAILS + 1))
	fi
}

# A repository with the CI scripts, one commit (base) and then one commit that adds the files given as arguments.
make_repo() {
	rm -rf "$TMP/repo" "$TMP/origin"
	git init -q "$TMP/origin"
	git -C "$TMP/origin" checkout -q -b main
	mkdir -p "$TMP/origin/tools"
	cp "$ROOT/tools/ci_changes.sh" "$ROOT/tools/ci_plan_circleci.sh" "$TMP/origin/tools/"
	git -C "$TMP/origin" add -A
	git -C "$TMP/origin" -c user.name=t -c user.email=t@t commit -q -m base
	git clone -q "$TMP/origin" "$TMP/repo"
	git -C "$TMP/repo" checkout -q -b feature
	for f in "$@"; do
		mkdir -p "$TMP/repo/$(dirname "$f")"
		echo x > "$TMP/repo/$f"
	done
	git -C "$TMP/repo" add -A
	git -C "$TMP/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m change
}

changes() { (cd "$TMP/repo" && tools/ci_changes.sh origin/main | tr '\n' ' '); }
plan() { (cd "$TMP/repo" && CIRCLE_BRANCH="${BRANCH:-feature}" tools/ci_plan_circleci.sh "$@" | tr '\n' ' '); }

echo "ci_changes.sh"
make_repo README.md docs/a.md .claude/skills/x.md
check "only documentation: no code, no render" "code=false render=false " "$(changes)"
make_repo docs/design-system/tokens.json
check "design tokens in docs/ are code and drawn" "code=true render=true " "$(changes)"
make_repo tests/run_all.sh
check "a test script is code, not drawn" "code=true render=false " "$(changes)"
make_repo scripts/net/tv_server.gd
check "network code is code, not drawn" "code=true render=false " "$(changes)"
for f in scripts/ui/a.gd scripts/game/a.gd scripts/core/a.gd scripts/input/a.gd scripts/app.gd scenes/a.tscn assets/a.png project.godot; do
	make_repo "$f"
	check "$f is drawn" "code=true render=true " "$(changes)"
done
make_repo "docs/photo 1.md" "scripts/net/odd name.gd"
check "names with spaces: a document and a script" "code=true render=false " "$(changes)"
make_repo "docs/photo 1.md"
check "a document with a space in its name is documentation" "code=false render=false " "$(changes)"
make_repo README.md
check "no base: everything runs" "code=true render=true " "$(cd "$TMP/repo" && tools/ci_changes.sh | tr '\n' ' ')"
check "an unknown base: everything runs" "code=true render=true " "$(cd "$TMP/repo" && tools/ci_changes.sh deadbeef | tr '\n' ' ')"
check "a base of zeros (a new branch): everything runs" "code=true render=true " "$(cd "$TMP/repo" && tools/ci_changes.sh 0000000000000000000000000000000000000000 | tr '\n' ' ')"

echo "ci_plan_circleci.sh"
make_repo README.md
check "branch, documentation only: nothing runs" "tier=unit pixels=false code=false " "$(plan "" false)"
check "branch, documentation only, tests=all: it runs" "tier=all pixels=false code=true " "$(plan all false)"
check "branch, documentation only, pixels=true: it runs" "tier=unit pixels=true code=true " "$(plan "" true)"
make_repo scripts/net/tv_server.gd
check "branch with code: unit suites, no pixels" "tier=unit pixels=false code=true " "$(plan "" false)"
make_repo scripts/ui/a.gd
check "branch with drawn code: unit suites and pixels" "tier=unit pixels=true code=true " "$(plan "" false)"
check "tests=scenario gives the scenario tier" "tier=scenario pixels=true code=true " "$(plan scenario false)"
make_repo README.md
git -C "$TMP/repo" checkout -q -b main2 origin/main
git -C "$TMP/repo" checkout -q main 2>/dev/null || git -C "$TMP/repo" checkout -q -b main origin/main
echo y > "$TMP/repo/README.md"
git -C "$TMP/repo" add -A
git -C "$TMP/repo" -c user.name=t -c user.email=t@t commit -q -m docs
BRANCH=main
check "main, documentation only: nothing runs" "tier=unit pixels=true code=false " "$(plan "" false)"
mkdir -p "$TMP/repo/scripts"
echo y > "$TMP/repo/scripts/a.gd"
git -C "$TMP/repo" add -A
git -C "$TMP/repo" -c user.name=t -c user.email=t@t commit -q -m code
check "main with code: unit suites and pixels" "tier=unit pixels=true code=true " "$(plan "" false)"
BRANCH=feature

echo "run_suites.sh tiers"
mkdir -p "$TMP/suites/tests"
cp "$ROOT/tests/run_suites.sh" "$TMP/suites/tests/"
cp "$ROOT/tests/suite_lib.sh" "$TMP/suites/tests/"
printf '%s\n' "# comment" "a.gd|tv|first|unit" "b.gd|tv|second|scenario" "c.gd|tv|third|unit" > "$TMP/suites/tests/suites.txt"
printf '#!/bin/sh\necho "RUN $*"\n' > "$TMP/godot"
chmod +x "$TMP/godot"
run_tier() { (cd "$TMP/suites" && GODOT="$TMP/godot" SUITE_TIER="$1" tests/run_suites.sh 2>&1 | grep -o 'script [a-z.]*' | tr '\n' ' '); }
check "unit runs the unit lines" "script a.gd script c.gd " "$(run_tier unit)"
check "scenario runs the scenario lines" "script b.gd " "$(run_tier scenario)"
check "all runs every line" "script a.gd script b.gd script c.gd " "$(run_tier all)"
printf '%s\n' "a.gd|tv|first|Unit" > "$TMP/suites/tests/suites.txt"
(cd "$TMP/suites" && GODOT="$TMP/godot" SUITE_TIER=unit tests/run_suites.sh >/dev/null 2>&1)
check "an unknown tier stops the run with exit 2" "2" "$?"
printf '%s\n' "a.gd|tv|first" > "$TMP/suites/tests/suites.txt"
(cd "$TMP/suites" && GODOT="$TMP/godot" SUITE_TIER=unit tests/run_suites.sh >/dev/null 2>&1)
check "a line with no tier stops the run with exit 2" "2" "$?"
(cd "$TMP/suites" && GODOT="$TMP/godot" SUITE_TIER=wrong tests/run_suites.sh >/dev/null 2>&1)
check "an unknown SUITE_TIER stops the run with exit 2" "2" "$?"

echo "tools/env.sh (portable build scripts, issue #287)"
env_run() { # env_run <var> [VAR=value ...]: source tools/env.sh in a clean shell and print one variable
	V="$1"; shift
	(cd "$ROOT" && env -i PATH="/usr/bin:/bin" HOME="$TMP/home" "$@" sh -c ". tools/env.sh; eval \"printf '%s' \\\"\\\${$V:-}\\\"\"")
}
mkdir -p "$TMP/home"
printf '#!/bin/sh\n' > "$TMP/mygodot"
chmod +x "$TMP/mygodot"
check "GODOT from the environment is kept" "$TMP/mygodot" "$(env_run GODOT GODOT="$TMP/mygodot")"
check "a JAVA_HOME that is set is not overwritten" "/my/jdk" "$(env_run JAVA_HOME GODOT="$TMP/mygodot" JAVA_HOME=/my/jdk)"
check "an ANDROID_HOME that is set is not overwritten" "/my/sdk" "$(env_run ANDROID_HOME GODOT="$TMP/mygodot" ANDROID_HOME=/my/sdk)"
check "no Godot: it stops with a message and exit 1" "1" "$(cd "$ROOT" && env -i PATH="/nonexistent" HOME="$TMP/home" /bin/sh -c '. tools/env.sh' >/dev/null 2>&1; echo $?)"
check "no tool script uses the BSD form sed -i ''" "" "$(grep -n "sed -i ''" "$ROOT"/tools/*.sh "$ROOT"/tests/*.sh | grep -v 'tests/ci_scripts.sh' || true)"
check "no tool script sets JAVA_HOME to a fixed path" "" "$(grep -n '^[[:space:]]*export JAVA_HOME=/' "$ROOT"/tools/*.sh || true)"
check "caffeinate is used only when it exists" "" "$(grep -n 'caffeinate' "$ROOT"/tools/*.sh | grep -v 'command -v caffeinate' | grep -v '^[^:]*:[0-9]*:[[:space:]]*#' | grep -v 'exec caffeinate' || true)"

echo "patch_android_manifest.sh (replaces the job build-android, issue #286)"
# A fake build template with the lines the script patches; the script is copied with the files it needs, so no Godot, SDK or JDK is used.
PT="$TMP/patch"
mkdir -p "$PT/tools" "$PT/assets/icons" "$PT/android/plugin"
cp "$ROOT/tools/patch_android_manifest.sh" "$PT/tools/"
cp "$ROOT/assets/icons/banner.png" "$PT/assets/icons/"
cp "$ROOT/android/plugin/QrScannerPlugin.java" "$PT/android/plugin/"
for DIR in android android-tv; do
	mkdir -p "$PT/$DIR/build/src/main"
	cat > "$PT/$DIR/build/src/main/AndroidManifest.xml" <<'MANIFEST'
<manifest>
    <application android:icon="@mipmap/icon">
        <activity>
            <intent-filter>
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
MANIFEST
	printf 'dependencies {\n}\n' > "$PT/$DIR/build/build.gradle"
done
(cd "$PT" && tools/patch_android_manifest.sh >/dev/null 2>&1)
check "patch: the controller manifest gets the QR plugin entry" "1" "$(grep -c 'org.godotengine.plugin.v2.QrScanner' "$PT/android/build/src/main/AndroidManifest.xml")"
check "patch: the controller gets the code scanner dependency" "1" "$(grep -c 'play-services-code-scanner' "$PT/android/build/build.gradle")"
check "patch: the controller gets the plugin source" "yes" "$([ -f "$PT/android/build/src/main/java/io/github/alonzo86/sababi/QrScannerPlugin.java" ] && echo yes)"
check "patch: the TV manifest has no QR entry" "0" "$(grep -c 'QrScanner' "$PT/android-tv/build/src/main/AndroidManifest.xml")"
check "patch: the TV has no code scanner dependency" "0" "$(grep -c 'play-services-code-scanner' "$PT/android-tv/build/build.gradle")"
check "patch: the TV has no plugin source" "no" "$([ -f "$PT/android-tv/build/src/main/java/io/github/alonzo86/sababi/QrScannerPlugin.java" ] && echo yes || echo no)"
check "patch: both manifests have the banner, the leanback flag and the launcher category" "3 3" "$(for D in android android-tv; do grep -c 'android:banner=\|android.software.leanback\|LEANBACK_LAUNCHER' "$PT/$D/build/src/main/AndroidManifest.xml"; done | tr '\n' ' ' | sed 's/ $//')"
cp "$PT/android/build/src/main/AndroidManifest.xml" "$TMP/before.xml"
(cd "$PT" && tools/patch_android_manifest.sh >/dev/null 2>&1)
check "patch: a second run changes nothing" "same" "$(cmp -s "$TMP/before.xml" "$PT/android/build/src/main/AndroidManifest.xml" && echo same || echo changed)"
echo "Godot version in both CI configs (issue #285)"
gv() { sed -n "s/^[[:space:]]*GODOT_VERSION:[[:space:]]*\([0-9][0-9.]*\).*/\1/p" "$1" | head -1; }
V_ACTIONS="$(gv "$ROOT/.github/workflows/ci.yml")"
V_CIRCLE="$(gv "$ROOT/.circleci/config.yml")"
check "ci.yml has a GODOT_VERSION" "yes" "$([ -n "$V_ACTIONS" ] && echo yes)"
check "GODOT_VERSION is the same in ci.yml and in .circleci/config.yml" "$V_ACTIONS" "$V_CIRCLE"
check "the CircleCI cache keys name that version (2 keys, same key)" "godot-$V_ACTIONS-v1 godot-$V_ACTIONS-v1" "$(sed -n 's/^[[:space:]]*key:[[:space:]]*\(godot-.*\)$/\1/p' "$ROOT/.circleci/config.yml" | tr '\n' ' ' | sed 's/ $//')"

echo "tools/set_version.sh (one app version, issue #289)"
check "the 3 version places of export_presets.cfg agree" "0" "$("$ROOT/tools/set_version.sh" --check >/dev/null 2>&1; echo $?)"
cp "$ROOT/export_presets.cfg" "$TMP/presets.cfg"
FILE="$TMP/presets.cfg" "$ROOT/tools/set_version.sh" 2.3.4 12 >/dev/null
check "set_version writes name and code to the 6 lines" "6" "$(grep -c '"2.3.4"\|^version/code=12$\|^application/version="12"$' "$TMP/presets.cfg")"
check "after set_version the check passes" "0" "$(FILE="$TMP/presets.cfg" "$ROOT/tools/set_version.sh" --check >/dev/null 2>&1; echo $?)"
sed -i.bak 's/^application\/version="12"/application\/version="13"/' "$TMP/presets.cfg"
check "one place that differs makes the check fail" "1" "$(FILE="$TMP/presets.cfg" "$ROOT/tools/set_version.sh" --check >/dev/null 2>&1; echo $?)"
check "a bad name is refused" "1" "$(FILE="$TMP/presets.cfg" "$ROOT/tools/set_version.sh" abc 1 >/dev/null 2>&1; echo $?)"
check "a bad code is refused" "1" "$(FILE="$TMP/presets.cfg" "$ROOT/tools/set_version.sh" 1.0.0 x1 >/dev/null 2>&1; echo $?)"
check ".gitignore keeps keystores and certificates out" "3" "$(grep -c '^\*\.keystore$\|^\*\.jks$\|^\*\.p12$' "$ROOT/.gitignore")"

echo "$CHECKS checks, $FAILS failed"
[ "$FAILS" -eq 0 ]
