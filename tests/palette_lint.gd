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
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_detection()
	_migrated()
	_color_blind()
	_scan()
	_meaning()
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
	var slots: Array = Protocol.PLAYER_COLORS
	_check(sheep.CONFETTI.slice(0, 4) == slots and bowling.DISCO.slice(0, 4) == slots,
			"the party lights are the 4 player colors (they follow the palette)")
	var moved := {"RACE_RED": "e83838", "RACE_GREEN": "48c838", "RACE_BLUE": "1c88b0", "RACE_WOOD": "d89850", "RACE_AMBER": "e8a050",
			"ICE_BLUE": "5a90c0", "MAZE_RED": "d02838", "HOCKEY_RED": "d62828", "BANANA_TAN": "dc9660", "BANANA_RED": "e6323c",
			"BANANA_PEACH": "e6aa6e", "LANE_WOOD": "d8a058", "TOY_RED": "e63946", "TONGUE_PINK": "ff4060", "GOLF_GREEN": "00a800"}
	var consts: Dictionary = (Palette as GDScript).get_script_constant_map()
	var changed: Array[String] = []
	for n in moved:
		if consts.get(n) != Color(moved[n]):
			changed.append(n)
	_check(changed.is_empty() and moved.size() == 15,
			"the 15 named world colors have the value of the literals they replaced (changed: %s)" % str(changed))
	var golf: GDScript = load("res://scripts/game/mini_golf/golf_look.gd")
	_check(golf.RED == Color("f83800") and golf.BALLOON[0] == Color("f83800"), "Mini Golf red and balloon are the old red")


## Machado et al. (2009) matrices for severity 1.0, applied in linear RGB (docs/COLOR_BLIND_AUDIT.md).
const CB_MATRICES := {
	"protanopia": [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
	"deuteranopia": [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.011820, 0.042940, 0.968881],
	"tritanopia": [1.255528, -0.076749, -0.178779, -0.078411, 0.930809, 0.147602, 0.004733, 0.691367, 0.303900]}
const CB_MIN_DELTA_E := 40.0


static func simulate(c: Color, m: Array) -> Color:
	var l := c.srgb_to_linear()
	var r := clampf(m[0] * l.r + m[1] * l.g + m[2] * l.b, 0.0, 1.0)
	var g := clampf(m[3] * l.r + m[4] * l.g + m[5] * l.b, 0.0, 1.0)
	var b := clampf(m[6] * l.r + m[7] * l.g + m[8] * l.b, 0.0, 1.0)
	return Color(r, g, b).linear_to_srgb()


## Issue #237 (REQ-GM-46a): any two slot colors are at least 40 delta E apart for normal vision and under each simulation.
func _color_blind() -> void:
	print("the slot colors under color blindness")
	var slots: Array = Protocol.PLAYER_COLORS
	_check(SimInput.min_delta_e(slots) >= CB_MIN_DELTA_E, "normal vision: %.1f" % SimInput.min_delta_e(slots))
	for n in CB_MATRICES:
		var sim: Array = []
		for c in slots:
			sim.append(simulate(c, CB_MATRICES[n]))
		var d := SimInput.min_delta_e(sim)
		_check(d >= CB_MIN_DELTA_E, "%s: the closest two slots are %.1f apart (%.0f or more)" % [n, d, CB_MIN_DELTA_E])
	# The test must fail on the old palette (so the limit means something).
	var old: Array = [Color("e63946"), Color("2a9d8f"), Color("f4a261"), Color("457b9d")]
	var sim_old: Array = []
	for c in old:
		sim_old.append(simulate(c, CB_MATRICES["deuteranopia"]))
	var worst_old := SimInput.min_delta_e(sim_old)
	_check(worst_old < CB_MIN_DELTA_E, "the old palette is under the limit for deuteranopia (%.1f)" % worst_old)
	# Slot color against the empty tile and the black screen.
	for c in slots:
		_check(UiTheme.contrast(c, UiTheme.BG) >= 4.5, "slot %s has 4.5:1 on black" % c.to_html(false))


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
			"REQ-GM-23: no new literal equal or near a player color, OK or BAD; use scripts/game/palette.gd (new: %s)" % str(newer))
	_check(older.is_empty(),
			"the baseline has no line that is too high; lower it in tests/palette_baseline.txt (old: %s)" % str(older))


## REQ-GM-44: OK green means good and BAD red means danger, in every screen and game. The uses of `UiTheme.OK` and `UiTheme.BAD`
## outside the three files that define them are listed here with what each one means. A new use (or one that is gone) fails the
## test: whoever adds it checks its meaning and adds the line. {file: [uses of OK, uses of BAD]}
const MEANING := {
	"scripts/ui/tv_connect.gd": [0, 1],           # BAD: the TV has no network address (an error).
	"scripts/ui/pencil_icon.gd": [0, 1],          # BAD: the red rubber of the pencil picture (a drawing detail, not a message).
	"scripts/ui/track_picker.gd": [1, 0],         # OK: the green start mark of a track sketch (go).
	"scripts/ui/tv_game_settings.gd": [1, 0],     # OK: the roster line "IN" (good, taking part).
	"scripts/ui/controller_connect.gd": [0, 1],   # BAD: a failed join (an error).
	"scripts/ui/tv_settings.gd": [1, 0],          # OK: a switch that is ON.
	"scripts/ui/controller_settings.gd": [1, 0],  # OK: the haptics switch is ON.
	"scripts/ui/switch_icon.gd": [1, 0],          # OK: a switch that is ON.
	"scripts/ui/controller_pad.gd": [1, 6],       # OK: the best score. BAD: the lost link, the B button, its stripes.
	"scripts/game/mini_golf/golf_look.gd": [1, 0],   # OK: the aim mark is snapped to the cup (good aim).
	"scripts/ui/slot_list.gd": [1, 1],            # OK: READY. BAD: LOST.
	"scripts/ui/join_card.gd": [1, 1],            # OK: the ALLOW word and cursor. BAD: the REFUSE word and cursor (the mock).
	"scripts/game/marble_race/marble_race.gd": [1, 0]}   # OK: the GO word (go).


func _meaning() -> void:
	print("OK and BAD keep their meaning")
	var re_ok := RegEx.create_from_string("UiTheme\\.OK\\b")
	var re_bad := RegEx.create_from_string("UiTheme\\.(BAD|DANGER|BAD_TEXT)\\b")
	var found := {}
	for path in _files("res://scripts"):
		if DEFINERS.has(path):
			continue
		var ok := 0
		var bad := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.split("#")[0]
			ok += re_ok.search_all(code).size()
			bad += re_bad.search_all(code).size()
		if ok + bad > 0:
			found[path.trim_prefix("res://")] = [ok, bad]
	_check(found == MEANING, "REQ-GM-44: every use of OK green and BAD red is on the list of MEANING; found %s" % str(found))
	_check(re_ok.search("c = UiTheme.OK") != null and re_bad.search("c = UiTheme.BAD") != null
			and re_ok.search("UiTheme.OKAY") == null,
			"the pattern finds a use of OK and of BAD")
