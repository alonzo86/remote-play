extends SceneTree
## The TV start, the Connect screen, the Players modal, the Games tiles, the remote on every kind of screen, Back in a game and on
## a result menu, the three cards in English and Hebrew, the Hebrew result menu and the late phone (docs/MANUAL_TESTS.md
## tests 1, 8 and 8b: the machine half of the steps 1.1c/1d/1e/1f, 8.1a/2c/2f, 8b.1a/1c/2a/3a/4b/4c/5b/9a/9b/10d). The real
## remote, the real Android Back key and the real TV box stay manual. Steps that depend on the PIN change with issue #52
## (marked "#52").
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r1_tv_screens.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")

## The titles of the three cards in both languages (the Hebrew ones are the texts of the step 8b.9b).
const CARD_TITLES := {
	"minigame.no_players_connected": {"en": "NO PLAYERS CONNECTED",
			"he": "\u05d0\u05d9\u05df \u05e9\u05d7\u05e7\u05e0\u05d9\u05dd \u05de\u05d7\u05d5\u05d1\u05e8\u05d9\u05dd"},
	"minigame.paused": {"en": "PAUSED", "he": "\u05de\u05d5\u05e9\u05d4\u05d4"},
	"minigame.end_game_ask": {"en": "END THE GAME?",
			"he": "\u05dc\u05e1\u05d9\u05d9\u05dd \u05d0\u05ea \u05d4\u05de\u05e9\u05d7\u05e7?"},
}

var _checks := 0
var _fails := 0
var _app: Node
var _quits := [0]
var _saved_settings := ""
var _had_settings := false
var _orig_lookup: Callable
var _connect_script: GDScript
var _logo_script: GDScript
var _games_script: GDScript
var _qr_script: GDScript
var _slot_list_script: GDScript
var _maze: GDScript
var _race: GDScript


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A known bug of the game: it counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) (", issue, ") ", what)


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


## An arrow key or OK of a remote as an input action (press, two frames, release).
func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


## A real key event, as Android TV sends it (Back, Enter).
func _key(keycode: Key) -> void:
	if keycode == KEY_BACK:
		_app._last_back_ms = 0   # Two Back presses inside 250 ms count once (tested in ui_states_a).
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(2)
	await _frames(1)


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false)


func _label_texts(node: Node) -> Array:
	return _labels(node).map(func(l): return String(l.text))


## The nodes under `node` that run `script`.
func _with_script(node: Node, script: GDScript) -> Array:
	return node.find_children("*", "Control", true, false).filter(func(n): return n.get_script() == script)


func _screen_is(script: GDScript) -> bool:
	return _app.current_screen().get_script() == script


func _join(n: int) -> Array[ControllerClient]:
	var out: Array[ControllerClient] = []
	for i in n:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		out.append(c)
	await _wait_until(func(): return _app.server.connected_slots().size() >= n, 5000)
	await _frames(2)
	return out


func _leave(phones: Array[ControllerClient]) -> void:
	for c in phones:
		c.leave()
		c.queue_free()
	await _wait_until(func(): return _app.server.connected_slots().is_empty(), 4000)
	await _frames(2)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	await _frames(3)
	_app = root.get_node("App")
	if not _app.server.listening:
		_check(false, "the TV server listens (another TV app or test holds port %d)" % Protocol.WS_PORT)
		return
	_connect_script = load("res://scripts/ui/tv_connect.gd")
	_logo_script = load("res://scripts/ui/tv_logo.gd")
	_games_script = load("res://scripts/ui/tv_games.gd")
	_qr_script = load("res://scripts/ui/qr_view.gd")
	_slot_list_script = load("res://scripts/ui/slot_list.gd")
	_maze = load("res://scripts/game/maze/maze_game.gd")
	_race = load("res://scripts/game/marble_race/marble_race.gd")
	_had_settings = FileAccess.file_exists(_app.SETTINGS_FILE)
	_saved_settings = FileAccess.get_file_as_string(_app.SETTINGS_FILE) if _had_settings else ""
	_orig_lookup = _app.server.address_lookup
	_app.quit_hook = func(): _quits[0] += 1
	_app.settings.language = "en"
	_app.set_language("en", false)
	await _logo_time()
	await _first_start()
	await _logo_back()
	await _connect_screen()
	await _no_address()
	await _players_modal()
	await _tiles()
	var phones: Array[ControllerClient] = await _join(2)
	await _walk_screens()
	await _back_in_game()
	await _back_on_results()
	await _leave(phones)
	await _cards()
	await _hebrew_results()
	await _late_phone()
	_app.quit_hook = Callable()
	_app.server.address_lookup = _orig_lookup
	_app.set_language("en", false)
	if _had_settings:
		FileAccess.open(_app.SETTINGS_FILE, FileAccess.WRITE).store_string(_saved_settings)
	elif FileAccess.file_exists(_app.SETTINGS_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_app.SETTINGS_FILE))


