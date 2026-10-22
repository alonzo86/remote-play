extends SceneTree
## Player profiles on the TV (FD-22, tests 20.1 and 20.6 of docs/MANUAL_TESTS.md): the Players list shows the name and the
## avatar of
## each profile phone, the result menu shows names and no "Player N", the pause card names the phone that lost its connection
## (also
## two phones with 10 letter names, in English and in Hebrew, inside the screen edge) and offers Resume when it is back.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/tv_profiles.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")
const Lang = preload("res://scripts/core/lang.gd")

const ID_A := "9f2c4e7a1b3d5f60718293a4b5c6d7e8"
const ID_B := "00112233445566778899aabbccddeeff"

var _checks := 0
var _fails := 0
var _app: Node
var _maze: GDScript


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


func _wait_while(cond: Callable, ms: int) -> void:
	var start := Time.get_ticks_msec()
	while cond.call() and Time.get_ticks_msec() - start < ms:
		await process_frame


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false)


func _texts(node: Node) -> Array:
	return _labels(node).map(func(l): return String(l.text))


func _run() -> void:
	await _frames(5)
	_app = root.get_node("App")
	_maze = load("res://scripts/game/maze/maze_game.gd")
	_app.settings.language = "en"
	_app.set_language("en", false)
	await _phones_and_card()
	await _two_long_names()
	_app.set_language("en", false)


func _phone(pid: String, p_name: String, av: int) -> ControllerClient:
	var c := ControllerClient.new()
	root.add_child(c)
	c.set_profile(pid, p_name, av)
	c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
	return c


## Steps 1a, 1c, 6a1, 6b: two phones with profiles over the network.
func _phones_and_card() -> void:
	print("two profile phones")
	_app.go_games()
	await _frames(3)
	var maya := _phone(ID_A, "Maya", 3)
	var noam := _phone(ID_B, "Noam", 7)
	await _wait_while(func(): return _app.server.connected_slots().size() < 2, 4000)
	await _frames(3)
	var games: Control = _app.current_screen()
	games._open_players()
	await _frames(3)
	var modal: Node = games._modal
	var rows: Array = modal.find_children("*", "HBoxContainer", true, false).filter(
			func(h): return h.find_children("*", "Label", false, false).any(func(l): return l.text in ["MAYA", "NOAM", "Maya", "Noam"]))
	var found := {}
	for h in rows:
		var avatars: Array = h.get_children().filter(func(n): return n is AvatarView)
		for l in h.find_children("*", "Label", false, false):
			if l.text.to_upper() in ["MAYA", "NOAM"] and avatars.size() == 1:
				found[l.text.to_upper()] = avatars[0].index
	_check(found == {"MAYA": 3, "NOAM": 7},
			"the Players list shows the name and the avatar of each profile phone, and the avatar replaces 1P: %s" % str(found))
	_check(not _texts(modal).any(func(t): return t == "1P" or t == "2P"), "a profile phone has no 1P or 2P text in the list")
	games.on_back()
	await _frames(2)

	# The result menu names the profiles, and no label on the TV says "Player 1" (step 1c).
	_app.go(_maze)
	await _frames(4)
	var game: Control = _app.current_screen()
	var board := Scoreboard.new([], true)
	board.set_score(0, 31.0)
	board.set_score(1, 40.0)
	game.open_results(board)
	await _frames(2)
	var result_texts := _texts(game._menu_box)
	_check(result_texts.any(func(t): return t.contains("MAYA")) and result_texts.any(func(t): return t.contains("NOAM")),
			"the result menu shows the names of the profiles: %s" % str(result_texts))
	var player_n := RegEx.create_from_string("(?i)^\\s*player\\s*\\d")
	var bad: Array = []
	for l in _labels(_app):
		if player_n.search(String(l.text)) != null:
			bad.append(String(l.text))
	_check(bad.is_empty(), "no label on the TV says Player 1 / Player 2 while the phones have profiles: %s" % str(bad))
	game.close_menu()
	_app.go(_maze)   # A new round: the first one is over. Wait for the countdown.
	await _frames(4)
	game = _app.current_screen()
	await create_timer(3.6).timeout

	# Step 6a1: a silent phone (no Wi-Fi) pauses the game with its name, within the timeout of the protocol.
	_check(Protocol.PEER_TIMEOUT_MS <= 3000,
			"a silent phone is given up after 3 s or less (PEER_TIMEOUT_MS %d)" % Protocol.PEER_TIMEOUT_MS)
	_app.server.peer_timeout_ms = Protocol.PEER_TIMEOUT_MS
	noam.set_process(false)
	var t0 := Time.get_ticks_msec()
	await _wait_while(func(): return not game._hold, 12000)
	var took := Time.get_ticks_msec() - t0
	await _frames(3)
	_check(game._hold and took <= Protocol.PEER_TIMEOUT_MS + 1500,
			"the game pauses within %d ms of the last packet of the phone: %d ms" % [Protocol.PEER_TIMEOUT_MS + 1500, took])
	var title: String = _labels(game._menu_box)[0].text
	var buttons: Array = game.menu_buttons().map(func(b): return b.text)
	_check(title == "NOAM LOST CONNECTION" and buttons == ["RESUME WITHOUT NOAM", "minigame.end_game"],
			"the card names the phone by its profile and offers Resume without it: %s %s" % [title, str(buttons)])
	# Step 6b: the phone is back: the card says so and offers Resume.
	noam.set_process(true)
	await _wait_while(func(): return not game.lost_participants().is_empty(), 8000)
	await _frames(5)
	title = _labels(game._menu_box)[0].text
	buttons = game.menu_buttons().map(func(b): return b.text)
	_check(game.is_paused() and title == "NOAM RECONNECTED" and buttons == ["minigame.resume", "minigame.end_game"],
			"when the phone is back the card says NOAM RECONNECTED and offers Resume: %s %s" % [title, str(buttons)])
	game.menu_buttons()[0].pressed.emit()
	await _frames(3)
	_check(not game.is_paused() and game.participants == [0, 1], "Resume goes on with both players")
	maya.leave()
	noam.leave()
	await _frames(5)
	for p in _app.server.players:
		if p.is_present():
			_app.server.drop_player(p.slot)
	await _frames(2)


