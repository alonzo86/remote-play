extends SceneTree
## The result of a game on the phone (issue #455, REQ-FL-67a, step 3c of Test 19): at the end of every game each phone shows
## the line of its own row of the TV result list, centered, with only the HOLD TO DISCONNECT box, until the next round.
## Three parts: (1) every game ends through the shared result menu, (2) that menu sends each phone the text of its row,
## (3) a real TV server and the phone pad: the line shows, only the leave box shows and works, buttons return next round. Run:
##   godot --headless --path . --script tests/phone_result_line.gd -- --role=controller
## The flag `--role=controller` is needed: without it the App makes no phone client.

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")

# Not the game port: it depends on the process (as in pad_pause.gd).
var PORT := 47000 + OS.get_process_id() % 900
var _checks := 0
var _fails := 0
var _server: TvServer
var _client: ControllerClient
var _pad: Control


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


func _wait_until(cond: Callable, max_ms := 3000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _run() -> void:
	await process_frame
	_every_game_uses_the_shared_result()
	await _menu_sends_rows()
	await _pad_shows_the_line()


## The phone line comes from the shared result menu, so a game that ends in its own way would have a phone with buttons.
func _every_game_uses_the_shared_result() -> void:
	print("every game ends in the shared result menu")
	var games := Registry.all()
	var missing: Array[String] = []
	var own: Array[String] = []
	for g in games:
		var dir := String(g.path).get_base_dir()
		var shared := false
		var bypass := false
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var text := FileAccess.get_file_as_string(dir + "/" + file)
				shared = shared or text.contains("open_results(") or text.contains("open_result_menu(")
				bypass = bypass or text.contains("send_final(")
		if not shared:
			missing.append(String(g.id))
		if bypass:
			own.append(String(g.id))
	_check(games.size() >= 12, "the registry lists the games: %d" % games.size())
	_check(missing.is_empty(), "each game opens its result with open_results() or open_result_menu(): missing %s" % str(missing))
	_check(own.is_empty(), "no game sends the line of its own (the base class does): %s" % str(own))


## The base class sends each phone with a row the text of that row, as the TV list shows it.
func _menu_sends_rows() -> void:
	print("the result menu sends each phone its row")
	var Minigame = load("res://scripts/game/minigame.gd")
	var host = load("res://tests/stub_game_host.gd").new()
	var game = Minigame.new()
	game.game_host = host
	root.add_child(game)
	await process_frame
	game.player(0).player_name = "Noa"
	game.player(2).player_name = "Dan"
	var board := Scoreboard.new([0, 2])
	board.set_score(0, 12.0)
	board.set_unfinished(2, 0.4)
	host.calls.clear()
	game.open_results(board)
	var finals: Array = host.calls.filter(func(c: Array) -> bool: return c[0] == "final")
	_check(finals.size() == 2, "both phones get a line: %d" % finals.size())
	var n0: String = game.player(0).player_name
	var n2: String = game.player(2).player_name
	_check(["final", 0, "%s   %s   12" % [Scoreboard.ordinal(1), n0]] in finals,
			"the winner gets place, name and score: %s" % str(finals))
	_check(["final", 2, "%s   %s   %s" % [Scoreboard.ordinal(2), n2, Lang.t("result.not_finished")]] in finals,
			"a player without a score gets 'not finished' as the TV shows it")
	var flat := str(finals)
	_check(not flat.contains("#") and not flat.contains("avatar"), "the line has no color and no avatar")
	game.queue_free()
	await process_frame


func _pad_shows_the_line() -> void:
	print("the pad shows the line and only the leave box")
	var app: Node = root.get_node("App")
	_client = app.client
	_server = TvServer.new()
	_server.port = PORT
	root.add_child(_server)
	_server.start({})
	_server.set_phase("menu")
	_client.connect_to("127.0.0.1", PORT, _server.room_code)
	await _wait_until(func(): return _client.state == ControllerClient.State.CONNECTED)
	var holder := Control.new()
	holder.size = Vector2(1080, 1920)
	root.add_child(holder)
	_pad = load("res://scripts/ui/controller_pad.gd").new()
	_pad.theme = app.theme_res
	holder.add_child(_pad)
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	_pad._sampler.set_process(false)

	var slot: int = _client.slot
	_server.set_phase("playing")
	await _wait_until(func(): return _client.phase == "playing")
	var a: Vector2 = _pad._center_a()
	var leave: Vector2 = _pad._rect_leave().get_center()
	var recenter: Vector2 = _pad._rect_recenter().get_center()
	var pause: Vector2 = _pad._rect_pause().get_center()
	_check(_pad._button_shown("a") and _pad._button_shown("b") and _pad._recenter_shown() and _pad._pause_shown()
			and not _pad._result_shown(), "during play: A, B, RECENTER and the pause button show")
	_check(_pad._zone_at(a) == "a" and _pad._zone_at(leave) == "leave" and _pad._zone_at(recenter) == "recenter"
			and _pad._zone_at(pause) == "pause", "during play: a finger on each of them is in its zone")

	var line := "1st   Noa   12"
	_server.send_final(slot, line)
	await _wait_until(func(): return _client.final_text == line)
	_check(_client.final_text == line, "the phone has the line of the TV: '%s'" % _client.final_text)
	_check(_pad._result_shown(), "the pad shows the result")
	_check(not _pad._button_shown("a") and not _pad._button_shown("b") and not _pad._recenter_shown()
			and not _pad._pause_shown() and not _pad._aim_mode(), "no A, B, RECENTER, pause button or aim strip shows")
	_check(_pad._zone_at(a) == "pad" and _pad._zone_at(recenter) == "pad" and _pad._zone_at(pause) == "pad",
			"a finger on the old places of A, RECENTER and the pause button presses nothing")
	_check(_pad._zone_at(leave) == "leave", "a finger on the HOLD TO DISCONNECT box is in its zone (REQ-FL-67a)")
	var aim_pos: Vector2 = _pad._rect_aim().get_center()
	_check(_pad._zone_at(aim_pos) == "pad" and _pad._zone_at(_pad._center_b()) == "pad", "the aim strip and B are dead too")
	_check(not _pad._rect_leave().intersects(_pad._rect_final()), "the leave box does not overlap the line")
	_layout_does_not_overlap(holder)
	await _short_tap_does_nothing(leave, slot)
	var r: Rect2 = _pad._rect_final()
	_check(is_equal_approx(r.get_center().y, _pad.size.y * 0.5) and is_equal_approx(r.get_center().x, _pad.size.x * 0.5),
			"the line is centered on the middle of the screen: %s" % str(r.get_center()))
	_check("".join(_pad.final_lines(line, r.size.x)) == line.to_upper(), "the line is the TV text in capitals, none cut")
	var long: Array[String] = _pad.final_lines("1st   WWWWWWWWWW   NOT FINISHED", r.size.x)
	_check("".join(long).replace(" ", "") == "1STWWWWWWWWWWNOTFINISHED",
			"a long line wraps and keeps every letter: %s" % str(long))

	_server.set_phase("paused")
	await _wait_until(func(): return _client.phase == "paused")
	_server.set_phase("playing")
	await _wait_until(func(): return _client.phase == "playing")
	_check(_client.final_text == line and _server._final_sent.has(slot), "a pause and its resume keep the line")

	_server.set_phase("playing")   # The next round (Try again) is a phase message that follows a phase 'playing'.
	await _wait_until(func(): return _client.final_text == "")
	_check(_client.final_text == "" and not _pad._result_shown(), "the next round clears the line")
	_check(_pad._button_shown("a") and _pad._button_shown("b") and _pad._recenter_shown() and _pad._pause_shown()
			and _pad._zone_at(leave) == "leave", "and the buttons are back")

	_server.send_final(slot, line)
	await _wait_until(func(): return _client.final_text == line)
	_server.set_phase("menu")
	await _wait_until(func(): return _client.phase == "menu")
	_check(_client.final_text == "" and _server._final_sent.is_empty(), "the menu clears the line on the phone and on the TV")
	await _returning_and_new_phone(slot, line)
	await _older_phone(line)
	_client.leave()
	_server.stop()


func _touch(pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 5
	e.pressed = pressed
	e.position = pos
	return e


## The box and the line do not meet on a small phone (720x1280), a 1080x1920 and a tall one; the longest line (60 characters,
## wrapped) is about 76 px per row, centered on the middle.
func _layout_does_not_overlap(holder: Control) -> void:
	var longest := "".rpad(60, "W")
	for sz in [Vector2(720, 1280), Vector2(1080, 1920), Vector2(1080, 1440), Vector2(1080, 2400)]:
		holder.size = sz
		_pad.size = sz
		var rows: int = _pad.final_lines(longest, _pad._rect_final().size.x).size()
		var half := rows * 76.0 * 0.5
		var mid: float = _pad.size.y * 0.5
		_check(mid + half < _pad._rect_leave().position.y and _pad._zone_at(Vector2(sz.x * 0.5, mid)) == "pad",
				"%s: %d rows of the longest line end at %.0f, above the box at %.0f" % [str(sz), rows, mid + half,
				_pad._rect_leave().position.y])
	holder.size = Vector2(1080, 1920)
	_pad.size = holder.size


## A tap on the box (shorter than 0.8 s) does not leave the TV while the line shows.
func _short_tap_does_nothing(leave: Vector2, slot: int) -> void:
	_pad._input(_touch(true, leave))
	_pad._process(0.5)
	_pad._input(_touch(false, leave))
	_pad._process(0.5)
	_check(_client.state == ControllerClient.State.CONNECTED and _client.slot == slot and _pad._leave_hold == 0.0,
			"a short tap on the box does not leave the TV")
	_pad._input(_touch(true, _pad._center_a()))
	_pad._process(2.0)
	_check(_client.state == ControllerClient.State.CONNECTED and _pad._leave_hold == 0.0,
			"a long press on the old place of A does nothing")
	_pad._input(_touch(false, _pad._center_a()))


## A hold of 0.8 s on the box while the line shows leaves the TV, and the box fills from left to right.
func _hold_leaves(slot: int) -> void:
	var leave: Vector2 = _pad._rect_leave().get_center()
	_pad._input(_touch(true, leave))
	_pad._process(0.4)
	_check(_pad._leave_hold > 0.39 and _client.state == ControllerClient.State.CONNECTED, "0.4 s: the box is half full, still here")
	_pad._process(0.45)
	_check(not _server.players[slot].is_present() or _client.slot == -1 or _client.state != ControllerClient.State.CONNECTED,
			"after 0.8 s on the box the phone leaves the TV")
	await _wait_until(func(): return not _server.players[slot].is_present(), 4000)


## The same phone that returns while the result is open gets its line again; a new phone in a freed slot gets none.
func _returning_and_new_phone(slot: int, line: String) -> void:
	print("a phone that returns, and a new phone")
	_server.set_phase("playing")
	await _wait_until(func(): return _client.phase == "playing")
	_server.send_final(slot, line)
	await _wait_until(func(): return _client.final_text == line)
	_client._close_socket()   # The link drops; the phone reconnects with its token.
	_client._on_closed()
	await _wait_until(func(): return _client.state == ControllerClient.State.CONNECTED and _client.final_text == line, 8000)
	_check(_client.state == ControllerClient.State.CONNECTED and _client.slot == slot and _client.final_text == line,
			"the same phone returns during the result and gets its line again: '%s'" % _client.final_text)
	_check(not _pad._button_shown("a") and not _pad._pause_shown(), "and its pad shows no A and no pause button")
	await _hold_leaves(slot)
	await _wait_until(func(): return not _server.players[slot].is_present(), 4000)
	_server.drop_player(slot)
	_check(not _server._final_sent.has(slot), "the row of a player that left is forgotten")
	var other := ControllerClient.new()
	root.add_child(other)
	other.connect_to("127.0.0.1", PORT, _server.room_code)
	await _wait_until(func(): return other.state == ControllerClient.State.CONNECTED)
	await create_timer(0.3).timeout
	_check(other.state == ControllerClient.State.CONNECTED and other.final_text == "",
			"a new phone that joins during the result gets no line (slot %d)" % other.slot)
	other.leave()
	other.queue_free()


## A phone of an older build has no handler for `final`: the message is an unknown type and changes nothing (change-protocol).
func _older_phone(line: String) -> void:
	print("an older phone")
	var old := ControllerClient.new()
	root.add_child(old)
	var before := [old.phase, old.score_text, old.final_text, old.pad_buttons, old.recenter_button]
	old._handle({"t": "final_v99_unknown", "v": line}, Time.get_ticks_msec())   # What an older build does with `final`.
	_check([old.phase, old.score_text, old.final_text, old.pad_buttons, old.recenter_button] == before,
			"a message of a type the phone does not know changes nothing: the pad stays")
	old.queue_free()