# ---- Test 1 items 1c, 1d and Test 8b items 1a, 1c: the logo screen ----

## 1d and 8b.1a (the logic half): with a saved language the logo goes on to Connect after 2.0 to 3.0 s (REQ-FL-2).
func _logo_time() -> void:
	print("the logo screen lasts 2 to 3 s")
	_app.settings.language = "en"
	_app.go_logo()
	var t0 := Time.get_ticks_msec()
	_check(_screen_is(_logo_script), "the logo screen shows")
	var left := await _wait_until(func(): return _screen_is(_connect_script), 5000)
	var ms := Time.get_ticks_msec() - t0
	_check(left and ms >= 2000 and ms <= 3000, "the Connect screen shows %d ms after the logo (2000 to 3000 ms, REQ-FL-2)" % ms)


## 1c: at the first start (no saved language) the logo does not go on until OK; OK chooses the language that has the focus.
func _first_start() -> void:
	print("the first start waits for OK")
	_app.settings.language = ""
	_app.go_logo()
	await _frames(3)
	var logo: Control = _app.current_screen()
	_check(logo.asks_language and logo.language_buttons.size() == 2, "the first start asks for the language")
	await create_timer(3.5).timeout   # More than the 2.5 s of the normal logo.
	_check(_app.current_screen() == logo and not logo._done, "3.5 s later the logo is still there: it waits for OK")
	await _key(KEY_ENTER)
	var gone := await _wait_until(func(): return _screen_is(_connect_script), 2000)
	_check(gone and String(_app.settings.language) in Lang.CODES, "OK chooses the language and the Connect screen follows")
	_app.settings.language = "en"
	_app.set_language("en", false)


## 8b.1c: Back on the logo screen skips it and does not quit, as a key and as the Android Back request.
func _logo_back() -> void:
	print("Back on the logo screen")
	_quits[0] = 0
	_app.go_logo()
	await _frames(3)
	_app._last_back_ms = 0
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	_check(_screen_is(_connect_script) and _quits[0] == 0,
			"the Android Back request on the logo shows the Connect screen and does not quit")
	await create_timer(3.0).timeout
	_check(_screen_is(_connect_script) and _quits[0] == 0 and _app.server.listening,
			"3 s later the app is still open on the Connect screen")
	_app.go_logo()
	await _frames(3)
	await _key(KEY_BACK)
	_check(_screen_is(_connect_script) and _quits[0] == 0, "the Back key on the logo shows the Connect screen and does not quit")


# ---- Test 1 items 1e, 1f and Test 8b item 3a ----

func _use_address(ip: String) -> void:
	_app.server.address_lookup = func() -> String: return ip
	_app.server.ip = ip


## 1e: the PLAYERS screen has a QR code with the join link, the room code of 4 letters (of the TV address), no PIN and 4 slots.
func _connect_screen() -> void:
	print("the PLAYERS screen")
	_use_address("192.168.1.20")
	_app.go_connect()
	await _frames(4)
	var screen: Control = _app.current_screen()
	var qrs := _with_script(screen, _qr_script)
	_check(qrs.size() == 1, "the screen has one QR code")
	var qr: Control = qrs[0]
	var pair := Protocol.parse_pair_url(qr.text)
	_check(not pair.is_empty() and pair.host == "192.168.1.20" and pair.room == _app.server.room_code
			and not pair.has("pin") and not qr.text.contains("pin") and qr._qr.size() >= 21,
			"the QR code holds the link with the address and the room code, and no PIN: %s" % qr.text)
	var room: String = _app.server.room_code
	var regex_room := RegEx.create_from_string("^[A-Z]{4}$")
	_check(regex_room.search(room) != null and _label_texts(screen).has(room),
			"the room code is 4 letters and shown on the screen: %s" % room)
	_check(room == Protocol.room_code_for_ip("192.168.1.20"), "and it is the code of the TV address 192.168.1.20")
	var texts := _label_texts(screen)
	_check(texts.has("connect.room_code") and Lang.t("connect.room_code") == "ROOM CODE" and not texts.has("pin.name"),
			"the words ROOM CODE are on the screen, and no PIN")
	_check(texts.has("connect.same_wi_fi") and texts.has("connect.open_app_scan_code") and texts.has("connect.or_type_code"),
			"the help says: same Wi-Fi, scan the code, or type the room code")
	var lists := _with_script(screen, _slot_list_script)
	_check(lists.size() == 1 and lists[0].get_child_count() == 4
			and ["1P", "2P", "3P", "4P"].all(func(s): return texts.has(s)), "the screen has 4 slots, 1P to 4P")


