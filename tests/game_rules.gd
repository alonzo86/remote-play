extends SceneTree
## The pure rules of the minigames, without a screen: the Puffs of Snowball Splat (REQ-SS-3, 7 to 10, 12).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/game_rules.gd -- --role=controller

const Shell = preload("res://scripts/game/shell.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")

const AREA := Rect2(60.0, 150.0, 1800.0, 870.0)   # The play area at 1920x1080.

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
	_aim()
	_kinds_and_lanes()
	_flying()
	_spawning()
	_hit_test()
	_visual_rules()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## A Puff in lane `lane` (0 top: Little Puffs to the right, 1 middle: Puffs to the left, 2 bottom: Puffs to the right) at `x`
## (px of the play area), at the start of its wave.
func _puff(lane: int, x: float) -> PuffField.Puff:
	var p := PuffField.Puff.new()
	p.lane = lane
	p.kind = PuffField.LANES[lane].kind
	p.dir = PuffField.LANES[lane].dir
	p.lane_y = PuffField.LANES[lane].y
	p.radius = PuffField.KINDS[p.kind].radius
	p.speed = PuffField.KINDS[p.kind].speed
	p.points = PuffField.KINDS[p.kind].points
	p.x = x
	return p


func _aim() -> void:
	print("snowball splat: aim")
	var c := AREA.get_center()
	_check(PuffField.aim_to_screen(Vector2.ZERO, AREA) == c, "pointer 0 is the center of the play area (REQ-SS-3)")
	_check(PuffField.aim_to_screen(Vector2(-1, -1), AREA) == AREA.position
			and PuffField.aim_to_screen(Vector2(1, 1), AREA) == AREA.end, "pointer -1 and +1 are the corners of the play area")
	_check(PuffField.aim_to_screen(Vector2(0.5, -0.5), AREA) == c + Vector2(AREA.size.x * 0.25, -AREA.size.y * 0.25),
			"pointer 0.5 is a quarter of the area from the center")
	_check(PuffField.aim_to_screen(Vector2(7, -9), AREA) == Vector2(AREA.end.x, AREA.position.y),
			"the cursor stays inside the play area")
	var small := Rect2(60.0, 150.0, 1160.0, 510.0)   # A 1280x720 screen.
	_check(is_equal_approx(PuffField.scale_for(AREA), 1.0) and PuffField.scale_for(small) < 0.6,
			"the scale is 1 at 1920x1080 and smaller on a small screen (REQ-SS-15)")


func _kinds_and_lanes() -> void:
	print("snowball splat: kinds and lanes")
	var kinds: Dictionary = PuffField.KINDS
	_check(kinds.puff.points == 10 and kinds.puff.radius == 100.0 and kinds.puff.speed == 100.0
			and kinds.little.points == 25 and kinds.little.radius == 72.0 and kinds.little.speed == 160.0,
			"Puff: 10 points, radius 100, 100 px/s. Little Puff: 25 points, radius 72, 160 px/s (REQ-SS-7)")
	var slow := true
	var big := true
	for k in kinds:
		slow = slow and float(kinds[k].speed) <= 200.0
		big = big and float(kinds[k].radius) >= 72.0
	_check(slow and big, "no Puff is faster than 200 px/s, and every Puff is at least 144 px wide (REQ-SS-7, REQ-GM-82)")
	var inside := true
	var kinds_ok := true
	for lane in PuffField.LANES:
		var r: float = kinds[lane.kind].radius
		inside = inside and lane.y - r - PuffField.WAVE >= 0.0 and lane.y + r + PuffField.WAVE <= PuffField.REF_AREA.y - 70.0
		kinds_ok = kinds_ok and kinds.has(lane.kind) and (lane.dir == 1 or lane.dir == -1)
	_check(inside and kinds_ok, "every lane, with its wave, is inside the play area and above the snow (REQ-SS-8)")
	_check(PuffField.LANES.size() == 3, "there are 3 lanes")
	var p := _puff(1, 500.0)
	p.age = PuffField.WAVE_TIME * 0.25
	var top := p.y()
	p.age = PuffField.WAVE_TIME * 0.75
	_check(is_equal_approx(top, p.lane_y + PuffField.WAVE) and is_equal_approx(p.y(), p.lane_y - PuffField.WAVE),
			"a Puff goes up and down 28 px around its lane")


