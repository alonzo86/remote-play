extends SceneTree
## A phone that loses its Wi-Fi during a game, in real time with the real timeouts (docs/MANUAL_TESTS.md test 7, items 1a, 1d,
## 4a, 5a, 5b, 5c, 5d): the card comes in 8 s or less, it names the phone and says "waiting to reconnect", it changes to
## "reconnected" with Resume in 10 s or less, the game stays paused for 10 s without a press while the other phone tilts, Resume
## without the lost player goes on with the other ball, and the only phone gives the card with End game only and then
## "reconnected" and Resume in the maze, in Road Rally and in Banana Party. A silent phone is a simulated phone whose update
## loop is switched off (its socket stays open, nothing arrives), like a phone without Wi-Fi; the real radio stays manual.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r1_reconnect.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

const LOST_LIMIT_MS := 8000       # Step 1a: the card comes within 8 s of the moment the Wi-Fi goes off.
const BACK_LIMIT_MS := 10000      # Step 1d: the card says "reconnected" within 10 s of the moment the Wi-Fi is on.

var _checks := 0
var _fails := 0
var _app: Node
var _seq := {}   # phone index -> next sequence number
var _maze: GDScript
var _race: GDScript
var _banana: GDScript


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


## Sends one sensor packet from the simulated phone `c` (index `idx`) for `ms` milliseconds, one packet each frame, while
## `until` (optional) is false. Returns when the time is over or `until` is true.
func _stream(c: ControllerClient, idx: int, ms: int, accel: Vector3, until := Callable()) -> void:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		if until.is_valid() and until.call():
			return
		_seq[idx] = int(_seq.get(idx, 0)) + 1
		c.send_sensor(Protocol.encode_sensor(_seq[idx], Time.get_ticks_msec(), Vector3.ZERO, accel, 0, 0, Vector2.ZERO))
		await process_frame


func _tilt(right_deg: float, up_deg := 0.0) -> Vector3:
	var r := deg_to_rad(right_deg)
	var u := deg_to_rad(up_deg)
	return Vector3(-sin(r), sin(u), cos(r) * cos(u)) * 9.81


func _join(n: int) -> Array[ControllerClient]:
	var out: Array[ControllerClient] = []
	for i in n:
		var c := ControllerClient.new()
		c.player_name = ""   # A guest: the cards say "1P", "2P".
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		out.append(c)
	await _wait_until(func(): return _app.server.connected_slots().size() >= n, 5000)
	await _frames(2)
	return out


func _leave(phones: Array[ControllerClient]) -> void:
	for c in phones:
		c.set_process(true)
		c.leave()
		c.queue_free()
	await _wait_until(func(): return _app.server.connected_slots().is_empty(), 4000)
	await _frames(2)


func _card_title(game: Control) -> String:
	return String(game._menu_box.find_children("*", "Label", true, false)[0].text) if game._menu_box != null else ""


func _card_buttons(game: Control) -> Array:
	return game.menu_buttons().map(func(b): return b.text)


## The text of every label of the card, in upper case (the lines "name   state").
func _card_lines(game: Control) -> Array:
	return game._menu_box.find_children("*", "Label", true, false).map(func(l): return String(l.text).to_upper())


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	if not _app.server.listening:
		_check(false, "the TV server listens (another TV app or test holds port %d)" % Protocol.WS_PORT)
		return
	_maze = load("res://scripts/game/maze/maze_game.gd")
	_race = load("res://scripts/game/marble_race/marble_race.gd")
	_banana = load("res://scripts/game/snowball_splat/snowball_splat_game.gd")
	_app.set_language("en", false)
	await _two_phones_in_the_maze()
	await _only_phone(_maze, {}, "maze")
	await _only_phone(_race, {"track_choice": "1"}, "Road Rally")
	await _only_phone(_banana, {"seed": 4}, "Banana Party")
	_app.go_menu()
	await _frames(3)


