extends SceneTree
## The cost of one frame with 4 simulated phones on Hard, for every game of the registry (REQ-GM-50, issue #132). It replaces
## the manual steps "play with 4 phones and read the FPS": a machine cannot measure the FPS of a real TV box, but it can
## measure the logic of a frame with the most players on the hardest level. Four real clients on the loopback tilt their phones,
## so every game has its full load. Nothing is drawn in --headless, so the drawing is not part of the number.
##   godot --headless --path . --script tests/frame_cost.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Slow = preload("res://tests/slow_run.gd")

const FRAME_BUDGET_MS := 8.0   # 60 fps leaves 16.7 ms: half is for the drawing and the rest of the TV box.
const BURST := 60              # Frames that are timed in a row; the phones send between two bursts.
const BURSTS := 8
const PHONES := 4
## Games that need a state that costs more than the start: Star Shield at wave 8 (Test 22 step 12g).
const LATE_WAVE := 8

var _checks := 0
var _fails := 0
var _clients: Array = []
var _seq := [0, 0, 0, 0]


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The phones tilt (x and y), so the blobs, cars, dogs and paddles move.
func _stream(seconds: float, phase: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in PHONES:
			var a := phase + float(i) * 1.3 + float(Time.get_ticks_msec()) / 700.0
			_clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO,
					Vector3(3.0 * sin(a), 3.0 * cos(a), 9.3), 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var app: Node = root.get_node("App")
	load("res://scripts/game/game_settings.gd").clear()
	for i in PHONES:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		_clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	_check(app.server.connected_slots().size() == PHONES, "%d simulated phones joined" % PHONES)
	var budget := Slow.limit(FRAME_BUDGET_MS, 6.0)
	for spec in Registry.all():
		await _measure(app, spec, budget)
	for c in _clients:
		c.leave()
	await _frames(5)


## One game on Hard with 4 phones: the worst average of a burst of frames must stay under the budget.
func _measure(app: Node, spec: Dictionary, budget: float) -> void:
	var id: String = spec.id
	var props: Dictionary = spec.get("props", {}).duplicate()
	props["difficulty"] = "hard"
	if id == "marble_race":
		props["track_choice"] = "random"
	var built := Time.get_ticks_msec()
	app.go(Registry.load_script(id), props)
	var build_ms := Time.get_ticks_msec() - built
	await _frames(3)
	var game: Control = app.current_screen()
	# REQ-GM-52: the scene is built in _game_ready() / _world_ready(), which run inside go(): 2 s or less.
	_check(build_ms <= Slow.limit(2000.0, 6.0),
			"%s: REQ-GM-52: the game builds its scene in %d ms (2000 ms or less)" % [id, build_ms])
	if spec.get("enroll", false):   # Air Hockey: two phones press A and the match starts.
		game._on_button(Protocol.BTN_A, 0)
		game._on_button(Protocol.BTN_A, 1)
	await _stream(0.5, 0.0)
	_check(game.participants.size() >= spec.min_players and not game.is_over,
			"%s: runs on Hard with %d phones (%d players)" % [id, PHONES, game.participants.size()])
	if id == "asteroid_blast":
		game.field.wave = LATE_WAVE
	_player_colors(id, game)
	await _pause_menu(id, game, app)
	var worst := 0.0
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for b in BURSTS:
		var start := Time.get_ticks_usec()
		for i in BURST:
			game._process(1.0 / 60.0)
		worst = maxf(worst, float(Time.get_ticks_usec() - start) / float(BURST) / 1000.0)
		await _stream(0.1, float(b))
	# REQ-GM-51: a game does not create nodes in a frame. 480 ticks of play (8 s) may add a few nodes for events (a banner, a
	# pop-up), but not one for each frame.
	var grown := Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes_before
	_check(grown < BURST, "%s: REQ-GM-51: %d ticks add %d nodes, not one for each frame" % [id, BURST * BURSTS, int(grown)])
	print("  info %s: worst logic of one frame %.2f ms" % [id, worst])
	_check(worst < budget, "%s: the logic of a frame with %d phones on Hard is under %.0f ms (%.2f ms)"
			% [id, PHONES, budget, worst])


## REQ-GM-23: the color of a player in the game is the slot color of its PlayerInput.
func _player_colors(id: String, game: Control) -> void:
	var ok := not game.participants.is_empty()
	for s in game.participants:
		ok = ok and game.player(s).color == Protocol.PLAYER_COLORS[s]
	_check(ok, "%s: REQ-GM-23: every player of the game has the color of its slot" % id)


## REQ-GM-36: during play the only menu is the pause card with Resume and End game: no row that changes the setup of the game.
func _pause_menu(id: String, game: Control, app: Node) -> void:
	if game.is_paused() or not game._in_progress():
		return
	game.on_back()   # The Back key of the remote during play.
	await _frames(2)
	var texts: Array = game.menu_buttons().map(func(b: Button) -> String: return b.text)
	_check(texts == ["minigame.resume", "minigame.end_game"] and app.current_screen() == game,
			"%s: REQ-GM-36: the menu during play has Resume and End game only (%s)" % [id, str(texts)])
	game.close_menu()
