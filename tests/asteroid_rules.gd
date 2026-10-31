extends SceneTree
## The rules and the pictures of Star Shield (REQ-AB-*), pure logic. Run:
##   godot --headless --path . --script tests/asteroid_rules.gd -- --role=controller

const Shell = preload("res://scripts/game/shell.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const SpaceField = preload("res://scripts/game/asteroid_blast/space_field.gd")
const BlastLook = preload("res://scripts/game/asteroid_blast/blast_look.gd")
const SimInput = preload("res://tests/sim_input.gd")

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
	_space_field()
	_space_waves()
	_blast_look()
	_ship_speed_and_fire()
	_waves()
	_pictures()
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


## The ships, the beams, the asteroids and the upgrades of Star Shield (REQ-AB-2, 4 to 7, 10 to 13).
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
	_check(not f.events.any(func(e: Dictionary) -> bool: return e.t == "shot"),
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
	_check(is_equal_approx(f.ships[0].grace, SpaceField.GRACE_TIME),
			"a force field that took a hit leaves the ship 3 s of grace (issue #137)")
	var hit2 := f._make(0, 900.0, SpaceField.SHIP_Y - 20.0, rng)
	f._ship_contacts()
	_check(f.ships[0].alive and f.asteroids.has(hit2) and f.ships[0].shield == false,
			"a second asteroid inside the grace time costs nothing: it passes through the ship (issue #137)")
	f.tick(0.5, rng, {0: 0.0, 1: 0.0})
	_check(f.ships[0].grace > 0.0 and f.events.any(func(e: Dictionary) -> bool: return e.t == "shot" and e.slot == 0),
			"a ship in its grace time still shoots (issue #137)")
	f.tick(SpaceField.GRACE_TIME, rng, {0: 0.0, 1: 0.0})
	_check(f.ships[0].grace == 0.0, "the grace time ends after 3 s")
	hit2 = f._make(0, 900.0, SpaceField.SHIP_Y - 20.0, rng)
	f._ship_contacts()
	_check(not f.ships[0].alive and f.ships[1].alive and f.asteroids.has(hit2) and f.alive_count() == 1 and not f.all_lost()
			and f.events.any(func(e: Dictionary) -> bool: return e.t == "ship_lost"),
			"a hit without a force field blows up the ship: it is out, the others fly on (REQ-AB-13)")
	f.tick(0.5, rng, {0: 1.0, 1: 0.0})
	_check(f.ships[0].x == 900.0, "a ship that is out does not steer any more")
	f._make(0, 1500.0, SpaceField.SHIP_Y, rng)
	f._ship_contacts()
	_check(f.all_lost() and not SpaceField.new().all_lost(), "when the last ship is gone every ship is lost (REQ-AB-14)")

	# Two asteroids touch a shielded ship in one tick: one force field, the ship lives.
	f = _field([900.0])
	f.ships[0].shield = true
	var twin1 := f._make(0, 890.0, SpaceField.SHIP_Y - 20.0, rng)
	var twin2 := f._make(0, 910.0, SpaceField.SHIP_Y - 20.0, rng)
	f._ship_contacts()
	_check(f.ships[0].alive and not f.ships[0].shield and not f.asteroids.has(twin1) and not f.asteroids.has(twin2)
			and f.events.filter(func(e: Dictionary) -> bool: return e.t == "shield_pop").size() == 1,
			"two asteroids in one tick cost one force field, not the ship (REQ-AB-12)")

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
	var timed := _field([900.0])
	timed._tick_upgrades(SpaceField.UPGRADE_FIRST - 0.1, rng)
	_check(timed.upgrades.is_empty(), "no upgrade falls in the first 10 s (REQ-AB-10)")
	timed._tick_upgrades(0.2, rng)
	_check(timed.upgrades.size() == 1, "the first upgrade falls after 10 s of play (REQ-AB-10)")
	for i in 4:
		timed._upgrade_timer = 0.0
		timed._tick_upgrades(0.0, rng)
	_check(timed.upgrades.size() == SpaceField.UPGRADE_MAX_ON_SCREEN, "there are at most 2 upgrades on the screen (REQ-AB-10)")
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
	f.beams.clear()
	f.tick(0.5, rng, {0: 0.0, 1: 0.0})
	_check(f.phase == SpaceField.Phase.REST and not f.beams.is_empty(), "the lasers go on firing during the rest (REQ-AB-8)")
	f._tick_waves(1.1, rng)
	_check(f.wave == 2 and f.phase == SpaceField.Phase.WAVE
			and f.events.any(func(e: Dictionary) -> bool: return e.t == "wave_start"),
			"after the rest wave 2 starts (REQ-AB-8)")
	f.ships[1].alive = false
	f._tick_waves(30.1, rng)
	_check(f.scores[0] == 50 + 100 and f.scores[1] == 50, "the bonus is 50 times the wave, only for a ship that is still flying")
	# Issue #136: the asteroids that are left at the end of a wave fly off, and the screen is empty in the rest.
	f = _field([900.0, 1200.0])
	var left := f._make(2, 900.0, SpaceField.SHIP_Y - 40.0, rng)   # On top of the ship 0 when the wave ends.
	f.phase_time = SpaceField.WAVE_TIME - 0.01
	f.tick(0.02, rng, {0: 0.0, 1: 0.0})
	_check(f.phase == SpaceField.Phase.REST and left.leaving and f.ships[0].alive and f.ships[0].shield == false,
			"at the end of the wave the asteroids that are left stop being a danger: the ship on which one sits is not hit")
	f.beams.clear()
	f.tick(1.0, rng, {0: 0.0, 1: 0.0})
	_check(f.asteroids.is_empty() and f.phase == SpaceField.Phase.REST,
			"1 s into the rest the left asteroids are gone and the screen has no asteroid (REQ-AB-8, issue #136)")
	f = _field([900.0, 1200.0])
	var hit_by_beam := f._make(1, 900.0, 300.0, rng)
	hit_by_beam.leaving = true
	var beam := SpaceField.Beam.new()
	beam.x = 900.0
	beam.y = 300.0
	f.beams.append(beam)
	f._hit_asteroids()
	_check(hit_by_beam.hp == 2 and f.scores[0] == 0, "a beam passes through an asteroid that flies off: no points for it")
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
		g._tick_waves(0.0, rng)
		g._tick_waves(10.0, rng)
		rate_ok = rate_ok and g.asteroids.size() > 0
	_check(easy.asteroids.size() < hard.asteroids.size() and rate_ok,
			"Hard brings more asteroids than Easy in the same time (REQ-AB-20)")
	var no_tiers := true
	for level in ["easy", "medium", "hard"]:
		no_tiers = no_tiers and not SpaceField.LEVELS[level].has("tiers")
	_check(no_tiers, "no difficulty has medal tiers: a single player gets no medal (REQ-AB-14, REQ-AB-20)")


## True when `img` has a pixel of exactly `color`.
func _has_pixel(img: Image, color: Color) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).is_equal_approx(color):
				return true
	return false


## The pictures of Star Shield (REQ-AB-17).
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



## 22.3b, 3c, 3d, 4a, 5a, 5e, 6a, 6c: the speed of the ship, the rate of fire and the upgrades with numbers.
func _ship_speed_and_fire() -> void:
	print("ship speed and fire")
	var f := _field([SpaceField.EDGE])
	var s: SpaceField.Ship = f.ships[0]
	var t := 0.0
	while s.x < SpaceField.REF_AREA.x - SpaceField.EDGE and t < 20.0:
		f.steer(s, 0.71, 1.0 / 60.0)
		t += 1.0 / 60.0
	_check(t > 2.5 and t < 4.2, "at a tilt of 0.71 the ship needs %.2f s from the left stop to the right stop (2.5 to 4.2 s)" % t)
	var held := true
	for i in 120:
		f.steer(s, 0.71, 1.0 / 60.0)
		held = held and s.x == SpaceField.REF_AREA.x - SpaceField.EDGE
	_check(held and s.x - SpaceField.SHIP_R >= 0.0 and s.x + SpaceField.SHIP_R <= SpaceField.REF_AREA.x
			and SpaceField.EDGE >= SpaceField.SHIP_R and SpaceField.EDGE / 1920.0 > 0.02 and SpaceField.EDGE / 1920.0 < 0.04,
			"kept against the right stop for 2 s the ship stays there, fully on the screen, 60 px (3 %) from the side of the play area")
	var noise := _rng(11)
	var still := s.x
	for i in 600:   # 10 s of a phone that lies on a table: the readings wobble below the dead zone.
		f.steer(s, noise.randf_range(-0.039, 0.039), 1.0 / 60.0)
	_check(is_equal_approx(s.x, still), "10 s of noise below the dead zone does not move the ship")
	var one := _field([900.0])
	for i in 600:   # 10 s in steps of 1/60 s.
		one._fire(1.0 / 60.0)
	var shots := one.events.filter(func(e: Dictionary) -> bool: return e.t == "shot").size()
	_check(shots >= 22 and shots <= 28, "one ship fires %d times in 10 s on Medium (22 to 28)" % shots)
	var timed := _field([900.0])
	timed._tick_upgrades(SpaceField.UPGRADE_FIRST - 1.0, _rng(2))
	var none_before_9 := timed.upgrades.is_empty()
	timed._tick_upgrades(2.1, _rng(2))
	_check(none_before_9 and timed.upgrades.size() == 1, "the first upgrade falls between 9 s and 11 s of play (REQ-AB-10)")
	var f2 := _field([900.0])
	var weapon := SpaceField.Upgrade.new()
	weapon.kind = SpaceField.WEAPON
	for i in 3:
		f2._apply(f2.ships[0], weapon)
	f2._apply(f2.ships[0], weapon)
	_check(f2.scores[0] == 50 and f2.ships[0].lasers == 4, "the 5th weapon upgrade gives exactly 50 points")
	var f3 := _field([900.0])
	f3.ships[0].shield = true
	f3._make(2, 900.0, SpaceField.SHIP_Y - 40.0, _rng(3))
	f3._ship_contacts()
	_check(f3.asteroids.is_empty() and f3.ships[0].alive, "a large asteroid that hits the ring is gone with no pieces")
	var f4 := _field([900.0, 1500.0])
	f4._make(0, 900.0, SpaceField.SHIP_Y, _rng(4))
	f4._ship_contacts()
	var dead_x: float = f4.ships[0].x
	for i in 594:   # 9.9 s
		f4.tick(1.0 / 60.0, _rng(5), {0: 1.0, 1: 0.0})
		f4.asteroids.clear()
	_check(not f4.ships[0].alive and f4.ships[0].x == dead_x and f4.alive_count() == 1, "a ship that is out stays out for 9.9 s")
	var returns: Array = []
	for i in 12:   # up to 10.1 s
		f4.tick(1.0 / 60.0, _rng(5), {0: 0.0, 1: 0.0})
		for e in f4.events:
			if e.t == "ship_back":
				returns.append(e.slot)
		f4.asteroids.clear()
	_check(returns == [0], "the return is reported once, for the slot of the ship (REQ-AB-15)")
	_check(f4.ships[0].alive and f4.ships[0].shield and f4.ships[0].x == dead_x and f4.alive_count() == 2,
			"after 10 s the ship is back where it was, with a force field (REQ-AB-13)")
	var f5 := _field([900.0])
	f5._make(0, 900.0, SpaceField.SHIP_Y, _rng(4))
	f5._ship_contacts()
	for i in 1800:   # 30 s
		f5.tick(1.0 / 60.0, _rng(5), {0: 0.0})
		f5.asteroids.clear()
	_check(not f5.ships[0].alive and f5.all_lost(), "the last ship that is lost does not come back: the game is over (REQ-AB-14)")


## 22.7d, 7e: the waves get faster and fuller.
func _waves() -> void:
	print("waves")
	_check(1.0 / SpaceField.wave_speed(6) <= 0.75, "an asteroid of wave 6 needs at most 0.75 of the fall time of wave 1: %.2f"
			% (1.0 / SpaceField.wave_speed(6)))
	var counts := []
	for wave_no in [1, 6]:
		var f := _field([900.0])
		f.wave = wave_no
		var r := _rng(21)
		for i in 100:
			f._tick_waves(0.1, r)
		counts.append(f.asteroids.size())
	_check(counts[1] >= int(1.5 * counts[0]) and counts[0] >= 5,
			"wave 6 brings %d asteroids in 10 s, wave 1 brings %d (1.5 times or more)"
			% [counts[1], counts[0]])


## 22.4c, 5b, 12a, 12c, 12d: the pictures are made of a few known colors, in sizes that can be seen.
func _pictures() -> void:
	print("pictures")
	var sm := BlastLook.asteroid_image(0, 0, SpaceField.SIZES[0].radius)
	var me := BlastLook.asteroid_image(1, 0, SpaceField.SIZES[1].radius)
	var lg := BlastLook.asteroid_image(2, 0, SpaceField.SIZES[2].radius)
	_check(float(lg.get_width()) / float(sm.get_width()) > 2.0 and me.get_width() > sm.get_width()
			and me.get_width() < lg.get_width()
			and sm.get_width() == 2 * 8 + 1 + 2 and me.get_width() == 2 * 12 + 1 + 2 and lg.get_width() == 2 * 19 + 1 + 2,
			"the large asteroid is more than 2 times as wide as the small one: %d, %d, %d px" % [sm.get_width(), me.get_width(),
					lg.get_width()])
	var rock_colors := [BlastLook.ROCK_LIGHT, BlastLook.ROCK_MID, BlastLook.ROCK_DARK, BlastLook.ROCK_CRATER, BlastLook.OUTLINE]
	var rocks_ok := true
	for size_no in 3:
		for look in 4:
			rocks_ok = rocks_ok and _only_colors(BlastLook.asteroid_image(size_no, look, SpaceField.SIZES[size_no].radius),
					rock_colors)
	_check(rocks_ok, "every asteroid picture has whole pixels in 5 colors only (no gradient)")
	var ships_ok := true
	for col in Protocol.PLAYER_COLORS:
		for frame in 2:
			ships_ok = ships_ok and _only_colors(BlastLook.ship_image(col, frame), [col, Color("fcfcfc"), Color("5ad2ff"),
					BlastLook.FLAME_A,
					BlastLook.FLAME_B, BlastLook.OUTLINE])
	_check(ships_ok, "every ship picture has whole pixels in the color of the player and 5 fixed colors")
	var h: int = BlastLook.ship_image(Protocol.PLAYER_COLORS[0], 0).get_height()
	_check(float(h) * BlastLook.PX / 1080.0 >= 0.044,
			"a ship is %.1f %% of the screen height (4.4 %% or more) at 1080p and at 720p"
			% (float(h) * BlastLook.PX / 10.8))
	var counts := {}
	for kind in ["shield", "weapon"]:
		var img := BlastLook.pickup_image(kind)
		var c := {"base": 0, "white": 0, "outline": 0, "other": 0}
		var base: Color = BlastLook.SHIELD_COLOR if kind == "shield" else BlastLook.WEAPON_COLOR
		for y in img.get_height():
			for x in img.get_width():
				var px := img.get_pixel(x, y)
				if px.a == 0.0:
					continue
				if px.is_equal_approx(base):
					c.base += 1
				elif px.is_equal_approx(Color.WHITE):
					c.white += 1
				elif px.is_equal_approx(BlastLook.OUTLINE):
					c.outline += 1
				else:
					c.other += 1
		counts[kind] = c
	_check(counts.shield.other == 0 and counts.weapon.other == 0 and counts.shield.base > counts.shield.white
			and counts.weapon.base > counts.weapon.white and counts.shield.white > 0 and counts.weapon.white > 0
			and counts.shield.outline > 0,
			"a shield pickup is mostly blue and a weapon pickup mostly orange, each with white and a black outline")


## True when every visible pixel of `img` has one of `colors` and no pixel is half transparent.
func _only_colors(img: Image, colors: Array) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a != 0.0 and (px.a != 1.0 or not colors.any(func(c: Color) -> bool: return c.is_equal_approx(px))):
				return false
	return true
