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
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")
const Medal = preload("res://scripts/ui/medal.gd")

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
	# The base class sends `g` = Registry.id_of_script(get_script()) for each of them: the id must find the game, and the phone must
	# have its name in both languages (an unknown id draws no game line).
	var pad_script: GDScript = load("res://scripts/ui/controller_pad.gd")
	var no_id: Array[String] = []
	var no_name: Array[String] = []
	for g in games:
		if Registry.id_of_script(load(String(g.path)) as Script) != String(g.id):
			no_id.append(String(g.id))
		for code in ["en", "he"]:
			Lang.set_language(code)
			if pad_script.game_name(String(g.id)) == "":
				no_name.append("%s/%s" % [g.id, code])
	Lang.set_language("en")
	_check(no_id.is_empty(), "the id that the result sends as `g` is the registry id of each game: wrong %s" % str(no_id))
	_check(no_name.is_empty(), "the phone has the name of each game from `g`, in English and in Hebrew: missing %s" % str(no_name))


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
	_check(_final_of(finals, 0)[2] == "%s   %s   12" % [Scoreboard.ordinal(1), n0],
			"the winner gets place, name and score as the old one-line text: %s" % str(finals))
	_check(_final_of(finals, 2)[2] == "%s   %s   %s" % [Scoreboard.ordinal(2), n2, Lang.t("result.not_finished")],
			"a player without a score gets 'not finished' as the TV shows it")
	var flat := str(finals)
	_check(not flat.contains("#") and not flat.contains("avatar"), "the line has no color and no avatar")
	# The same row in pieces for the three lines of the phone: the place, the score text as the row shows it, the medal.
	var p0: Dictionary = _final_of(finals, 0)[3]
	var p2: Dictionary = _final_of(finals, 2)[3]
	_check(p0.get("p") == Scoreboard.ordinal(1) and p0.get("s") == "12" and p0.get("m") == "gold",
			"the winner's pieces: place 1ST, score 12, a gold medal: %s" % str(p0))
	_check(p2.get("p") == Scoreboard.ordinal(2) and p2.get("s") == Lang.t("result.not_finished") and p2.get("m") == "",
			"a player that did not finish: its place, NOT FINISHED and no medal: %s" % str(p2))
	_check(not str(p0).contains(n2) and not str(p2).contains(n0) and p0.get("s") != p2.get("s"),
			"a phone gets its own row only: no piece has the name or the score of the other phone")
	await _medal_per_place(game, host)
	game.queue_free()
	await process_frame
	await _real_game_sends_its_id()


func _final_of(finals: Array, slot: int) -> Array:
	for c in finals:
		if c[1] == slot:
			return c
	return ["final", slot, "", {}]


