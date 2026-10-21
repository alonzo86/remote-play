extends SceneTree
## The TV remote (docs/MANUAL_TESTS.md tests 8 and 8b): the arrow keys and OK reach every screen as
## key events, the focus frame and
## cursor, Back one step at a time, the quit question, the debug overlay on the Menu key, and the Games screen in Hebrew. The real
## remote and the real Android Back key stay manual (test 8R); this checks everything after the key reaches the engine.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/focus_walk.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _checks := 0
var _fails := 0
var _app: Node
var _phones: Array[ControllerClient] = []
var _games_script: GDScript
var _connect_script: GDScript
var _settings_script: GDScript


func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


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


func _wait_until(cond: Callable, max_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


## A key of the remote as an input action (the engine maps the keys to these actions).
func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var up := InputEventAction.new()   # A button acts when the key is let go.
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


## A real key event (Back, Menu, F3, Enter and the arrows), as Android TV sends it.
func _key(keycode: Key) -> void:
	if keycode == KEY_BACK:
		_app._last_back_ms = 0   # Two Back presses inside 250 ms count once (tested in ui_states_a).
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = keycode
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


func _frame_color(tile: Button) -> Color:
	return (tile._frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _run() -> void:
	await _frames(5)
	_app = root.get_node("App")
	_games_script = load("res://scripts/ui/tv_games.gd")
	_connect_script = load("res://scripts/ui/tv_connect.gd")
	_settings_script = load("res://scripts/ui/tv_settings.gd")
	root.size = Vector2i(1920, 1080)   # A headless window is tiny; the TV is 1920 x 1080.
	await _frames(3)
	if not _app.server.listening:
		_check(false, "the TV server listens (another TV app or test holds port %d)" % Protocol.WS_PORT)
		return
	_app.settings.language = "en"
	_app.set_language("en")
	await _logo()
	await _join_phones()
	await _keys_map_to_actions()
	await _overlay()
	await _games_walk()
	await _focus_style()
	await _modal_walk()
	await _settings_walk()
	await _tiles_in_hebrew()
	await _game_flow()
	await _quit_question()
	for p in _phones:
		p.leave()
		p.queue_free()


## 8b.1b: OK on the logo goes to Connect within 1 s.
func _logo() -> void:
	print("logo")
	_app.go_logo()
	await _frames(3)
	var t0 := Time.get_ticks_msec()
	await _press("ui_accept")
	var ok := await _wait_until(func(): return _app.current_screen().get_script() == _connect_script, 1000)
	_check(ok, "OK on the logo reaches Connect in %d ms (less than 1 s)" % (Time.get_ticks_msec() - t0))


func _join_phones() -> void:
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Walk%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		_phones.append(c)
	await _wait_until(func(): return _app.server.connected_slots().size() >= 2, 4000)


## The keys of a remote are mapped to the UI actions of the project (project.godot): an arrow key, Enter, Escape/Back.
func _keys_map_to_actions() -> void:
	print("key mapping")
	var wanted := {"ui_up": KEY_UP, "ui_down": KEY_DOWN, "ui_left": KEY_LEFT, "ui_right": KEY_RIGHT, "ui_accept": KEY_ENTER,
			"ui_cancel": KEY_ESCAPE}
	var missing: Array[String] = []
	for action in wanted:
		var found := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and (ev.keycode == wanted[action] or ev.physical_keycode == wanted[action]):
				found = true
		if not found:
			missing.append(action)
	_check(missing.is_empty(), "the arrow keys, Enter and Escape are mapped to the UI actions (missing: %s)" % str(missing))
	var dpad := InputEventKey.new()
	dpad.keycode = KEY_DOWN
	dpad.pressed = true
	_check(dpad.is_action("ui_down") and InputMap.event_is_action(dpad, "ui_down"), "a Down key event is the action ui_down")


## 8.4: Menu and F3 toggle the debug overlay, whose first line is DEBUG, the room, the address and a frame rate.
func _overlay() -> void:
	print("debug overlay")
	_app.go_connect()
	await _frames(3)
	if _app.overlay.visible:
		_app.toggle_overlay()
	await _key(KEY_MENU)
	_check(_app.overlay.visible, "the Menu key shows the debug overlay")
	await _key(KEY_MENU)
	_check(not _app.overlay.visible, "the Menu key hides it again")
	await _key(KEY_F3)
	_check(_app.overlay.visible, "F3 shows it")
	var overlay_script: GDScript = load("res://scripts/ui/debug_overlay.gd")   # Not a preload: it uses the App autoload.
	var head: String = overlay_script.header_text(_app.server.room_code, "192.168.1.20", 60.0)
	var re := RegEx.create_from_string("^DEBUG\\s+room [A-Z]{4}\\s+[0-9.]+:\\d+\\s+\\d+ FPS$")
	_check(re.search(head) != null, "the first line has DEBUG, the room, the address and a number before FPS: '%s'" % head)
	var live: String = overlay_script.header_text(_app.server.room_code, "?", Engine.get_frames_per_second())
	_check(live.begins_with("DEBUG") and live.contains("room " + _app.server.room_code), "and it carries the room of this TV")
	await _key(KEY_F3)
	_check(not _app.overlay.visible, "F3 hides it")


## 8.1a: on the Games screen each arrow key moves the focus, and OK presses the focused item.
func _games_walk() -> void:
	print("Games screen")
	_app.go_games()
	await _frames(6)
	var games: Control = _app.current_screen()
	var start: Control = _focus()
	_check(start != null and start in games._tiles, "a tile has the focus on the Games screen")
	var seen := {}
	var before := start
	for action in ["ui_right", "ui_down", "ui_left", "ui_up"]:
		await _press(action)
		var now := _focus()
		_check(now != null and now != before, "%s moves the focus to another item (%s)" % [action,
				now.name if now != null else "none"])
		before = now
	# 8a: from the first tile, the OPTIONS button is reachable in at most 2 key presses (up, then right).
	games._tiles[0].grab_focus()
	await _frames(2)
	var presses := 0
	while _focus() != games._gear and presses < 6:
		await _press("ui_up" if _focus() in games._tiles else "ui_right")
		presses += 1
	_check(_focus() == games._gear and presses <= 2,
			"OPTIONS is reached from the first tile in %d key presses (at most 2)" % presses)
	seen["gear"] = true
	await _press("ui_accept")
	_check(_app.current_screen().get_script() == _settings_script, "OK on OPTIONS opens Settings")
	await _key(KEY_BACK)
	_check(_app.current_screen().get_script() == _games_script and _app.current_screen()._gear.has_focus(),
			"Back from Settings returns to OPTIONS")


## 8.1b and 1d: the focused item is yellow and has a cursor, a destructive one is red; the frame, the text and the contrast.
func _focus_style() -> void:
	print("focus style")
	var theme: Theme = _app.theme_res
	_check(theme.get_color("font_focus_color", "Button") == UiTheme.ACCENT and theme.get_color("font_focus_color",
			"DangerButton") == UiTheme.BAD,
			"a focused item is yellow and a focused destructive item is red")
	_check(UiTheme.contrast(UiTheme.ACCENT, UiTheme.BG) >= 7.0,
			"the yellow of the focus has a contrast of 7:1 or more on black (%.1f)"
			% UiTheme.contrast(UiTheme.ACCENT, UiTheme.BG))
	_check(UiTheme.contrast(UiTheme.BAD, UiTheme.BG) >= 4.5, "the red of a destructive item has 4.5:1 or more on black (%.1f)"
			% UiTheme.contrast(UiTheme.BAD, UiTheme.BG))
	_check(UiTheme.LINE >= 4 and UiTheme.SIZE_BODY >= 28, "the focus frame is at least 4 px (%d) and the text at least 28 px (%d)"
			% [UiTheme.LINE, UiTheme.SIZE_BODY])
	_app.go_games()
	await _frames(6)
	var games: Control = _app.current_screen()
	games._tiles[0].grab_focus()
	await _frames(3)
	var tile: Button = _focus()
	var frame := (tile._frame.get_theme_stylebox("panel") as StyleBoxFlat)
	_check(frame.border_color == UiTheme.ACCENT and frame.border_width_left >= 4,
			"the focused tile has a yellow frame of %d px" % frame.border_width_left)
	var others_dim: bool = games._tiles.all(func(t): return t == tile or _frame_color(t) == UiTheme.TEXT_DIM)
	_check(others_dim, "and the other tiles have a gray frame")
	# A menu item with the focus has a cursor: its drawing uses the focus color of the theme.
	_app.go_game_settings("maze")
	await _frames(4)
	var items: Array = _app.current_screen().find_children("*", "Button", true, false).filter(func(b): return b.has_focus())
	_check(items.size() == 1 and items[0].focus_mode == Control.FOCUS_ALL, "one item of the settings view has the focus")
	_app.go_games()
	await _frames(3)


## 8b.8b: with the Players modal open, the arrow keys stay in the modal and no tile gets the frame.
func _modal_walk() -> void:
	print("Players modal")
	_app.go_games()
	await _frames(6)
	var games: Control = _app.current_screen()
	games._open_players()
	await _frames(4)
	var modal: Control = games._modal
	_check(modal != null, "the badge opens the Players modal")
	var stayed := true
	for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		for i in 5:
			await _press(action)
			var f := _focus()
			if f == null or not modal.is_ancestor_of(f):
				stayed = false
	_check(stayed, "20 arrow presses (5 each way) keep the focus inside the modal")
	var framed: Array = games._tiles.filter(func(t): return _frame_color(t) == UiTheme.ACCENT)
	_check(framed.is_empty(), "and no tile under the modal has the yellow frame")
	await _key(KEY_BACK)
	_check(games._modal == null, "Back closes the modal")


## 8.1a for Settings: the arrow keys walk through all rows, and the rows stay on the screen (8b.10a).
func _settings_walk() -> void:
	print("Settings screen")
	_app.go_settings()
	await _frames(6)
	var screen: Control = _app.current_screen()
	var first := _focus()
	_check(first != null, "a row of Settings has the focus")
	var visible_rect := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var inside := true
	var seen := {}
	for i in 12:
		var f := _focus()
		if f != null:
			seen[f.get_instance_id()] = true
			if not visible_rect.encloses(f.get_global_rect()):
				print("    outside: ", f.name, " ", f.get_global_rect())
				inside = false
		await _press("ui_down")
	_check(seen.size() >= 4, "Down walks through the rows of Settings (%d different rows)" % seen.size())
	_check(inside, "every focused row is inside the screen (%s)" % str(visible_rect))
	var back: Control = null
	for b in screen.find_children("*", "Button", true, false):
		if b.text == "common.back":
			back = b
	_check(back == null or visible_rect.encloses(back.get_global_rect()), "and the Back row is inside the screen")
	await _press("ui_up")
	_check(_focus() != null, "Up keeps a focus")
	_app.go_games()
	await _frames(3)


## 8b.8c and 10b: in Hebrew and in English, the cursor and the title of the focused tile do not touch, and only that title moves.
func _tiles_in_hebrew() -> void:
	print("tiles in Hebrew")
	for lang in ["he", "en"]:
		_app.set_language(lang)
		_app.go_games()
		await _frames(8)
		var games: Control = _app.current_screen()
		games._tiles[0].grab_focus()
		await _frames(3)
		var tile: Button = _focus()
		var cursor_w: float = UiTheme.CURSOR_UNIT * 4.0
		var cursor := Rect2(Vector2(tile.size.x - cursor_w if lang == "he" else 0.0, tile.SHOT.y + 36.0 - 17.5),
				Vector2(cursor_w, 35.0))
		var title: Rect2 = tile._name.get_rect()
		var gap: float = (title.position.x - cursor.end.x) if lang == "en" else (cursor.position.x - title.end.x)
		_check(not cursor.intersects(title) and gap > 0.0,
				"[%s] the cursor and the title do not touch (gap %.0f px)" % [lang, gap])
		var shifted: Array = games._tiles.filter(func(t): return t._name.size.x < t.SHOT.x)
		_check(shifted == [tile], "[%s] only the title of the focused tile moves (%d tiles moved)" % [lang, shifted.size()])
		var over: Array[String] = []
		for t in games._tiles:
			if t._name.get_minimum_size().x > t.SHOT.x:
				over.append("%s %d px" % [t.game.id, t._name.get_minimum_size().x])
		_check(over.is_empty(), "[%s] every title fits in its tile (too wide: %s)" % [lang, str(over)])
		_check(games._tiles.all(func(t): return t._meta.get_minimum_size().y <= 80.0),
				"[%s] every player range fits in its box" % lang)
	_app.set_language("en")


## 8.2: the pause menu and the end of a game with the remote.
func _game_flow() -> void:
	print("pause, Back and End game")
	var maze: GDScript = load("res://scripts/game/maze/maze_game.gd")
	_app.go(maze)
	var game: Control = _app.current_screen()
	await _wait_until(func(): return game._can_open_menu(), 8000)
	await _frames(3)
	await _press("ui_accept")
	_check(game.is_paused(), "OK opens the pause menu")
	var entries: Array = game.menu_buttons().map(func(b): return b.text)
	_check(entries == ["minigame.resume", "minigame.restart", "minigame.end_game"],
			"the pause menu has 3 items: %s" % str(entries))
	_check(game.menu_buttons()[2].theme_type_variation == "DangerButton", "End game in the pause menu is a destructive (red) item")
	var clock: float = game._ring_time
	await create_timer(1.5).timeout
	_check(game._ring_time == clock, "the game clock stands still while the menu is open")
	# Back on the pause menu closes it (Back is Keep playing); Back during play opens the question.
	await _key(KEY_BACK)
	_check(not game.is_paused(), "Back on the pause menu goes on with the game")
	await _frames(3)
	var running: float = game._ring_time
	await create_timer(0.5).timeout
	_check(game._ring_time > running, "and the game clock runs again")
	await _key(KEY_BACK)
	var ask: Array = game.menu_buttons().map(func(b): return b.text)
	_check(game.is_paused() and ask == ["minigame.resume_play", "minigame.end_game"],
			"Back during play asks END THE GAME?: %s" % str(ask))
	_check(_focus() == game.menu_buttons()[0], "RESUME PLAY has the focus")
	var stopped: float = game._ring_time
	await create_timer(1.0).timeout
	_check(game._ring_time == stopped, "the clock stays stopped while the question is open")
	_check(game.menu_buttons()[1].theme_type_variation == "DangerButton", "END GAME is a destructive (red) item")
	await _key(KEY_BACK)
	_check(not game.is_paused(), "Back on the question resumes the game")
	await _frames(3)
	await _key(KEY_BACK)
	game.menu_buttons()[1].pressed.emit()
	await _frames(4)
	_check(_app.current_screen().get_script() == _games_script, "END GAME goes to the Games screen")
	_check(_app.server.connected_slots().size() == 2, "and the players stay")


## 8.3 and 8.6: Back from Games goes to Connect, Back on Connect asks to quit, STAY has the focus, Quit calls the quit.
func _quit_question() -> void:
	print("quit question")
	var quits := [0]
	_app.quit_hook = func(): quits[0] += 1
	_app.go_games()
	await _frames(4)
	var slots_before: int = _app.server.connected_slots().size()
	_app._last_back_ms = 0
	await _key(KEY_BACK)
	var on_connect: bool = _app.current_screen().get_script() == _connect_script
	_check(on_connect and _app.server.connected_slots().size() == slots_before,
			"Back from Games leads to Connect and the players stay")
	await create_timer(0.3).timeout
	_app._last_back_ms = 0
	var connect: Control = _app.current_screen()
	# The Android Back key arrives as a notification, not as a key.
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(4)
	_check(connect._modal != null and quits[0] == 0, "the Back notification of Android opens QUIT SABABI? and does not quit")
	_check(_focus() != null and _focus().text == "connect.stay", "STAY has the focus")
	_check(ProjectSettings.get_setting("application/config/quit_on_go_back", true) == false,
			"the engine does not quit on Back by itself")
	await create_timer(0.3).timeout
	_app._last_back_ms = 0
	await _key(KEY_BACK)
	_check(connect._modal == null and quits[0] == 0, "Back again closes the question (Stay)")
	await create_timer(0.3).timeout
	_app._last_back_ms = 0
	await _key(KEY_BACK)
	for b in connect.find_children("*", "Button", true, false):
		if b.text == "connect.quit":
			_check(b.theme_type_variation == "DangerButton", "QUIT is a destructive (red) item")
			b.pressed.emit()
	await _frames(2)
	_check(quits[0] == 1, "QUIT calls the quit of the app once (%d)" % quits[0])
	_app.quit_hook = Callable()
