extends SceneTree
## Smoke test of Air Hockey with simulated phones (REQ-AH-*, REQ-GM-105, 106). Run:
##   godot --headless --path . --script tests/smoke_air_hockey.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const MedalView = preload("res://scripts/ui/medal_view.gd")

var _fails := 0
var _checks := 0
var _seq := [0, 0, 0, 0]


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


## Sends sensor packets of every phone for `seconds`. `buttons` is the button bits of each phone (0 for none).
func _stream(clients: Array, seconds: float, accel: Array, buttons := []) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in clients.size():
			var b: int = int(buttons[i]) if i < buttons.size() else 0
			clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, accel[i], b, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _labels(game: Control) -> Array:
	var r := []
	if game._menu_box != null:
		for l in game._menu_box.find_children("*", "Label", true, false):
			r.append(l.text)
	return r


func _new_haptics() -> RefCounted:
	return load("res://scripts/game/haptics.gd").new()


func _connect(app: Node, n: int, have := 0) -> Array:
	var clients := []
	for i in n:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < have + i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	return clients


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var Hockey = load("res://scripts/game/air_hockey/air_hockey_game.gd")
	var TvGameSettings = load("res://scripts/ui/tv_game_settings.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	GameSettings.clear()
	var clients: Array = await _connect(app, 3)
	var flat := Vector3(0, 0, 9.81)
	var lean := deg_to_rad(15.0)
	var right := Vector3(-sin(lean), 0, cos(lean)) * 9.81
	await _stream(clients, 0.5, [flat, flat, flat])

	# The settings view: Difficulty and Goals (REQ-AH-18), and no IN or OUT (REQ-GM-106).
	app.go_game_settings("air_hockey")
	await _frames(4)
	var sv: Control = app.current_screen()
	await _stream(clients, 0.4, [flat, flat, flat])
	_check(is_instance_of(sv, TvGameSettings) and sv.rows.size() == 2 and sv.rows[1].value == "5" and not sv.start_button.disabled,
			"Air Hockey opens the settings view with Difficulty and Goals on 5; Start works with 3 phones")
	_check(not sv.in_label.visible and not sv.out_label.visible and not clients[0].setup_pick,
			"with 3 phones the settings view has no IN and OUT lines and the phones are not asked IN or OUT (REQ-GM-106)")
	_check(GameSettings.props_for(app.Registry.find("air_hockey")) == {"difficulty": "medium", "goals": "5"},
			"the game gets the props difficulty and goals (REQ-GM-93)")
	var entry: Dictionary = app.Registry.find("air_hockey")
	_check(entry.pad == ["a"] and not app.Registry.has_control(entry, "recenter") and not app.Registry.has_control(entry, "b"),
			"the pad has button A alone, no B and no RECENTER (Test 27 step 13, REQ-GM-37a)")
	var key := InputEventAction.new()
	key.action = "ui_right"
	key.pressed = true
	sv.rows[1]._gui_input(key)
	_check(sv.rows[1].value == "6", "the Goals row steps from 5 to 6")
	var row = sv.rows[1].row
	_check(GameSettings.step(row, "10", 1) == "10" and GameSettings.step(row, "3", -1) == "3"
			and row.values.size() == 8 and GameSettings.title_text(row, "7") == "7",
			"the Goals row goes from 3 to 10, stops at both ends and shows only the number (REQ-AH-18)")
	GameSettings.clear()

	# Enrollment with 3 phones (REQ-GM-106): nobody plays until two press A.
	app.go(Hockey, {"difficulty": "medium", "goals": "3"})
	await _frames(3)
	var game: Control = app.current_screen()
	_check(game.phase == game.Phase.ENROLL and game.participants.size() == 3 and game.bot == null and game.goals_to_win() == 3,
			"3 phones: the game waits for enrollment, with no bot, and first to 3 (REQ-GM-106, REQ-AH-18)")
	game._game_tick(0.1)
	_check(game.sim.puck_pos.is_equal_approx(game.sim.RINK.get_center()), "nothing moves before the match starts")
	await _stream(clients, 0.3, [right, flat, flat], [0, 0, 0])
	_check(game.phase == game.Phase.ENROLL, "a tilt does not enroll a phone")
	await _stream(clients, 0.2, [flat, flat, flat], [Protocol.BTN_B, 0, 0])
	_check(game.phase == game.Phase.ENROLL and game._enrolled.is_empty(), "B does not enroll a phone")
	await _stream(clients, 0.2, [flat, flat, flat], [0, 0, Protocol.BTN_A])
	_check(game._enrolled == [2] and game.phase == game.Phase.ENROLL and not clients[0].pad_buttons.is_empty(),
			"a press of A on phone 3 enrolls it: the first enrolled stands on the left, "
			+ "and the match waits for a second player (REQ-AH-3)")
	game._on_button(Protocol.BTN_A, 2)
	_check(game._enrolled == [2], "a phone that is enrolled already is not enrolled twice")
	game._on_button(Protocol.BTN_A, 0)
	await _frames(3)
	_check(game.phase == game.Phase.PLAY and game.participants == [2, 0] and game.bot == null and game.seats.size() == 2
			and game.seats[0].slot == 2 and game.seats[1].slot == 0 and game.sim.wait > 0.0,
			"the second press starts the match for the two that enrolled, left seat and right seat in that order (REQ-AH-1, REQ-AH-3)")
	_check(clients[1].phase == "waiting" and clients[2].phase == "playing" and clients[0].phase == "playing",
			"the third phone watches: its pad says waiting (REQ-GM-106, REQ-AH-2)")
	_check(game._scoreboard() != null and game._board.size() == 2,
			"two phones: the phones get a place and a score (REQ-GM-46, REQ-AH-11)")

	# Play: a tilt moves the paddle of its seat (REQ-AH-4).
	var seat1_start: Vector2 = game.sim.paddles[1].pos
	game.sim.wait = 0.0
	await _stream(clients, 0.5, [right, right, flat])
	_check(game.sim.paddles[1].pos.x != seat1_start.x or game.sim.paddles[1].pos.y != seat1_start.y,
			"the tilt of phone 1 moves the paddle of the right seat")
	_check(game.seat_tilt(0, 0.016) == game.player(2).tilt(), "the left seat is tilted by its phone")
	game.sim.reset(-1)
	game.sim.wait = 0.0

	# A hit buzzes the phone of the paddle (REQ-AH-12), a soft one does not.
	game._haptics = _new_haptics()
	game._on_hit(0, 300.0)
	var soft_buzz: bool = game._haptics._last.is_empty()
	game._on_hit(0, 900.0)
	_check(soft_buzz and game._haptics._last.has(2) and not game._haptics._last.has(0),
			"a hard hit buzzes the phone of the seat that hit, and a soft hit buzzes none (REQ-AH-12)")

	# A goal (REQ-AH-9): the puck goes in the left goal, the right seat scores.
	var c: Vector2 = game.sim.RINK.get_center()
	game.sim.puck_pos = Vector2(game.sim.RINK.position.x + 100.0, c.y)
	game.sim.puck_vel = Vector2(-900.0, 0.0)
	for i in 30:
		game._game_tick(1.0 / 60.0)
		if game.phase == game.Phase.GOAL:
			break
	_check(game.phase == game.Phase.GOAL and game.scores == [0, 1] and game._board.score(0) == 1.0
			and game.banner_text == "GOAL FOR Sim0!",
			"a puck in the left goal gives a goal to the right seat and a banner names the player: %s" % game.banner_text)
	_check(game.is_paused() == false and game._can_open_menu(), "the pause menu works during the match")
	var frozen: Vector2 = game.sim.puck_pos
	game._game_tick(0.5)
	_check(game.sim.puck_pos == frozen and game.phase == game.Phase.GOAL, "nothing moves while the banner shows")
	game._game_tick(game.GOAL_BANNER)
	_check(game.phase == game.Phase.PLAY and game.sim.puck_pos.x < c.x and game.sim.wait > 0.0,
			"after the banner the puck is served on the side of the seat that conceded")
	await _frames(3)
	_check(clients[0].score_rank == 1 and clients[0].score_text == "1" and clients[2].score_rank == 2,
			"each phone gets its place and its goals; the leader is the right seat (REQ-FL-67)")
	_check(game.leader_text() == "1", "the leader chip shows the goals of the leader (REQ-GM-46, REQ-AH-11)")

	# The end of the match: first to 3 (REQ-AH-10).
	game.scores[1] = 2
	game._board.set_score(0, 2.0)
	game._goal(1)
	await _frames(3)
	var labels := _labels(game)
	var menu: Array = game.menu_buttons().map(func(b): return b.text)
	_check(game.is_over and menu == ["minigame.restart", "minigame.new_game", "minigame.back_to_menu"]
			and labels[0] == "SIM0 WINS!" and labels[1].contains("3 GOALS") and labels[2].contains("0 GOALS"),
			"3 goals end the match: the result menu names the winner and lists the goals "
			+ "(REQ-AH-1, REQ-GM-95): %s %s" % [str(menu), str(labels)])
	_check(MedalView.tiers_in(game._menu_box) == ["gold", "silver"],
			"two players get the medals of their places (REQ-GM-73)")

	# A lost phone in the match: the card has no "Resume without" (REQ-AH-19).
	app.go(Hockey, {"difficulty": "easy", "goals": "5"})
	await _frames(3)
	game = app.current_screen()
	game._on_button(Protocol.BTN_A, 0)
	game._on_button(Protocol.BTN_A, 1)
	_check(game.phase == game.Phase.PLAY and game.participants == [0, 1] and game._allow_resume_without() == false,
			"a new match enrolls again at every start; the card of a lost phone may not offer Resume without")
	await _stream(clients, 0.3, [flat, flat, flat])
	clients[1].set_process(false)
	var waited := Time.get_ticks_msec()
	while not game.is_paused() and Time.get_ticks_msec() - waited < 9000:
		await process_frame
	var titles := _labels(game)
	var buttons: Array = game.menu_buttons().map(func(b): return b.text)
	_check(game.is_paused() and titles[0] == "2P LOST CONNECTION" and buttons == ["minigame.end_game"],
			"a silent phone pauses the match: the card has End game only, no Resume while it is away: %s %s" % [str(titles), str(buttons)])
	var frozen_pos: Vector2 = game.sim.puck_pos
	game._process(0.5)
	_check(game.sim.puck_pos == frozen_pos, "nothing runs during the pause")
	clients[1].set_process(true)
	var back := Time.get_ticks_msec()
	while game.menu_buttons().map(func(b): return b.text) != ["minigame.resume", "minigame.end_game"] \
			and Time.get_ticks_msec() - back < 8000:
		await _stream(clients, 0.1, [flat, flat, flat])
	buttons = game.menu_buttons().map(func(b): return b.text)
	_check(buttons == ["minigame.resume", "minigame.end_game"],
			"when the phone is back, the card offers Resume and End game: %s" % [str(buttons)])
	game._resume_game()
	_check(not game.is_paused() and game.phase == game.Phase.PLAY, "Resume goes on with the match")

	# A player that leaves for good ends the match (REQ-AH-19); the one that stays wins.
	game.scores[0] = 1
	game._board.set_score(0, 1.0)
	clients[1].leave()
	var gone := Time.get_ticks_msec()
	while not game.is_over and Time.get_ticks_msec() - gone < 8000:
		await _stream([clients[0], clients[2]], 0.1, [flat, flat])
	labels = _labels(game)
	_check(game.is_over and labels[0] == "SIM0 WINS!" and game.participants == [0],
			"a player that left ends the match, and the player that stays wins: %s" % [str(labels)])
	_check(MedalView.tiers_in(game._menu_box) == ["gold"], "the player that stays has a technical win with the gold medal")
	clients.remove_at(1)

	# One phone: the match starts at once against ROBO (REQ-GM-105, REQ-AH-14).
	clients[1].leave()
	var left := Time.get_ticks_msec()
	while app.server.connected_slots().size() > 1 and Time.get_ticks_msec() - left < 8000:
		await _stream([clients[0]], 0.1, [flat])
	clients.remove_at(1)
	app.go(Hockey, {"difficulty": "hard", "goals": "3"})
	await _frames(3)
	game = app.current_screen()
	_check(game.phase == game.Phase.PLAY and game.bot != null and game.participants == [0] and game.seats.size() == 2
			and game.seats[1].slot == -1 and game.seats[1].name == "ROBO" and game.seats[1].color == game.Look.BOT_COLOR
			and game.seats[1].color == Color("a678e6") and game.seats[1].avatar == -1,
			"one phone: the match starts at once against ROBO, named ROBO, purple #a678e6, "
			+ "with no avatar on its chip (REQ-GM-105, REQ-AH-15)")
	_check(not Protocol.PLAYER_COLORS.has(game.Look.BOT_COLOR), "the color of ROBO is not the color of any phone slot")
	# Issue #227: the puck is black with a light ring: the ring stands out from the black goal mouth, the black from
	# the white table.
	var contrast := Callable(game.Look.UiTheme, "contrast")
	_check(contrast.call(game.Look.PUCK_RING, game.Look.FLOOR) >= 3.0 and contrast.call(game.Look.RAIL, game.Look.SURFACE) >= 3.0,
			"the puck ring has 3:1 against the black goal mouth, and the black puck has 3:1 against the white table")
	# Issue #223: the hint at the start stands above the two score chips and does not cover them.
	var Shell = load("res://scripts/game/shell.gd")
	var hints: Array[Rect2] = []
	var chips: Array[Rect2] = []
	Shell.recorder = func(kind: String, ci: CanvasItem, rect: Rect2, _info: Dictionary) -> void:
		if ci == game and kind == "hint":
			hints.append(rect)
		elif ci == game and kind == "chip":
			chips.append(rect)
	await _frames(3)
	Shell.recorder = Callable()
	var covered := hints.is_empty() or chips.size() < 2 or chips.any(func(c: Rect2) -> bool: return hints[-1].intersects(c))
	_check(not covered, "the hint plate shows and does not cover a score chip (hints %s, chips %s)" % [str(hints), str(chips)])
	_check(game._scoreboard() == null and game.bot.skill.reaction == 0.07,
			"with ROBO there is no place on the phone, and the bot has the hard skill")
	game.sim.wait = 0.0
	var before: Vector2 = game.sim.paddles[1].pos
	game.sim.puck_pos = Vector2(game.sim.RINK.get_center().x + 200.0, game.sim.RINK.get_center().y - 220.0)
	game.sim.puck_vel = Vector2(400.0, 0.0)
	for i in 90:
		game._game_tick(1.0 / 60.0)
	_check(game.sim.paddles[1].pos != before, "ROBO moves its paddle by itself")
	game.sim.puck_pos = Vector2(game.sim.RINK.end.x - 100.0, game.sim.RINK.get_center().y)
	game.sim.puck_vel = Vector2(900.0, 0.0)
	game.sim.paddles[1].pos = Vector2(game.sim.RINK.end.x - 400.0, game.sim.RINK.position.y + 150.0)
	for i in 30:
		game._game_tick(1.0 / 60.0)
		if game.phase == game.Phase.GOAL:
			break
	_check(game.scores == [1, 0] and game.banner_text == "GOAL FOR Sim0!", "a goal for the phone: %s" % game.banner_text)
	game._game_tick(game.GOAL_BANNER)
	game.scores[1] = 2   # ROBO reaches the third goal: it wins the match.
	game._goal(1)
	await _frames(3)
	labels = _labels(game)
	_check(game.is_over and labels[0] == "ROBO WINS!" and labels[1].begins_with("1ST") and labels[1].contains("ROBO")
			and labels[1].contains("3 GOALS")
			and labels[2].contains("SIM0") and labels[2].contains("1 GOAL"),
			"ROBO wins: the result menu names it and lists both rows with no medals: %s" % [str(labels)])
	_check(MedalView.tiers_in(game._menu_box).is_empty(), "a match against ROBO has no medal (REQ-AH-10, REQ-AH-15)")
	game.restart()
	await _frames(3)
	game = app.current_screen()
	game.scores[0] = 2
	game._goal(0)
	await _frames(3)
	labels = _labels(game)
	_check(game.is_over and labels[0] == "SIM0 WINS!" and labels[1].contains("3 GOALS") and labels[2].contains("ROBO"),
			"the phone wins against ROBO: %s" % [str(labels)])
	_check(game.menu_buttons().size() == 3, "the result menu has Try again, New game and Back to menu")

	# The world is drawn in the pixel view (REQ-GM-47i) and the layout fits inside the margin (REQ-AH-20).
	_check(game._pixel_layer != null and game._pixel_viewport.size == Vector2i(480, 270),
			"the world is drawn in the 480x270 pixel view")
	_check(game.sim.RINK.position.x - 24.0 >= 60.0 - 24.0 and game.sim.RINK.end.x + 24.0 <= 1920.0 - 60.0 + 24.0
			and game.sim.RINK.position.y - 24.0 >= 112.0 and game.CHIP_Y + 64.0 <= 1080.0 - 60.0,
			"the table is under the black bar and the chips are inside the 60 px margin")

	# REQ-AH-23: the design screen scales to `size` with one factor; the sim stays in design units.
	var rink_before: Rect2 = game.sim.RINK
	var size_before: Vector2 = game.size
	var scaled := {}
	for res in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1600, 1200)]:
		game.size = res
		game._fit_design(game.CHIP_Y, game.CHIP_H)
		scaled[res] = {"k": game.design_k, "a": game._to_screen(rink_before.position), "b": game._to_screen(rink_before.end),
				"chip": game._chip_pos(1, 250.0)}
	game.size = size_before
	var s720: Dictionary = scaled[Vector2(1280, 720)]
	var s1080: Dictionary = scaled[Vector2(1920, 1080)]
	var s43: Dictionary = scaled[Vector2(1600, 1200)]
	_check(is_equal_approx(s720.k, (720.0 - 60.0 - 64.0 - 112.0) / (940.0 - 112.0)) and s720.a.y >= 112.0 + 24.0 * s720.k
			and s720.b.y + 24.0 * s720.k < s720.chip.y and s720.chip.y + 64.0 <= 720.0 - 60.0
			and s720.chip.x + 250.0 <= 1280.0,
			"REQ-AH-23: at 1280x720 the rink is under the 112 px bar, the chips stand under it, inside the 60 px margin: %s"
			% str(s720))
	_check(s1080.k == 1.0 and s1080.a == rink_before.position and s1080.b == rink_before.end
			and s1080.chip == Vector2(1550.0, 940.0),
			"REQ-AH-23: at 1920x1080 nothing moves (factor 1, chip at 1550, 940)")
	_check(is_equal_approx(s43.k, 5.0 / 6.0) and s43.a.x >= 0.0 and s43.b.x <= 1600.0 and s43.b.y <= 1200.0
			and s43.chip.y + 64.0 <= 1200.0, "REQ-AH-23: a 4:3 window keeps one factor and the table is centered: %s" % str(s43))
	_check(game.sim.RINK == rink_before, "REQ-AH-23: the rink of the simulation is in design units whatever the window")

	# One phone and two phones: the TV remote starts a match against ROBO (REQ-GM-106).
	clients.append_array(await _connect(app, 1, 1))
	var second: int = app.server.connected_slots()[-1]
	game.restart()
	await _frames(3)
	game = app.current_screen()
	_check(game.phase == game.Phase.ENROLL and game._enrolled.is_empty(),
			"two phones: a new match waits for the players to enroll")
	game._on_button(Protocol.BTN_A, second)
	var ok := InputEventAction.new()
	ok.action = "ui_accept"
	ok.pressed = true
	game._unhandled_input(ok)
	_check(game.phase == game.Phase.PLAY and game.bot != null and game.participants == [second] and game.seats[1].name == "ROBO",
			"OK on the TV remote starts the match with the one enrolled phone against ROBO")
	game.restart()
	await _frames(3)
	game = app.current_screen()
	game._unhandled_input(ok)
	_check(game.phase == game.Phase.ENROLL, "OK with nobody enrolled starts nothing")
	game.on_back()
	await _frames(3)
	_check(not is_instance_of(app.current_screen(), Hockey), "Back before the match leaves at once, with no question")

	for c2 in clients:
		c2.leave()
	await _frames(20)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
