extends SceneTree
## Bowling with moving phones (Test 23): sensor traces (tests/sensor_replay.gd) go into the running game, which is stepped
## by hand at 60 Hz. The aim from the turn of the phone, the swing in three grips, the ball speed, the hint after a weak swing,
## the banners, the turn order and the pause. One check sends a swing over a real loopback phone.
## Run: godot --headless --path . --script tests/bowling_replay.gd -- --role=tv

const R = preload("res://tests/sensor_replay.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const BowlingRules = preload("res://scripts/game/bowling/bowling_rules.gd")
const LaneSim = preload("res://scripts/game/bowling/lane_sim.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")

var _checks := 0
var _fails := 0
var _app: Node
var _Bowling
var _clients: Array = []
var _haptic_ms: Array = [[], [], [], []]


## A Haptics that only writes down what the game wants to buzz. It is made when the test runs, because haptics.gd uses the App
## autoload, which does not exist yet when this script is compiled.
func _rec_haptics() -> Object:
	var script := GDScript.new()
	script.source_code = "extends \"res://scripts/game/haptics.gd\"\nvar log: Array = []\n" \
			+ "func pulse(slot: int, ms: int, _cooldown_ms: int) -> bool:\n\tlog.append([slot, ms])\n\treturn true\n"
	script.reload()
	return script.new()


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


## A check that fails because the game breaks a requirement. It counts as a failure until the game is fixed.
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
	_Bowling = load("res://scripts/game/bowling/bowling_game.gd")
	_app = root.get_node("App")
	_app.set_language("en", false)   # The texts are compared in English, whatever language the saved settings have.
	load("res://scripts/game/game_settings.gd").clear()
	for i in 4:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		c.haptic_requested.connect(func(ms: int) -> void: _haptic_ms[i].append(ms))
		_clients.append(c)
		var joined := Time.get_ticks_msec()
		while _app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	await _aim_at_start()
	await _swing_in_the_game()
	await _finger_and_shake()
	await _sideways_and_soft()
	await _grips()
	await _weak_and_wait()
	await _banners_and_turns()
	await _four_names_sheet()
	await _wait_time()
	await _pause()
	await _over_the_network()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


# ---- Helpers ----

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


# ---- Items 2e, 3a, 3d: the aim (a finger on the aim strip, REQ-BW-4) ----

## Puts a finger on the strip at `x` (0 to 1), or lifts it with a negative `x`.
func _finger(f: R.Feeder, x: float) -> void:
	f.touching = x >= 0.0
	f.touch = Vector2(maxf(x, 0.0), 0.5)


func _aim_at_start() -> void:
	print("aim")
	var ctx := await _new_game(2)
	var game: Control = ctx.game
	var f: R.Feeder = ctx.feeders[0]
	_check(not game.has_method("countdown_spots") and game.player(0).color != game.player(1).color,
			"the game has no name tags (removed 2026-10-21): the 2 balls differ by color")
	_play(game, f, R.turn(30.0, 0.5))
	_begin(game)
	_check(absf(game._aim) < 0.01,
			"the phone was turned 30 degrees before the turn; at the start of the turn the aim is in the middle (%.2f)" % game._aim)
	_play(game, f, R.turn(-14.0, 2.0))
	_check(absf(game._aim) < 0.01, "turning the phone does not move the aim (%.2f)" % game._aim)
	var aims: Array = []
	_finger(f, 0.0)
	_play(game, f, R.still(0.3))
	_check(is_equal_approx(game._aim, -1.0), "a finger at the left end of the strip aims to the left end (%.2f)" % game._aim)
	f.feed(R.still(1.0), func() -> void:
		_finger(f, minf(1.0, f.touch.x + R.DT))   # From the left end to the right end in 1 s.
		game._game_tick(R.DT)
		aims.append(game._aim))
	var smooth := true
	for i in range(1, aims.size()):
		smooth = smooth and aims[i] >= aims[i - 1] - 1e-9 and absf(aims[i] - aims[i - 1]) < 0.05
	_check(smooth and aims[-1] > 0.95 and aims[aims.size() / 2] > -0.2 and aims[aims.size() / 2] < 0.2,
			"a finger that slides across the strip in 1 s moves the aim from the left to the right end, one way and without a jump "
			+ "(middle %.2f, end %.2f)" % [aims[aims.size() / 2], aims[-1]])
	# The slide above sets the place after each packet, so its last packet was at 1 - 1/60: the finger rests at the end for a
	# moment, as a real finger does, and then lifts.
	_finger(f, 1.0)
	_play(game, f, R.still(0.1))
	_finger(f, -1.0)
	_play(game, f, R.still(0.5))
	_check(not game.player(0).touching and is_equal_approx(game._aim, 1.0), "the aim stays at the right end when the finger lifts")
	_play(game, f, R.turn(14.0, 2.0))
	_play(game, f, R.gyro_drift(30.0, 0.02, 0.03, 4))
	_check(is_equal_approx(game._aim, 1.0) and not game.detector.aim_locked and game.phase == game.Phase.AIM,
			"30 s of a phone that lies still (gyro noise and drift) and a turn of 14 degrees do not move the aim (%.3f)" % game._aim)
	_again(game)
	_check(is_equal_approx(game._aim, 1.0), "the same player keeps the aim for the next ball (REQ-BW-4)")


# ---- Items 4a to 4d: the swing ----

func _swing_in_the_game() -> void:
	print("swing")
	var ctx := await _new_game(2)
	var game: Control = ctx.game
	var f: R.Feeder = ctx.feeders[0]
	var g := R.grip(R.UP_FLAT)
	var fw := g.dir(0.0)
	var rec = _rec_haptics()
	game._haptics = rec
	_begin(game)
	_wait(game, f, 0.3)
	var turn_buzz: int = rec.log.size()
	var m := {"steps": 0, "locked": -1}
	f.feed(R.back_swing(fw, 10.0, 0.25), func() -> void:
		game._game_tick(R.DT)
		m.steps += 1
		if m.locked < 0 and game.detector.aim_locked:
			m.locked = m.steps)
	_check(game.detector.aim_locked and m.locked >= 0 and m.locked / 60.0 <= 0.5, "the back swing locks the aim within 0.5 s")
	var aim: float = game._aim
	_play(game, f, R.turn(20.0, 0.4))
	_check(game._aim == aim and game.detector.aim_locked and game.phase == game.Phase.AIM,
			"a turn of 20 degrees while the aim is locked changes nothing")
	_play(game, f, R.forward_swing(fw, 25.0, 0.25))
	_wait(game, f, 0.4)
	_check(game.phase == game.Phase.ROLL, "the forward swing throws the ball")
	var buzzes: Array = rec.log.slice(turn_buzz).filter(func(e): return e[1] == 40)
	_check(buzzes.size() == 1 and buzzes[0][0] == 0, "one buzz of 40 ms at the throw, for the phone on turn")
	# Five throws: one buzz each.
	var thrown := 0
	var before: int = rec.log.size()
	for i in 5:
		_again(game)
		_wait(game, f, 0.3)
		_play(game, f, R.stroke(fw, 10.0, 25.0))
		_wait(game, f, 0.2)
		if _threw(game):
			thrown += 1
	var throw_buzzes: int = rec.log.slice(before).filter(func(e): return e[1] == 40).size()
	_check(thrown == 5 and throw_buzzes == 5, "5 throws give 5 buzzes of 40 ms (%d thrown, %d buzzes)" % [thrown, throw_buzzes])
	# Soft and hard: the time from the foul line to the first pin.
	var times := {}
	for name in ["soft", "hard"]:
		_again(game)
		_wait(game, f, 0.3)
		_play(game, f, R.stroke(fw, 5.0 if name == "soft" else 10.0, 9.0 if name == "soft" else 32.0))
		_wait(game, f, 0.2)
		var guard := 0
		while not game.sim.first_hit and game.phase == game.Phase.ROLL and guard < 1200:
			game._game_tick(R.DT)
			guard += 1
		times[name] = game.sim.time
	_check(times.soft > 0.0 and times.hard > 0.0 and times.soft / times.hard >= 1.25,
			"a soft swing takes %.2f s to the first pin, a hard swing %.2f s: at least 1.25 times as long" % [times.soft, times.hard])


# ---- Items 4g, 4h: shakes are ignored, a finger on the strip blocks the throw (REQ-BW-5) ----

func _finger_and_shake() -> void:
	print("shake and finger")
	var ctx := await _new_game(1)
	var game: Control = ctx.game
	var f: R.Feeder = ctx.feeders[0]
	var fw := R.grip(R.UP_FLAT).dir(0.0)
	_begin(game)
	_wait(game, f, 0.3)
	var threw := 0
	var threw_soft := 0   # Shakes of 5 m/s2, the size the manual step 4g starts with and A-24-7 uses.
	var thrown_by := []
	for hz in [6.0, 8.0, 10.0, 12.0]:
		for amp in [5.0, 12.0, 25.0]:
			_play(game, f, R.shake(1.0, amp, hz))
			_wait(game, f, 0.3)
			if _threw(game):
				threw += 1
				threw_soft += 1 if amp == 5.0 else 0
				thrown_by.append("%d Hz %d m/s2" % [int(hz), int(amp)])
				_again(game)
	_check(threw_soft == 0, "4 shakes of 5 m/s2 (6 to 12 Hz) throw nothing (%d thrown)" % threw_soft)
	_check(threw == 0, "12 shakes (6 to 12 Hz, 5 to 25 m/s2) throw nothing (%d thrown: %s)" % [threw, ", ".join(thrown_by)])
	_again(game)
	_wait(game, f, 0.3)
	_finger(f, 0.5)
	_play(game, f, R.stroke(fw, 10.0, 25.0))
	_check(not _threw(game) and not game.detector.aim_locked and game._lift_left > 0.0,
			"a full swing with a finger on the strip throws nothing, locks nothing and shows the hint 'Lift your finger'")
	_finger(f, -1.0)
	_wait(game, f, 0.5)
	_play(game, f, R.stroke(fw, 10.0, 25.0))
	_wait(game, f, 0.3)
	_check(game.phase == game.Phase.ROLL, "the same swing with the finger lifted throws")
	_again(game)
	_finger(f, 0.5)
	_wait(game, f, 0.3)
	_play(game, f, R.still(0.3))
	_check(game._lift_left == 0.0 and not _threw(game), "a finger on the strip without a swing shows no hint and throws nothing")


# ---- Issues #141, #142: a move to the side or a slow shake throws nothing, a soft swing throws ----

func _sideways_and_soft() -> void:
	print("sideways and soft")
	var ctx := await _new_game(1)
	var game: Control = ctx.game
	var f: R.Feeder = ctx.feeders[0]
	var g := R.grip(R.UP_FLAT)
	_begin(game)
	_wait(game, f, 0.3)
	var thrown := []
	var cases := {}
	for cm_s in [[20.0, 0.3], [30.0, 0.4], [50.0, 0.5]]:   # The hand carries the phone from left to right and stops.
		var peak: float = TAU * cm_s[0] / 100.0 / (cm_s[1] * cm_s[1])
		var t := R.Trace.new()
		var n := int(round(cm_s[1] / R.DT))
		for i in n:
			t.add(g.right * peak * sin(TAU * float(i) / float(n)))
		cases["%d cm in %.1f s" % [cm_s[0], cm_s[1]]] = t
	cases["shake 3 Hz 15 m/s2, no finger"] = R.shake(1.0, 15.0, 3.0)
	cases["shake 4 Hz 15 m/s2, no finger"] = R.shake(1.0, 15.0, 4.0)
	for name in cases:
		_play(game, f, cases[name])
		_wait(game, f, 2.0)
		if _threw(game):
			thrown.append(name)
			_again(game)
	_check(thrown.is_empty(), "a move to the side and slow shakes without a finger throw nothing (thrown: %s)" % ", ".join(thrown))
	for name in ["soft", "gentle back"]:
		_again(game)
		_wait(game, f, 0.5)
		_play(game, f, R.stroke(g.dir(0.0), 5.0 if name == "soft" else 4.2, 12.0))
		_wait(game, f, 0.3)
		_check(_threw(game), "a %s swing throws the ball" % name)


# ---- Items 4e, 4f: three grips, and no throw by accident ----

func _grips() -> void:
	print("grips")
	for up in [R.UP_FLAT, R.UP_UPRIGHT, R.UP_SIDE, R.UP_SIDE_LEFT]:
		var ctx := await _new_game(1, {"difficulty": "medium"}, [up])
		var game: Control = ctx.game
		var f: R.Feeder = ctx.feeders[0]
		var g := R.grip(up)
		_begin(game)
		var ok := 0
		for i in 10:
			_again(game)
			_wait(game, f, 0.3)
			_play(game, f, R.noisy(R.stroke(g.dir(0.0), 10.0, 25.0, 0.25, 0.25), 0.3, i + 1))
			_wait(game, f, 0.3)
			if _threw(game):
				ok += 1
		_check(ok >= 8, "grip %s: %d of 10 swings throw" % [str(up), ok])
		_again(game)
		_wait(game, f, 0.3)
		var accidental := false
		for i in 10:
			_play(game, f, R.turn(10.0 if i % 2 == 0 else -10.0, 1.0, up))
			accidental = accidental or _threw(game) or game.detector.aim_locked
		_check(not accidental, "grip %s: 10 turns of the phone (10 degrees in 1 s) throw nothing and lock nothing" % str(up))
		_play(game, f, R.walk(20.0, up, 2.0, [1.5, 3.0, 2.5, 3.0, 2.0]))
		_check(not _threw(game) and not game.detector.aim_locked,
				"grip %s: 20 s of walking (peaks up to 3 m/s2) throw nothing and lock nothing" % str(up))
		_again(game)
		_play(game, f, R.walk(20.0, up))
		var hard_walk_threw := _threw(game)
		print("       hard walking (peaks 2 to 6 m/s2): threw %s, aim locked %s" % [hard_walk_threw, game.detector.aim_locked])
		_check(not hard_walk_threw, "grip %s: 20 s of brisk walking (peaks 2 to 6 m/s2) throw nothing" % str(up))


# ---- Items 5a, 5b: a weak swing, and no time limit ----

func _weak_and_wait() -> void:
	print("weak swing")
	var ctx := await _new_game(2)
	var game: Control = ctx.game
	var f: R.Feeder = ctx.feeders[0]
	var fw := R.grip(R.UP_FLAT).dir(0.0)
	_begin(game)
	_wait(game, f, 0.3)
	var m := {"t": 0.0, "locked": -1.0, "unlocked": -1.0, "on": -1.0, "off": -1.0}
	f.feed(R.back_swing(fw, 10.0, 0.25).append(R.still(5.0)), func() -> void:
		game._game_tick(R.DT)
		m.t += R.DT
		if m.locked < 0.0 and game.detector.aim_locked:
			m.locked = m.t
		if m.locked >= 0.0 and m.unlocked < 0.0 and not game.detector.aim_locked:
			m.unlocked = m.t
		if m.on < 0.0 and game._weak_left > 0.0:
			m.on = m.t
		if m.on >= 0.0 and m.off < 0.0 and game._weak_left <= 0.0:
			m.off = m.t)
	_check(m.locked >= 0.0 and m.unlocked - m.locked >= 1.0 and m.unlocked - m.locked <= 2.0,
			"a back swing without a forward swing frees the aim after %.1f s (1 to 2 s)" % (m.unlocked - m.locked))
	_check(m.on >= 0.0 and m.off - m.on >= 2.0 and m.off - m.on <= 4.0 and game.phase == game.Phase.AIM,
			"'Swing a bit more!' shows for %.1f s (2 to 4 s) and the player is still on turn" % (m.off - m.on))
	_again(game)
	_wait(game, f, 60.0)
	_check(game.phase == game.Phase.AIM and game.rules.current_slot() == 0 and game._weak_left == 0.0,
			"60 s with no swing: the player is still on turn and no time ran out")
	_play(game, f, R.stroke(fw, 10.0, 25.0))
	_wait(game, f, 0.3)
	_check(game.phase == game.Phase.ROLL, "then a normal swing throws")
	# A phone that is not on turn cannot throw (5 tries).
	var ctx2 := await _new_game(2)
	var g2: Control = ctx2.game
	_begin(g2)
	for i in 5:
		_play(g2, ctx2.feeders[1], R.stroke(fw, 10.0, 25.0))
		_wait(g2, ctx2.feeders[1], 0.8)
	_check(g2.phase == g2.Phase.AIM and g2.rules.current_slot() == 0 and not g2.detector.aim_locked
			and g2.rules.row_of(0).rolls.is_empty(),
			"5 swings of the phone that is not on turn do nothing")


## Test 23 14f (REQ-BW-12): 4 players, two names of 10 letters. The bar has the title and "FRAME N/10  BALL N" and no leader
## chip, the
## score sheet has one row for each of the 4 players with 10 cells each, and no name is cut.
func _four_names_sheet() -> void:
	print("four players with long names")
	var ctx := await _new_game(4)
	var game: Control = ctx.game
	var names := ["WWWWWWWWWW", "Maximilian", "Ann", "Bo"]
	for s in 4:
		game.player(s).player_name = names[s]
	_begin(game)
	game.rules.record_roll(10)   # Player 0 has thrown a strike: the frame of the bar is still 1 for the next player.
	var boxes: Array = []
	var shell = load("res://scripts/game/shell.gd")   # The same script as the game uses.
	shell.recorder = func(kind: String, ci: CanvasItem, rect: Rect2, info: Dictionary) -> void:
		if ci == game:
			boxes.append({"kind": kind, "rect": rect, "info": info})
	await _frames(3)
	shell.recorder = Callable()
	var of_kind := func(k: String) -> Array: return boxes.filter(func(b): return b.kind == k)
	var status: Array = of_kind.call("status")
	var expect_text: String = Lang.f("bowling.frame", [game.rules.current_frame(), 10, game.rules.current_ball()]).to_upper()
	var bar_ok: bool = not status.is_empty() and status[-1].info.text == expect_text and expect_text.begins_with("FRAME ")
	_check(bar_ok and expect_text.contains("/10  BALL "),
			"the bar says '%s' (%s)" % [expect_text, str(status[-1].info.text if not status.is_empty() else "-")])
	_check(not of_kind.call("title").is_empty() and of_kind.call("leader").is_empty(),
			"the bar has the title and no leader chip (REQ-BW-12)")
	var chips: Array = of_kind.call("chip")
	var rows := {}
	for c in chips:
		rows[c.info.name] = c.rect
	var all_rows: bool = game.rules.rows.size() == 4
	var cells_ok := true
	for r in game.rules.rows:
		cells_ok = cells_ok and BowlingRules.sheet_cells(r.rolls).size() == 10
	var whole_names := true
	var inside := true
	var stacked: Array = []
	for n in names:
		whole_names = whole_names and rows.has(n)
		if rows.has(n):
			var need: float = game.name_column_width()
			var need_name: float = shell.chip_width(n, 0.0, game.player(names.find(n)).avatar)
			whole_names = whole_names and rows[n].size.x >= need_name - 0.5 and need >= need_name
			inside = inside and rows[n].end.x <= 1920.0 - 60.0 and rows[n].end.y <= 1080.0 - 60.0
			stacked.append(rows[n].position.y)
	_check(all_rows and cells_ok and rows.size() == 4 and whole_names,
			"the sheet has one row for each of the 4 players with 10 cells each, and each name chip holds its whole name (%s)"
			% str(rows.keys()))
	stacked.sort()
	var one_each := stacked.size() == 4
	for i in range(1, stacked.size()):
		one_each = one_each and stacked[i] - stacked[i - 1] >= game.ROW_H - 0.5
	_check(one_each and inside, "the 4 rows stand one under the other and inside the 60 px edge (y: %s)" % str(stacked))


# ---- Items 6b, 8a: the banners and the turn order ----

func _banners_and_turns() -> void:
	print("banners and turns")
	var ctx := await _new_game(1)
	var game: Control = ctx.game
	_begin(game)
	var cases := [
		["strike", 0, 10, false, "bowling.strike"], ["spare", 4, 6, false, "bowling.spare"],
		["8 pins", 0, 8, false, "bowling.nice_roll"], ["7 pins", 0, 7, false, "bowling.nice_roll"],
		["6 pins", 0, 6, false, "bowling.nice_try"], ["1 pin", 0, 1, false, "bowling.nice_try"],
		["no pin", 0, 0, false, "bowling.gutter"], ["gutter", 0, 0, true, "bowling.gutter"]]
	for c in cases:
		game.rules.setup([0] as Array[int])
		game.sim.set_rack(game.FULL_RACK)
		if c[1] > 0:   # A first ball, then the second one is the one that is judged.
			var mask := []
			for i in 10:
				mask.append(i >= c[1])
			game.rules.record_roll(c[1])
			game.sim.set_rack(mask)
		game._before = game.sim.standing_mask()
		var knocked := 0
		for p in game.sim.pins:
			if game._before[p.n - 1] and knocked < c[2]:
				p.state = 1
				knocked += 1
		game.sim.in_gutter = c[3]
		game._roll_done()
		_check(game._banner == Lang.t(c[4]), "%s: the banner is '%s' (%s)" % [c[0], Lang.t(c[4]), game._banner])
	var fresh := await _new_game(3)
	var g3: Control = fresh.game
	_begin(g3)
	var cells_ok: bool = g3.rules.rows.size() == 3
	for r in g3.rules.rows:
		cells_ok = cells_ok and BowlingRules.sheet_cells(r.rolls).size() == 10
	var top_bar: String = Lang.f("bowling.frame", [g3.rules.current_frame(), 10, g3.rules.current_ball()]).to_upper()
	_check(cells_ok and top_bar == "FRAME 1/10  BALL 1" and not _Bowling.source_code.contains("draw_leader_chip"),
			"3 players: the sheet has 10 cells for each, the top bar says 'FRAME 1/10  BALL 1' and the game draws no leader chip")
	for n in [2, 3, 4]:
		var ctx2 := await _new_game(n)
		var g2: Control = ctx2.game
		_begin(g2)
		var order := []
		var told := true
		for i in n * 2:
			var slot: int = g2.rules.current_slot()
			order.append(slot)
			g2._game_tick(R.DT)   # The phones are told whose turn it is.
			for s in n:
				var sent: Dictionary = _app.server._turn_sent.get(s, {})
				var who_ok: bool = s == slot or sent.get("who", "") == g2.player(slot).player_name
				told = told and sent.get("s", -1) == (1 if s == slot else 2) and who_ok
			g2.sim.set_rack(g2.FULL_RACK)
			g2._before = g2.sim.standing_mask()
			for p in g2.sim.pins:
				p.state = 1
			g2._roll_done()
			g2._after_result()
		var expect := []
		for k in 2:
			for s in n:
				expect.append(s)
		_check(order == expect and told and g2.rules.current_frame() == 3,
				"%d phones: the turns go 1..%d, 1..%d (%s) and each phone is told whose turn it is" % [n, n, n, str(order)])


# ---- Item 8e: how long the others wait ----

func _wait_time() -> void:
	print("wait for the others")
	var four := {}
	for d in ["easy", "medium", "hard"]:
		var lv := BowlingRules.level(d)
		var speeds := [LaneSim.SPEED_TOP * float(lv.fixed_speed)] if lv.has("fixed_speed") else [
				LaneSim.SPEED_TOP * float(lv.speed_min), LaneSim.SPEED_TOP * 0.8, LaneSim.SPEED_TOP]
		var worst := 0.0
		var sum := 0.0
		var count := 0
		for speed in speeds:
			for x in [-0.45, -0.2, 0.0, 0.1, 0.3, 0.5]:
				var sim := LaneSim.new()
				sim.throw(x, speed, false)
				var guard := 0
				while not sim.finished and guard < 2000:
					sim.tick(R.DT)
					guard += 1
				worst = maxf(worst, sim.time)
				sum += sim.time
				count += 1
		# Three others with two balls each (the worst case: no strike), every ball the slowest one, plus the banner of each.
		four[d] = 3.0 * 2.0 * (sum / float(count) + _Bowling.RESULT_TIME)
		print("       %s: slowest ball %.1f s, the average ball %.1f s; the other three wait %.1f s (average balls, two each)"
				% [d, worst, sum / float(count), four[d]])
	_check(four.easy <= 35.0 and four.medium <= 35.0 and four.hard <= 35.0,
			"the three others of a 4 player game wait at most 35 s for the fixed times of the game (%.1f, %.1f, %.1f s)"
			% [four.easy, four.medium, four.hard])


# ---- Item 10c: pause and resume ----

func _pause() -> void:
	print("pause")
	var ctx := await _new_game(2)
	var game: Control = ctx.game
	var f: R.Feeder = ctx.feeders[0]
	var fw := R.grip(R.UP_FLAT).dir(0.0)
	_begin(game)
	_wait(game, f, 0.3)
	_play(game, f, R.back_swing(fw, 10.0, 0.25))
	_check(game.detector.aim_locked, "the back swing is under way")
	game.open_menu("minigame.end_game_ask", [["minigame.resume", game.close_menu]])
	_check(game.is_paused(), "the TV pauses the game")
	OS.delay_msec(600)   # The pause lasts longer than the gap that the game takes for a pause.
	game.close_menu()
	_wait(game, f, 0.2)
	_check(not game.detector.aim_locked and game.phase == game.Phase.AIM, "after Resume the swing that was under way starts again")
	_play(game, f, R.stroke(fw, 10.0, 25.0))
	_wait(game, f, 0.3)
	_check(game.phase == game.Phase.ROLL, "and a full swing within 10 s of Resume throws")


# ---- A swing from a real loopback phone ----

func _over_the_network() -> void:
	print("loopback")
	var ctx := await _new_game(2)
	var game: Control = ctx.game
	var fw := R.grip(R.UP_FLAT).dir(0.0)
	var rec = _rec_haptics()
	game._haptics = rec
	var state := {}
	await R.stream(self, _clients[0], R.still(0.6), R.UP_FLAT, state)
	game._start_turn()   # The fresh phone settled for 0.6 s: its first readings are not a back swing.
	await _frames(3)
	_check(not game._has_countdown() and game.rules.current_slot() == 0, "there is no countdown and phone 1 is on turn")
	await R.stream(self, _clients[0], R.still(0.4), R.UP_FLAT, state)
	await R.stream(self, _clients[0], R.stroke(fw, 10.0, 25.0).append(R.still(0.4)), R.UP_FLAT, state)
	await _frames(3)
	_check(game.phase != game.Phase.AIM, "a swing that comes over the network throws the ball")
	_check(rec.log.filter(func(e): return e[1] == 40).size() >= 1, "and the game buzzes the phone")
