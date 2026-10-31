extends SceneTree
## The rules, the lane and the swing of Pin Pals (REQ-BW-*), pure logic and pictures. Run:
##   godot --headless --path . --script tests/bowling_rules.gd -- --role=controller

const BowlingRules = preload("res://scripts/game/bowling/bowling_rules.gd")
const LaneSim = preload("res://scripts/game/bowling/lane_sim.gd")
const SwingDetector = preload("res://scripts/input/swing_detector.gd")
var BowlingLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
const OrientationFusion = preload("res://scripts/input/orientation.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Medals = preload("res://scripts/game/medals.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _checks := 0
var _fails := 0


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
	BowlingLook = load("res://scripts/game/bowling/bowling_look.gd")
	_score_sheet()
	_last_frame()
	_turn_flow()
	_leaving()
	_levels()
	_lane()
	_lane_rails_and_gutter()
	_swing()
	_shake()
	_swing_axes()
	_orientation()
	_aim_from_touch()
	_look()
	_aim_map()
	_hall()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rolls(values: Array) -> Array[int]:
	var r: Array[int] = []
	r.assign(values)
	return r


func _repeat(value: int, count: int) -> Array:
	var a := []
	for i in count:
		a.append(value)
	return a


## 9 frames of nothing, then the 10th frame `last`.
func _with_last(last: Array) -> Array[int]:
	return _rolls(_repeat(0, 18) + last)


# ---- The score sheet (REQ-BW-2) ----

func _score_sheet() -> void:
	print("score sheet")
	_check(BowlingRules.total_of(_rolls(_repeat(10, 12))) == 300, "12 strikes are 300 (REQ-BW-2)")
	_check(BowlingRules.total_of(_rolls(_repeat(0, 20))) == 0, "a game with no pin down is 0")
	_check(BowlingRules.total_of(_rolls(_repeat(5, 21))) == 150, "21 balls of 5 pins (all spares) are 150")
	_check(BowlingRules.total_of(_rolls([9, 1, 4, 2])) == 10 + 4 + 4 + 2, "a spare adds the next ball only")
	var nines := _rolls([9, 1, 9, 1, 9, 1, 9, 1, 9, 1, 9, 1, 9, 1, 9, 1, 9, 1, 9, 1, 9])
	_check(BowlingRules.total_of(nines) == 190, "ten frames of 9 and a spare, and a last 9, are 190")
	_check(BowlingRules.total_of(_rolls([3, 4, 2, 5, 1, 1])) == 7 + 7 + 2, "open frames add the pins that fell")
	var c := BowlingRules.sheet_cells(_rolls([10, 7, 3, 9, 0]))
	_check(c[0].marks == ["X"] and int(c[0].total) == 20 and c[1].marks == ["7", "/"] and int(c[1].total) == 39
			and c[2].marks == ["9", "-"] and int(c[2].total) == 48, "X, 7 / and 9 - give 20, 39, 48 (strike and spare bonuses)")
	var wait := BowlingRules.sheet_cells(_rolls([10]))
	_check(int(wait[0].total) == -1 and wait[1].marks.is_empty(), "a strike has no total until the next 2 balls are bowled")
	wait = BowlingRules.sheet_cells(_rolls([10, 3]))
	_check(int(wait[0].total) == -1 and wait[1].marks == ["3"], "a strike still waits after one more ball")
	wait = BowlingRules.sheet_cells(_rolls([10, 3, 4]))
	_check(int(wait[0].total) == 17 and int(wait[1].total) == 24, "the strike is scored when 2 balls are known: 17, then 24")
	wait = BowlingRules.sheet_cells(_rolls([6, 4]))
	_check(int(wait[0].total) == -1 and wait[0].marks == ["6", "/"], "a spare has no total until the next ball")
	_check(BowlingRules.sheet_cells(_rolls([])).size() == 10 and BowlingRules.total_of(_rolls([])) == 0,
			"an empty sheet has 10 empty cells and the score 0")
	_check(BowlingRules.frame_rolls(_rolls([10, 3, 4, 5]), 2) == _rolls([3, 4])
			and BowlingRules.frame_rolls(_rolls([10, 3, 4]), 1) == _rolls([10]),
			"the rolls of a frame: one after a strike, else two")


func _last_frame() -> void:
	print("10th frame")
	var cases := [
		[[10, 10, 10], ["X", "X", "X"], 30],
		[[10, 7, 3], ["X", "7", "/"], 20],
		[[9, 1, 5], ["9", "/", "5"], 15],
		[[9, 0], ["9", "-"], 9],
		[[0, 10, 4], ["-", "/", "4"], 14],
		[[10, 0, 10], ["X", "-", "/"], 20],
		[[10, 10, 5], ["X", "X", "5"], 25],
		[[3, 4], ["3", "4"], 7],
	]
	for cs in cases:
		var cells := BowlingRules.sheet_cells(_with_last(cs[0]))
		_check(cells[9].marks == cs[1] and BowlingRules.total_of(_with_last(cs[0])) == cs[2],
				"10th frame %s shows %s and scores %d (got %s, %d)" % [str(cs[0]), str(cs[1]), cs[2], str(cells[9].marks),
				BowlingRules.total_of(_with_last(cs[0]))])
	var open := BowlingRules.sheet_cells(_with_last([10, 5]))
	_check(int(open[9].total) == -1, "the 10th frame has no total while the third ball is missing")


# ---- The turns (REQ-BW-1, 3) ----

func _turn_flow() -> void:
	print("turns")
	var g := BowlingRules.new()
	g.setup(_slots([0, 1]))
	_check(g.current_slot() == 0 and g.current_frame() == 1
			and g.current_ball() == 1 and g.pins_standing() == 10 and not g.game_over(),
			"the first player bowls first in frame 1 (REQ-BW-3)")
	var e := g.record_roll(10)
	_check(e.strike and e.frame_done and e.fresh_rack and e.slot == 0 and g.current_slot() == 1,
			"a strike ends the frame and the next player bowls")
	e = g.record_roll(3)
	_check(not e.frame_done and g.current_slot() == 1 and g.current_ball() == 2 and g.pins_standing() == 7 and not e.fresh_rack,
			"the same player bowls ball 2 at the pins that stand")
	e = g.record_roll(7)
	_check(e.spare and e.frame_done and e.fresh_rack and g.current_slot() == 0 and g.current_frame() == 2,
			"a spare ends the frame; frame 2 starts with the first player")
	e = g.record_roll(15)
	_check(e.pins == 10 and e.strike, "a count above the standing pins is limited")
	g.record_roll(0)
	_check(g.current_slot() == 1 and g.current_ball() == 2 and g.pins_standing() == 10,
			"a ball with no pin leaves the rack as it was")
	e = g.record_roll(10)
	_check(e.spare and not e.strike, "all pins after a ball with no pin are a spare, not a strike")

	var solo := BowlingRules.new()
	solo.setup(_slots([2]))
	for i in 12:
		solo.record_roll(10)
	_check(solo.game_over() and solo.current_slot() == -1 and solo.score_of(2) == 300 and solo.row_of(2).rolls.size() == 12
			and solo.current_ball() == -1 and solo.pins_standing() == 0, "12 strikes end a one-player game with 300 (REQ-BW-1)")

	var last := BowlingRules.new()
	last.setup(_slots([0]))
	for i in 9:
		last.record_roll(10)
	e = last.record_roll(10)
	_check(e.frame == 10 and e.ball == 1 and e.strike and e.fresh_rack and not e.frame_done and last.current_ball() == 2,
			"10th frame: a strike gives ball 2")
	e = last.record_roll(4)
	_check(not e.fresh_rack and last.current_ball() == 3 and last.pins_standing() == 6,
			"10th frame: after X 4 there is a third ball at 6 pins")
	e = last.record_roll(6)
	_check(e.spare and e.frame_done and e.game_over and last.score_of(0) == 284 and last.game_over(),
			"10th frame: the third ball ends the game")
	var open := BowlingRules.new()
	open.setup(_slots([0]))
	for i in 9:
		open.record_roll(0)
		open.record_roll(0)
	open.record_roll(3)
	e = open.record_roll(4)
	_check(e.frame_done and e.game_over and open.score_of(0) == 7, "10th frame: an open frame has 2 balls only")
	var fresh := BowlingRules.new()
	fresh.setup(_slots([0]))
	for i in 9:
		fresh.record_roll(10)
	fresh.record_roll(10)
	e = fresh.record_roll(10)
	_check(e.strike and e.fresh_rack and fresh.pins_standing() == 10, "10th frame: X X gives a fresh rack for ball 3")

	var three := BowlingRules.new()
	three.setup(_slots([0, 1, 2]))
	var order := []
	for i in 6:
		order.append(three.current_slot())
		three.record_roll(10)
	_check(order == [0, 1, 2, 0, 1, 2] and three.current_frame() == 3, "turns go in slot order, frame by frame: %s" % str(order))


func _slots(values: Array) -> Array[int]:
	var s: Array[int] = []
	s.assign(values)
	return s


func _leaving() -> void:
	print("leaving")
	var g := BowlingRules.new()
	g.setup(_slots([0, 1, 2]))
	g.record_roll(10)
	g.remove_player(1)
	_check(g.current_slot() == 2 and g.slots() == [0, 2],
			"the turn goes on with the next player when the one on turn leaves (REQ-BW-3)")
	g.remove_player(0)
	_check(g.current_slot() == 2 and g.slots() == [2], "a player who already bowled leaves: the player on turn stays")
	g.record_roll(5)
	g.record_roll(5)
	_check(g.current_frame() == 2 and g.current_slot() == 2, "one player left: the game goes on with the next frame")
	g.remove_player(2)
	_check(g.game_over() and g.current_slot() == -1 and g.rows.is_empty(), "nobody left: the game is over")
	g.remove_player(9)
	_check(g.rows.is_empty(), "removing an unknown slot does nothing")
	var h := BowlingRules.new()
	h.setup(_slots([0, 1, 2]))
	h.record_roll(10)
	h.record_roll(10)
	h.remove_player(0)
	_check(h.current_slot() == 2 and h.slots() == [1, 2],
			"a player before the one on turn leaves: the turn stays with the same player")
	h.record_roll(10)
	h.remove_player(1)
	_check(h.current_slot() == 2 and h.current_frame() == 2, "the last player of a frame is alone: frame 2 goes on")


func _levels() -> void:
	print("difficulty")
	var easy := BowlingRules.ball_speed("easy", 0.0, 9.0)
	_check(is_equal_approx(easy, 7.2) and is_equal_approx(BowlingRules.ball_speed("easy", 1.0, 9.0), 7.2),
			"Easy: the ball always has the same speed (REQ-BW-17)")
	_check(is_equal_approx(BowlingRules.ball_speed("medium", 0.0, 9.0), 6.3)
			and is_equal_approx(BowlingRules.ball_speed("medium", 1.0, 9.0), 9.0),
			"Medium: the speed goes from 0.7 to 1.0 of the top speed with the swing")
	_check(is_equal_approx(BowlingRules.ball_speed("hard", 0.0, 9.0), 4.5)
			and is_equal_approx(BowlingRules.ball_speed("hard", 2.0, 9.0), 9.0),
			"Hard: a gentle swing gives a slow ball, and the power is limited to 1")
	_check(BowlingRules.level("nope") == BowlingRules.LEVELS.medium
			and BowlingRules.level("easy").threshold < BowlingRules.level("medium").threshold,
			"an unknown level is Medium; Easy counts a lighter swing")
	for d in ["easy", "medium", "hard"]:
		_check(not BowlingRules.level(d).has("tiers"), "%s has no medal tiers (REQ-GM-73)" % d)


# ---- The lane (REQ-BW-9 to 11) ----

func _roll(x: float, speed: float, rails := false, dt := 1.0 / 60.0) -> LaneSim:
	var l := LaneSim.new()
	l.throw(x, speed, rails)
	var guard := 0
	while not l.finished and guard < 5000:
		l.tick(dt)
		guard += 1
	return l


func _lane() -> void:
	print("lane")
	var l := LaneSim.new()
	_check(l.standing_count() == 10 and l.finished and LaneSim.rack_pos(1) == Vector2(0.0, LaneSim.HEAD_Y)
			and LaneSim.rack_pos(7).x < LaneSim.rack_pos(10).x
			and LaneSim.rack_pos(7).y > LaneSim.HEAD_Y, "the rack has 10 pins in a triangle, 7 left and 10 right at the back")
	var before := l.standing_mask()
	var rolled := _roll(0.04, 7.0)
	var down := rolled.knocked_since(before)
	_check(rolled.finished and down >= 5 and down == 10 - rolled.standing_count(),
			"a ball at the head pin knocks pins down: %d" % down)
	var again := _roll(0.04, 7.0)
	var same := true
	for i in 10:
		same = same and again.pins[i].state == rolled.pins[i].state and again.pins[i].pos == rolled.pins[i].pos
	_check(same, "the same throw gives the same result (REQ-BW-9)")
	var slow_frames := _roll(0.04, 7.0, false, 1.0 / 30.0)
	var fast_frames := _roll(0.04, 7.0, false, 1.0 / 144.0)
	var frames_same := true
	for i in 10:
		frames_same = frames_same and slow_frames.pins[i].state == fast_frames.pins[i].state
	_check(frames_same and slow_frames.standing_count() == fast_frames.standing_count(),
			"the result does not depend on the frame rate (REQ-GM-13)")
	var strikes := 0
	var x := -0.3
	while x <= 0.3:
		if _roll(x, 7.0).standing_count() == 0:
			strikes += 1
		x += 0.02
	_check(strikes >= 3, "a ball in the pocket can make a strike: %d of 31 places" % strikes)
	var side := _roll(-0.5, 7.0)
	_check(side.standing_count() >= 3 and side.standing_count() < 10,
			"a ball at the edge of the pins knocks a few pins: %d left" % side.standing_count())
	var one_pin := LaneSim.new()
	one_pin.set_rack([false, false, false, false, false, false, false, false, false, true])
	var ten := _roll_on(one_pin, LaneSim.rack_pos(10).x, 7.0)
	_check(ten.standing_count() == 0, "a spare of the 10 pin: a ball at it takes it (the pin is reachable)")
	_check(one_pin.pins[0].state == LaneSim.State.GONE, "a pin that is not in the rack is gone")
	var all := LaneSim.new()
	var mask := all.standing_mask()
	var hit := _roll_on(all, 0.0, 7.0)
	var knocked := hit.knocked_since(mask)
	hit.sweep()
	_check(hit.standing_count() == 10 - knocked and not hit.ball_active, "the sweep takes the fallen pins; the standing pins stay")
	hit.set_rack(mask)
	_check(hit.standing_count() == 10 and hit.finished, "a new rack has 10 pins")
	var rested := _roll(0.0, 7.0)
	var moving := false
	for p in rested.pins:
		moving = moving or p.vel != Vector2.ZERO
	_check(not moving, "when the throw is over nothing moves")
	var hits := LaneSim.new()
	hits.throw(0.0, 7.0, false)
	var got_hit := false
	var got_fall := false
	for i in 400:
		hits.tick(1.0 / 60.0)
		for e in hits.events:
			got_hit = got_hit or e.t == "hit"
			got_fall = got_fall or e.t == "fall"
	_check(got_hit and got_fall, "the hit and the fall of pins are events for the sound (REQ-BW-S4)")
	var idle := LaneSim.new()
	idle.tick(1.0)
	_check(idle.finished and idle.time == 0.0, "a lane with no throw does not run")


func _roll_on(l: LaneSim, x: float, speed: float) -> LaneSim:
	l.throw(x, speed, false)
	var guard := 0
	while not l.finished and guard < 5000:
		l.tick(1.0 / 60.0)
		guard += 1
	return l


func _lane_rails_and_gutter() -> void:
	print("gutter and rails")
	var g := _roll(0.58, 7.0)
	_check(g.in_gutter and g.standing_count() == 10, "a ball past the lane edge is in the gutter and knocks nothing (REQ-BW-10)")
	var gl := _roll(-0.58, 7.0)
	_check(gl.in_gutter and gl.standing_count() == 10, "the left gutter too")
	var r := _roll(0.58, 7.0, true)
	_check(not r.in_gutter and r.standing_count() < 10,
			"with rails the same throw stays on the lane and knocks pins: %d left" % r.standing_count())
	var rl := _roll(-0.58, 7.0, true)
	_check(not rl.in_gutter and rl.standing_count() < 10, "with rails, the left side too")
	var mid := LaneSim.new()
	mid.throw(0.0, 7.0, true)
	_check(mid.ball_vel.x == 0.0, "a ball in the middle is not pushed")
	var late := LaneSim.new()
	late.throw(0.4, 7.0, false)
	late.ball_pos.x = 0.6
	late.tick(1.0 / 60.0)
	_check(late.in_gutter and is_equal_approx(late.ball_pos.x, LaneSim.GUTTER_X),
			"a ball that drifts out of the lane falls into the gutter")
	var wide := LaneSim.new()
	wide.throw(0.3, 7.0, true)
	wide.ball_pos.x = 0.5
	wide.tick(1.0 / 60.0)
	_check(wide.ball_pos.x <= LaneSim.RAIL_LIMIT + 0.001 and wide.ball_vel.x < 0.0,
			"a ball that touches a rail is pushed back into the lane")


# ---- The swing (REQ-BW-5, 6) ----

## Feeds a made-up swing: back for `back_s` seconds with strength `back`, then forward with `fwd` for `fwd_s`, then still.
func _swing_run(d: SwingDetector, axis: Vector3, back: float, back_s: float, fwd: float, fwd_s: float) -> void:
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < back_s:
		d.update(dt, axis * back)
		t += dt
	t = 0.0
	while t < fwd_s:
		d.update(dt, -axis * fwd)
		t += dt
	for i in 30:
		d.update(dt, Vector3.ZERO)


func _shake() -> void:
	print("shake")
	var axis := Vector3(0, 1, 0)
	var shake := SwingDetector.new()
	shake.min_back = _game().MIN_BACK
	var plain := SwingDetector.new()
	var wind := SwingDetector.new()
	wind.min_back = _game().MIN_BACK
	for d in [shake, plain]:
		_swing_run(d, axis, 9.0, 0.08, 18.0, 0.08)   # Back and forth in 0.1 s each way: a shake.
	_check(shake.state != SwingDetector.State.LOCKED and plain.state == SwingDetector.State.LOCKED,
			"a shake (0.08 s back, then forth) does not throw when the back swing must last MIN_BACK (REQ-BW-5)")
	_swing_run(wind, axis, 9.0, 0.3, 18.0, 0.15)
	_check(wind.state == SwingDetector.State.LOCKED and wind.power > 0.0, "a real wind-up of 0.3 s still throws (REQ-BW-5)")


func _swing() -> void:
	print("swing")
	var d := SwingDetector.new()
	var released_at := -1
	var dt := 1.0 / 60.0
	for i in 60:
		d.update(dt, Vector3(0.3, -0.2, 0.1))
	_check(d.state == SwingDetector.State.READY and not d.aim_locked, "a phone that is held still is ready and the aim is free")
	for i in 20:
		d.update(dt, Vector3(2.0, 0.0, 0.0))
	_check(d.state == SwingDetector.State.READY, "a small move (2 m/s2) is not a swing")
	for i in 6:
		d.update(dt, Vector3(6.0, 0.0, 0.0))
	_check(d.state == SwingDetector.State.BACK and d.aim_locked, "a strong move is the back swing and it locks the aim (REQ-BW-5)")
	for i in 12:
		d.update(dt, Vector3(-20.0, 0.0, 0.0))
		if d.released:
			released_at = i
	_check(d.state == SwingDetector.State.FORWARD and released_at < 0, "the move the other way is the forward swing")
	d.update(dt, Vector3(-5.0, 0.0, 0.0))
	_check(d.released and d.state == SwingDetector.State.LOCKED and d.power > 0.3 and d.power < 0.9,
			"the ball goes when the forward swing fades: power %.2f (REQ-BW-5)" % d.power)
	d.update(dt, Vector3.ZERO)
	_check(not d.released, "the release is a one-shot flag")
	for i in 100:
		d.update(dt, Vector3.ZERO)
	_check(d.state == SwingDetector.State.READY and not d.aim_locked, "after the throw the detector is ready again after 1.5 s")

	var strong := SwingDetector.new()
	_swing_run(strong, Vector3(1, 0, 0), 8.0, 0.2, 40.0, 0.2)
	var gentle := SwingDetector.new()
	_swing_run(gentle, Vector3(1, 0, 0), 8.0, 0.2, 12.0, 0.2)
	_check(strong.power == 1.0 and gentle.power > 0.0 and gentle.power < strong.power,
			"a harder forward swing gives more power: %.2f and %.2f (REQ-BW-6)" % [gentle.power, strong.power])

	var weak := SwingDetector.new()
	var weak_flag := false
	for i in 6:
		weak.update(dt, Vector3(6.0, 0.0, 0.0))
	for i in 140:
		weak.update(dt, Vector3(-3.0, 0.0, 0.0))
		weak_flag = weak_flag or weak.weak
	_check(weak_flag and weak.state == SwingDetector.State.READY and not weak.aim_locked and not weak.released,
			"a back swing with a weak forward swing is dropped and the aim is free again (REQ-BW-5)")

	var easy := SwingDetector.new()
	easy.threshold = 0.7
	var hard := SwingDetector.new()
	for i in 12:
		easy.update(1.0 / 60.0, Vector3(0, 3.2, 0))
		hard.update(1.0 / 60.0, Vector3(0, 3.2, 0))
	_check(easy.aim_locked and not hard.aim_locked,
			"Easy counts a lighter swing than Medium (REQ-BW-17)")

	var slow := SwingDetector.new()
	for i in 6:
		slow.update(dt, Vector3(6.0, 0.0, 0.0))
	var slow_released := false
	for i in 90:
		slow.update(dt, Vector3(-12.0, 0.0, 0.0))
		slow_released = slow_released or slow.released
	_check(slow_released, "a forward swing that never fades ends after 1 s")
	slow.reset()
	_check(slow.state == SwingDetector.State.READY and slow.power == 0.0 and not slow.aim_locked, "reset() makes it ready")


func _swing_axes() -> void:
	print("swing axes")
	var ok := true
	var axes := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 1, 0).normalized(), Vector3(-1, 2, 1).normalized()]
	for axis in axes:
		var d := SwingDetector.new()
		_swing_run(d, axis, 8.0, 0.2, 25.0, 0.2)
		ok = ok and d.state == SwingDetector.State.LOCKED and d.power > 0.5
	_check(ok, "the swing works with any way of holding the phone: the axis is found from the back swing (REQ-BW-5)")
	var mixed := SwingDetector.new()
	var dt := 1.0 / 60.0
	for i in 8:
		mixed.update(dt, Vector3(6.0, 0.0, 0.0))
	for i in 12:
		mixed.update(dt, Vector3(0.0, -25.0, 0.0))
	_check(mixed.state == SwingDetector.State.BACK, "a move across the swing axis is not the forward swing")


