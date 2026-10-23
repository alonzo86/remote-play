extends SceneTree
## Behavior that a manual test used to check on real phones, done here with simulated phones (a real client on loopback that
## streams sensor values and button presses, and listens for the buzz): the buzz at GO in the games with a countdown, none in the
## others, no buzz and no change in
## the countdown, RECENTER and A/B in Paint Grab, and a phone that goes silent pauses the turn games (a lock or a lost Wi-Fi).
## It tests what the TV does with such a phone, not what a real phone does. Run by tests/run_all.sh and tools/coverage.sh:
##   godot --headless --path . --script tests/device_mocks.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const Registry = preload("res://scripts/game/registry.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

const GAMES := {
	"maze": ["res://scripts/game/maze/maze_game.gd", {}],
	"paint_grab": ["res://scripts/game/paint_grab/paint_grab_game.gd", {"difficulty": "medium"}],
	"sumo_bumpers": ["res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd", {"difficulty": "medium"}],
	"asteroid_blast": ["res://scripts/game/asteroid_blast/asteroid_blast_game.gd", {"difficulty": "medium"}],
	"snowball_splat": ["res://scripts/game/snowball_splat/snowball_splat_game.gd", {"difficulty": "medium"}],
	"marble_race": ["res://scripts/game/marble_race/marble_race.gd", {"track_choice": "3", "difficulty": "easy"}],
	"mini_golf": ["res://scripts/game/mini_golf/mini_golf_game.gd", {"difficulty": "medium", "holes": "1"}],
	"bowling": ["res://scripts/game/bowling/bowling_game.gd", {"difficulty": "medium"}],
	"tennis": ["res://scripts/game/tennis/tennis_game.gd", {"difficulty": "medium"}],
	"sheep_herding": ["res://scripts/game/sheep_herding/sheep_herding_game.gd", {"difficulty": "medium"}],
}
## Only a game with a visible timer has the countdown and the buzz at GO (REQ-GM-35). Tennis with 2 phones has no timer.
const COUNTDOWN_GAMES := ["paint_grab", "snowball_splat", "marble_race", "maze", "sheep_herding"]
## The turn games buzz the phone on turn (60 ms) when the first turn starts, and no other phone.
const TURN_GAMES := ["mini_golf", "bowling"]

var _checks := 0
var _fails := 0
var _seq := [0, 0]
var _clients: Array = []
var _buzzes: Array = [[], []]


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


