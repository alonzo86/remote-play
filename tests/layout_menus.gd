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
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
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
		game.open_results(board)
		await _frames(3)
		_check(_problems(game._menu_box).is_empty(),
				"%s: race results with 4 rows and medals fit: %s" % [lang, str(_problems(game._menu_box))])
		var names_shown := _texts(game._menu_box).map(func(c): return String(c.text).to_upper())
		var all_names := true
		for n in NAMES[lang]:
			all_names = all_names and names_shown.any(func(t: String) -> bool: return t.contains(String(n).to_upper()))
		_check(all_names, "%s: every long name is in the list, none is cut" % lang)
		# The buttons of a result menu are Try again, New game and Back to menu, 60 px (3.1 %) from the screen edge (Test 11.3a, 3b).
		var buttons := _texts(game._menu_box).filter(func(c): return c is Button)
		var wanted := ["minigame.restart", "minigame.new_game", "minigame.back_to_menu"]   # The buttons carry the text key.
		var got := buttons.map(func(b): return String(b.text))
		_check(got == wanted, "%s: the race results have the 3 buttons %s (%s)" % [lang, str(wanted), str(got)])
		var edge_ok := not buttons.is_empty()
		for b in buttons:
			var r: Rect2 = b.get_global_rect()
			edge_ok = edge_ok and r.position.x >= 1920.0 * 0.031 and r.end.x <= 1920.0 * (1.0 - 0.031)
		_check(edge_ok, "%s: no button is closer than 3.1 %% of the screen width (59.5 px) to the left or right edge" % lang)
		# One car finished, three did not (REQ-MR-9, REQ-FL-65): the places are 1st to 4th, the rows of the others say not finished.
		board = Scoreboard.new([], true)
		board.set_score(2, 41.5)
		board.set_unfinished(0, 80.0)
		board.set_unfinished(1, 120.0)
		board.set_unfinished(3, 20.0)
		game.open_results(board)
		await _frames(3)
		var rows := []
		for l in game._menu_box.find_children("*", "Label", true, false):
			if not l.get_parent() is GridContainer:
				rows.append(String(l.text).to_upper())
		rows = rows.slice(1)   # The first text is the title.
		var places := [Lang.t("result.place_1"), Lang.t("result.place_2"), Lang.t("result.place_3"), Lang.t("result.place_4")]
		var order := [2, 1, 0, 3]   # The finisher, then the others by how far they got.
		var rows_ok := rows.size() == 4
		for i in mini(rows.size(), 4):
			rows_ok = rows_ok and rows[i].begins_with(String(places[i]).to_upper()) \
					and rows[i].contains(String(NAMES[lang][order[i]]).to_upper())
			rows_ok = rows_ok and (rows[i].ends_with(Lang.t("result.not_finished").to_upper()) == (i > 0))
		rows_ok = rows_ok and rows[0].contains("41.5")
		_check(rows_ok and _problems(game._menu_box).is_empty(),
				"%s: 4 rows, places 1st to 4th, the finisher with its time and 3 cars not finished, all in the edge: %s"
				% [lang, str(rows)])
		# The pause menu and the card of a lost phone.
		game.restart()
		await _frames(5)
		game = app.current_screen()
		game.open_menu("minigame.end_game_ask", game.pause_entries())
		await _frames(3)
		_check(_problems(game._menu_box).is_empty(), "%s: a pause menu fits: %s" % [lang, str(_problems(game._menu_box))])
	Lang.set_language("en", root)