## The medal of the row of each place (REQ-GM-73): 1st gold, 2nd silver, 3rd bronze, a tie shares the medal, the 4th and a player
## who did not finish have none, one player has none, a player that stays after the others left has a technical win (gold).
func _medal_per_place(game, host) -> void:
	print("the medal of each place")
	var four: Array[int] = [0, 1, 2, 3]
	host.slots = four
	for sl in 4:
		game.player(sl).player_name = "P%d" % sl
	game.players_at_start = 4
	var board := Scoreboard.new([0, 1, 2, 3])
	for sl in 4:
		board.set_score(sl, [12.0, 9.0, 7.0, 3.0][sl])
	host.calls.clear()
	game.open_results(board)
	var finals: Array = host.calls.filter(func(c: Array) -> bool: return c[0] == "final")
	var tiers := []
	for sl in 4:
		tiers.append(String(_final_of(finals, sl)[3].get("m", "")) if _final_of(finals, sl)[3].get("m", "") != "" else "none")
	_check(tiers == ["gold", "silver", "bronze", "none"], "1st gold, 2nd silver, 3rd bronze, 4th none: %s" % str(tiers))
	board = Scoreboard.new([0, 1, 2, 3])
	for sl in 4:
		board.set_score(sl, [12.0, 12.0, 7.0, 3.0][sl])
	host.calls.clear()
	game.open_results(board)
	finals = host.calls.filter(func(c: Array) -> bool: return c[0] == "final")
	_check(_final_of(finals, 0)[3].get("m") == "gold" and _final_of(finals, 1)[3].get("m") == "gold"
			and _final_of(finals, 0)[3].get("p") == _final_of(finals, 1)[3].get("p"), "a tie for 1st: both gold, the same place")
	board = Scoreboard.new([0, 1, 2, 3])
	board.set_score(0, 12.0)
	board.set_unfinished(1, 0.4)
	host.calls.clear()
	game.open_results(board)
	finals = host.calls.filter(func(c: Array) -> bool: return c[0] == "final")
	_check(_final_of(finals, 1)[3].get("m") == "" and _final_of(finals, 1)[3].get("s") == Lang.t("result.not_finished"),
			"a player that did not finish has no medal: %s" % str(_final_of(finals, 1)[3]))
	game.players_at_start = 1   # One player from the start: no medal at all.
	board = Scoreboard.new([0])
	board.set_score(0, 12.0)
	host.calls.clear()
	game.open_results(board)
	finals = host.calls.filter(func(c: Array) -> bool: return c[0] == "final")
	_check(_final_of(finals, 0)[3].get("m") == "" and _final_of(finals, 0)[3].get("p") == Scoreboard.ordinal(1),
			"one player from the start: place 1ST and no medal")
	game.players_at_start = 3   # The others left: the one that stays wins technically and has the gold medal.
	board = Scoreboard.new([2])
	board.set_score(2, 5.0)
	host.calls.clear()
	game.open_results(board)
	finals = host.calls.filter(func(c: Array) -> bool: return c[0] == "final")
	_check(_final_of(finals, 2)[3].get("m") == "gold", "a technical win (the others left) has the gold medal")
	var two: Array[int] = [0, 2]
	host.slots = two


## A real game (not the base class) sends the registry id of the game as `g`.
func _real_game_sends_its_id() -> void:
	var host = load("res://tests/stub_game_host.gd").new()
	var script: GDScript = Registry.load_script("snowball_splat")
	var game = script.new()
	game.game_host = host
	root.add_child(game)
	await process_frame
	var board := Scoreboard.new([0, 2])
	board.set_score(0, 12.0)
	board.set_score(2, 8.0)
	host.calls.clear()
	game.open_results(board)
	var finals: Array = host.calls.filter(func(c: Array) -> bool: return c[0] == "final")
	_check(finals.size() == 2 and _final_of(finals, 0)[3].get("g") == "snowball_splat"
			and _final_of(finals, 2)[3].get("g") == "snowball_splat", "a real game (Banana Party) sends its registry id as g: %s" % str(finals))
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
	_pad.leave_drawn = false
	await process_frame
	await process_frame
	_check(_pad._leave_shown() and _pad.leave_drawn, "the HOLD TO DISCONNECT box is drawn while the result shows")
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

	await _three_lines_over_the_wire(slot, line)
	await _block_layout(app)
	await _new_best_line(app)
	_set_final("", "", "", "")
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
## wrapped) is one line step of the pad per row, centered on the middle.
func _layout_does_not_overlap(holder: Control) -> void:
	var longest := "".rpad(60, "W")
	for sz in [Vector2(720, 1280), Vector2(1080, 1920), Vector2(1080, 1440), Vector2(1080, 2400)]:
		holder.size = sz
		_pad.size = sz
		var rows: int = _pad.final_lines(longest, _pad._rect_final().size.x).size()
		var half := rows * UiTheme.line_step(UiTheme.font(), _pad.LINE_SIZE) * 0.5
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
	_check(_client.slot == -1 and _client.state != ControllerClient.State.CONNECTED,
			"after 0.8 s on the box the phone leaves the TV")
	_check(await _wait_until(func(): return not _server.players[slot].is_present(), 4000), "and the TV frees its slot")


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


func _set_final(g: String, p: String, sc: String, m: String) -> void:
	_client.final_game = g
	_client.final_place = p
	_client.final_score = sc
	_client.final_medal = m