## The game script is loaded when a test runs: it needs the autoloads, so a preload cannot compile it.
func _game() -> GDScript:
	return load("res://scripts/game/bowling/bowling_game.gd")


func _aim_from_touch() -> void:
	print("aim from touch")
	_check(is_equal_approx(_game().aim_from_touch(0.0), -1.0) and is_equal_approx(_game().aim_from_touch(0.5), 0.0)
			and is_equal_approx(_game().aim_from_touch(1.0), 1.0) and is_equal_approx(_game().aim_from_touch(2.0), 1.0),
			"the place on the aim strip gives the aim from -1 to 1 (REQ-BW-4)")


func _orientation() -> void:
	print("orientation")
	var o := OrientationFusion.new()
	o.up = Vector3(0, 0, 1)
	_check(o.linear_accel(Vector3(0, 0, 9.81)).length() < 0.01
			and o.linear_accel(Vector3(3, 0, 9.81)).is_equal_approx(Vector3(3, 0, 0)),
			"a phone that lies still has no linear acceleration; a push shows (REQ-BW-5)")
	var inverted := OrientationFusion.new({"invert_tilt": true})
	inverted.up = Vector3(0, 0, 1)
	_check(inverted.linear_accel(Vector3(0, 0, -9.81)).length() < 0.01, "the invert setting is applied to the reading")