func _flying() -> void:
	print("snowball splat: flying")
	var f := PuffField.new()
	var p := _puff(1, 500.0)   # The middle lane flies to the left.
	f.puffs.append(p)
	f.tick(1.0, _rng(1), 99)
	_check(p.dir == -1 and is_equal_approx(p.x, 400.0), "a Puff of the middle lane flies left at 100 px/s: x = %.1f" % p.x)
	var q := _puff(0, 0.0)   # The top lane flies to the right.
	var g := PuffField.new()
	g.puffs.append(q)
	g.tick(0.5, _rng(1), 99)
	_check(q.dir == 1 and is_equal_approx(q.x, 80.0), "a Little Puff of the top lane flies right at 160 px/s: x = %.1f" % q.x)
	var once := _puff(1, 1200.0)
	var split := _puff(1, 1200.0)
	var fa := PuffField.new()
	var fb := PuffField.new()
	fa.puffs.append(once)
	fb.puffs.append(split)
	fa.tick(2.0, _rng(2), 0)
	for i in 200:
		fb.tick(0.01, _rng(2), 0)
	_check(absf(once.x - split.x) < 0.01 and absf(once.age - split.age) < 0.0001,
			"the flight does not depend on the frame time (REQ-GM-13): %.3f and %.3f" % [once.x, split.x])
	var leaving := _puff(1, 150.0)
	var h := PuffField.new()
	h.puffs.append(leaving)
	var away := h.tick(2.0, _rng(3), 0)   # 150 - 200 = -50: still inside the edge zone (radius 100).
	away += h.tick(1.0, _rng(3), 0)       # -150 is beyond -radius - 2.
	_check(away == 1 and not h.puffs.has(leaving), "a Puff that flew out of the other edge is gone and nothing else happens")


func _spawning() -> void:
	print("snowball splat: coming in")
	var rng := _rng(11)
	var f := PuffField.new()
	f.tick(0.01, rng, 2)
	_check(f.puffs.size() == 1, "the first Puff comes at once (REQ-SS-9)")
	var first := f.puffs[0]
	var right_edge: float = PuffField.REF_AREA.x + first.radius
	var edge_ok := (first.dir > 0 and first.x <= -first.radius + 0.5) or (first.dir < 0 and first.x >= right_edge - 0.5)
	_check(edge_ok and first.kind == PuffField.LANES[first.lane].kind,
			"a Puff comes in at the edge of its lane, with the kind of the lane")
	f.tick(1.0, rng, 2)
	_check(f.puffs.size() == 1, "the next Puff waits for the 1.5 s")
	f.tick(0.6, rng, 2)
	_check(f.puffs.size() == 2, "a new Puff every 1.5 s")
	var overlaps := false
	var too_many := false
	var colors_ok := true
	var run := PuffField.new()
	var rng2 := _rng(5)
	for i in 3600:   # 2 minutes at 30 frames per second, 3 players.
		run.tick(1.0 / 30.0, rng2, 3)
		too_many = too_many or run.puffs.size() > PuffField.max_puffs(3)
		for a in run.puffs:
			colors_ok = colors_ok and a.color_index >= 0 and a.color_index < PuffField.COLOR_COUNT
			for b in run.puffs:
				if a != b and a.lane == b.lane and absf(a.x - b.x) < a.radius + b.radius:
					overlaps = true
	_check(not overlaps, "in 2 minutes two Puffs of one lane never overlap (REQ-SS-8)")
	_check(not too_many and PuffField.max_puffs(3) == 6, "never more than 3 + the number of players Puffs on the screen (REQ-SS-9)")
	_check(colors_ok, "every Puff has one of the colors")
	var counts := {"puff": 0, "little": 0}
	var rng3 := _rng(21)
	for i in 3000:
		var one := PuffField.new()
		var p := one.spawn(rng3, 99)
		counts[p.kind] += 1
	_check(absf(counts.puff / 3000.0 - 0.70) < 0.04 and absf(counts.little / 3000.0 - 0.30) < 0.04,
			"Puffs and Little Puffs come in the ratio 70 : 30: %s" % str(counts))
	var full := PuffField.new()
	for i in 12:
		full.spawn(rng3, 0)
	_check(full.puffs.size() <= PuffField.max_puffs(0) and full.puffs.size() <= 3, "a full screen (or full lanes) adds no Puff")
	var a1 := PuffField.new()
	var a2 := PuffField.new()
	var s1 := _rng(8)
	var s2 := _rng(8)
	var same := true
	for i in 40:
		a1.tick(0.5, s1, 2)
		a2.tick(0.5, s2, 2)
		same = same and a1.puffs.size() == a2.puffs.size()
		for j in a1.puffs.size():
			same = same and a1.puffs[j].lane == a2.puffs[j].lane and a1.puffs[j].color_index == a2.puffs[j].color_index \
					and is_equal_approx(a1.puffs[j].x, a2.puffs[j].x)
	_check(same, "the same seed gives the same Puffs (REQ-SS-9)")


