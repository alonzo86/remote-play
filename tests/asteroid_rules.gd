extends SceneTree
## The rules and the pictures of Asteroid Blast (REQ-AB-*), pure logic. Run:
##   godot --headless --path . --script tests/asteroid_rules.gd -- --role=controller

const Shell = preload("res://scripts/game/shell.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const SpaceField = preload("res://scripts/game/asteroid_blast/space_field.gd")
const BlastLook = preload("res://scripts/game/asteroid_blast/blast_look.gd")

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
	_space_field()
	_space_waves()
	_blast_look()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## A field with one ship per x in `xs` (slots 0, 1, ...) at the given difficulty.
func _field(xs: Array, difficulty := "medium") -> SpaceField:
	var f := SpaceField.new()
	f.setup(difficulty)
	for i in xs.size():
		f.add_ship(i, float(xs[i]))
	return f


## The ships, the beams, the asteroids and the upgrades of Asteroid Blast (REQ-AB-2, 4 to 7, 10 to 13).
func _space_field() -> void:
	print("space field")
	var f := _field([900.0])
	var s: SpaceField.Ship = f.ships[0]
	for i in 60:
		f.steer(s, 1.0, 1.0 / 60.0)
	_check(s.x > 1000.0 and s.x < SpaceField.REF_AREA.x - SpaceField.EDGE,
			"a tilt to the right moves the ship to the right, smoothly (REQ-AB-2)")
	for i in 600:
		f.steer(s, 1.0, 1.0 / 60.0)
	var right_end := s.x
	for i in 1200:
		f.steer(s, -1.0, 1.0 / 60.0)
	_check(right_end == SpaceField.REF_AREA.x - SpaceField.EDGE and s.x == SpaceField.EDGE,
			"the ship stops at both sides of the screen (REQ-AB-2)")
	var still := s.x
	for i in 60:
		f.steer(s, 0.02, 1.0 / 60.0)
	_check(is_equal_approx(s.x, still), "a tilt inside the dead zone does not move the ship")

	var rng := _rng(5)
	f = _field([900.0])
	f.tick(0.5, rng, {0: 0.0}, false)
	_check(f.beams.is_empty() and f.asteroids.is_empty() and f.phase_time == 0.0,
			"nothing fires, falls or counts while the countdown runs (REQ-AB-2)")
	f.tick(0.01, rng, {0: 0.0})
	_check(f.beams.size() == 1 and f.events.any(func(e: Dictionary) -> bool: return e.t == "shot"),
			"the ship fires by itself (REQ-AB-4)")
	f.tick(0.2, rng, {0: 0.0})
	var after_200 := f.beams.size()
	f.tick(0.25, rng, {0: 0.0})
	_check(after_200 == 1 and f.beams.size() == 2, "it fires again every 0.4 s (REQ-AB-4)")
	f.tick(0.1, rng, {0: 0.0})
	_check(f.events.is_empty() or not f.events.any(func(e: Dictionary) -> bool: return e.t == "shot"),
			"the events are those of the last tick only")

	var offs := SpaceField.laser_offsets(1)
	var offs4 := SpaceField.laser_offsets(4)
	_check(offs == [0.0] and SpaceField.laser_offsets(2) == [-11.0, 11.0] and offs4.size() == 4 and offs4[0] == -offs4[3]
			and is_equal_approx(offs4[1] - offs4[0],
					SpaceField.LASER_GAP), "the beams of 1 to 4 lasers are in a row around the ship (REQ-AB-11)")

	# Sizes and splitting (REQ-AB-5, 7).
	f = _field([900.0])
	var small := f._make(0, 300.0, 400.0, rng)
	var beam := SpaceField.Beam.new()
	beam.x = 300.0
	beam.y = 400.0
	beam.owner = 0
	f.beams.append(beam)
	f._hit_asteroids()
	_check(f.asteroids.is_empty() and f.beams.is_empty() and f.scores[0] == 10,
			"a beam breaks a small asteroid: 10 points to its ship (REQ-AB-5)")
	var medium := f._make(1, 300.0, 400.0, rng)
	for i in 2:
		var b := SpaceField.Beam.new()
		b.x = 300.0
		b.y = 400.0 + 4.0 * i
		b.owner = 0
		f.beams.append(b)
		f._hit_asteroids()
		if i == 0:
			_check(f.asteroids.has(medium) and medium.hp == 1 and f.scores[0] == 10, "a medium asteroid needs 2 hits (REQ-AB-5)")
	_check(not f.asteroids.has(medium) and f.scores[0] == 30 and f.asteroids.size() == 2
			and f.asteroids.all(func(a: SpaceField.Asteroid) -> bool: return a.size == 0),
			"the 2nd hit gives 20 points and 2 small pieces (REQ-AB-7)")
	f.asteroids.clear()
	var large := f._make(2, 600.0, 300.0, rng)
	for i in 4:
		var b := SpaceField.Beam.new()
		b.x = 600.0
		b.y = 300.0
		b.owner = 0
		f.beams.append(b)
		f._hit_asteroids()
	var pieces: Array = f.asteroids.filter(func(a: SpaceField.Asteroid) -> bool: return a != large)
	_check(f.scores[0] == 70 and pieces.size() == 2 and pieces.all(func(a: SpaceField.Asteroid) -> bool: return a.size == 1)
			and pieces[0].x < 600.0 and pieces[1].x > 600.0 and pieces[0].vx < 0.0 and pieces[1].vx > 0.0,
			"a large asteroid needs 4 hits, gives 40 points and 2 medium pieces that fly apart (REQ-AB-5, 7)")
	_check(SpaceField.SIZES[0].radius < SpaceField.SIZES[1].radius and SpaceField.SIZES[1].radius < SpaceField.SIZES[2].radius
			and SpaceField.SIZES[0].speed > SpaceField.SIZES[2].speed, "three sizes: a smaller asteroid is faster (REQ-AB-5)")
	var seen := {}
	var in_range := true
	for seed_value in 120:
		var g := _field([900.0])
		var a := g.spawn(_rng(seed_value))
		seen[a.size] = true
		in_range = in_range and a.y < 0.0 and a.x >= a.radius and a.x <= SpaceField.REF_AREA.x - a.radius
	_check(seen.size() == 3 and in_range, "asteroids of all sizes enter from the top at a random place (REQ-AB-6)")
	f = _field([900.0, 1200.0])
	var drift := f._make(1, SpaceField.REF_AREA.x - 10.0, 100.0, rng)
	drift.vx = 80.0
	f._move_asteroids(0.1)
	_check(drift.vx < 0.0 and f.scores.size() == 2, "an asteroid at the side turns back and stays on the screen")
	f.remove_ship(1)
	_check(not f.ships.has(1) and not f.scores.has(1) and f.beams.all(func(b: SpaceField.Beam) -> bool: return b.owner != 1),
			"a ship that leaves takes its score and beams away (REQ-AB-19)")

	# Shield and loss (REQ-AB-12, 13).
	f = _field([900.0, 1500.0])
	var hit := f._make(1, 900.0, SpaceField.SHIP_Y - 30.0, rng)
	f.ships[0].shield = true
	f._ship_contacts()
	_check(f.ships[0].alive and not f.ships[0].shield and not f.asteroids.has(hit) and f.scores[0] == 0
			and f.events.any(func(e: Dictionary) -> bool: return e.t == "shield_pop"),
			"a force field takes one hit and goes away; the ship flies on, the asteroid is gone with no points (REQ-AB-12)")
	var hit2 := f._make(0, 900.0, SpaceField.SHIP_Y - 20.0, rng)
	f._ship_contacts()
	_check(not f.ships[0].alive and f.ships[1].alive and f.asteroids.has(hit2) and f.alive_count() == 1 and not f.all_lost()
			and f.events.any(func(e: Dictionary) -> bool: return e.t == "ship_lost"),
			"a hit without a force field blows up the ship: it is out, the others fly on (REQ-AB-13)")
	f.tick(0.5, rng, {0: 1.0, 1: 0.0})
	_check(f.ships[0].x == 900.0, "a ship that is out does not steer any more")
	f._make(0, 1500.0, SpaceField.SHIP_Y, rng)
	f._ship_contacts()
	_check(f.all_lost() and not SpaceField.new().all_lost(), "when the last ship is gone every ship is lost (REQ-AB-14)")

	# Upgrades (REQ-AB-10, 11).
	f = _field([900.0])
	var ship: SpaceField.Ship = f.ships[0]
	for i in 3:
		var u := SpaceField.Upgrade.new()
		u.kind = SpaceField.WEAPON
		f._apply(ship, u)
	_check(ship.lasers == 4 and f.scores[0] == 0, "each weapon upgrade adds one laser, up to 4 (REQ-AB-11)")
	var spare := SpaceField.Upgrade.new()
	spare.kind = SpaceField.WEAPON
	f._apply(ship, spare)
	_check(ship.lasers == 4 and f.scores[0] == SpaceField.UPGRADE_SPARE and f.events[-1].used == false,
			"a 5th weapon upgrade gives points instead (REQ-AB-11)")
	var shield := SpaceField.Upgrade.new()
	shield.kind = SpaceField.SHIELD
	f._apply(ship, shield)
	var first_shield := ship.shield
	f._apply(ship, shield)
	_check(first_shield and f.scores[0] == 2 * SpaceField.UPGRADE_SPARE,
			"a force field upgrade turns the shield on; a second one gives points (REQ-AB-11)")
	f = _field([900.0])
	f._upgrade_timer = 0.0
	f.tick(0.016, rng, {0: 0.0})
	var dropped: SpaceField.Upgrade = f.upgrades[0]
	_check(f.upgrades.size() == 1 and dropped.y < 0.0 and (dropped.kind == SpaceField.SHIELD or dropped.kind == SpaceField.WEAPON)
			and f._upgrade_timer >= SpaceField.UPGRADE_MIN,
			"an upgrade falls from the top and the next one comes after 12 to 20 s (REQ-AB-10)")
	dropped.x = 900.0
	dropped.y = SpaceField.SHIP_Y
	f.tick(0.016, rng, {0: 0.0})
	_check(f.upgrades.is_empty() and (f.ships[0].shield or f.ships[0].lasers == 2),
			"a ship that touches an upgrade takes it (REQ-AB-10)")


## The waves (REQ-AB-8, 9, 20).
func _space_waves() -> void:
	print("space waves")
	var rng := _rng(8)
	var f := _field([900.0, 1200.0])
	_check(f.wave == 1 and f.phase == SpaceField.Phase.WAVE and is_equal_approx(f.phase_left(), 30.0),
			"the game starts with wave 1 of 30 s (REQ-AB-8)")
	f._tick_waves(29.9, rng)
	_check(f.phase == SpaceField.Phase.WAVE and f.scores[0] == 0, "a wave lasts 30 s")
	f._tick_waves(0.2, rng)
	_check(f.phase == SpaceField.Phase.REST and f.scores[0] == 50 and f.scores[1] == 50 and is_equal_approx(f.phase_left(), 5.0)
			and f.events.any(func(e: Dictionary) -> bool: return e.t == "wave_end"),
			"after 30 s the players rest for 5 s and each living ship gets 50 points (REQ-AB-8)")
	var before := f.asteroids.size()
	f._tick_waves(4.0, rng)
	_check(f.asteroids.size() == before and f.phase == SpaceField.Phase.REST, "no asteroid comes during the rest")
	f._tick_waves(1.1, rng)
	_check(f.wave == 2 and f.phase == SpaceField.Phase.WAVE
			and f.events.any(func(e: Dictionary) -> bool: return e.t == "wave_start"),
			"after the rest wave 2 starts (REQ-AB-8)")
	f.ships[1].alive = false
	f._tick_waves(30.1, rng)
	_check(f.scores[0] == 50 + 100 and f.scores[1] == 50, "the bonus is 50 times the wave, only for a ship that is still flying")
	_check(SpaceField.wave_speed(1) == 1.0 and is_equal_approx(SpaceField.wave_speed(6), 1.5),
			"each wave is 10 % faster (REQ-AB-9)")
	var every_1 := SpaceField.spawn_every(1, 1)
	_check(SpaceField.spawn_every(2, 1) < every_1 and SpaceField.spawn_every(5, 1) < SpaceField.spawn_every(2, 1)
			and SpaceField.spawn_every(100,
					1) == SpaceField.SPAWN_MIN, "later waves bring more asteroids, but not endlessly many (REQ-AB-9)")
	_check(SpaceField.spawn_every(1, 4) < every_1 and SpaceField.spawn_every(1, 0) == every_1,
			"more ships in the sky bring more asteroids (REQ-AB-9)")
	var weights_ok := true
	for n in [1, 4, 10, 40]:
		weights_ok = weights_ok and SpaceField.size_weights(n).reduce(func(a: int, b: int) -> int: return a + b) == 100
	_check(weights_ok and SpaceField.size_weights(8)[2] > SpaceField.size_weights(1)[2]
			and SpaceField.size_weights(8)[0] < SpaceField.size_weights(1)[0],
			"big asteroids come more often in later waves (REQ-AB-9)")
	# Difficulty (REQ-AB-20).
	var easy := _field([900.0], "easy")
	var hard := _field([900.0], "hard")
	var unknown := _field([900.0], "x")
	var a_easy := easy._make(1, 500.0, 0.0, rng)
	var a_hard := hard._make(1, 500.0, 0.0, rng)
	var a_unknown := unknown._make(1, 500.0, 0.0, rng)
	_check(a_easy.vy < a_unknown.vy and a_unknown.vy < a_hard.vy and a_unknown.vy == SpaceField.BASE_SPEED,
			"Easy is slower, Hard faster than Medium; an unknown level is Medium (REQ-AB-20)")
	var rate_ok := true
	for g in [easy, hard]:
		var count := 0
		g._tick_waves(0.0, rng)
		g._tick_waves(10.0, rng)
		count = g.asteroids.size()
		rate_ok = rate_ok and count > 0
	_check(easy.asteroids.size() < hard.asteroids.size() and rate_ok,
			"Hard brings more asteroids than Easy in the same time (REQ-AB-20)")
	var tiers_ok := true
	for level in ["easy", "medium", "hard"]:
		var t: Array = SpaceField.LEVELS[level].tiers
		tiers_ok = tiers_ok and t[0] < t[1] and t[1] < t[2]
	_check(tiers_ok and SpaceField.LEVELS.easy.tiers[0] > SpaceField.LEVELS.hard.tiers[0],
			"the medal tiers rise and Hard asks less (REQ-AB-20)")


## True when `img` has a pixel of exactly `color`.
func _has_pixel(img: Image, color: Color) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).is_equal_approx(color):
				return true
	return false