# ---- The pictures (REQ-BW-13) ----

func _look() -> void:
	print("look")
	var pin = BowlingLook.pin_image(false)
	var lying = BowlingLook.pin_image(true)
	_check(pin.get_width() == 7 and pin.get_height() == 14 and lying.get_width() == 14 and lying.get_height() == 7,
			"a pin is 7 x 14 world pixels and a lying pin 14 x 7")
	_check(pin.get_height() * Shell.WORLD_PIXEL >= 48.0, "a pin is 48 units high or more (REQ-GM-47m)")
	_check(pin.get_pixel(0, 0).a == 0.0 and pin.get_pixel(3, 0).is_equal_approx(Color("000000"))
			and pin.get_pixel(3, 4).is_equal_approx(Color("e63946")),
			"a pin has a one-pixel black outline and a red stripe on its neck")
	var geo = BowlingLook.Geo.new(Vector2(1920, 1080), 718.0 + 2.0)
	_check(is_equal_approx(geo.top, 232.0) and geo.bot < 720.0 and geo.half(0.0) > geo.half(1.0),
			"the lane narrows towards the pins")
	var near = geo.at(Vector2(0.0, 0.0))
	var far = geo.at(Vector2(0.0, LaneSim.HEAD_Y))
	_check(is_equal_approx(near.x, 960.0) and near.y > far.y and far.y > geo.top,
			"the foul line is at the bottom, the head pin is near the far end")
	var p8 = geo.at(LaneSim.rack_pos(8))
	var p9 = geo.at(LaneSim.rack_pos(9))
	_check(p9.x - p8.x >= 28.0, "two pins of a row do not overlap on the screen: %.0f units apart" % (p9.x - p8.x))
	_check(geo.ball_radius(0.0) * 2.0 >= 48.0 and geo.ball_radius(1.0) * 2.0 >= 48.0 and geo.ball_radius(0.0) > geo.ball_radius(0.9),
			"the ball is 48 units across or more and smaller at the far end (REQ-GM-47m)")
	var geo_small = BowlingLook.Geo.new(Vector2(1280, 720), 480.0)
	_check(geo_small.cx == 640.0 and geo_small.half(0.0) < geo.half(0.0), "the lane scales with the screen width")
	var canvas := Control.new()
	canvas.size = Vector2(1920, 1080)
	root.add_child(canvas)
	var sim := LaneSim.new()
	var colors := [Color.RED, Color.BLUE]
	canvas.draw.connect(func() -> void:
		BowlingLook.draw_hall(canvas, canvas.size, geo, false)
		BowlingLook.draw_hall(canvas, canvas.size, geo, true)
		BowlingLook.draw_pins(canvas, geo, sim, colors)
		BowlingLook.draw_ball(canvas, geo, Vector2(0.1, 5.0), Color.RED)
		BowlingLook.draw_aim(canvas, geo, 0.2, Color.RED)
		BowlingLook.draw_lying_pin(canvas, Vector2(500, 400), true)
		BowlingLook.draw_lying_pin(canvas, Vector2(600, 400), false)
		BowlingLook.draw_burst(canvas, Vector2(700, 400), 0.2, colors))
	canvas.queue_redraw()
	_check(true, "the hall, the pins, the ball and the bursts draw without an error")
	var thrown := LaneSim.new()
	thrown.throw(0.0, 7.0, false)
	for i in 300:
		thrown.tick(1.0 / 60.0)
	var states := {}
	for p in thrown.pins:
		states[p.state] = true
	canvas.draw.connect(func() -> void: BowlingLook.draw_pins(canvas, geo, thrown, colors))
	canvas.queue_redraw()
	_check(states.has(LaneSim.State.FALLEN) or states.has(LaneSim.State.GONE),
			"a throw makes pins fall for the picture of the fallen pins")
	canvas.queue_free()


