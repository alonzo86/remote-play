extends SceneTree
## The result menu and the pause menu with 4 long player names, in English and in Hebrew: every text and button is inside the
## 60 px screen edge (REQ-GM-40), no text is below 28 px (REQ-GM-41), buttons do not overlap and no label is cut (REQ-GM-72).
## Replaces the layout part of manual tests 11.1 to 11.3. Run by tests/run_all.sh and tools/coverage.sh:
##   godot --headless --path . --script tests/layout_menus.gd -- --role=tv

const Lang = preload("res://scripts/core/lang.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")

const EDGE := Rect2(60, 60, 1800, 960)
const NAMES := {
	"en": ["ABCDEFGHIJ", "Maximilian", "Wolfgang12", "iiiiiiiiii"],
	"he": ["אבגדהוזחטי", "מקסימיליאן", "ירושלמיתא", "שששששששששש"],
}

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
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The visible controls of `box` that show a text (labels and buttons).
func _texts(box: Node) -> Array:
	var out := []
	for c in box.find_children("*", "Control", true, false):
		if (c is Label or c is Button) and c.is_visible_in_tree() and String(c.text) != "":
			out.append(c)
	return out


## What is wrong with the menu in `box`, as short texts. Empty when it is fine.
func _problems(box: Control) -> Array:
	var bad := []
	var buttons := []
	for c in _texts(box):
		var r: Rect2 = c.get_global_rect()
		if not EDGE.encloses(r):
			bad.append("outside the edge: %s %s" % [String(c.text).left(24), str(r)])
		if c.get_theme_font_size("font_size") < 28:
			bad.append("small text: %s" % String(c.text).left(24))
		if c is Button:
			buttons.append(c)
	for i in buttons.size():
		for j in range(i + 1, buttons.size()):
			if buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()):
				bad.append("buttons overlap: %s and %s" % [buttons[i].text, buttons[j].text])
	return bad


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	await _frames(3)
	var app: Node = root.get_node("App")
	for lang in ["en", "he"]:
		Lang.set_language(lang, root)
		for i in 4:
			var p = app.server.players[i]
			p.state = 1
			p.player_name = NAMES[lang][i]
		app.go(load("res://scripts/game/maze/maze_game.gd"))
		await _frames(5)
		var game: Control = app.current_screen()
		# Maze: one winner, the others not finished. Race: four times.
		var board := Scoreboard.new([0, 1, 2, 3], true)
		board.set_score(2, 31.5)
		game.open_results(board)
		await _frames(3)
		_check(_problems(game._menu_box).is_empty(),
				"%s: maze results (%d texts) fit: %s" % [lang, _texts(game._menu_box).size(), str(_problems(game._menu_box))])
		board = Scoreboard.new([], true)
		for s in 4:
			board.set_score(s, 30.0 + s * 12.34)
		game.open_results(board, [40.0, 30.0, 20.0])
		await _frames(3)
		_check(_problems(game._menu_box).is_empty(),
				"%s: race results with 4 rows and medals fit: %s" % [lang, str(_problems(game._menu_box))])
		var names_shown := _texts(game._menu_box).map(func(c): return String(c.text).to_upper())
		var all_names := true
		for n in NAMES[lang]:
			all_names = all_names and names_shown.any(func(t: String) -> bool: return t.contains(String(n).to_upper()))
		_check(all_names, "%s: every long name is in the list, none is cut" % lang)
		# The pause menu and the card of a lost phone.
		game.restart()
		await _frames(5)
		game = app.current_screen()
		game.open_menu("minigame.paused", game.pause_entries())
		await _frames(3)
		_check(_problems(game._menu_box).is_empty(), "%s: a pause menu fits: %s" % [lang, str(_problems(game._menu_box))])
	Lang.set_language("en", root)
