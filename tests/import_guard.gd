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
##
## `ok()` also does one thing for the TV app suites (issue #393, `docs/JOIN_APPROVAL_PLAN.md` section 8): the setting "approve new
## players" is ON by default, so a phone that joins the TV App would wait for a card nobody answers. When the App of this run is a
## TV, `ok()` turns the approval OFF in memory only (`TvServer.set_approve_new`; the settings file is not touched). A suite that
## tests the approval turns it ON again itself.

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
		approval_off()
		return true
	print(MESSAGE)
	print("  not loaded: ", ", ".join(m))
	return false


## The TV App of this run, if any, stops asking the host to approve new phones (memory only, nothing is saved). At the time of
## `_initialize` the App is in the tree but its `_ready` has not run (no server yet), so this waits for its `ready` signal, which
## comes before any `await` of the suite goes on.
static func approval_off() -> void:
	var loop := Engine.get_main_loop()
	var app: Node = (loop as SceneTree).root.get_node_or_null("App") if loop is SceneTree else null
	if app == null:
		return
	var off := func() -> void:
		if app.get("server") != null:
			app.server.set_approve_new(false)
	if app.is_node_ready():
		off.call()
	else:
		app.ready.connect(off, CONNECT_ONE_SHOT)
