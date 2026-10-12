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