## The parts of `final` reach the phone, are cleaned like `v`, and an older TV (only `v`) or an older phone (only reads `v`) still works.
func _three_lines_over_the_wire(slot: int, line: String) -> void:
	print("the three lines over the wire")
	_server.send_final(slot, line, {"g": "snowball_splat", "p": "1st", "s": "12", "m": "gold"})
	await _wait_until(func(): return _client.final_place == "1st")
	_check(_client.final_game == "snowball_splat" and _client.final_place == "1st" and _client.final_score == "12"
			and _client.final_medal == "gold" and _client.final_text == line, "the phone has g, p, s, m and v of its row")
	_check(_pad._result_shown() and _pad._final_structured(), "the pad shows the three lines")
	var kept: Dictionary = _server._final_sent[slot]
	_check(kept.get("v") == line and kept.get("t") == "final" and kept.keys().size() == 6,
			"the message keeps `v` (an older phone reads only that) and adds g, p, s, m: %s" % str(kept))
	var nothing := {"t": "final", "v": line}
	_client._handle(nothing, Time.get_ticks_msec())
	_check(_client.final_text == line and _client.final_place == "" and _client.final_game == "" and not _pad._final_structured()
			and _pad._result_shown(), "an older TV (no p, no s): the pad falls back to the one line v and has no game line")
	_client._handle({"t": "final", "v": "x", "g": "a\nb", "p": "1ST\u0007", "s": "W".repeat(80), "m": "platinum"}, Time.get_ticks_msec())
	_check(_client.final_game == "a b" and _client.final_place == "1ST" and _client.final_score.length() == 60
			and _client.final_medal == "",
			"each part is cleaned like v (control characters to spaces, 60 characters); a medal that is not gold, silver or bronze is none")
	_client._handle({"t": "final", "v": 5, "g": [1], "p": {"a": 1}, "s": 3, "m": null}, Time.get_ticks_msec())
	_check(_client.final_game == "" and _client.final_place == "" and _client.final_score == "" and _client.final_medal == "",
			"parts of the wrong type are empty")
	_server.send_final(slot, line)   # An older game host: no parts at all.
	await _wait_until(func(): return _client.final_place == "" and _client.final_text == line)
	var sent: Dictionary = _server._final_sent[slot]
	_check(not sent.has("p") and not sent.has("g") and not sent.has("m") and not sent.has("s"), "a field that is empty is not sent")
	_client.clear_final()
	_check(_client.final_text == "" and _client.final_game == "" and _client.final_place == "" and _client.final_score == ""
			and _client.final_medal == "", "the end of the result clears every part")
	_client.final_text = line
	_set_final("snowball_splat", "1ST", "12", "gold")


