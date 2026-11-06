extends SceneTree
## The setup of a game in the TV settings view (issues #79 and #76, REQ-GM-102, REQ-GM-104), with simulated phones on the
## loopback network. Swing games (Pin Pals, Tennis, Mini Golf): the settings view sends `setup` to the phones, Start waits
## for the answer `swing_ok` of every phone that plays, the card shows every time the view opens (tests/ui_states_a.gd), and
## the other games have no card. IN and OUT: each phone chooses, the TV lists it, the game has the IN players only. Run:
##   godot --headless --path . --script tests/swing_setup.gd -- --role=tv

const Sim = preload("res://tests/sim_b.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _fails := 0
var _checks := 0
var sim


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
	await _fit()
	await _one_phone()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _wait_for(cond: Callable) -> void:
	var start := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - start < 3000:
		await process_frame


## Only the games with the `swing` flag of the registry have the card (Pin Pals, Tennis, Mini Golf, Freeze Dance).
func _games() -> void:
	print("which games")
	var swing: Array[String] = []
	for g in Registry.all():
		if bool(g.get("swing", false)):
			swing.append(String(g.id))
	swing.sort()
	_check(swing == ["bowling", "freeze_dance", "mini_golf", "tennis"],
			"the swing games are Pin Pals, Freeze Dance (it is wiggled), Mini Golf and Tennis: %s" % [swing])
	var app: Node = sim.app
	app.go_game_settings("maze")
	await sim.frames(6)
	_check(not app.server.setup_swing and app.server.swing_pending().is_empty() and not sim.clients[0].setup_swing,
			"the settings view of Treasure Maze has no safety card")
	_check(not app.current_screen().start_button.disabled, "Start works in Treasure Maze")
	# Issue #148: every swing game asks a phone that has not tapped OK yet, Freeze Dance too.
	for id in swing:
		for c in sim.clients:
			c.swing_acked = false
		app.go_game_settings(id)
		await _wait_for(func(): return sim.clients[0].setup_swing and sim.clients[1].setup_swing)
		await sim.frames(3)
		_check(app.server.swing_pending() == [0, 1] and app.current_screen().start_button.disabled,
				"%s: both phones are asked for the safety card and Start waits" % id)


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
	var tv_line: String = load("res://scripts/ui/ui_kit.gd").shown("swing.tv_line")
	var line_shown := false
	for l in view.find_children("*", "Label", true, false):
		line_shown = line_shown or (l.text == tv_line and l.is_visible_in_tree())
	_check(line_shown,
			"the settings view of a swing game shows the safety line under the rows and Start waits for the OK "
			+ "of every phone (Test 23 step 14a, REQ-BW-22)")
	# Issue #121: a disabled Start cannot be reached. Down from the last row goes to Back, and Start takes no focus.
	var last: Control = view.rows[-1]
	last.grab_focus()
	last.find_valid_focus_neighbor(SIDE_BOTTOM).grab_focus()
	_check(view.get_viewport().gui_get_focus_owner() == view.back_button,
			"Down from the last row goes to Back while Start waits")
	view.start_button.grab_focus()
	_check(view.get_viewport().gui_get_focus_owner() == view.back_button, "Start waits: it takes no focus")
	sim.clients[0].send_swing_ok()
	await _wait_for(func(): return app.server.swing_pending() == [1])
	await sim.frames(3)
	_check(app.server.swing_pending() == [1] and view.start_button.disabled,
			"one phone answered: Start still waits for the other")
	sim.clients[1].send_swing_ok()
	await _wait_for(func(): return app.server.swing_pending().is_empty())
	await sim.frames(3)
	_check(not view.start_button.disabled and view.reason_label.text == "",
			"both phones answered: Start works and the line is empty")
	_check(view.get_viewport().gui_get_focus_owner() == view.back_button,
			"the user moved the focus to Back while Start waited: it stays on Back when Start works (issue #226)")
	view.start_button.grab_focus()
	_check(view.get_viewport().gui_get_focus_owner() == view.start_button, "Start works: it takes the focus")
	view._set_start_reachable(false)   # Start becomes disabled while it has the focus (a phone left): the focus moves to Back.
	_check(view.get_viewport().gui_get_focus_owner() == view.back_button, "Start disabled while focused: Back gets the focus")
	view._set_start_reachable(true)
	# Issue #148: the answer is for one view: the next visit asks every phone again.
	app.go_games()
	await sim.frames(3)
	_check(not sim.clients[0].setup_swing and not app.server.setup_swing, "the Games screen closes the safety card")
	app.go_game_settings("tennis")
	await _wait_for(func(): return app.server.setup_swing and sim.clients[0].setup_swing and sim.clients[1].setup_swing)
	await sim.frames(3)
	_check(not sim.clients[0].swing_acked and not sim.clients[1].swing_acked and app.server.swing_pending() == [0, 1]
			and app.current_screen().start_button.disabled,
			"the second visit asks both phones again: the card shows and Start waits (before every game, REQ-TN-22)")
	var second: Control = app.current_screen()
	_check(second.get_viewport().gui_get_focus_owner() == second.rows[0],
			"Start waits from the first frame: the view has the focus on the first row")
	sim.clients[0].send_swing_ok()
	sim.clients[1].send_swing_ok()
	await _wait_for(func(): return app.server.swing_pending().is_empty())
	await sim.frames(3)
	_check(not app.current_screen().start_button.disabled, "after the answers of the second visit Start works")
	_check(second.get_viewport().gui_get_focus_owner() == second.start_button,
			"and the focus, which the user did not move, goes to Start (issue #226)")
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
	app.server._swing_ok[2] = true   # A phone that had this slot before tapped OK.
	app.server._out[2] = true   # ... and chose OUT.
	await sim.join(1)   # a third phone
	await _wait_for(func(): return sim.clients[2].setup_swing)
	_check(sim.clients[2].setup_swing and app.server.swing_pending() == [0, 1, 2],
			"a phone that joins in the settings view of Mini Golf gets the card (REQ-MG-17)")
	_check(sim.clients[2].setup_in and app.server.players_in().has(2), "a new phone in a slot that was OUT is IN")
	app.go_games()
	await sim.frames(3)


func _name(slot: int) -> String:
	return String(sim.app.server.players[slot].player_name).to_upper()


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
	_check(view.in_label.text == "IN: %s, %s, %s" % [_name(0), _name(1), _name(2)],
			"the TV lists the 3 players as IN: %s" % view.in_label.text)
	sim.clients[1].send_play(false)
	await _wait_for(func(): return app.server.players_in() == [0, 2])
	await sim.frames(3)
	_check(app.server.players_in() == [0, 2] and not sim.clients[1].setup_in and sim.clients[0].setup_in,
			"OUT on phone 2: the TV keeps players 1 and 3")
	_check(view.in_label.text == "IN: %s, %s" % [_name(0), _name(2)],
			"the TV list has the players that are IN only, no OUT line: %s" % view.in_label.text)
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
	await _wait_for(func(): return app.server.players_in().is_empty())
	await sim.frames(3)
	_check(app.server.players_in().is_empty() and not sim.clients[0].setup_in and view.start_button.disabled
			and view.in_label.text == ""
			and view.reason_label.text == Lang.f("games.needs_at_least", [2]).to_upper(),
			"every phone may go OUT: nobody is IN, Start is off, the list is empty and the line says AT LEAST 2 PLAYERS NEEDED")
	sim.clients[0].send_play(true)
	await _wait_for(func(): return app.server.players_in() == [0])
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
	_check(not sim.clients[0].setup_open, "the phone knows that the settings view is closed, so it shows 'choose a game' again")
	# Review of PR 379: a phone that is OUT must not be stuck OUT when the other phone leaves (nobody is asked with one phone).
	app.go_game_settings("maze")
	await sim.frames(4)
	_check(sim.clients[0].setup_open, "with the settings view open the phone knows it (GET READY! on the waiting screen)")
	sim.clients[2].leave()
	await _wait_for(func(): return app.server.connected_slots() == [0, 1])
	sim.clients[1].send_play(false)
	await _wait_for(func(): return app.server.players_in() == [0])
	sim.clients[0].leave()
	await _wait_for(func(): return app.server.connected_slots() == [1])
	await sim.frames(4)
	_check(app.server.players_in() == [1] and sim.clients[1].setup_in and not app.current_screen().start_button.disabled,
			"the last phone is IN even when it chose OUT before the other phone left: Start works")


## With one phone the question does not show.
func _one_phone() -> void:
	print("one phone")
	var app: Node = sim.app
	await sim.leave_all()
	await sim.join(1)
	app.go_game_settings("maze")
	await _wait_for(func(): return app.server.setup_open)
	await sim.frames(6)
	_check(not sim.clients[0].setup_pick and app.current_screen().in_label.text == "",
			"with one phone there is no question and no list")
	sim.clients[0].send_play(false)
	await sim.frames(6)
	_check(app.server.players_in() == [0] and not app.current_screen().start_button.disabled,
			"with one phone an OUT message changes nothing: the phone stays IN and Start works")


## The tallest views (the track list of Car Race; a swing game has the safety line) with 3 players listed stay inside the 60 px
## safe margin (REQ-GM-40, REQ-GM-90).
func _fit() -> void:
	print("fit")
	var app: Node = sim.app
	await sim.join(1)   # the 4th phone
	for id in ["marble_race", "tennis", "mini_golf"]:
		app.go_game_settings(id)
		await _wait_for(func(): return sim.clients[3].setup_pick)
		await sim.frames(4)
		var view: Control = app.current_screen()
		var low: float = view.in_label.get_global_rect().end.y
		_check(view.in_label.text != "" and low <= 1080.0 - 60.0 and view.how_to_label.get_global_rect().position.y >= 60.0,
				"%s with 4 players listed: the view ends at %.0f px of 1020" % [id, low])
		# REQ-GM-90: the IN and OUT lines do not widen the column: the rows and the Back and Start line keep the width of the
		# widest row (880 px, wider only for the track list), not the 1500 px of how to play.
		var span: float = view.start_button.get_global_rect().end.x - view.back_button.get_global_rect().position.x
		_check(view.rows[0].size.x < 1500.0 and is_equal_approx(view.rows[0].size.x, span),
				"%s with 4 players listed: the column is %.0f px wide, the same as the rows (%.0f px)" % [id, span, view.rows[0].size.x])