func _hit_test() -> void:
	print("snowball splat: hit test")
	var f := PuffField.new()
	var a := _puff(2, 900.0)
	f.puffs.append(a)
	var c := PuffField.center_of(a, AREA)
	_check(f.hit(c, AREA) == a, "a snowball in the middle hits")
	_check(f.hit(c + Vector2(100.0, 0.0), AREA) == a, "a snowball at the edge of the radius hits")
	_check(f.hit(c + Vector2(100.0 + PuffField.HIT_SLOP, 0.0), AREA) == a, "a snowball inside the 12 px slop hits (REQ-SS-10)")
	_check(f.hit(c + Vector2(100.0 + PuffField.HIT_SLOP + 1.0, 0.0), AREA) == null, "a snowball just outside the slop misses")
	var b := _puff(0, 940.0)   # A Little Puff that is moved down, so that it touches the first Puff in this test.
	b.lane_y = a.lane_y + 60.0
	f.puffs.append(b)
	var between := PuffField.center_of(b, AREA) + Vector2(-20.0, 0.0)
	_check(f.hit(between, AREA) == b, "inside two Puffs, the nearer center is hit")
	f.take(b)
	_check(f.hit(between, AREA) == a and f.puffs.size() == 1, "a taken Puff is gone")
	f.tick(2.0, _rng(4), 0)   # The Puff moves 200 px to the left.
	_check(f.hit(c, AREA) == null and f.hit(PuffField.center_of(a, AREA), AREA) == a,
			"the hit follows the Puff where it is when the snowball lands")
	var small := Rect2(60.0, 150.0, 1160.0, 510.0)
	var k := PuffField.scale_for(small)
	var sc := PuffField.center_of(a, small)
	_check(f.hit(sc + Vector2(100.0 * k, 0.0), small) == a and f.hit(sc + Vector2(120.0, 0.0), small) == null,
			"the radius scales with the screen")


func _visual_rules() -> void:
	print("snowball splat: visual rules")
	var consts: Dictionary = load("res://scripts/game/snowball_splat/snowball_splat_game.gd").get_script_constant_map()
	var board: Color = consts["BOARD_COLOR"]
	var bg: Color = consts["BACKGROUND"]
	var slots_ok := true
	for c in Protocol.PLAYER_COLORS:
		if Shell.contrast(c, board) < 3.0:
			slots_ok = false
			print("    slot color too close to the board: ", c)
	_check(slots_ok, "every player color has a contrast of 3:1 on the board (REQ-GM-47e)")
	var puff_colors: Array = consts["PUFF_COLORS"] + [consts["LITTLE_COLOR"]]
	var colors_ok := puff_colors.size() == PuffField.COLOR_COUNT + 1
	for c in puff_colors:
		if Shell.contrast(c, board) < 3.0 or c.s < 0.55 or c.v < 0.60:
			colors_ok = false
			print("    Puff color not bright enough or not saturated: ", c)
	_check(colors_ok, "Puff colors have a contrast of 3:1 on the board, saturation 0.55+ and value 0.60+ (REQ-GM-47d, 47e)")
	_check(board.s >= 0.35 and board.v >= 0.25 and board.v <= 0.65 and bg.s >= 0.35 and bg.v >= 0.25 and bg.v <= 0.65,
			"the board and the background are dark and saturated (REQ-GM-47e)")
	var smallest := 1e9
	for kind in PuffField.KINDS:
		smallest = minf(smallest, float(PuffField.KINDS[kind].radius) * 2.0)
	_check(smallest >= 48.0 and float(consts["CURSOR_R"]) * 2.0 >= 48.0,
			"every key object is 48 px high or more at 1080p (REQ-GM-47e)")
	var clash := false
	for c in Protocol.PLAYER_COLORS:
		for t in puff_colors:
			if c.is_equal_approx(t):
				clash = true
	_check(not clash, "no Puff color is a player color")
	_check(float(consts["RELOAD"]) <= 0.5 and float(consts["ROUND_TIME"]) >= 45.0,
			"a quick reload (0.5 s or less) and a round of at least 45 s: a child is not stopped after a miss (REQ-GM-83)")
