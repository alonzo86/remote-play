extends SceneTree
## The setup of a game in the TV settings view (issues #79 and #76, REQ-GM-102, REQ-GM-104), with simulated phones on the
## loopback network. Swing games (Pin Pals, Tennis, Mini Golf): the settings view sends `setup` to the phones, Start waits
## for the answer `swing_ok` of every phone that plays, the card shows once for each run of the app (tests/ui_states_a.gd), and
## the other games have no card. IN and OUT: each phone chooses, the TV lists it, the game has the IN players only. Run:
##   godot --headless --path . --script tests/swing_setup.gd -- --role=tv

const Sim = preload("res://tests/sim_b.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _fails := 0
var _checks := 0
var sim


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _run() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	sim = Sim.new(self)
	await sim.join(2)
	await _games()
	await _answers()
	await _late_phone()
	await _choices()
	await _one_phone()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _wait_for(cond: Callable) -> void:
	var start := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - start < 3000:
		await process_frame


## Only the games with the `swing` flag of the registry have the card (Pin Pals, Tennis, Mini Golf).
func _games() -> void:
	print("which games")
	var swing: Array[String] = []
	for g in Registry.all():
		if bool(g.get("swing", false)):
			swing.append(String(g.id))
	swing.sort()
	_check(swing == ["bowling", "mini_golf", "tennis"], "the swing games are Pin Pals, Mini Golf and Tennis: %s" % [swing])
	var app: Node = sim.app
	app.go_game_settings("maze")
	await sim.frames(6)
	_check(not app.server.setup_swing and app.server.swing_pending().is_empty() and not sim.clients[0].setup_swing,
			"the settings view of Treasure Maze has no safety card")
	_check(not app.current_screen().start_button.disabled, "Start works in Treasure Maze")


## Start of a swing game waits for the OK of every phone, and the line says why.
func _answers() -> void:
	print("answers")
	var app: Node = sim.app
	app.go_game_settings("bowling")
	await _wait_for(func(): return sim.clients[0].setup_swing and sim.clients[1].setup_swing)
	var view: Control = app.current_screen()
	await sim.frames(3)
	_check(sim.clients[0].setup_swing and sim.clients[1].setup_swing and app.server.swing_pending() == [0, 1],
			"both phones get the safety card and none has answered")
	_check(view.start_button.disabled and view.reason_label.text == Lang.t("game_settings.waiting_phones").to_upper(),
			"Start is off and the line says WAITING FOR PHONES")
	sim.clients[0].send_swing_ok()
	await _wait_for(func(): return app.server.swing_pending() == [1])
	await sim.frames(3)
	_check(app.server.swing_pending() == [1] and view.start_button.disabled, "one phone answered: Start still waits for the other")
	sim.clients[1].send_swing_ok()
	await _wait_for(func(): return app.server.swing_pending().is_empty())
	await sim.frames(3)
	_check(not view.start_button.disabled and view.reason_label.text == "",
			"both phones answered: Start works and the line is empty")
	# The answer is kept for this run of the app: the second visit asks nobody.
	app.go_games()
	await sim.frames(3)
	_check(not sim.clients[0].setup_swing and not app.server.setup_swing, "the Games screen closes the safety card")
	app.go_game_settings("tennis")
	await _wait_for(func(): return app.server.swing_pending().is_empty() and app.server.setup_swing)
	await sim.frames(3)
	_check(sim.clients[0].swing_acked and app.server.swing_pending().is_empty()
			and not app.current_screen().start_button.disabled, "a phone that answered once answers at once, with no card")
	app.go_games()
	await sim.frames(3)


## A phone that joins while the settings view is open gets the card too.
func _late_phone() -> void:
	print("late phone")
	var app: Node = sim.app
	for c in sim.clients:
		c.swing_acked = false
	app.go_game_settings("mini_golf")
	await _wait_for(func(): return sim.clients[0].setup_swing)
	await sim.join(1)   # a third phone
	await _wait_for(func(): return sim.clients[2].setup_swing)
	_check(sim.clients[2].setup_swing and app.server.swing_pending() == [0, 1, 2],
			"a phone that joins in the settings view gets the card")
	app.go_games()
	await sim.frames(3)


func _rows(view: Control) -> Array[String]:
	var r: Array[String] = []
	for row in view.slot_list.get_children():
		for l in row.find_children("*", "Label", true, false):
			if l.text in ["setup.in", "setup.out"]:
				r.append(l.text)
	return r


## Issue #76: IN and OUT on the phones.
func _choices() -> void:
	print("IN and OUT")
	var app: Node = sim.app
	app.go_game_settings("maze")
	await _wait_for(func(): return sim.clients[2].setup_pick)
	await sim.frames(3)
	var view: Control = app.current_screen()
	_check(sim.clients[0].setup_pick and sim.clients[1].setup_pick and sim.clients[2].setup_pick
			and sim.clients[0].setup_in and sim.clients[1].setup_in and app.server.players_in() == [0, 1, 2],
			"with 3 phones every phone gets the question and everybody is IN")
	_check(view.slot_list.visible and _rows(view) == ["setup.in", "setup.in", "setup.in"], "the TV lists the 3 players as IN")
	sim.clients[1].send_play(false)
	await _wait_for(func(): return app.server.players_in() == [0, 2])
	await sim.frames(3)
	_check(app.server.players_in() == [0, 2] and not sim.clients[1].setup_in and sim.clients[0].setup_in,
			"OUT on phone 2: the TV keeps players 1 and 3")
	_check(_rows(view) == ["setup.in", "setup.out", "setup.in"], "the TV list says OUT for player 2")
	# Start counts the players that are IN.
	app.go_game_settings("sumo_bumpers")
	await sim.frames(4)
	view = app.current_screen()
	sim.clients[1].send_play(false)
	sim.clients[2].send_play(false)
	await _wait_for(func(): return app.server.players_in() == [0])
	await sim.frames(3)
	_check(app.server.players_in() == [0] and view.start_button.disabled
			and view.reason_label.text == Lang.t("games.needs_players").replace("%d", "2").to_upper(),
			"Sumo Bumpers needs 2 players: with one phone IN Start is off and the line says so")
	sim.clients[0].send_play(false)
	await sim.frames(6)
	await _wait_for(func(): return sim.clients[0].setup_in)
	_check(app.server.players_in() == [0] and sim.clients[0].setup_in,
			"the last phone that is IN cannot go OUT, and its button says IN again")
	sim.clients[2].send_play(true)
	await _wait_for(func(): return app.server.players_in() == [0, 2])
	await sim.frames(3)
	_check(not view.start_button.disabled, "a second phone IN: Start works")
	# The game has the IN players only; the phone that is OUT waits.
	app.go_game_settings("maze")
	await sim.frames(4)
	view = app.current_screen()
	_check(app.server.players_in() == [0, 1, 2] and sim.clients[1].setup_in, "a new settings view makes everybody IN again")
	sim.clients[1].send_play(false)
	await _wait_for(func(): return app.server.players_in() == [0, 2])
	view.start()
	await sim.frames(4)
	var game: Control = app.current_screen()
	await _wait_for(func(): return sim.clients[1].phase == "waiting")
	_check(game.participants == [0, 2] and sim.clients[1].phase == "waiting" and sim.clients[0].phase == "playing",
			"the game has players 1 and 3 only, and phone 2 gets the waiting screen")
	app.go_games()
	await sim.frames(4)
	_check(app.server.players_in() == [0, 1, 2], "the Games screen makes everybody IN again")


## With one phone the question does not show.
func _one_phone() -> void:
	print("one phone")
	var app: Node = sim.app
	await sim.leave_all()
	await sim.join(1)
	app.go_game_settings("maze")
	await _wait_for(func(): return app.server.setup_open)
	await sim.frames(6)
	_check(not sim.clients[0].setup_pick and not app.current_screen().slot_list.visible,
			"with one phone there is no question and no list")
