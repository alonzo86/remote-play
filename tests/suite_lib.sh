# shellcheck shell=sh
# Shared by tests/run_suites.sh and tests/run_one.sh (issue #291). Source it; it defines one function.
# run_suite <script> <role>: runs one suite with $GODOT, prints its output and returns its status. A script error (a call of a
# function that does not exist, a null) stops the code that ran it, but the suite can still end with "0 failed" and exit 0: the
# checks after the error never ran (issue #276). So the output is kept and a SCRIPT ERROR line fails the suite.
run_suite() {
	_log="$(mktemp)"
	_status=0
	# A suite writes settings.cfg and controller.cfg (it saves the language it switched to). It runs with its own empty user data
	# folder, so it never changes the saved language of the person who runs it, and a saved "he" cannot fail it (issue #394).
	# HOME is for macOS, XDG_DATA_HOME for Linux.
	_home="$(mktemp -d)"
	HOME="$_home" XDG_DATA_HOME="$_home/data" "${GODOT:-godot}" --headless --path . --script "$1" -- --role="$2" >"$_log" 2>&1 || _status=$?
	cat "$_log"
	if [ "$_status" = 0 ] && grep -q "^SCRIPT ERROR" "$_log"; then
		echo "FAIL: $1 printed a SCRIPT ERROR, so some checks did not run"
		_status=1
	fi
	rm -rf "$_log" "$_home"
	return "$_status"
}
