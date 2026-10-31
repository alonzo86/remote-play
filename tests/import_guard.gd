extends RefCounted
## The first line of every suite (issue #291): a suite that runs on a tree that was never imported (no `.godot/imported`) must not
## go on. The fonts and sprite sheets fail to load, the drawing code gets null, and a suite can end with "0 failed" or fail
## with a script error that has nothing to do with the code. `ok()` loads the resources every screen needs and prints the
## reason when one is missing. A suite uses it like this:
##   func _initialize() -> void:
##       if not preload("res://tests/import_guard.gd").ok():
##           quit(1)
##           return
## tests/import_guard_check.gd checks that every suite of tests/suites.txt has this line.

const REQUIRED := [
	"res://assets/fonts/PressStart2P-Regular.ttf",
	"res://assets/fonts/SababiPixelHebrew.ttf",
	"res://assets/avatars/avatars.png",
	"res://assets/medals/medals.png",
	"res://assets/logo/logo.png",
]

const MESSAGE := "FAIL: assets not imported, run: godot --headless --path . --import"


## The resources of REQUIRED that do not load (empty when the project is imported).
static func missing() -> Array:
	var out := []
	for path in REQUIRED:
		if ResourceLoader.load(path) == null:
			out.append(path)
	return out


## True when the project is imported. Otherwise prints MESSAGE and the missing files, and returns false.
static func ok() -> bool:
	var m := missing()
	if m.is_empty():
		return true
	print(MESSAGE)
	print("  not loaded: ", ", ".join(m))
	return false