## 1f: a TV with no network address shows an empty QR code and the line that says so.
func _no_address() -> void:
	print("a TV with no network address")
	_use_address("")
	_app.go_connect()
	await _frames(4)
	var screen: Control = _app.current_screen()
	var qr: Control = _with_script(screen, _qr_script)[0]
	_check(qr.text == "" and qr._qr.is_empty(), "the QR code is empty without an address")
	_check(screen._hint.text == "connect.no_wi_fi_address" and screen._hint.get_theme_color("font_color") == UiTheme.BAD
			and Lang.t("connect.no_wi_fi_address").begins_with("NO WI-FI ADDRESS"),
			"the red line says that the TV has no network address: '%s'" % Lang.t("connect.no_wi_fi_address"))


## 8b.3a: the Players modal has 4 slots, the QR code and the room code (no PIN). 8b.5b (the token half): the frame of the
## modal is white outside and blue inside, the focused tile is framed in yellow and the others in gray, the screen is black.
func _players_modal() -> void:
	print("the Players modal")
	_use_address("192.168.1.20")
	_app.go_games()
	await _frames(8)
	var games: Control = _app.current_screen()
	games._open_players()
	await _frames(6)
	var modal: Control = games._modal
	_check(modal != null, "the badge opens the Players modal")
	var qrs := _with_script(modal, _qr_script)
	_check(qrs.size() == 1 and qrs[0].text == Protocol.pair_url("192.168.1.20", _app.server.room_code),
			"the modal has the QR code of the join link")
	var texts := _label_texts(modal)
	_check(texts.has(_app.server.room_code), "the modal shows the room code %s" % _app.server.room_code)
	_check(not texts.any(func(t): return String(t).contains("pin.")), "the modal shows no PIN")
	var lists := _with_script(modal, _slot_list_script)
	_check(lists.size() == 1 and lists[0].get_child_count() == 4, "the modal has 4 slots")
	var frame = modal.card.get_theme_stylebox("panel")
	_check(frame.outer_color == UiTheme.TEXT and frame.inner_color == UiTheme.FRAME and UiTheme.FRAME == Color("0058f8"),
			"the frame of the modal is white outside and blue inside")
	modal.close()
	await _frames(3)
	var tile_focus: Button = _focus()
	var others_gray: bool = games._tiles.all(func(t): return (t == tile_focus or
			(t._frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color == UiTheme.TEXT_DIM))
	_check(tile_focus in games._tiles and others_gray
			and (tile_focus._frame.get_theme_stylebox("panel") as StyleBoxFlat).border_color == UiTheme.ACCENT,
			"the focused tile has a yellow frame and the other tiles a gray frame")
	var clear = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	_check(UiTheme.BG == Color.BLACK and clear == UiTheme.BG and UiTheme.ACCENT == Color("f8b800"),
			"the screen is black and the focus is yellow")


# ---- Test 8b item 2a: the tiles ----

func _tiles() -> void:
	print("the tiles of the Games screen")
	for i in 2:
		_app.server.players[i].state = 1   # Two phones are joined: every tile shows its player range.
	_app.go_games()
	await _frames(10)
	var tiles: Array = _app.current_screen()._tiles
	_check(tiles.size() == Registry.all().size() and tiles.size() >= 9, "one tile for each game of the registry (%d)" % tiles.size())
	var no_picture: Array[String] = []
	var no_title: Array[String] = []
	var no_range: Array[String] = []
	for t in tiles:
		var id := String(t.game.id)
		var shots: Array = t.find_children("*", "TextureRect", true, false)
		var tex: Texture2D = shots[0].texture if shots.size() == 1 else null
		var placeholder: bool = not t.find_children("*", "ColorRect", true, false).is_empty()
		if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0 or placeholder:
			no_picture.append(id)
		if String(t._name.text) == "" or Lang.t(String(t.game.title)) == String(t.game.title):
			no_title.append(id)
		if String(t._meta.text) == "" or String(t._meta.text) != t.players_text().to_upper():
			no_range.append(id)
	_check(no_picture.is_empty(), "every tile shows its picture, no color placeholder (missing: %s)" % str(no_picture))
	_check(no_title.is_empty(), "every tile has a title that is a text of the table (wrong: %s)" % str(no_title))
	_check(no_range.is_empty(), "every tile shows its player range (wrong: %s)" % str(no_range))
	for i in 2:
		_app.server.players[i].reset()
	await _frames(2)


# ---- Test 8 item 1a: the remote on every kind of screen ----

## The arrow keys move the focus and OK acts on the Connect screen (the quit question), the settings view of a game, the pause
## menu and the result menu. The Games screen, the Players modal and Settings are in focus_walk.
func _walk_screens() -> void:
	print("the remote on the Connect screen, the settings view, the pause menu and the result menu")
	_quits[0] = 0
	_app.go_connect()
	await _frames(4)
	var connect: Control = _app.current_screen()
	_check(connect.find_children("*", "Button", true, false).is_empty() and _focus() == null,
			"the Connect screen has no button: nothing has the focus (REQ-FL-6)")
	connect.on_back()   # The quit question: the only items of the Connect screen.
	await _frames(25)
	var stay: Control = _focus()
	_check(stay != null and stay.text == "connect.stay", "the quit question has STAY in focus")
	await _press("ui_down")
	_check(_focus() != stay and _focus().text == "connect.quit", "Down moves the focus to QUIT")
	await _press("ui_up")
	_check(_focus() == stay, "Up moves it back to STAY")
	await _key(KEY_ENTER)
	_check(connect._modal == null and _screen_is(_connect_script) and _quits[0] == 0, "OK on STAY closes the question")

	_app.go_game_settings("maze")
	await _frames(25)
	var sv: Control = _app.current_screen()
	_check(_focus() == sv.start_button, "the settings view opens with Start in focus (issue #226)")
	var moved := false
	var presses := 0
	while _focus() != sv.rows[0] and presses < sv.rows.size() + 3:
		var before := _focus()
		await _press("ui_up")
		moved = moved or _focus() != before
		presses += 1
	_check(moved and _focus() == sv.rows[0],
			"Up moves the focus from Start through the rows to the first row (%d presses)" % presses)
	presses = 0
	while _focus() != sv.start_button and presses < sv.rows.size() + 3:
		await _press("ui_down")
		presses += 1
	_check(_focus() == sv.start_button, "Down moves the focus through the rows back to Start (%d presses)" % presses)
	await _key(KEY_ENTER)
	var started := await _wait_until(func(): return _screen_is(_maze), 2000)
	_check(started, "OK on Start begins the game")

	var game: Control = _app.current_screen()
	await _press("ui_accept")
	_check(game.is_paused(), "OK in the game opens the pause menu")
	var buttons: Array = game.menu_buttons()
	_check(buttons.size() == 3 and _focus() == buttons[0], "the pause menu has 3 items and the first has the focus")
	await _press("ui_down")
	_check(_focus() == buttons[1], "Down moves the focus to the second item")
	await _press("ui_up")
	_check(_focus() == buttons[0], "Up moves it back to the first item")
	await _key(KEY_ENTER)
	_check(not game.is_paused(), "OK on Resume closes the pause menu")

	var board := Scoreboard.new([0, 1], true)
	board.set_score(0, 12.3)
	board.set_score(1, 15.0)
	game.open_results(board)
	await _frames(3)
	buttons = game.menu_buttons()
	_check(buttons.size() >= 2 and _focus() == buttons[0], "the result menu has the first item in focus")
	var walked := true
	for i in range(1, buttons.size()):
		await _press("ui_down")
		walked = walked and _focus() == buttons[i]
	_check(walked, "Down walks through the %d items of the result menu" % buttons.size())
	_check(buttons[-1].text == "minigame.back_to_menu", "the last item is Back to menu")
	await _key(KEY_ENTER)
	var back := await _wait_until(func(): return _screen_is(_games_script), 2000)
	_check(back, "OK on Back to menu opens the Games screen")


# ---- Test 8 items 2c and 2f ----

## 2c: Back in a game opens the question, and the timer shows the same value 5 s later (REQ-FL-55). The Android Back request
## and the key do the same.
func _back_in_game() -> void:
	print("Back in a game")
	_quits[0] = 0
	_app.go(_maze)
	await _frames(3)
	var game: Control = _app.current_screen()
	await _wait_until(func(): return game._round.is_playing(), 6000)
	_app._last_back_ms = 0
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	var ask: Array = game.menu_buttons().map(func(b): return b.text)
	_check(game.is_paused() and ask == ["minigame.resume", "minigame.end_game"] and _quits[0] == 0,
			"the Android Back request in the game opens END THE GAME? (%s) and does not quit" % str(ask))
	var round_time: float = game._round.time
	var ring: float = game._ring_time
	await create_timer(5.0).timeout
	_check(game._round.time == round_time and game._ring_time == ring and game.is_paused() and _app.current_screen() == game,
			"5 s later the timer shows the same value (%.2f s) and the game still waits" % round_time)
	await _key(KEY_BACK)
	_check(not game.is_paused(), "the Back key on the question goes on with the game")
	await _frames(3)
	await _key(KEY_BACK)
	ask = game.menu_buttons().map(func(b): return b.text)
	_check(game.is_paused() and ask == ["minigame.resume", "minigame.end_game"],
			"the Back key in the game opens the question too")
	game.menu_buttons()[1].pressed.emit()
	await _frames(4)
	_check(_screen_is(_games_script) and _quits[0] == 0, "END GAME opens the Games screen")


## 2f: Back on the result menu leaves for the Games screen at once, with no question (REQ-GM-31a, REQ-MR-34).
func _back_on_results() -> void:
	print("Back on a result menu")
	for script in [_race, _maze]:
		var is_race: bool = script == _race
		_app.go(script, {"track_choice": "1"} if is_race else {})
		await _frames(4)
		var game: Control = _app.current_screen()
		var board := Scoreboard.new([0, 1], true)
		board.set_score(0, 31.5)
		board.set_score(1, 40.0)
		game.open_results(board)
		await _frames(3)
		_check(game.is_over and game.menu_buttons().size() >= 2, "[%s] the result menu is open" % ("race" if is_race else "maze"))
		await _key(KEY_BACK)
		await _frames(3)
		var left := _screen_is(_games_script)
		_check(left, "[%s] Back on the result menu opens the Games screen at once (REQ-GM-31a, REQ-MR-34)"
				% ("race" if is_race else "maze"))
		if not left:
			_app.go_menu()
			await _frames(3)


# ---- Test 8b items 9a, 9b: the three cards ----

## The title of the card is white, the items are white and yellow only with the focus, and in Hebrew the title is on one line.
func _card_checks(game: Control, key: String, lang: String) -> void:
	var card: Control = game._menu_box
	var title: Label = _labels(card)[0]
	var want: String = CARD_TITLES[key][lang]
	_check(title.text == key and Lang.t(key) == want, "[%s] the card says '%s'" % [lang, Lang.t(key)])
	_check(title.get_theme_color("font_color") == UiTheme.TEXT, "[%s] '%s': the title is white" % [lang, want])
	if lang == "he":
		_check(title.get_line_count() == 1, "[he] '%s': the title is on one line (%d)" % [want, title.get_line_count()])
	var wrong: Array[String] = []
	var focused := 0
	for b in game.menu_buttons():
		var danger: bool = b.theme_type_variation == &"DangerButton"
		var focus_color: Color = UiTheme.BAD if danger else UiTheme.ACCENT
		if b.get_theme_color("font_color") != UiTheme.TEXT or b.get_theme_color("font_focus_color") != focus_color:
			wrong.append(String(b.text))
		if b.has_focus():
			focused += 1
	_check(wrong.is_empty() and focused == 1 and game.menu_buttons()[0].has_focus(),
			"[%s] '%s': the items are white, yellow only with the focus, and one item has it (wrong: %s)" % [lang, want, str(wrong)])


func _cards() -> void:
	print("the three cards")
	for lang in ["en", "he"]:
		_app.set_language(lang, false)
		var phones: Array[ControllerClient] = await _join(1)
		_app.go(_maze)
		await _frames(4)
		var game: Control = _app.current_screen()
		await _press("ui_accept")
		await _frames(2)
		_check(game.is_paused(), "[%s] OK opens the pause menu" % lang)
		_card_checks(game, "minigame.paused", lang)
		await _key(KEY_BACK)
		_check(not game.is_paused(), "[%s] Back closes it" % lang)
		await _frames(3)
		await _key(KEY_BACK)
		await _frames(2)
		_check(game.is_paused(), "[%s] Back in the game opens the question" % lang)
		_card_checks(game, "minigame.end_game_ask", lang)
		await _key(KEY_BACK)
		await _frames(3)
		phones[0].leave()   # The Disconnect button of the phone frees the slot at once.
		var over := await _wait_until(func(): return game.is_over and game._menu_box != null, 4000)
		await _frames(3)
		_check(over, "[%s] the last phone leaves and the card opens" % lang)
		if over:
			_card_checks(game, "minigame.no_players_connected", lang)
		phones[0].queue_free()
		_app.go_menu()
		await _wait_until(func(): return _app.server.connected_slots().is_empty(), 3000)
		await _frames(3)
	_app.set_language("en", false)


# ---- Test 8b item 10d: the result menu in Hebrew ----

## The time says the Hebrew seconds (ש׳) and each row has the avatar next to the color square, in Hebrew and in English.
func _hebrew_results() -> void:
	print("the result menu with profiles")
	for lang in ["he", "en"]:
		_app.set_language(lang, false)
		for i in 2:
			var p = _app.server.players[i]
			p.state = 1
			p.player_name = ["נועה", "דני"][i]
			p.avatar = 3 + i
		_app.go(_maze)
		await _frames(4)
		var mz: Control = _app.current_screen()
		mz._round.time = -0.005
		mz._game_tick(0.01)
		mz._balls[0].pos = mz._exit_center()
		mz._game_tick(0.016)
		await _frames(6)
		_check(mz.is_over and mz._menu_box != null, "[%s] a ball in the exit opens the result menu" % lang)
		var rows: Array = mz._menu_box.find_children("*", "HBoxContainer", true, false).filter(
				func(h): return h.get_children().any(func(c): return c is ColorRect))
		_check(rows.size() == 2, "[%s] the result menu has 2 rows" % lang)
		if rows.size() == 2:
			var time_text := String(_labels(rows[0])[0].text)
			var unit_ok: bool = time_text.ends_with("ש׳") if lang == "he" else time_text.ends_with(" S")
			_check(unit_ok, "[%s] the time of the winner ends with the unit of seconds: '%s'" % [lang, time_text])
			var near := true
			var indexes := []
			for r in rows:
				var squares: Array = r.get_children().filter(func(c): return c is ColorRect)
				var avatars: Array = r.get_children().filter(func(c): return c is AvatarView)
				if squares.size() != 1 or avatars.size() != 1:
					near = false
					continue
				var s: Rect2 = squares[0].get_global_rect()
				var a: Rect2 = avatars[0].get_global_rect()
				var gap := maxf(a.position.x - s.end.x, s.position.x - a.end.x)
				near = near and gap >= 0.0 and gap <= 30.0 and a.position.y < s.end.y and s.position.y < a.end.y
				indexes.append(avatars[0].index)
			_check(near and indexes == [3, 4], "[%s] each row has the avatar of its player next to the color square: %s" % [lang,
					str(indexes)])
		for i in 2:
			_app.server.players[i].reset()
		_app.go_menu()
		await _frames(4)
	_app.set_language("en", false)


# ---- Test 8b items 4b, 4c: the late phone ----

func _late_phone() -> void:
	print("a phone that joins during a round")
	var phones: Array[ControllerClient] = await _join(2)
	_app.go(_maze)
	await _frames(4)
	var game: Control = _app.current_screen()
	var late := ControllerClient.new()
	late.player_name = "Late"
	root.add_child(late)
	late.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
	await _wait_until(func(): return late.state == ControllerClient.State.CONNECTED, 4000)
	await _frames(5)
	_check(late.state == ControllerClient.State.CONNECTED and late.phase == "waiting", "the late phone joins and waits")
	_check(game.participants.size() == 2 and not game.participants.has(late.slot) and game._balls.size() == 2
			and not game._balls.any(func(b): return b.slot == late.slot), "the late phone has no object in the running game")
	game.restart()
	await _frames(4)
	var next: Control = _app.current_screen()
	_check(next != game and next.participants.has(late.slot) and next._balls.size() == 3
			and next._balls.any(func(b): return b.slot == late.slot), "the next round has an object for the late phone")
	late.leave()
	late.queue_free()
	await _leave(phones)
	_app.go_menu()
	await _frames(3)
