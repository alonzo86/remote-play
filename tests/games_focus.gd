extends SceneTree
## The arrow keys on the Games screen (REQ-FL-16): the players badge and OPTIONS can be reached from every state of the grid,
## also when the grid has scrolled (the first row of tiles is under the header then), in English and in Hebrew.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/games_focus.gd -- --role=tv

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


func _run() -> void:
	await _frames(5)
	var app: Node = root.get_node("App")
	root.size = Vector2i(1280, 720)   # The window of a TV run: the grid is taller than the room it has, so it scrolls.
	for i in 3:
		app.server.players[i].state = 1   # Three phones are joined.
	for code in ["en", "he"]:
		app.set_language(code, false)
		app.go_games()
		await _frames(20)
		await _reach(app.current_screen(), code)
	app.set_language("en", false)
	app.go_games()
	await _frames(5)
	var screen: Control = app.current_screen()
	await _grid_checks(app)
	screen = app.current_screen()
	screen._tiles.clear()
	screen._wire_focus()   # A Games screen without a game must not crash.
	_check(screen._badge.focus_neighbor_right != NodePath(), "the header is still linked when there are no tiles")


## From every tile, in the scrolled and in the unscrolled grid: Up reaches the badge, and the badge reaches OPTIONS and back.
func _reach(screen: Control, code: String) -> void:
	print("games screen in ", code)
	var to_gear := SIDE_LEFT if code == "he" else SIDE_RIGHT   # OPTIONS is at the left in Hebrew.
	var ok_up := true
	var ok_gear := true
	var ok_back := true
	var ok_stay := true
	for i in screen._tiles.size():
		screen._tiles[i].grab_focus()
		await _frames(25)   # The grid scrolls to the tile.
		var focused: Control = screen._tiles[i]
		var up: Control = focused
		for step in 3:   # Up as often as it takes: from the second row it takes two presses.
			up = up.find_valid_focus_neighbor(SIDE_TOP)
			if up == screen._badge:
				break
		ok_up = ok_up and up == screen._badge
		await _frames(10)   # The focus stays on the tile: the grid stays scrolled, and the first row of tiles is under the header.
		ok_gear = ok_gear and screen._badge.find_valid_focus_neighbor(to_gear) == screen._gear
		ok_back = ok_back and screen._gear.find_valid_focus_neighbor(SIDE_RIGHT if code == "he" else SIDE_LEFT) == screen._badge
		ok_stay = ok_stay and screen._badge.find_valid_focus_neighbor(SIDE_TOP) == screen._badge \
				and screen._gear.find_valid_focus_neighbor(SIDE_TOP) == screen._gear
	_check(ok_up, "from every tile the arrow key up reaches the players badge")
	_check(ok_gear, "from the badge the arrow key toward OPTIONS reaches it, also when the grid has scrolled")
	_check(ok_back, "and from OPTIONS the other way goes back to the badge")
	_check(ok_stay, "up from the header stays in the header")


## The grid has 3 tiles in a row with 1, 2 and 4 phones, and the focused tile is always on the screen, also the last one and the
## one with the longest title (REQ-FL-12, 16).
func _grid_checks(app: Node) -> void:
	root.size = Vector2i(1920, 1080)   # The real TV screen.
	await _frames(3)
	for n in [1, 2, 4]:
		for i in 4:
			app.server.players[i].state = 1 if i < n else 0
		app.go_games()
		await _frames(20)
		var tiles: Array = app.current_screen()._tiles
		var per_row := {}
		for t in tiles:
			var y := snappedf(t.get_parent().get_global_rect().position.y, 1.0)
			per_row[y] = int(per_row.get(y, 0)) + 1
		var counts: Array = per_row.values()
		_check(counts.size() == ceili(float(tiles.size()) / 3.0) and counts.slice(0, counts.size() - 1).all(func(c): return c == 3),
				"%d phones: the Games grid has 3 tiles in each row (%s)" % [n, str(counts)])
	for i in 3:
		app.server.players[i].state = 1
	app.go_games()
	await _frames(20)
	var screen: Control = app.current_screen()
	var view := Rect2(Vector2.ZERO, Vector2(root.size))
	var always_visible := true
	var one_cursor := true
	var order: Array = range(screen._tiles.size()) + range(screen._tiles.size() - 2, -1, -1)
	for i in order:
		screen._tiles[i].grab_focus()
		await _frames(25)
		var r: Rect2 = screen._tiles[i].get_global_rect()
		always_visible = always_visible and view.encloses(r)
		var focused: Array = screen._tiles.filter(func(t: Button) -> bool: return t.has_focus())
		one_cursor = one_cursor and focused.size() == 1
	_check(always_visible, "walking to the last tile and back, the focused tile is always inside the screen")
	_check(one_cursor, "exactly one tile has the focus (the yellow frame) at each step")
	var longest := 0
	for i in screen._tiles.size():
		if tr(screen._tiles[i].game.title).length() > tr(screen._tiles[longest].game.title).length():
			longest = i
	screen._tiles[longest].grab_focus()
	await _frames(25)
	var tile: Control = screen._tiles[longest]
	var labels := tile.find_children("*", "Label", true, false)
	var fits := not labels.is_empty()
	for l in labels:
		var w: float = l.get_theme_font("font").get_string_size(l.tr(l.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
				l.get_theme_font_size("font_size")).x
		fits = fits and (l.autowrap_mode != TextServer.AUTOWRAP_OFF or w <= l.size.x + 1.0)
	_check(fits and view.grow(-60.0).encloses(tile.get_global_rect()),
			"the focused tile with the longest title fits and is inside the 60 px margin")
	root.size = Vector2i(1280, 720)