## Both phones stream `accel` for `seconds`. A phone that is not processing sends nothing (a silent phone).
func _stream(seconds: float, accel: Vector3, only: Array = [0, 1]) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in only:
			_clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, accel, 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var app: Node = root.get_node("App")
	load("res://scripts/game/game_settings.gd").clear()
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.haptic_requested.connect(func(ms: int) -> void: _buzzes[i].append(ms))
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		_clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	var flat := Vector3(0, 0, 9.81)
	await _stream(0.5, flat)

	# The buzz at GO (REQ-GM-37): every phone gets one buzz of 60 ms when the countdown ends, and none before.
	for id in GAMES:
		_buzzes = [[], []]
		app.go(load(GAMES[id][0]), GAMES[id][1].duplicate())
		await _frames(3)
		await _stream(1.5, flat)
		var before: int = _buzzes[0].size() + _buzzes[1].size()
		await _stream(2.5, flat)
		# Issue #55: only a game where the phone is a pointer at a target has the Recenter box on the pad (REQ-GM-37).
		_check(_clients[0].recenter_button == (id == "snowball_splat") and _clients[1].recenter_button == (id == "snowball_splat"),
				"%s: the phones %s the Recenter box (REQ-GM-37)" % [id, "get" if id == "snowball_splat" else "do not get"])
		# Issue #80: the phones show only the buttons the game uses (REQ-GM-37a).
		var want := Registry.buttons_of(Registry.find(id))
		_check(_clients[0].pad_buttons == want and _clients[1].pad_buttons == want,
				"%s: the phones show the buttons \"%s\" (REQ-GM-37a)" % [id, want])
		if id in COUNTDOWN_GAMES:
			_check(before == 0, "%s: no buzz during 3, 2, 1" % id)
			_check(_buzzes[0].count(60) >= 1 and _buzzes[1].count(60) >= 1,
					"%s: every phone gets a 60 ms buzz at GO: %s %s" % [id, str(_buzzes[0]), str(_buzzes[1])])
		elif id in TURN_GAMES:
			_check(_buzzes[0].count(60) >= 1 and _buzzes[1].is_empty(),
					"%s: no countdown (no timer); only the phone on turn gets the 60 ms turn buzz: %s %s"
					% [id, str(_buzzes[0]), str(_buzzes[1])])
		else:
			_check(_buzzes[0].count(60) == 0 and _buzzes[1].count(60) == 0,
					"%s: no countdown (no timer), so no 60 ms buzz at the start: %s %s" % [id, str(_buzzes[0]), str(_buzzes[1])])

	# The pose held in the countdown is the center: a phone that leans during 3, 2, 1 has no tilt after GO (REQ-GM-37).
	var lean0 := deg_to_rad(15.0)
	var leaning := Vector3(-sin(lean0), 0.0, cos(lean0)) * 9.81
	var centered := {
		"maze": ["res://scripts/game/maze/maze_game.gd", {}],
		"paint_grab": GAMES.paint_grab,
		"sheep_herding": GAMES.sheep_herding,
	}
	for id in centered:
		await _stream(0.5, flat)
		app.server.players[0].recenter()   # Flat is the center before the game, so the lean is a real tilt.
		app.go(load(centered[id][0]), centered[id][1].duplicate())
		await _frames(3)
		await _stream(2.5, leaning)
		var held: float = app.server.players[0].tilt().length()
		await _stream(2.0, leaning)
		_check(held > 0.1 and app.server.players[0].tilt().length() < 0.05,
				"%s: a phone that leans in the countdown is centered at GO (%.2f then %.3f)"
				% [id, held, app.server.players[0].tilt().length()])

	# No countdown (REQ-GM-35): Galaxy Protector takes the pose held when the game starts as the center.
	await _stream(0.5, leaning)
	app.go(load(GAMES.asteroid_blast[0]), GAMES.asteroid_blast[1].duplicate())
	await _frames(3)
	await _stream(0.5, leaning)
	_check(app.server.players[0].tilt().length() < 0.05,
			"asteroid_blast: the pose held at the start is the center (%.3f)" % app.server.players[0].tilt().length())

	# Paint Grab: A and B do not recenter, and the pad has no Recenter box (REQ-PG-14).
	app.go(load(GAMES.paint_grab[0]), GAMES.paint_grab[1].duplicate())
	await _frames(3)
	await _stream(4.0, flat)
	var lean := deg_to_rad(15.0)
	var tilted := Vector3(-sin(lean), 0.0, cos(lean)) * 9.81
	await _stream(1.0, tilted)
	var player = app.server.players[0]
	_check(player.tilt().length() > 0.2, "Paint Grab: a leaning phone has a tilt (%.2f)" % player.tilt().length())
	player.button_pressed.emit(Protocol.BTN_A)
	player.button_pressed.emit(Protocol.BTN_B)
	_check(player.tilt().length() > 0.2, "Paint Grab: A and B do not recenter")
	_check(not _clients[0].recenter_button, "Paint Grab: the pad has no Recenter box (REQ-GM-37, issue #55)")

	# A phone that goes silent (lock, no Wi-Fi) pauses the turn games,, and the card offers Resume when it is back.
	app.server.peer_timeout_ms = 2500
	for id in ["mini_golf", "bowling", "tennis"]:
		app.go(load(GAMES[id][0]), GAMES[id][1].duplicate())
		await _frames(3)
		await _stream(4.0, flat)
		var game: Control = app.current_screen()
		_clients[1].set_process(false)
		var waited := Time.get_ticks_msec()
		while not game.is_paused() and Time.get_ticks_msec() - waited < 9000:
			await _stream(0.2, flat, [0])
		_check(game.is_paused() and not game.is_over, "%s: a silent phone pauses the game" % id)
		_clients[1].set_process(true)
		await _stream(1.5, flat)
		var labels: Array = game.menu_buttons().map(func(b: Button) -> String: return b.text)
		_check(labels.has("minigame.resume"), "%s: when the phone is back the card offers Resume: %s" % [id, str(labels)])
		game.close_menu()