## The pictures of Asteroid Blast (REQ-AB-17).
func _blast_look() -> void:
	print("blast look")
	var a := BlastLook.asteroid_image(1, 2, 48.0)
	var b := BlastLook.asteroid_image(1, 2, 48.0)
	var c := BlastLook.asteroid_image(1, 3, 48.0)
	_check(a.get_data() == b.get_data() and a.get_data() != c.get_data(),
			"an asteroid picture is always the same; the 4 looks differ")
	_check(a.get_width() == 12 * 2 + 1 + 2 and a.get_pixel(0, 0).a == 0.0 and _has_pixel(a, BlastLook.OUTLINE),
			"an asteroid is as wide as its size and has a black outline")
	var small := BlastLook.asteroid_image(0, 0, 30.0)
	var large := BlastLook.asteroid_image(2, 0, 74.0)
	_check(small.get_width() < a.get_width() and a.get_width() < large.get_width(), "the pictures grow with the size")
	var red := BlastLook.ship_image(Protocol.PLAYER_COLORS[0], 0)
	var green := BlastLook.ship_image(Protocol.PLAYER_COLORS[1], 0)
	var flame := BlastLook.ship_image(Protocol.PLAYER_COLORS[0], 1)
	_check(red.get_data() != green.get_data() and red.get_data() != flame.get_data(),
			"a ship has the color of its player and its flame flickers")
	_check(BlastLook.pickup_image("shield").get_data() != BlastLook.pickup_image("weapon").get_data()
			and BlastLook.pickup_image("shield").get_pixel(8, 8).is_equal_approx(Color.WHITE), "the two pickups look different")
	var moved: bool = BlastLook.star_at(3, 0.0).y != BlastLook.star_at(3, 5.0).y
	var wraps := true
	for i in BlastLook.STAR_COUNT:
		var st := BlastLook.star_at(i, 123.4)
		wraps = wraps and st.y >= 0 and st.y < int(BlastLook.VIEW.y) and st.x >= 0 and st.x < int(BlastLook.VIEW.x)
	_check(moved and wraps and BlastLook.star_at(7, 0.0) == BlastLook.star_at(7, 0.0),
			"the stars drift down and come back on top")
	_check(Shell.contrast(BlastLook.OUTLINE, BlastLook.ROCK_DARK) >= 2.0 and Shell.contrast(BlastLook.SKY_BOTTOM,
			BlastLook.ROCK_LIGHT) >= 3.0,
			"the asteroids stand out from the sky and from their outline")

