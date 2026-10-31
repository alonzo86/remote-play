extends SceneTree
## Issue #291: a suite that runs on a tree that was never imported must fail with a clear message, not report a green result.
## (1) every suite of tests/suites.txt starts with the import guard, (2) the guard passes on an imported tree, (3) a copy of the
## project without `.godot` makes a suite exit with 1 and print the message. Run:
##   godot --headless --path . --script tests/import_guard_check.gd -- --role=controller

const Guard = preload("res://tests/import_guard.gd")

var _checks := 0
var _fails := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	if not Guard.ok():
		quit(1)
		return
	_wiring()
	_unimported_copy()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _suites() -> Array:
	var out := []
	for line in FileAccess.get_file_as_string("res://tests/suites.txt").split("\n"):
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		out.append(line.split("|")[0])
	return out


func _wiring() -> void:
	_check(Guard.missing().is_empty(), "an imported tree: every resource of the guard loads")
	var without := []
	for path in _suites():
		if path == "tests/import_guard_check.gd":
			continue   # It calls the guard through its own constant (gdlint: duplicated-load).
		var text := FileAccess.get_file_as_string("res://" + path)
		var first := text.find("func _initialize() -> void:\n")
		var guard := text.find('if not preload("res://tests/import_guard.gd").ok():')
		# The guard is the first statement of _initialize().
		if first < 0 or guard != first + "func _initialize() -> void:\n".length() + 1:
			without.append(path)
	_check(_suites().size() > 90, "tests/suites.txt lists the suites (%d)" % _suites().size())
	_check(without.is_empty(), "every suite starts _initialize() with the import guard (without: %s)" % str(without))


## A copy of the project without .godot: qr.gd must exit with 1 and print the message of the guard.
func _unimported_copy() -> void:
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var out := []
	OS.execute("mktemp", ["-d"], out)
	var tmp := String(out[0]).strip_edges() if out.size() > 0 else ""
	_check(tmp != "", "a temporary folder")
	if tmp == "":
		return
	var copy := "tar -C '%s' --exclude=./.godot --exclude=./.git --exclude=./build -cf - . | tar -C '%s' -xf -" % [root, tmp]
	OS.execute("sh", ["-c", copy])
	_check(not DirAccess.dir_exists_absolute(tmp + "/.godot"), "the copy has no .godot folder")
	var log := []
	var code := OS.execute(OS.get_executable_path(),
			["--headless", "--path", tmp, "--script", "tests/qr.gd", "--", "--role=controller"], log, true)
	var text := String(log[0]) if log.size() > 0 else ""
	_check(code != 0, "a suite on a tree that was not imported exits with a failure (exit code %d)" % code)
	_check(text.contains(Guard.MESSAGE), "and it prints the reason: %s" % Guard.MESSAGE)
	_check(not text.contains("checks, 0 failed"), "and it does not print a green result")
	OS.execute("rm", ["-rf", tmp])
