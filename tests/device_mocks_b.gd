extends SceneTree
## Real-time checks with simulated phones on the loopback network for Treasure Maze, Car Race and banana Party (tests 6, 9 and
## 10 of docs/MANUAL_TESTS.md): a silent phone, the buzzes of the phone, RECENTER, and two throws in one frame. Run:
##   godot --headless --path . --script tests/device_mocks_b.gd -- --role=tv
## The sensor values are written with a fake clock (tests/sim_b.gd). The things that need real time (the network, the cool-down of
## a buzz) use the real clock.

const Sim = preload("res://tests/sim_b.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")

var _fails := 0
var _checks := 0
var sim
var _buzz: Array = []   # [[ms of the buzz, real time of arrival]] for each phone


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
	GameSettings.clear()
	await sim.join(2)
	for i in 2:
		_buzz.append([])
		var idx := i
		sim.clients[i].haptic_requested.connect(func(ms: int): _buzz[idx].append([ms, Time.get_ticks_msec()]))
	for s in 2:
		sim.settle(s, Sim.FLAT)
	await _buzzes()
	await _continuous_wall()
	await _recenter_distance()
	await _same_frame_throws()
	await _silent_phone()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _race() -> GDScript:
	return load("res://scripts/game/marble_race/marble_race.gd")


func _banana() -> GDScript:
	return load("res://scripts/game/snowball_splat/snowball_splat_game.gd")


func _ms_list(i: int) -> Array:
	return _buzz[i].map(func(b): return b[0])


## Test 9.5a: a hit on a wall, a post and a car buzzes the phone 20 ms; a soft hit does not.
func _buzzes() -> void:
	print("device: buzzes in Car Race")
	var race = _race()
	var game: Control = await sim.start(race, {"track_choice": "1", "difficulty": "medium"})
	for s in 2:
		sim.settle(s, Sim.FLAT)
		sim.app.server.players[s].recenter()
	sim.through_countdown(game)
	await sim.frames(6)
	_buzz[0].clear()
	_buzz[1].clear()
	var r0 = game._racers[0]
	var r1 = game._racers[1]
	var hit := func(setup: Callable, who: int) -> Array:
		game._haptics = game.Haptics.new()
		_buzz[0].clear()
		_buzz[1].clear()
		setup.call()
		game._step(1.0 / 120.0)
		await sim.frames(8)
		return _ms_list(who)
	var tr = game.track
	var wall_setup := func() -> void:
		var side: Vector2 = Vector2(1, 0)
		r0.pos = tr.point_at(10.0) + side * (tr.half_width - race.R - 0.01)
		r0.vel = side * 8.0
		r0.arc = 10.0
	var wall: Array = await hit.call(wall_setup, 0)
	_check(wall == [20], "a hard hit on a wall buzzes the phone 20 ms: %s" % str(wall))
	var soft_setup := func() -> void:
		var side: Vector2 = Vector2(1, 0)
		r0.pos = tr.point_at(10.0) + side * (tr.half_width - race.R - 0.01)
		r0.vel = side * 2.0
		r0.arc = 10.0
	var soft: Array = await hit.call(soft_setup, 0)
	_check(soft.is_empty(), "a soft hit (2 m/s, under 3) gives no buzz: %s" % str(soft))
	if game._bumpers.is_empty():
		_check(false, "the track has a post")
	else:
		var b: Vector2 = game._bumpers[0]
		var post_setup := func() -> void:
			r0.pos = b + Vector2(0.0, race.R + race.BUMPER_R - 0.01)
			r0.vel = Vector2(0.0, -8.0)
		var post: Array = await hit.call(post_setup, 0)
		_check(post == [20], "a hit on a post buzzes the phone 20 ms: %s" % str(post))
	var car_setup := func() -> void:
		r0.pos = tr.point_at(8.0)
		r1.pos = r0.pos + Vector2(0.0, -(race.R * 2.0 - 0.02))
		r0.vel = Vector2(0.0, -6.0)
		r1.vel = Vector2.ZERO
	var car: Array = await hit.call(car_setup, 0)
	var car1: Array = _ms_list(1)
	_check(car == [20] and car1 == [20], "two cars that hit at 6 m/s buzz both phones 20 ms: %s %s" % [str(car), str(car1)])
	game.set_process(false)


