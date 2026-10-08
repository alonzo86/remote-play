extends SceneTree
## The pure rules of the minigames, without a screen: Target Shoot targets (REQ-TS-3, 7 to 10) and its visual rules (REQ-TS-12).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/game_rules.gd -- --role=controller

const Shell = preload("res://scripts/game/shell.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const TargetField = preload("res://scripts/game/target_shoot/target_field.gd")

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
	_target_aim()
	_target_hit()
	_target_spawn()
	_target_tick()
	_target_visual_rules()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _target(kind: String, uv: Vector2) -> TargetField.Target:
	var t := TargetField.Target.new()
	t.kind = kind
	t.uv = uv
	t.radius = TargetField.KINDS[kind].radius
	t.points = TargetField.KINDS[kind].points
	t.life_left = TargetField.KINDS[kind].life
	return t


func _target_aim() -> void:
	print("target shoot: aim")
	var c := AREA.get_center()
	_check(TargetField.aim_to_screen(Vector2.ZERO, AREA) == c, "pointer 0 is the center of the play area (REQ-TS-3)")
	_check(TargetField.aim_to_screen(Vector2(-1, -1), AREA) == AREA.position
			and TargetField.aim_to_screen(Vector2(1, 1), AREA) == AREA.end, "pointer -1 and +1 are the corners of the play area")
	_check(TargetField.aim_to_screen(Vector2(0.5, -0.5), AREA) == c + Vector2(AREA.size.x * 0.25, -AREA.size.y * 0.25),
			"pointer 0.5 is a quarter of the area from the center")
	_check(TargetField.aim_to_screen(Vector2(7, -9), AREA) == Vector2(AREA.end.x, AREA.position.y),
			"the cursor stays inside the play area")
	var small := Rect2(60.0, 150.0, 1160.0, 510.0)   # A 1280x720 screen.
	_check(is_equal_approx(TargetField.scale_for(AREA), 1.0) and TargetField.scale_for(small) < 0.6,
			"the scale is 1 at 1920x1080 and smaller on a small screen (REQ-TS-14)")


func _target_hit() -> void:
	print("target shoot: hit test")
	var f := TargetField.new()
	var a := _target("standard", Vector2(0.5, 0.5))
	f.targets.append(a)
	var c := TargetField.center_of(a, AREA)
	_check(f.hit(c, AREA) == a, "a shot at the center hits")
	_check(f.hit(c + Vector2(56.0, 0.0), AREA) == a, "a shot at the edge of the radius hits")
	_check(f.hit(c + Vector2(56.0 + TargetField.HIT_SLOP, 0.0), AREA) == a, "a shot inside the 8 px slop hits (REQ-TS-10)")
	_check(f.hit(c + Vector2(56.0 + TargetField.HIT_SLOP + 1.0, 0.0), AREA) == null, "a shot just outside the slop misses")
	var b := _target("small", Vector2(0.5, 0.5) + Vector2(70.0, 0.0) / TargetField.REF_AREA)
	f.targets.append(b)
	var between := c + Vector2(50.0, 0.0)   # Inside both: 50 px from a, 20 px from b.
	_check(f.hit(between, AREA) == b, "inside two targets, the nearer center is hit")
	f.take(b)
	_check(f.hit(between, AREA) == a and f.targets.size() == 1, "a taken target is gone")
	var small := Rect2(60.0, 150.0, 1160.0, 510.0)
	var k := TargetField.scale_for(small)
	var sc := TargetField.center_of(a, small)
	_check(f.hit(sc + Vector2(56.0 * k, 0.0), small) == a and f.hit(sc + Vector2(60.0, 0.0), small) == null,
			"the radius scales with the screen")


func _target_spawn() -> void:
	print("target shoot: spawn")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var f := TargetField.new()
	var in_bounds := true
	var spaced := true
	var counts := {"standard": 0, "small": 0, "decoy": 0}
	for round_i in 400:
		f.targets.clear()
		for i in 6:
			f.spawn(rng, 2)
		for i in f.targets.size():
			var t: TargetField.Target = f.targets[i]
			counts[t.kind] += 1
			var m := Vector2(t.radius, t.radius) / TargetField.REF_AREA
			if t.uv.x < m.x or t.uv.x > 1.0 - m.x or t.uv.y < m.y or t.uv.y > 1.0 - m.y:
				in_bounds = false
			for j in range(i + 1, f.targets.size()):
				if ((t.uv - f.targets[j].uv) * TargetField.REF_AREA).length() < TargetField.MIN_SPACING:
					spaced = false
	_check(in_bounds, "every target is fully inside the play area (REQ-TS-8)")
	_check(spaced, "two targets are never closer than 160 px")
	var total: int = counts.standard + counts.small + counts.decoy
	_check(total > 1000 and absf(counts.standard / float(total) - 0.60) < 0.05 and absf(counts.small / float(total) - 0.25) < 0.05
			and absf(counts.decoy / float(total) - 0.15) < 0.05,
			"the kinds come in the ratio 60 : 25 : 15: %s of %d" % [str(counts), total])
	f.targets.clear()
	for i in 12:
		f.spawn(rng, 2)
	_check(f.targets.size() == TargetField.max_targets(2) and TargetField.max_targets(2) == 6,
			"with 2 players at most 6 targets are on the screen")
	_check(TargetField.max_targets(1) == 5 and TargetField.max_targets(4) == 8, "4 plus the number of players")
	var seeded_a := RandomNumberGenerator.new()
	seeded_a.seed = 5
	var seeded_b := RandomNumberGenerator.new()
	seeded_b.seed = 5
	var fa := TargetField.new()
	var fb := TargetField.new()
	for i in 4:
		fa.spawn(seeded_a, 2)
		fb.spawn(seeded_b, 2)
	var same := fa.targets.size() == fb.targets.size()
	for i in mini(fa.targets.size(), fb.targets.size()):
		same = same and fa.targets[i].uv == fb.targets[i].uv and fa.targets[i].kind == fb.targets[i].kind
	_check(same and fa.targets.size() > 0, "the same seed gives the same targets (REQ-TS-9)")
	var full := TargetField.new()
	for x in range(0, 1801, 100):   # A lattice of 100 px: no point of the area is 160 px from every target.
		for y in range(0, 871, 100):
			full.targets.append(_target("small", Vector2(x, y) / TargetField.REF_AREA))
	var before := full.targets.size()
	_check(full.spawn(rng, 999) == null and full.targets.size() == before, "with no free place no target is added")


func _target_tick() -> void:
	print("target shoot: time")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var f := TargetField.new()
	f.tick(0.01, rng, 4)
	_check(f.targets.size() == 1, "the first target appears at once")
	f.tick(0.5, rng, 4)
	_check(f.targets.size() == 1, "the next one waits for the 0.7 s")
	f.tick(0.3, rng, 4)
	_check(f.targets.size() == 2, "a new target every 0.7 s (REQ-TS-8)")
	var once := TargetField.new()
	var split := TargetField.new()
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 9
	r2.seed = 9
	once.tick(1.4, r1, 4)
	for i in 4:
		split.tick(0.35, r2, 4)
	_check(once.targets.size() == split.targets.size() and once.targets.size() > 0,
			"the targets do not depend on the frame time (REQ-GM-13): %d and %d" % [once.targets.size(), split.targets.size()])
	var life := TargetField.new()
	life.targets.append(_target("small", Vector2(0.2, 0.2)))
	life.targets.append(_target("standard", Vector2(0.8, 0.8)))
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var gone := 0
	gone += life.tick(2.3, rng2, 1)   # Small lives 2.2 s. Standard lives 3.2 s.
	var kinds_left := life.targets.map(func(t: TargetField.Target) -> String: return t.kind)
	_check(gone == 1 and not kinds_left.has("small") and kinds_left.has("standard"),
			"a small target is gone after 2.2 s, a standard one stays (REQ-TS-7)")
	_check(is_equal_approx(_target("standard", Vector2.ZERO).grow(TargetField.GROW_TIME), 0.0), "a new target has not grown yet")
	var g := _target("standard", Vector2.ZERO)
	g.age = TargetField.GROW_TIME * 0.5
	var half: float = g.grow(TargetField.GROW_TIME)
	g.age = 5.0
	_check(is_equal_approx(half, 0.5) and g.grow(TargetField.GROW_TIME) == 1.0, "a target grows in 0.15 s and stays at full size")
	var kinds: Dictionary = TargetField.KINDS
	_check(kinds.standard.points == 10 and kinds.small.points == 25 and kinds.decoy.points == -15,
			"the points are 10, 25 and -15 (REQ-TS-7)")


func _target_visual_rules() -> void:
	print("target shoot: visual rules")
	var consts: Dictionary = load("res://scripts/game/target_shoot/target_shoot_game.gd").get_script_constant_map()
	var board: Color = consts["BOARD_COLOR"]
	var bg: Color = consts["BACKGROUND"]
	var slots_ok := true
	for c in Protocol.PLAYER_COLORS:
		if Shell.contrast(c, board) < 3.0:
			slots_ok = false
			print("    slot color too close to the board: ", c)
	_check(slots_ok, "every player color has a contrast of 3:1 on the board (REQ-GM-47e)")
	var kinds_ok := true
	for key in ["STANDARD_COLOR", "SMALL_COLOR", "DECOY_COLOR"]:
		var c: Color = consts[key]
		if Shell.contrast(c, board) < 3.0 or c.s < 0.55 or c.v < 0.60:
			kinds_ok = false
			print("    target color not bright enough or not saturated: ", key)
	_check(kinds_ok, "target colors have a contrast of 3:1 on the board, saturation 0.55+ and value 0.60+ (REQ-GM-47d, 47e)")
	_check(board.s >= 0.35 and board.v >= 0.25 and board.v <= 0.65 and bg.s >= 0.35 and bg.v >= 0.25 and bg.v <= 0.65,
			"the board and the background are dark and saturated (REQ-GM-47e)")
	var smallest := 1e9
	for kind in TargetField.KINDS:
		smallest = minf(smallest, float(TargetField.KINDS[kind].radius) * 2.0)
	_check(smallest >= 48.0 and float(consts["CURSOR_R"]) * 2.0 >= 48.0,
			"every key object is 48 px high or more at 1080p (REQ-GM-47e)")
	var slot_like := [Color("3ddcff"), Color("ffd23f"), Color("ff3d8b")]
	var clash := false
	for c in Protocol.PLAYER_COLORS:
		for t in slot_like:
			if c.is_equal_approx(t):
				clash = true
	_check(not clash, "no target color is a player color")