# ---- The aim (REQ-BW-4, Test 23 item 3) ----

func _aim_map() -> void:
	print("aim strip")
	var g := _game()
	var last := -2.0
	var steady := true
	for i in range(0, 101):
		var a: float = g.aim_from_touch(float(i) / 100.0)
		steady = steady and a >= last and a >= -1.0 and a <= 1.0
		last = a
	_check(steady and is_equal_approx(g.aim_from_touch(0.0), -1.0) and is_equal_approx(last, 1.0),
			"a finger sliding from the left end to the right end of the strip moves the aim from -1 to 1, one way only")
	_check(is_equal_approx(g.aim_from_touch(0.25), -0.5) and is_equal_approx(g.aim_from_touch(0.75), 0.5),
			"a quarter and three quarters of the strip are half way to each side")
	_check(g.aim_from_touch(-0.5) == -1.0 and g.aim_from_touch(1.5) == 1.0, "a place outside the strip stops at the end")
	_check(g.AIM_X > LaneSim.LANE_HALF and g.AIM_X < LaneSim.GUTTER_X + 0.05,
			"the end of the strip (%.2f m) is in the gutter, past the edge of the lane (%.3f m) (REQ-BW-4)"
			% [g.AIM_X, LaneSim.LANE_HALF])
	var in_gutter := LaneSim.new()
	in_gutter.throw(g.aim_from_touch(0.0) * g.AIM_X, 6.0, false)
	var rails := LaneSim.new()
	rails.throw(g.aim_from_touch(1.0) * g.AIM_X, 6.0, true)
	for i in 1200:
		in_gutter.tick(LaneSim.STEP)
		rails.tick(LaneSim.STEP)
	_check(in_gutter.in_gutter and rails.finished and not rails.in_gutter,
			"a ball from the left end of the strip is a gutter ball; with Rails a ball from the right end stays on the lane")