## Test 9.5b: a car that is pushed into a wall for 5 s gives a buzz at most every 150 ms and not more than 7 in any second.
func _continuous_wall() -> void:
	print("device: a car against a wall for 5 s")
	var race = _race()
	var game: Control = await sim.start(race, {"track_choice": "1", "difficulty": "easy"})
	game.set_process(true)
	for s in 2:
		sim.settle(s, Sim.FLAT)
		sim.app.server.players[s].recenter()
	while game._round.is_counting():
		sim.feed(0, Sim.FLAT)
		sim.feed(1, Sim.FLAT)
		await process_frame
	_buzz[0].clear()
	var end := Time.get_ticks_msec() + 5000
	var side := Vector2(1, 0)
	var r0 = game._racers[0]
	while Time.get_ticks_msec() < end:
		sim.feed(0, Sim.FLAT)
		r0.vel = Vector2(8.0, 0.0)   # pushed into the wall again in every frame: a hard hit in every frame
		r0.pos = game.track.point_at(10.0) + side * (game.track.half_width - game.R - 0.01)
		await process_frame
	var times: Array = _buzz[0].filter(func(b): return b[0] == 20).map(func(b): return b[1])
	var min_gap := 99999
	for k in range(1, times.size()):
		min_gap = mini(min_gap, times[k] - times[k - 1])
	var busiest := 0
	for k in times.size():
		var n := 0
		for m in times:
			if m >= times[k] and m < times[k] + 1000:
				n += 1
		busiest = maxi(busiest, n)
	_check(times.size() >= 3 and min_gap >= 130 and busiest <= 7,
			"%d buzzes in 5 s, the shortest gap %d ms (>= 150 on the TV, 130 here for the network jitter), at most %d in one second (<= 7)"
			% [times.size(), min_gap, busiest])
	game.set_process(false)


## Issue #55: the pad has no Recenter box in the maze and in Car Race; the car and the ball still start from the pose held in
## the countdown (REQ-GM-37).
func _recenter_distance() -> void:
	print("device: no Recenter box in the race and the maze")
	var race = _race()
	var game: Control = await sim.start(race, {"track_choice": "1", "difficulty": "easy"})
	sim.step(game, 0.5, {0: Sim.FLAT, 1: Sim.FLAT})
	await process_frame
	await process_frame
	_check(not sim.clients[0].recenter_button and not sim.clients[1].recenter_button,
			"Car Race: the phones have no Recenter box (REQ-GM-37)")
	game.set_process(false)
	# Issue #124: the phone was level when it joined, and lies tilted (a phone on a table, in a hand) during the countdown. The
	# pose held at GO is the center: the car does not drift (20 degrees is beyond the 1.7 degree snap to flat, REQ-GM-37b).
	var game2: Control = await sim.start(race, {"track_choice": "1", "difficulty": "easy"})
	var tilted: Vector3 = Sim.lean(20.0, 0.0)
	for s in 2:
		sim.settle(s, tilted)
	sim.through_countdown(game2, {0: tilted, 1: tilted})
	var drift: Vector2 = sim.app.server.players[0].tilt()
	_check(drift.length() < 0.03,
			"Car Race: the pose held in the countdown is the center, no drift at GO (tilt %s, issue #124)" % drift)
	game2.set_process(false)


## Test 10.7b: two phones press A in the same frame on the same animal; the throw that arrived first scores, the other not.
func _same_frame_throws() -> void:
	print("device: two throws in one frame")
	var banana = _banana()
	var game: Control = await sim.start(banana, {"seed": 4})
	for s in 2:
		sim.settle(s, Sim.FLAT)
		sim.app.server.players[s].recenter()
	sim.through_countdown(game, {0: Sim.FLAT, 1: Sim.FLAT})
	var area: Rect2 = game._area()
	var ok := true
	for rep in 5:
		game._field.puffs.clear()
		game._field.bushes.clear()
		for s in 2:
			game._throwers[s].reload_left = 0.0
		var puff: PuffField.Puff = game._field._add(1, "orangutan")
		puff.x = 900.0 - rep
		var center: Vector2 = PuffField.center_of(puff, area)
		# Both cursors are at the middle of the area: put the animal there.
		puff.x = (area.get_center().x - area.position.x) * PuffField.REF_AREA.x / area.size.x
		puff.lane_y = (area.get_center().y - area.position.y) * PuffField.REF_AREA.y / area.size.y + PuffField.WAVE * 0.0
		game._presses.clear()
		var before0: float = game._board.score(0)
		var before1: float = game._board.score(1)
		for s in 2:
			sim.feed(s, Sim.FLAT, Vector3.ZERO, Protocol.BTN_A)
		await sim.frames(3)
		var order: Array = game._presses.duplicate()
		for s in 2:
			sim.feed(s, Sim.FLAT, Vector3.ZERO, 0)
		for k in 12:
			sim.feed(0, Sim.FLAT)
			sim.feed(1, Sim.FLAT)
			game._game_tick(Sim.DT)
		var g0: float = game._board.score(0) - before0
		var g1: float = game._board.score(1) - before1
		var single: bool = (g0 == 10.0 and g1 == 0.0) or (g0 == 0.0 and g1 == 10.0)
		var first_wins: bool = order.size() == 2 and ((order[0] == 0 and g0 == 10.0) or (order[0] == 1 and g1 == 10.0))
		ok = ok and single and first_wins
		if not (single and first_wins):
			print("    round ", rep, ": presses ", order, " gains ", g0, " ", g1)
		puff.x = -5000.0
	_check(ok, "5 times: two A presses on one animal give the points to the press that came first, once (REQ-SS-11)")
	game.set_process(false)