## The block: game name, place row, line 3, in this order, centered as a whole on the middle of the screen (the formula of REQ-FL-67a),
## and clear of the header and of the HOLD TO DISCONNECT box on every size.
func _block_layout(app: Node) -> void:
	print("the block of three lines")
	app.last_best = {}
	# [size, line 3, a best, game y0, y1, row y0, y1, line 3 y0, y1]; the numbers are the approved mock (v3).
	var cases := [
		[Vector2(1080, 1920), "12", false, 804, 844, 892, 1020, 1052, 1116],
		[Vector2(1080, 1920), "12", true, 804, 844, 892, 1020, 1052, 1116],
		[Vector2(1080, 1920), "12.34 S", true, 764, 804, 852, 980, 1012, 1156],
		[Vector2(1080, 1440), "12", false, 564, 604, 652, 780, 812, 876],
		[Vector2(1080, 1440), "12.34 S", true, 524, 564, 612, 740, 772, 916],
		[Vector2(1080, 2400), "12", false, 1044, 1084, 1132, 1260, 1292, 1356],
		[Vector2(1080, 2400), "12.34 S", true, 1004, 1044, 1092, 1220, 1252, 1396],
		[Vector2(720, 1280), "12", false, 484, 524, 572, 700, 732, 796],
	]
	for cs in cases:
		var sz: Vector2 = cs[0]
		_pad.size = sz
		_set_final("snowball_splat", "1ST", String(cs[1]), "gold")
		app.last_best = {"pid": _client.pid, "key": "snowball_splat|medium", "value": 12, "old": 0} if cs[2] else {}
		var b: Dictionary = _pad._final_block()
		var got := [b.game.position.y, b.game.end.y, b.row.position.y, b.row.end.y, b.line3.position.y, b.line3.end.y]
		_check(got == [float(cs[3]), float(cs[4]), float(cs[5]), float(cs[6]), float(cs[7]), float(cs[8])],
				"%s %s%s: game, row, line 3 at y %s" % [str(sz), cs[1], " (NEW BEST!)" if cs[2] else "", str(got)])
		_check(absf((b.top + b.h * 0.5) - sz.y * 0.5) <= 0.5 and b.row.size.y == 128.0 and b.game.size.y == 40.0,
				"%s: the block is centered on the middle (to the pixel): top %.0f, h %.0f" % [str(sz), b.top, b.h])
	app.last_best = {}
	# No overlap with the header (it ends at y 170) or the box, in both languages, with the tallest block.
	for code in ["en", "he"]:
		Lang.set_language(code)
		for sz in [Vector2(720, 1280), Vector2(1080, 1920), Vector2(1080, 1440), Vector2(1080, 2400)]:
			_pad.size = sz
			_set_final("bumper_cars", "ראשון" if code == "he" else "1ST", "123.45 ש׳" if code == "he" else "123.45 S", "gold")
			app.last_best = {"pid": _client.pid, "key": "bumper_cars|medium", "value": 12, "old": 0}
			var b: Dictionary = _pad._final_block()
			var bottom: float = b.line3.end.y
			_check(b.top >= 170.0 + 48.0 and bottom + 48.0 <= _pad._rect_leave().position.y and b.line3_lines.size() == 2,
					"%s %s: the tallest block (2 lines) is y %.0f to %.0f, below the header (170) and above the box (%.0f)"
					% [code, str(sz), b.top, bottom, _pad._rect_leave().position.y])
	# Hebrew worst case at 1080x1920: the mock 24, h 400.
	Lang.set_language("he")
	_pad.size = Vector2(1080, 1920)
	var hb: Dictionary = _pad._final_block()
	_check([hb.game.position.y, hb.row.position.y, hb.line3.position.y, hb.line3.end.y] == [760.0, 848.0, 1008.0, 1160.0]
			and hb.h == 400.0, "Hebrew NEW BEST! with a time: the block is y 760 to 1160 (h 400): the Hebrew gap is larger")
	_check(hb.game_lines == ["מכוניות מתנגשות"] and hb.line3_lines == ["שיא חדש!", "123.45 ש׳"],
			"the name of the game comes from g in the phone language; NEW BEST! breaks between title and value: %s" % str(hb.line3_lines))
	var row: Dictionary = _pad._place_row_layout(hb.row)
	_check(row.medal.size == Vector2(128, 128) and row.medal.position.x > row.text.end.x and row.text.size.y == 128.0
			and absf((row.text.position.x + row.medal.end.x) * 0.5 - 540.0) <= 0.5,
			"Hebrew: the medal (128 px) is on the right of the place text and the row is centered: %s" % str(row))
	Lang.set_language("en")
	app.last_best = {}
	# The place row: the medal on the left in English, 128 px, none for no medal, and the row is as high without a medal.
	_pad.size = Vector2(1080, 1920)
	_set_final("snowball_splat", "1ST", "12", "gold")
	var en: Dictionary = _pad._place_row_layout(_pad._final_block().row)
	_check(en.medal.size == Vector2(128, 128) and en.medal.end.x + 32.0 == en.text.position.x
			and absf((en.medal.position.x + en.text.end.x) * 0.5 - 540.0) <= 0.5,
			"English: the medal (128 px) is 32 px left of the place text, the row is centered: %s" % str(en))
	for m in ["silver", "bronze"]:
		_set_final("snowball_splat", "2ND", "9", m)
		_check(Medal.is_known(_client.final_medal) and _pad._place_row_layout(_pad._final_block().row).medal.size.x == 128.0,
				"a %s medal is drawn" % m)
	_set_final("snowball_splat", "4TH", "3", "")
	var none: Dictionary = _pad._place_row_layout(_pad._final_block().row)
	_check(none.medal.size.x == 0.0 and absf((none.text.position.x + none.text.end.x) * 0.5 - 540.0) <= 0.5
			and _pad._final_block().row.size.y == 128.0 and _pad._final_block().row.position.y == 892.0,
			"4th, no medal: the text is centered alone and the row keeps its height and place")
	# An unknown game has no game line, and the row and line 3 are centered without it.
	_set_final("nope", "1ST", "12", "gold")
	var ub: Dictionary = _pad._final_block()
	_check(ub.game_lines.is_empty() and ub.row.position.y == 848.0 and ub.line3.end.y == 1072.0,
			"an unknown g draws no game line: the row is at y %.0f" % ub.row.position.y)
	# NOT FINISHED and a five digit score stay on one line at 64 px.
	_set_final("snowball_splat", "3RD", "NOT FINISHED", "")
	_check(_pad._final_block().line3_lines == ["NOT FINISHED"], "NOT FINISHED is one line")
	_set_final("snowball_splat", "1ST", "12345 POINTS", "gold")
	_check(_pad._final_block().line3_lines == ["12345 POINTS"], "a long score is one line")
	_pad.size = Vector2(1080, 1920)
	_set_final("snowball_splat", "1ST", "12", "gold")


