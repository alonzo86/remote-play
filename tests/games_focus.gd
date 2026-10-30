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
	await _room_checks(app)
	await _cue_checks(app)
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
		for step in 8:   # Up as often as it takes: from the second row it takes two presses, from the fourth row four.
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


## The scroll cue (REQ-FL-12a): a down arrow while rows are hidden below, an up arrow while rows are hidden above, none at the
## other end, in English and in Hebrew, and inside the 60 px margin.
func _cue_checks(app: Node) -> void:
	var Arrow = load("res://scripts/ui/scroll_arrow.gd")
	_check(Arrow.more_below(0, 400, 1000) and not Arrow.more_below(600, 400, 1000),
			"more_below: true in the middle, false at the end")
	_check(Arrow.more_above(50) and not Arrow.more_above(0), "more_above: true when scrolled, false at the top")
	_check(not Arrow.more_below(1610, 626, 2252), "more_below: false when only the 16 px padding of the grid is hidden")
	for code in ["en", "he"]:
		app.set_language(code, false)
		app.go_games()
		await _frames(20)
		var screen: Control = app.current_screen()
		_check(not screen._arrow_up.active and screen._arrow_down.active,
				"%s: at the top only the down arrow is on" % code)
		screen._tiles[screen._tiles.size() - 1].grab_focus()
		await _frames(30)
		_check(screen._arrow_up.active and not screen._arrow_down.active, "%s: at the last row only the up arrow is on" % code)
		screen._tiles[screen._tiles.size() / 2].grab_focus()
		await _frames(30)
		var bar: VScrollBar = screen._scroll.get_v_scroll_bar()
		if bar.value > 1.0 and bar.value + bar.page < bar.max_value - 1.0:
			_check(screen._arrow_up.active and screen._arrow_down.active, "%s: in the middle both arrows are on" % code)
		var view := Rect2(60, 60, 1800, 960)
		root.size = Vector2i(1920, 1080)
		await _frames(5)
		_check(view.encloses(screen._arrow_down.get_global_rect()) and view.encloses(screen._arrow_up.get_global_rect()),
				"%s: the arrows are inside the 60 px margin" % code)
		root.size = Vector2i(1280, 720)
		await _frames(5)
	# With enough room for all rows nothing is hidden, so no arrow is on.
	root.size = Vector2i(1920, 3000)
	app.go_games()
	await _frames(20)
	var tall: Control = app.current_screen()
	_check(not tall._arrow_up.active and not tall._arrow_down.active, "when all rows fit, no arrow is on")
	root.size = Vector2i(1280, 720)
	app.set_language("en", false)


## The room code is always in the header (REQ-FL-15a): with 0 and with 4 players, in English and in Hebrew, inside the 60 px
## margin, not over a tile, and it follows the address.
func _room_checks(app: Node) -> void:
	for code in ["en", "he"]:
		for n in [0, 4]:
			app.set_language(code, false)
			for i in 4:
				app.server.players[i].state = 1 if i < n else 0
			app.server.address_lookup = func(): return "192.168.1.77"   # The server looks the address up again from time to time.
			app.server.ip = "192.168.1.77"
			app.go_games()
			await _frames(20)
			var screen: Control = app.current_screen()
			var label: Label = screen._room
			var tag := "room code, %s, %d players" % [code, n]
			var shown: bool = label != null and label.is_visible_in_tree()
			_check(shown and label.text == app.server.room_code and label.text.length() == 4, tag + ": visible and equal to the TV code")
			var r := label.get_global_rect()
			var vp := root.get_visible_rect().size
			_check(r.position.x >= 60.0 and r.end.x <= vp.x - 60.0 and r.position.y >= 0.0, tag + ": inside the safe margin")
			var clear := true
			for t in screen._tiles:
				clear = clear and not r.intersects(t.get_global_rect())
			_check(clear, tag + ": does not cover a tile")
			_check(label.focus_mode == Control.FOCUS_NONE, tag + ": is not a focus target")
			var rtl: bool = code == "he"
			var b: Rect2 = screen._badge.get_global_rect()
			_check(r.position.x >= b.end.x if rtl else r.end.x <= b.position.x, tag + ": next to the badge on the title side")
	var old_code: String = app.current_screen()._room.text
	app.server.address_lookup = func(): return "10.0.5.9"
	app.server.ip = "10.0.5.9"   # A new address while the screen is open: the code follows within 2 frames.
	await _frames(2)
	var now: String = app.current_screen()._room.text
	_check(now == app.server.room_code and now != old_code, "room code: follows a new address")
	app.server.address_lookup = func(): return ""
	app.server.ip = ""
	app.go_games()
	await _frames(5)
	_check(app.current_screen()._room.text == "----", "room code: a TV with no address shows ----")
