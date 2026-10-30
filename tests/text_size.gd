extends SceneTree
## The floor of the text size (issue #222, REQ-FL-40): TV text is 32 px or larger. The test reads the sources in scripts/game and
## scripts/ui and finds every font size that is written as a number (a size argument of draw_string, draw_centered, fit_text,
## get_string_size, the font_size of a theme override, a *_FONT or *_SIZE constant, a font_size parameter).
## A size under 32 fails, except the places in KNOWN
## (issue #246, to be fixed: remove a line when it is fixed). The About screen has phone text, floor 24 px (REQ-FL-40).
## Run: godot --headless --path . --script tests/text_size.gd -- --role=controller

const FLOOR := 32
const FOLDERS: Array[String] = ["res://scripts/game", "res://scripts/ui"]
## Known text under the floor: file -> number of places. Issue #246.
const KNOWN := {
	"res://scripts/game/bumper_cars/bumper_cars_game.gd": 1,
	"res://scripts/game/mini_golf/mini_golf_game.gd": 4,
	"res://scripts/game/bowling/bowling_game.gd": 4,
	"res://scripts/game/tennis/tennis_game.gd": 3,
}
## Files with phone text (REQ-FL-40: 24 px or more on a phone, so the floor is 24 there).
const PHONE_FLOOR := 24
const PHONE_FILES: Array[String] = ["res://scripts/ui/about_screen.gd"]
const PATTERNS: Array[String] = [
	"HORIZONTAL_ALIGNMENT_\\w+,\\s*-?[\\d.]+,\\s*(\\d+)\\s*,",
	"get_string_size\\([^\\n]*?,\\s*-1,\\s*(\\d+)\\)",
	"add_theme_font_size_override\\(\\s*\"font_size\",\\s*(\\d+)\\)",
	"fit_text\\([^\\n]*,\\s*(\\d+)\\)",
	"draw_centered\\([^\\n]*?,\\s*(\\d+),\\s*[\\w.]+(?:\\(|\\))",
	"(?:label_plate|text_centered|Shell\\.text|Shell\\.hint)\\([^\\n]*?,\\s*(\\d+),\\s*[\\w.]+",
	"^\\s*(?:const\\s+)?\\w*(?:FONT|FONT_MIN|TEXT_SIZE|_FS|SIZE_[A-Z]+)\\s*(?::\\s*int\\s*)?:?=\\s*(\\d+)",
	"font_size\\s*:?=\\s*(\\d+)",
]

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
	_scanner()
	_sources()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The lines (1-based) of `text` with a written font size under `floor_px`, as "line:size".
static func small_sizes(text: String, floor_px: int = FLOOR) -> Array[String]:
	var found: Array[String] = []
	for p in PATTERNS:
		var re := RegEx.new()
		re.compile("(?m)" + p)
		for m in re.search_all(text):
			var n := int(m.get_string(1))
			if n < floor_px:
				var key := "%d:%d" % [text.substr(0, m.get_start(1)).count("\n") + 1, n]
				if not found.has(key):
					found.append(key)
	return found


func _scanner() -> void:
	print("the scanner finds a small size")
	_check(small_sizes("draw_string(f, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, c)") == ["1:28"], "a draw_string size of 28")
	var two_lines := "draw_string(f, at, t, HORIZONTAL_ALIGNMENT_RIGHT, 64.0,\n\t\t32, c)\n"
	two_lines += "x\ny, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, c)"
	_check(small_sizes(two_lines) == ["4:30"], "a size on the next line is read and 32 passes")
	_check(small_sizes("const BANNER_FONT := 24") == ["1:24"], "a *_FONT constant")
	_check(small_sizes("l.add_theme_font_size_override(\"font_size\", 20)") == ["1:20"], "a theme override")
	_check(small_sizes("var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x") == ["1:16"], "a measuring call")
	_check(small_sizes("Shell.label_plate(self, at, msg, 28, UiTheme.TEXT)") == ["1:28"], "a plate")
	_check(small_sizes("func f(font_size := 28)") == ["1:28"], "a font_size default")
	_check(small_sizes("const X := 32\nconst Y_FONT := 40\ndraw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, c)").is_empty(),
			"32 and larger pass")


func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + "/" + d))
	return out


func _sources() -> void:
	print("scripts/game and scripts/ui")
	var scanned := 0
	var new_ones: Array[String] = []
	var counts := {}
	for folder in FOLDERS:
		for path in _files(folder):
			scanned += 1
			var found := small_sizes(FileAccess.get_file_as_string(path), PHONE_FLOOR if PHONE_FILES.has(path) else FLOOR)
			if found.is_empty():
				continue
			counts[path] = found.size()
			if found.size() > int(KNOWN.get(path, 0)):
				new_ones.append("%s %s" % [path, str(found)])
	_check(scanned > 40, "the scan reads the sources (%d files)" % scanned)
	_check(new_ones.is_empty(), "no text under %d px outside the known list (found: %s)" % [FLOOR, str(new_ones)])
	var stale: Array[String] = []
	for path in KNOWN:
		if int(counts.get(path, 0)) < int(KNOWN[path]):
			stale.append(path)
	_check(stale.is_empty(), "every known exception still exists; lower the count or remove the line when fixed (%s)" % str(stale))