## Test 6.6h, 10.8a: a phone that goes silent. The TV notices within the timeout and the start button follows the phones.
func _silent_phone() -> void:
	print("device: a silent phone")
	var limit: int = sim.app.server.peer_timeout_ms + 2000
	# The settings of the maze with two phones; the phone 1 stops sending.
	sim.app.go_game_settings("maze")
	await sim.frames(3)
	var sv: Control = sim.app.current_screen()
	_check(not sv.start_button.disabled and sv.reason_label.text == "", "with two phones Start works")
	sim.clients[0].set_process(false)
	sim.clients[1].set_process(false)
	var t0 := Time.get_ticks_msec()
	while not sv.start_button.disabled and Time.get_ticks_msec() - t0 < limit + 3000:
		await process_frame
	var dt := Time.get_ticks_msec() - t0
	_check(sv.start_button.disabled and dt <= limit and sv.reason_label.text == "NO PLAYERS CONNECTED"
			and sv.reason_label.get_theme_color("font_color") == UiTheme.ACCENT,
			"both phones silent: Start is off and the reason is NO PLAYERS CONNECTED in yellow after %d ms (<= %d, REQ-GM-20)" % [dt,
					limit])
	sim.clients[0].set_process(true)
	sim.clients[1].set_process(true)
	var t1 := Time.get_ticks_msec()
	while sv.start_button.disabled and Time.get_ticks_msec() - t1 < 5000:
		await process_frame
	_check(not sv.start_button.disabled and Time.get_ticks_msec() - t1 < 5000,
			"the phones talk again: Start works after %d ms (< 5000)" % (Time.get_ticks_msec() - t1))
	# banana Party with two phones, one goes silent: the card names it. Both phones must be back first: the start button follows
	# the first one that returns, and a game made with one phone has no second player to lose.
	var t3 := Time.get_ticks_msec()
	while sim.app.server.connected_slots().size() < 2 and Time.get_ticks_msec() - t3 < 8000:
		await process_frame
	_check(sim.app.server.connected_slots().size() == 2, "both phones are connected again before the game starts")
	var banana = _banana()
	sim.app.go(banana, {"seed": 4})
	await sim.frames(3)
	var game: Control = sim.app.current_screen()
	sim.clients[1].set_process(false)
	var t2 := Time.get_ticks_msec()
	while not game.is_paused() and Time.get_ticks_msec() - t2 < limit + 3000:
		await process_frame
	var dt2 := Time.get_ticks_msec() - t2
	var title := ""
	if game._menu_box != null:
		title = (game._menu_box.find_children("*", "Label", true, false)[0] as Label).text
	_check(game.is_paused() and title == "2P LOST CONNECTION" and dt2 <= limit,
			"banana Party: a silent phone pauses the game with the card '%s' after %d ms (<= %d, REQ-GM-30)" % [title, dt2,
					limit])
	var game_script: Script = game.get_script()
	game.menu_buttons()[-1].pressed.emit()   # End game on the card of a lost phone leaves at once (issue #118).
	await sim.frames(3)
	_check(not is_instance_of(sim.app.current_screen(), game_script),
			"End game on the card of a lost phone leaves the game at once, with no 'End the game?' question (issue #118)")
	sim.clients[1].set_process(true)
