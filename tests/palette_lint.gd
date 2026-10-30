extends SceneTree
## Palette lint (issue #232, REQ-GM-48): a color literal `Color("rrggbb")` in scripts/ that is equal or near (CIE76 delta E under
## NEAR) to a player color, OK green or BAD red is a color that a player may take for a message. Only scripts/game/palette.gd,
## scripts/core/protocol.gd and scripts/ui/ui_theme.gd may define such a color. Every other file may keep only the literals
## that are counted in tests/palette_baseline.txt (the old ones: file, a tab, a count). A NEW one fails this test. A moved one
## must lower the count (the test fails when the count is lower than the baseline, so the baseline only gets smaller).
## The reference colors are read from `Protocol.PLAYER_COLORS`, `UiTheme.OK` and `UiTheme.BAD`, so a change of the player
## palette (issue #237) lists the new hits here: update the baseline then, with the list in the pull request.
## Run: godot --headless --path . --script tests/palette_lint.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Palette = preload("res://scripts/game/palette.gd")
const SimInput = preload("res://tests/sim_input.gd")

const NEAR := 12.0
const DEFINERS: Array[String] = ["res://scripts/game/palette.gd", "res://scripts/core/protocol.gd",
		"res://scripts/ui/ui_theme.gd"]
const BASELINE := "res://tests/palette_baseline.txt"

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
	_detection()
	_migrated()
	_scan()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


static func references() -> Array[Color]:
	var out: Array[Color] = []
	out.append_array(Protocol.PLAYER_COLORS)
	out.append(UiTheme.OK)
	out.append(UiTheme.BAD)
	return out


## The literals of `text` that are near a reference color, as "line:#rrggbb".
static func near_literals(text: String, refs: Array[Color]) -> Array[String]:
	var found: Array[String] = []
	var re := RegEx.create_from_string("Color\\(\"([0-9a-fA-F]{6})(?:[0-9a-fA-F]{2})?\"\\)")
	for m in re.search_all(text):
		var c := Color(m.get_string(1))
		for r in refs:
			if SimInput.delta_e(c, r) < NEAR:
				found.append("%d:#%s" % [text.substr(0, m.get_start()).count("\n") + 1, m.get_string(1).to_lower()])
				break
	return found


func _detection() -> void:
	print("the lint finds a near color")
	var refs := references()
	var p: Color = Protocol.PLAYER_COLORS[0]
	_check(near_literals("x = Color(\"%s\")" % p.to_html(false), refs) == ["1:#%s" % p.to_html(false)],
			"a player color")
	_check(near_literals("a\nb Color(\"f83800\")", refs) == ["2:#f83800"], "the BAD red, on line 2")
	_check(near_literals("Color(\"00b800aa\")", refs) == ["1:#00b800"], "the OK green with an alpha part")
	var free := "Color(\"fcfcfc\") Color(\"000000\") Color(\"f8b800\")"
	_check(near_literals(free, refs).is_empty(), "white, black and yellow are free")


## The constants that replaced a literal have the value of the literal (no change of the look).
func _migrated() -> void:
	print("migrated colors keep their value")
	_check(Palette.NES_RED == Color("f83800"), "Palette.NES_RED is the old red f83800")
	var sheep: GDScript = load("res://scripts/game/sheep_herding/sheep_look.gd")
	var bowling: GDScript = load("res://scripts/game/bowling/bowling_look.gd")
	var olds := [Color("e63946"), Color("2a9d8f"), Color("f4a261"), Color("457b9d")]
	_check(sheep.CONFETTI.slice(0, 4) == olds and bowling.DISCO.slice(0, 4) == olds,
			"the party lights are the 4 player colors (the values did not change)")
	var golf: GDScript = load("res://scripts/game/mini_golf/golf_look.gd")
	_check(golf.RED == Color("f83800") and golf.BALLOON[0] == Color("f83800"), "Mini Golf red and balloon are the old red")


func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + "/" + d))
	return out


func _baseline() -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string(BASELINE).split("\n"):
		if line.strip_edges().is_empty() or line.begins_with("#"):
			continue
		var cells := line.split("\t")
		if cells.size() == 2:
			out["res://" + cells[0]] = int(cells[1])
	return out


func _scan() -> void:
	print("scripts/")
	var base := _baseline()
	var refs := references()
	var newer: Array[String] = []
	var older: Array[String] = []
	var seen := {}
	for path in _files("res://scripts"):
		if DEFINERS.has(path):
			continue
		var hits := near_literals(FileAccess.get_file_as_string(path), refs)
		if hits.is_empty():
			continue
		seen[path] = true
		var allowed := int(base.get(path, 0))
		if hits.size() > allowed:
			newer.append("%s: %d (baseline %d): %s" % [path.trim_prefix("res://"), hits.size(), allowed, str(hits)])
		elif hits.size() < allowed:
			older.append("%s: %d (baseline %d)" % [path.trim_prefix("res://"), hits.size(), allowed])
	for path in base:
		if not seen.has(path):
			older.append("%s: 0 (baseline %d)" % [path.trim_prefix("res://"), base[path]])
	_check(newer.is_empty(),
			"no new literal equal or near a player color, OK or BAD; use scripts/game/palette.gd (new: %s)" % str(newer))
	_check(older.is_empty(),
			"the baseline has no line that is too high; lower it in tests/palette_baseline.txt (old: %s)" % str(older))
