# shellcheck shell=sh
# Shared by tests/run_suites.sh and tests/run_one.sh (issue #291). Source it; it defines one function.
# run_suite <script> <role>: runs one suite with $GODOT, prints its output and returns its status. A script error (a call of a
# function that does not exist, a null) stops the code that ran it, but the suite can still end with "0 failed" and exit 0: the
# checks after the error never ran (issue #276). So the output is kept and a SCRIPT ERROR line fails the suite.
run_suite() {
	_log="$(mktemp)"
	_status=0
	"${GODOT:-godot}" --headless --path . --script "$1" -- --role="$2" >"$_log" 2>&1 || _status=$?
	cat "$_log"
	if [ "$_status" = 0 ] && grep -q "^SCRIPT ERROR" "$_log"; then
		echo "FAIL: $1 printed a SCRIPT ERROR, so some checks did not run"
		_status=1
	fi
	rm -f "$_log"
	return "$_status"
}