## Steps 6c and 6d: two lost phones with 10 letter names. The card shows both names whole, inside the 60 px edge of the screen, in
## English and Hebrew; a Hebrew name stays in its typed order inside the English sentence and an English name inside the Hebrew
## one.
func _two_long_names() -> void:
	print("the card with two long names")
	for i in 4:
		_app.server.players[i].state = PlayerInput.State.CONNECTED
	_app.go(_maze)
	await _frames(4)
	var game: Control = _app.current_screen()
	var marks := [0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069]
	var cases := [
		{"lang": "en", "a": "ABCDEFGHIJ", "b": "KLMNOPQRST"},
		{"lang": "he", "a": "ABCDEFGHIJ", "b": "KLMNOPQRST"},
		{"lang": "en", "a": "מאיהמאיה", "b": "KLMNOPQRST"},
		{"lang": "he", "a": "מאיהמאיה", "b": "KLMNOPQRST"},
	]
	for c in cases:
		_app.set_language(c.lang, false)
		_app.server.players[0].set_profile(ID_A, 1, c.a)
		_app.server.players[0].player_name = c.a
		_app.server.players[1].set_profile(ID_B, 2, c.b)
		_app.server.players[1].player_name = c.b
		game._hold_info.clear()
		game._show_hold_card([0, 1] as Array[int])
		await _frames(3)
		var title_label: Label = _labels(game._menu_box)[0]
		var title := String(title_label.text)
		var label := "%s card, names %s and %s" % [c.lang, c.a, c.b]
		_check(title.contains(String(c.a).to_upper()) and title.contains(String(c.b).to_upper())
				and title.find(String(c.a).to_upper()) < title.find(String(c.b).to_upper()),
				"%s: the title has both names whole, in the typed order, a before b: %s" % [label, title])
		var has_mark := false
		for i in title.length():
			if title.unicode_at(i) in marks:
				has_mark = true
		_check(not has_mark, "%s: Lang.f adds no direction mark to the text" % label)
		var card: Control = game._menu_box.get_child(0)
		var r := card.get_global_rect()
		var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		_check(screen.grow(-60.0).grow(0.5).encloses(r),
				"%s: the card is inside the 60 px edge: %s of %s" % [label, str(r), str(screen)])
		var title_rect := title_label.get_global_rect()
		_check(r.encloses(title_rect) and title_label.get_minimum_size().x <= r.size.x,
				"%s: the title is inside the card (not cut): %s in %s" % [label, str(title_rect), str(r)])
		game.close_menu()
	_app.set_language("en", false)
	for i in 4:
		_app.server.players[i].state = PlayerInput.State.EMPTY
		_app.server.players[i].set_profile("", -1, "")
