extends SceneTree
## Issue #432 (REQ-BW-5, MIN_BACK; Test 23 step 4g): a fast shake of the phone with no wind-up and no finger on the aim strip
## must throw no ball. 5 shakes of 2 s, 2 s apart, 4 speeds, 3 directions. The detector throws on some of them today, so this
## suite FAILS and is NOT in tests/suites.txt until the detector is fixed (then add it there as `scenario`).
## Run: godot --headless --path . --script tests/bowling_shake_432.gd -- --role=tv

const R = preload("res://tests/sensor_replay.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")

var _checks := 0
var _fails := 0
var _app: Node
var _Bowling
var _clients: Array = []


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_Bowling = load("res://scripts/game/bowling/bowling_game.gd")
	_app = root.get_node("App")
	_app.set_language("en", false)   # The texts are compared in English, whatever language the saved settings have.
	load("res://scripts/game/game_settings.gd").clear()
	for i in 4:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		_clients.append(c)
		var joined := Time.get_ticks_msec()
		while _app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	await _shake_without_wind_up()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Starts a game for the first `n` phones. The phones start with a fresh sensor fusion (a new phone in the slot) and are
## fed with `ups[slot]`. Returns {game, feeders}.
func _new_game(n: int, props := {"difficulty": "medium"}, ups := []) -> Dictionary:
	var feeders := []
	for s in 4:
		var p: PlayerInput = _app.server.players[s]
		var nm := p.player_name
		var tok := p.token
		p.reset()
		p.on_join(nm, tok)
		feeders.append(R.Feeder.new(p, ups[s] if s < ups.size() else R.UP_FLAT))
	_app.go(_Bowling, props)
	await _frames(3)
	var game: Control = _app.current_screen()
	var slots: Array[int] = []
	for s in n:
		slots.append(s)
	game.participants = slots
	game.rules.setup(slots)
	game._board = Scoreboard.new(slots)
	for f in feeders:
		f.settle(0.5)
	return {"game": game, "feeders": feeders}


## The first turn starts (there is no countdown, REQ-GM-35).
func _begin(game: Control) -> void:
	game._start_turn()
	game._game_tick(R.DT)


## Feeds a trace to the phone of `f` and steps the game after each packet.
func _play(game: Control, f: R.Feeder, trace: R.Trace) -> void:
	f.feed(trace, func() -> void: game._game_tick(R.DT))


func _wait(game: Control, f: R.Feeder, seconds: float) -> void:
	_play(game, f, R.still(seconds))


## Starts a new turn of the player on turn with a full rack, as the game does after a ball.
func _again(game: Control) -> void:
	game.sim.set_rack(game.FULL_RACK)
	game._start_turn()


func _threw(game: Control) -> bool:
	return game.phase != game.Phase.AIM


func _shake_without_wind_up() -> void:
	print("fast shakes, no finger, no wind-up")
	var ctx := await _new_game(1)
	var game: Control = ctx.game
	var f: R.Feeder = ctx.feeders[0]
	_begin(game)
	_wait(game, f, 0.3)
	var thrown := []
	var tries := 0
	# A hand shake is not along one axis of the phone: the diagonal (1, 1, 1) is the plain case.
	for axis in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 1, 1)]:
		for case in [[4.0, 8.0], [4.0, 15.0], [5.0, 20.0], [6.0, 20.0]]:
			var count := 0
			for n in 5:
				tries += 1
				_play(game, f, R.shake(1.5, case[1], case[0], axis))
				_wait(game, f, 2.0)
				if _threw(game):
					count += 1
					_again(game)
					_wait(game, f, 0.3)
			if count > 0:
				thrown.append("%d Hz %d m/s2 axis %s: %d of 5" % [int(case[0]), int(case[1]), str(axis), count])
	_check(thrown.is_empty(), "no ball is thrown in %d shakes of 1.5 s, 2 s apart, with no wind-up and no finger (thrown: %s)"
			% [tries, "; ".join(thrown)])
