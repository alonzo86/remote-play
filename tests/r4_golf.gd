extends SceneTree
## Mini Golf, the rest of Test 26 (docs/MANUAL_TESTS.md test 26), with simulated phones over the loopback and the game stepped by
## hand: what is drawn at the start of a turn (3a, 3b), the plate with the name (3c), the lines on the two phones (3d), the gold
## aim mark (4c), the swing of the golfer and the moment the ball starts (5b), the sliding barriers (7d), the banner after the
## 6th stroke (8c), the strokes in the bar (8f), the result menu (10a) and its three buttons (10c, 10d).
## The golfer, the ball, the aim mark and the plates are seen through `Shell.recorder` (the game draws with `draw_*`).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r4_golf.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Trace = preload("res://tests/golf_tennis_trace.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Holes = preload("res://scripts/game/mini_golf/golf_holes.gd")
const GolfSim = preload("res://scripts/game/mini_golf/golf_sim.gd")
const GolfLook = preload("res://scripts/game/mini_golf/golf_look.gd")

const DT := 1.0 / 60.0

var _checks := 0
var _fails := 0
var _app: Node
var _golf: GDScript
var _clients: Array = []
var _game: Control
var _ticks := {}
var _notes: Array = []   # What the game drew: {kind, frame, info}.


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A check of something that is wrong today: it counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_app.set_language("en", false)
	_golf = load("res://scripts/game/mini_golf/mini_golf_game.gd")
	load("res://scripts/game/game_settings.gd").clear()
	_clients = await SimInput.connect_phones(self, _app, 2)
	await _start_of_turn()
	await _plate_time()
	await _phone_lines()
	await _aim_mark()
	await _swing_and_ball()
	_barriers()
	_barrier_passes()
	await _picked_up()
	await _bar_counts()
	await _result_menu()
	Shell.recorder = Callable()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


# ---- Helpers ----

func _rec(kind: String, ci: CanvasItem, rect: Rect2, info: Dictionary) -> void:
	if not is_instance_valid(_game) or not (ci == _game or ci == _game._pixel_layer):
		return
	_notes.append({"kind": kind, "frame": Engine.get_process_frames(), "info": info, "rect": rect})


## The notes of one kind from the last frame that drew it.
func _last(kind: String) -> Array:
	var best := -1
	for n in _notes:
		if n.kind == kind and n.frame > best:
			best = n.frame
	return _notes.filter(func(n: Dictionary) -> bool: return n.kind == kind and n.frame == best)


func _draw_once() -> void:
	_notes.clear()
	_game.queue_redraw()
	_game._request_redraw()
	await _frames(2)


func _plate() -> String:
	var plates := _last("plate")
	return String(plates[0].info.msg) if not plates.is_empty() else ""


## Skips the countdown so that a test goes straight to the first turn.
func _to_turn(game: Control) -> void:
	game._clock.time = -0.001
	game._game_tick(0.016)   # GO: the first turn starts


## Feeds one sample to the phone of `slot` and ticks the game.
func _sample(game: Control, slot: int, lin: Vector3, gyro := Vector3.ZERO) -> void:
	var tk: int = _ticks.get(slot, 0)
	game.player(slot).on_sensor(Trace.packet(lin, tk, gyro), int(round(float(tk) * Trace.DT * 1000.0)))
	_ticks[slot] = tk + 1
	game._game_tick(DT)