# ---- The hall (REQ-BW-13, Test 23 items 2b, 2c, 13a) ----

func _hall() -> void:
	print("the hall")
	var order: Array = BowlingLook.SIDE_ORDER
	var left := order.filter(func(n): return n < 0)
	var right := order.filter(func(n): return n > 0)
	_check(order.size() == 6 and left.size() == 3 and right.size() == 3 and not order.has(0) and BowlingLook.SIDE_LANES == 3,
			"3 dimmer lanes on each side of the own lane (7 lanes in all)")
	var all_racks := true
	var down_somewhere := false
	for n in order:
		var standing = BowlingLook._neighbor_mask(n).filter(func(b): return b).size()
		all_racks = all_racks and standing >= 1
		down_somewhere = down_somewhere or standing < 10
	_check(all_racks and down_somewhere, "each side lane has a rack, and some pins are down in some of them")
	for res: Vector2 in [Vector2(1920, 1080), Vector2(1280, 720)]:
		var geo = BowlingLook.Geo.new(res, res.y - 60.0 - 72.0)
		var tiles = BowlingLook.wall_tiles(res, geo)
		var y0 = BowlingLook.WALL_TOP * res.y / 1080.0
		var third = (geo.top - y0) / 3.0
		var top_ok = not tiles.is_empty()
		var colors := {}
		for t in tiles:
			top_ok = top_ok and t.rect.position.y >= y0 - 0.01 and t.rect.end.y <= y0 + 2.0 * third + 0.01
			colors[t.color] = true
		_check(top_ok, "%dx%d: the light tiles are in the top two thirds of the wall, the bottom third has none" % [res.x, res.y])
		var all_disco := true
		for c in colors:
			all_disco = all_disco and BowlingLook.DISCO.has(c)
		_check(all_disco and colors.size() == BowlingLook.DISCO.size(), "the tiles use the 7 disco colors and no other")
	var img = BowlingLook.pin_image(false)
	var white := 0
	var open_edge := false
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).is_equal_approx(BowlingLook.PIN_COLORS["W"]):
				white += 1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0 and (x == 0 or x == img.get_width() - 1 or y == 0 or y == img.get_height() - 1):
				open_edge = open_edge or not img.get_pixel(x, y).is_equal_approx(BowlingLook.PIN_COLORS["K"])
	_check(white >= 20 and not open_edge and UiTheme.BG == Color.BLACK
			and Shell.contrast(BowlingLook.PIN_COLORS["W"], UiTheme.BG) > 15.0,
			"the pins are white (%d pixels) with a black outline, and the wall behind them is black" % white)