## NEW BEST! is line 3, in place of the score, only on the phone of the player who set the best (App.current_best() decides).
func _new_best_line(app: Node) -> void:
	print("NEW BEST! on line 3")
	_pad.size = Vector2(1080, 1920)
	_set_final("snowball_splat", "1ST", "12", "gold")
	app.last_best = {}
	var plain: Dictionary = _pad._final_block()
	_check(plain.best == false and plain.line3_lines == ["12"], "no best: line 3 is the plain score")
	app.last_best = {"pid": _client.pid, "key": "snowball_splat|medium", "value": 12, "old": 5}
	var nb: Dictionary = _pad._final_block()
	_check(nb.best == true and nb.line3_lines == ["NEW BEST! 12"] and not str(nb).to_lower().contains("before"),
			"this player set a best: line 3 is NEW BEST! and the score, no old value")
	_check(nb.line3.position.y == plain.line3.position.y and nb.h == plain.h, "and it takes the place of the score (one line, same block)")
	app.last_best = {"pid": "f".repeat(32), "key": "snowball_splat|medium", "value": 12, "old": 0}
	_check(_pad._final_block().best == false and _pad._final_block().line3_lines == ["12"],
			"a best of another profile is not shown on this phone")
	app.last_best = {"pid": _client.pid, "key": "snowball_splat|medium", "value": 12, "old": 0}
	var keep := _client.phase
	_client.phase = "menu"
	_check(app.current_best().is_empty() and _pad._final_block().best == false, "the TV is at the menu: no NEW BEST!")
	_client.phase = keep
	# Where it breaks: one line when title and value are 960 px or less, else the title, then the value (never smaller).
	var width := 960.0
	_check(_pad.line3_lines("12345", true, width) == ["NEW BEST! 12345"], "NEW BEST! 12345 is 15 characters: one line")
	_check(_pad.line3_lines("3.4 s", true, width) == ["NEW BEST! 3.4 S"], "NEW BEST! 3.4 S is 15 characters: one line")
	_check(_pad.line3_lines("4.22 s", true, width) == ["NEW BEST!", "4.22 S"],
			"a race time (16 characters) breaks between the title and the value: the unit stays with the number")
	_check(_pad.line3_lines("12", false, width) == ["12"], "a plain score is not changed")
	Lang.set_language("he")
	_check(_pad.line3_lines("12", true, width) == ["שיא חדש! 12"], "Hebrew with a score: one line")
	_check(_pad.line3_lines("123.45 ש׳", true, width) == ["שיא חדש!", "123.45 ש׳"],
			"Hebrew with a time: breaks after the title, the unit stays with the number")
	Lang.set_language("en")
	app.last_best = {}