## Steps 1a, 1d and 4a: two phones in the maze, 2P loses its Wi-Fi.
func _two_phones_in_the_maze() -> void:
	print("two phones in the maze: 2P is silent")
	var phones: Array[ControllerClient] = await _join(2)
	_app.go(_maze)
	await _frames(3)
	var game: Control = _app.current_screen()
	var flat := _tilt(0.0)
	# The countdown and a control: phone 1P tilts to the right, so its ball rolls (the test can see a ball that moves).
	await _stream(phones[0], 0, 3600, flat)
	var x0: float = game._balls[0].pos.x
	await _stream(phones[0], 0, 1000, _tilt(15.0))
	_check(game._balls[0].pos.x > x0 + 15.0, "control: 1P tilts right and its ball rolls (%.0f px)" % (game._balls[0].pos.x - x0))

	# 1a: 2P goes silent (a phone without Wi-Fi keeps its socket open and sends nothing).
	phones[1].set_process(false)
	var t0 := Time.get_ticks_msec()
	var held := await _wait_stream(phones[0], game, func(): return game._hold, LOST_LIMIT_MS + 3000)
	var lost_ms := Time.get_ticks_msec() - t0
	await _frames(3)
	_check(held and lost_ms <= LOST_LIMIT_MS and game.is_paused(),
			"the game pauses %d ms after 2P went silent (8000 ms or less)" % lost_ms)
	_check(_card_title(game) == "2P LOST CONNECTION", "the card says '%s'" % _card_title(game))
	var waiting := Lang.t("pause.waiting_reconnect").to_upper()
	var who := String(_app.server.players[1].player_name).to_upper()   # A guest is "Player 2" on the TV.
	_check(who != "" and _card_lines(game).any(func(t): return String(t).contains(who) and String(t).contains(waiting)),
			"the card has the line '%s   %s'" % [who, waiting])
	_check(phones[0].phase == "paused" and _app.server.phase == "paused", "the phones are told that the game is paused")
	var paused_x: float = game._balls[0].pos.x

	# 1d: the Wi-Fi is back. The card changes to "reconnected" with Resume, and the game stays paused for 10 s.
	phones[1].set_process(true)
	var t1 := Time.get_ticks_msec()
	var back := await _wait_stream(phones[0], game, func(): return game.lost_participants().is_empty(), BACK_LIMIT_MS + 3000)
	var back_ms := Time.get_ticks_msec() - t1
	await _frames(5)
	_check(back and back_ms <= BACK_LIMIT_MS, "the phone is back after %d ms (10000 ms or less)" % back_ms)
	_check(_card_title(game) == "2P RECONNECTED" and _card_buttons(game) == ["minigame.resume", "minigame.end_game"],
			"the card says '%s' and offers Resume: %s" % [_card_title(game), str(_card_buttons(game))])
	await _stream(phones[0], 0, 10000, _tilt(15.0))   # 1P keeps tilting for 10 s.
	_check(game.is_paused() and game._hold and game._balls[0].pos.x == paused_x and _card_title(game) == "2P RECONNECTED",
			"10 s later the game is still paused and the ball of 1P has not moved (x %.1f, was %.1f)"
			% [game._balls[0].pos.x, paused_x])
	game.menu_buttons()[0].pressed.emit()
	await _frames(3)
	_check(not game.is_paused() and not game._hold and _app.server.phase == "playing", "Resume goes on with the game")

	# 4a: 2P is silent again; Resume without 2P goes on with the other ball.
	phones[1].set_process(false)
	var held2 := await _wait_stream(phones[0], game, func(): return game._hold, LOST_LIMIT_MS + 3000)
	await _frames(3)
	var buttons := _card_buttons(game)
	_check(held2 and buttons == ["RESUME WITHOUT 2P", "minigame.end_game"], "the card offers Resume without 2P: %s" % str(buttons))
	game.menu_buttons()[0].pressed.emit()
	await _frames(4)
	_check(not game.is_paused() and game.participants == [0] and game._balls.size() == 1 and game._balls[0].slot == 0,
			"Resume without 2P: the ball of 2P is gone and the game goes on with 1P")
	var start: Vector2 = game._balls[0].pos
	var far := 0.0
	var directions: Array[Vector3] = [_tilt(15.0), _tilt(-15.0), _tilt(0.0, 15.0), _tilt(0.0, -15.0)]
	for d in directions:
		await _stream(phones[0], 0, 750, d)
		far = maxf(far, game._balls[0].pos.distance_to(start))
	_check(far > 5.0, "the other ball moves within 3 s (%.0f px)" % far)
	phones[1].set_process(true)
	await _leave(phones)
	_app.go_menu()
	await _frames(3)


## Like `_stream`, but the tilt is flat and it waits for `cond`. Returns true when `cond` became true in `max_ms`.
func _wait_stream(phone: ControllerClient, _game: Control, cond: Callable, max_ms: int) -> bool:
	await _stream(phone, 0, max_ms, _tilt(15.0), cond)
	return cond.call()


## Steps 5a to 5d: the only phone goes silent. The card has End game only; when the phone is back it says "1P reconnected" and
## offers Resume.
func _only_phone(script: GDScript, props: Dictionary, name: String) -> void:
	print("the only phone is silent: ", name)
	var phones: Array[ControllerClient] = await _join(1)
	_app.go(script, props)
	await _frames(4)
	var game: Control = _app.current_screen()
	phones[0].set_process(false)
	var t0 := Time.get_ticks_msec()
	var held := await _wait_until(func(): return game._hold, LOST_LIMIT_MS + 3000)
	var ms := Time.get_ticks_msec() - t0
	await _frames(3)
	_check(held and ms <= LOST_LIMIT_MS and game.is_paused() and not game.is_over,
			"[%s] the game pauses %d ms after the phone went silent" % [name, ms])
	_check(_card_title(game) == "1P LOST CONNECTION" and _card_buttons(game) == ["minigame.end_game"],
			"[%s] the card says '%s' and has End game only: %s" % [name, _card_title(game), str(_card_buttons(game))])
	phones[0].set_process(true)
	var t1 := Time.get_ticks_msec()
	var back := await _wait_until(func(): return game.lost_participants().is_empty(), BACK_LIMIT_MS + 3000)
	var back_ms := Time.get_ticks_msec() - t1
	await _frames(5)
	_check(back and back_ms <= BACK_LIMIT_MS and game.is_paused(),
			"[%s] the phone is back after %d ms and the game still waits" % [name, back_ms])
	_check(_card_title(game) == "1P RECONNECTED" and _card_buttons(game) == ["minigame.resume", "minigame.end_game"],
			"[%s] the card says '%s' and offers Resume: %s" % [name, _card_title(game), str(_card_buttons(game))])
	game.menu_buttons()[0].pressed.emit()
	await _frames(3)
	_check(not game.is_paused() and not game._hold and _app.server.phase == "playing", "[%s] Resume goes on with the game" % name)
	await _leave(phones)
	_app.go_menu()
	await _frames(3)
