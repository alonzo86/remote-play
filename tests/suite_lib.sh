# shellcheck shell=sh
# Shared by tests/run_suites.sh and tests/run_one.sh (issue #291). Source it; it defines one function.
# run_suite <script> <role>: runs one suite with $GODOT, prints its output and returns its status. A script error (a call of a
# function that does not exist, a null) stops the code that ran it, but the suite can still end with "0 failed" and exit 0: the
# checks after the error never ran (issue #276). So the output is kept and a SCRIPT ERROR line fails the suite.
run_suite() {
	_log="$(mktemp)"
	_home=""
	_status=0
	# Ctrl-C or a kill must not leave the log and the user data folder behind: leave through exit, which runs the EXIT trap.
	trap 'rm -rf "$_log" "$_home"' EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	# A suite writes settings.cfg and controller.cfg (it saves the language it switched to). It runs with its own empty user data
	# folder, so it never changes the saved language of the person who runs it, and a saved "he" cannot fail it (issue #394).
	# Godot keeps the user data in $XDG_DATA_HOME on Linux and in $HOME/Library/Application Support on macOS, so both are replaced.
	# The project import cache (.godot) is in the project folder and is not affected.
	_home="$(mktemp -d)"
	HOME="$_home" XDG_DATA_HOME="$_home/data" "${GODOT:-godot}" --headless --path . --script "$1" -- --role="$2" >"$_log" 2>&1 || _status=$?
	cat "$_log"
	if [ "$_status" = 0 ] && grep -q "^SCRIPT ERROR" "$_log"; then
		echo "FAIL: $1 printed a SCRIPT ERROR, so some checks did not run"
		_status=1
	fi
	rm -rf "$_log" "$_home"
	trap - EXIT INT TERM
	return "$_status"
}