func _rest(game: Control, slot: int, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_sample(game, slot, Vector3.ZERO)


## A new game for the 2 phones after the countdown, the first turn running.
func _new_game(props := {}) -> Control:
	var p := {"difficulty": "medium", "holes": "3"}
	p.merge(props, true)
	_game = null
	Shell.recorder = Callable()
	_app.go(_golf, p)
	await _frames(3)
	_game = _app.current_screen()
	_game.set_process(false)
	Shell.recorder = _rec
	_to_turn(_game)
	for s in _game.participants:
		_rest(_game, s, 0.2)
	return _game


## The ball of the player on turn is put in the cup (`in_cup`) or stops on the grass: the result of one putt.
func _putt_result(game: Control, in_cup: bool) -> void:
	game.sim.in_cup = in_cup
	game.sim.in_water = false
	game._putt_done()


# ---- 3a, 3b ----

## 3a: at the start of a turn 1 golfer and 1 white ball are drawn. 3b: the shirt has the color of the phone on turn.
func _start_of_turn() -> void:
	print("the start of a turn")
	var game := await _new_game()
	await _draw_once()
	var golfers := _last("golfer")
	var balls := _last("ball")
	_check(game.rules.current_slot() == 0 and golfers.size() == 1 and balls.size() == 1,
			"3a: 1 golfer and 1 ball are drawn at the start of the turn of phone 1 (%d golfers, %d balls)"
			% [golfers.size(), balls.size()])
	_check(not balls.is_empty() and balls[0].info.color == GolfLook.WHITE, "3a: the ball is white")
	_check(not golfers.is_empty() and golfers[0].info.shirt == game.player(0).color,
			"3b: the shirt of the golfer has the color of phone 1")
	_putt_result(game, false)
	game._after_result()
	await _draw_once()
	golfers = _last("golfer")
	balls = _last("ball")
	_check(game.rules.current_slot() == 1 and golfers.size() == 1 and balls.size() == 1,
			"3a: on the turn of phone 2 there is still 1 golfer and 1 ball (%d, %d)" % [golfers.size(), balls.size()])
	_check(not golfers.is_empty() and golfers[0].info.shirt == game.player(1).color
			and game.player(0).color != game.player(1).color, "3b: the shirt is now the color of phone 2, not of phone 1")


# ---- 3c ----

## 3c: the plate "<NAME>'S TURN!" shows for 1.0 to 2.0 s: a look every 0.1 s of game time.
func _plate_time() -> void:
	print("the plate with the name")
	var game := await _new_game()
	var want := Lang.f("mini_golf.turn", [game.player(0).player_name])
	var shown := 0
	var first_hint := ""
	for k in 26:
		await _draw_once()
		if _plate() == want:
			shown += 1
		elif first_hint == "" and k > 0:
			first_hint = _plate()
		game._game_tick(0.1)
	var seconds := float(shown) * 0.1
	_check(seconds >= 1.0 and seconds <= 2.0,
			"3c: the plate '%s' showed in %d of 26 looks, 0.1 s apart: %.1f s (1.0 to 2.0 s)" % [want, shown, seconds])
	_check(first_hint != want, "3c: after the plate it is gone (the next plate is '%s')" % first_hint)


# ---- 3d ----

## 3d: the phone on turn is told YOUR TURN (state 1), the other one gets the name of the player on turn (state 2, golf words).
func _phone_lines() -> void:
	print("the phones")
	var game := await _new_game()
	await _frames(6)
	var c0 = _clients[0]
	var c1 = _clients[1]
	_check(c0.turn_state == 1 and c0.turn_kind == "golf" and c0.turn_who == "",
			"3d: phone 1 is on turn and shows YOUR TURN (state %d)" % c0.turn_state)
	_check(c1.turn_state == 2 and c1.turn_kind == "golf" and c1.turn_who == game.player(0).player_name,
			"3d: phone 2 shows '%s' with the name of the player on turn: '%s'"
			% [Lang.f("mini_golf.phone_wait", [c1.turn_who]), c1.turn_who])
	_putt_result(game, false)
	game._after_result()
	game._game_tick(DT)
	await _frames(6)
	_check(c1.turn_state == 1 and c0.turn_state == 2 and c0.turn_who == game.player(1).player_name,
			"3d: the next turn: phone 2 is on turn, phone 1 shows the name '%s'" % c0.turn_who)


# ---- 4c ----

## 4c: the aim mark is white before the back swing and gold after it.
func _aim_mark() -> void:
	print("the aim mark")
	var game := await _new_game()
	await _draw_once()
	var before := _last("aim")
	_check(before.size() == 1 and not before[0].info.locked and before[0].info.color != GolfLook.GOLD,
			"4c: before the back swing the aim mark is not gold")
	for i in 15:   # The back swing (the forward half is left out) and a rest: the direction is locked.
		_sample(game, 0, Trace.stroke(Vector3(1, 0, 0), 8.0, 0.0, 0.25, 0.01)[i])
	_rest(game, 0, 0.1)
	await _draw_once()
	var after := _last("aim")
	_check(game.detector.aim_locked and after.size() == 1 and after[0].info.locked and after[0].info.color == GolfLook.GOLD,
			"4c: at the back swing the aim mark is gold (locked: %s)" % str(game.detector.aim_locked))


# ---- 5b ----

## 5b: the golfer swings back and through; the ball starts when the club is at the ball.
func _swing_and_ball() -> void:
	print("the swing")
	var game := await _new_game()
	var address: Dictionary = game._pose()
	var back_a := -999.0
	for lin in Trace.stroke(Vector3(1, 0, 0), 8.0, 10.0):
		if game.phase != game.Phase.AIM:
			break
		_sample(game, 0, lin)
		if game.phase == game.Phase.AIM:
			back_a = maxf(back_a, float(game._pose().a))
	for i in 180:
		if game.phase != game.Phase.AIM:
			break
		_sample(game, 0, Vector3.ZERO)
	_check(game.phase == game.Phase.ROLL and game.rules.strokes_on_hole(0) == 0, "5b: the swing putts (the ball rolls)")
	_check(back_a > float(address.a) + 60.0,
			"5b: the club went back: its angle %.0f against %.0f at the address" % [back_a, address.a])
	var spot: Vector2 = game.sim.pos
	game._game_tick(DT)
	var moved: float = game.sim.pos.distance_to(spot)
	var early: Dictionary = game._pose()
	var hit_at := -1.0
	var through_a := -999.0
	for i in 40:
		var age: float = game._swing_age
		var pose: Dictionary = game._pose()
		if hit_at < 0.0 and age >= GolfLook.SWING_DOWN - 0.001:
			hit_at = float(pose.ab)
		if age >= 0.3 and through_a == -999.0:
			through_a = float(pose.a)
		game._game_tick(DT)
	_check(hit_at >= 0.9, "5b: at %.2f s after the putt the club touches the ball (ab %.2f)" % [GolfLook.SWING_DOWN, hit_at])
	_check(through_a > 60.0, "5b: and the club goes through to the front (angle %.0f at 0.3 s)" % through_a)
	# REQ-MG-16: "The ball starts at once" (the animation is played by the TV when the swing is found, and the detector reports a
	# swing a few samples after the hit). The manual step 26.5b said "at the hit": the requirement wins (align.md).
	_check(moved > 0.0, "5b: REQ-MG-16: the ball starts at once, it moved %.3f m in the first tick (the club is at ab %.2f)"
			% [moved, float(early.ab)])


# ---- 7d ----

## 7d: at every moment of 30 s a gap of 0.18 m or more is open at each sliding barrier (holes 3 and 5).
func _barriers() -> void:
	print("the sliding barriers")
	for n in [3, 5]:
		var h: Dictionary = Holes.hole(n)
		_check(h.movers.size() == 1, "7d: hole %d has a sliding barrier" % n)
		for m in h.movers:
			var along_z := String(m.axis) == "z"
			var r0: Rect2 = m.rect
			var cross: float = r0.get_center().x if along_z else r0.get_center().y
			var lo := 99.0
			var hi := -99.0
			for f in h.fairway:
				var fr: Rect2 = f
				var inside := (fr.position.x <= cross and cross <= fr.end.x) if along_z \
						else (fr.position.y <= cross and cross <= fr.end.y)
				if inside:
					lo = minf(lo, fr.position.y if along_z else fr.position.x)
					hi = maxf(hi, fr.end.y if along_z else fr.end.x)
			var worst := 99.0
			var lowest := 99.0
			var highest := -99.0
			for k in 600:   # 30 s, a look every 0.05 s
				var r: Rect2 = Holes.mover_rect(m, float(k) * 0.05)
				var b0: float = r.position.y if along_z else r.position.x
				var b1: float = r.end.y if along_z else r.end.x
				worst = minf(worst, maxf(b0 - lo, hi - b1))
				lowest = minf(lowest, b0)
				highest = maxf(highest, b0)
			_check(hi > lo and worst >= 4.0 * Holes.BALL_R,
					"7d: hole %d: the widest gap is never under %.2f m (the ball is %.2f m wide)" % [n, worst, 2.0 * Holes.BALL_R])
			_check(highest - lowest > 0.5 * float(m.amp), "7d: hole %d: the barrier moves by %.2f m" % [n, highest - lowest])


## 7d: a ball aimed at the gap passes the barrier of hole 3 at least once in 5 putts started at different times.
func _barrier_passes() -> void:
	var h: Dictionary = Holes.hole(3)
	var m: Dictionary = h.movers[0]
	var passed := 0
	for k in 5:
		var t0 := float(k) * 0.9
		var r: Rect2 = Holes.mover_rect(m, t0 + 0.2)
		var below_w: float = r.position.y - 2.9
		var above_w: float = 4.3 - r.end.y
		var zc: float = 2.9 + below_w * 0.5 if below_w >= above_w else r.end.y + above_w * 0.5
		var sim := GolfSim.new()
		sim.start(h, Vector2(1.25, zc))
		sim.clock = t0
		sim.putt(PI * 0.5, 2.5)
		var max_x := sim.pos.x
		var guard := 0
		while not sim.finished and guard < 2000:
			sim.tick(DT)
			max_x = maxf(max_x, sim.pos.x)
			guard += 1
		if max_x > 2.0:
			passed += 1
	_check(passed >= 1, "7d: a ball aimed at the gap passed the barrier in %d of 5 putts (at least 1)" % passed)


# ---- 8c ----

## 8c: the 6th stroke of a player that does not get the ball in shows "Picked up after 6 strokes" and the hole counts 6.
func _picked_up() -> void:
	print("picked up")
	var game := await _new_game()
	_putt_result(game, true)   # Phone 1 is in with one stroke.
	game._after_result()
	var banners_early := 0
	for k in 5:
		_putt_result(game, false)
		if game._banner != "":
			banners_early += 1
		game._after_result()
	_check(game.rules.strokes_on_hole(1) == 5 and banners_early == 0,
			"8c: after 5 strokes the ball is not picked up (no banner)")
	_putt_result(game, false)
	var want := Lang.f("mini_golf.picked", [6])
	await _draw_once()
	_check(game.rules.strokes_on_hole(1) == 6 and game._banner == want and _plate().to_lower() == want.to_lower(),
			"8c: the 6th stroke shows the banner '%s' (on the screen: '%s')" % [want, _plate()])
	_check(game.rules.hole_done() and game.rules.total(1) == 6, "8c: the hole is done and counts 6 strokes for phone 2")


# ---- 8f ----

## 8f: after every putt the number in the bar is the number of putts of that player counted by hand.
func _bar_counts() -> void:
	print("the bar")
	var game := await _new_game()
	var by_hand := [0, 0]
	var all_same := true
	for k in 10:
		var slot: int = game.rules.current_slot()
		by_hand[slot] += 1
		_putt_result(game, false)
		var text0: String = game.chip_text(0)
		var text1: String = game.chip_text(1)
		var want0: String = Lang.f("mini_golf.chip", [game.player(0).player_name, by_hand[0]])
		var want1: String = Lang.f("mini_golf.chip", [game.player(1).player_name, by_hand[1]])
		if text0 != want0 or text1 != want1:
			all_same = false
			print("    putt %d: '%s' / '%s', counted '%s' / '%s'" % [k + 1, text0, text1, want0, want1])
		game._after_result()
		if game.rules.hole_done():
			break
	_check(all_same and by_hand[0] + by_hand[1] >= 10,
			"8f: the chips of the bar agree with the putts counted by hand (%s) after each of them" % str(by_hand))


# ---- 10a, 10c, 10d ----

## Plays a 1 hole match to the result menu: phone 1 needs `strokes0`, phone 2 `strokes1` strokes.
func _finish_match(game: Control, strokes0: int, strokes1: int) -> void:
	var need := [strokes0, strokes1]
	var guard := 0
	while not game.rules.hole_done() and guard < 30:
		var slot: int = game.rules.current_slot()
		_putt_result(game, game.rules.strokes_on_hole(slot) + 1 >= int(need[slot]))
		game._after_result()
		guard += 1
	game._after_hole()
	var t := 0.0
	while not game.is_over and t < 5.0:
		game._game_tick(DT)
		t += DT
	await _frames(3)


func _menu_texts(game: Control) -> Array:
	var labels: Array = game._menu_box.find_children("*", "Label", true, false)
	return labels.map(func(l: Label) -> String: return String(l.text).to_lower())


func _press(game: Control, key: String) -> bool:
	for b in game.menu_buttons():
		if b.text == key or b.text.to_lower() == Lang.t(key).to_lower():
			_game = null
			b.pressed.emit()
			return true
	return false


func _screen_file() -> String:
	var scr: Control = _app.current_screen()
	return String(scr.get_script().resource_path).get_file()


func _result_menu() -> void:
	print("the result menu")
	var game := await _new_game({"holes": "1"})
	await _finish_match(game, 1, 3)
	var texts := _menu_texts(game)
	var rows := texts.filter(func(s: String) -> bool: return s.contains("   ") and (s.contains("sim0") or s.contains("sim1")))
	var title := Lang.f("result.winner", ["Sim0"]).to_lower()
	_check(game.is_over and texts.has(title), "10a: with 1 and 3 strokes the title is '%s': %s" % [title, str(texts)])
	_check(rows.size() == 2 and rows[0].contains("sim0") and rows[1].contains("sim1"),
			"10a: the list is in the order of the strokes, the fewest first (%s)" % str(rows))
	# 10c: Try again starts hole 1 again with 0 strokes.
	_check(_press(game, "minigame.restart"), "10c: the menu has the button Try again")
	await _frames(4)
	var again: Control = _app.current_screen()
	_check(again.get_script() == _golf and again.rules.hole_number() == 1 and again.holes == "1"
			and again.rules.strokes_on_hole(0) == 0 and again.rules.strokes_on_hole(1) == 0 and not again.is_over,
			"10c: Try again starts hole 1 again with 0 strokes for each player")
	# 10a: equal strokes are a tie.
	_game = again
	_game.set_process(false)
	Shell.recorder = _rec
	_to_turn(again)
	await _finish_match(again, 2, 2)
	texts = _menu_texts(again)
	_check(again.is_over and texts.has(Lang.t("minigame.tie").to_lower()),
			"10a: with equal strokes the title is 'Tie!': %s" % str(texts))
	# 10d: New game opens the settings view, Back to menu on the next result menu opens the Games screen.
	_check(_press(again, "minigame.new_game"), "10d: the menu has the button New game")
	await _frames(4)
	_check(_screen_file() == "tv_game_settings.gd", "10d: New game opens the settings view of the game (%s)" % _screen_file())
	var third := await _new_game({"holes": "1"})
	await _finish_match(third, 1, 2)
	_check(third.is_over and _press(third, "minigame.back_to_menu"), "10d: the next result menu has the button Back to menu")
	await _frames(4)
	_check(_screen_file() == "tv_games.gd", "10d: Back to menu opens the Games screen (%s)" % _screen_file())
