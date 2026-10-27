extends RefCounted
## The rules of Star Shield (REQ-AB-*): the ships, their beams, the asteroids, the upgrades and the waves. Pure logic: it
## draws nothing and uses no nodes, so the rules can be tested without a screen. Positions are in px of the play area at 1920x1080
## (`REF_AREA`); y grows downward and the ships are at the bottom.

const REF_AREA := Vector2(1800.0, 870.0)
const SHIP_Y := 730.0
const SHIP_R := 36.0           # The hit circle of a ship.
const EDGE := 60.0             # A ship stays this far from the sides.
const SHIP_SPEED := 760.0      # px/s at full tilt.
const SHIP_SMOOTH := 9.0       # How fast the speed follows the tilt (1/s).
const TILT_DEADZONE := 0.04
const FIRE_EVERY := 0.4        # A ship fires by itself.
const BEAM_SPEED := 1100.0
const BEAM_R := 10.0
const MAX_LASERS := 4
const LASER_GAP := 22.0        # Distance between two beams of one ship.
const WAVE_TIME := 30.0
const REST_TIME := 5.0
const GRACE_TIME := 3.0        # After a force field took a hit the ship is safe for this many seconds (issue #137).
const FLY_OFF_SPEED := 1500.0  # The asteroids that are left at the end of a wave fly off the screen at this speed (issue #136).
const OUT_TIME := 10.0         # A ship that is out comes back after this many seconds (REQ-AB-13).
const WAVE_BONUS := 50         # Points for each living ship at the end of wave n: WAVE_BONUS * n.
const UPGRADE_FIRST := 10.0    # The first upgrade falls after this many seconds of play, then after UPGRADE_MIN to UPGRADE_MAX.
const UPGRADE_MIN := 12.0
const UPGRADE_MAX := 20.0
const UPGRADE_SPEED := 130.0
const UPGRADE_R := 30.0
const UPGRADE_MAX_ON_SCREEN := 2
const UPGRADE_SPARE := 50      # Points for an upgrade that the ship cannot use (all lasers, or a force field already).
const BASE_SPEED := 120.0      # Fall speed of a medium asteroid in wave 1 at Medium.
const SPEED_PER_WAVE := 0.10   # Each wave is 10 % faster ...
const SPAWN_BASE := 1.5        # ... and has more asteroids: the time between two asteroids in wave 1 (s) ...
const SPAWN_PER_WAVE := 0.2    # ... shrinks by 1 / (1 + 0.2 * (wave - 1)) ...
const SPAWN_MIN := 0.35
const SPAWN_PER_PLAYER := 0.3  # ... and by 1 / (1 + 0.3 * (living ships - 1)).
const SPLIT_SPEED := 70.0      # Sideways speed of the two pieces of a broken asteroid.

## The sizes of an asteroid. `split` is the size of its two pieces, or -1. The speed is a factor on the fall speed.
const SIZES := [
	{"radius": 30.0, "hp": 1, "points": 10, "speed": 1.25, "split": -1},
	{"radius": 48.0, "hp": 2, "points": 20, "speed": 1.0, "split": 0},
	{"radius": 74.0, "hp": 4, "points": 40, "speed": 0.75, "split": 1},
]
const SHIELD := "shield"
const WEAPON := "weapon"
## Difficulty (REQ-AB-20): the speed and the number of asteroids, as factors on Medium. There are no medal tiers (REQ-AB-20).
const LEVELS := {
	"easy": {"speed": 0.8, "spawn": 0.8},
	"medium": {"speed": 1.0, "spawn": 1.0},
	"hard": {"speed": 1.25, "spawn": 1.3},
}

enum Phase { WAVE, REST }


class Ship:
	var slot := 0
	var x := 0.0
	var vx := 0.0
	var lasers := 1
	var shield := false
	var alive := true
	var out_time := 0.0    # Seconds since the ship was lost.
	var grace := 0.0       # Seconds left in which asteroids pass through the ship. It blinks and still shoots.
	var fire_left := 0.0


class Asteroid:
	var size := 0
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var radius := 0.0
	var hp := 1
	var age := 0.0         # For the spin of the picture.
	var look := 0          # Which picture of its size it has.
	var leaving := false   # The wave is over: it flies off, and beams and ships pass through it.


class Beam:
	var x := 0.0
	var y := 0.0
	var owner := 0


class Upgrade:
	var kind := ""
	var x := 0.0
	var y := 0.0


var ships := {}            # slot -> Ship
var asteroids: Array[Asteroid] = []
var beams: Array[Beam] = []
var upgrades: Array[Upgrade] = []
var scores := {}           # slot -> points
var wave := 1
var phase := Phase.WAVE
var phase_time := 0.0      # Seconds since the phase began.
var events: Array[Dictionary] = []   # What happened in the last tick: `{t, ...}`, for sounds and effects. Cleared by every tick.

var _speed := 1.0
var _spawn := 1.0
var _spawn_timer := 0.0
var _upgrade_timer := UPGRADE_FIRST


## Sets the difficulty (a key of `LEVELS`; an unknown one gives Medium).
func setup(difficulty: String) -> void:
	var level: Dictionary = LEVELS.get(difficulty, LEVELS.medium)
	_speed = float(level.speed)
	_spawn = float(level.spawn)


func add_ship(slot: int, x: float) -> void:
	var s := Ship.new()
	s.slot = slot
	s.x = x
	ships[slot] = s
	scores[slot] = 0


func remove_ship(slot: int) -> void:
	ships.erase(slot)
	scores.erase(slot)
	beams = beams.filter(func(b: Beam) -> bool: return b.owner != slot)


func alive_count() -> int:
	var n := 0
	for s in ships.values():
		if s.alive:
			n += 1
	return n


## True when every ship is gone: the game is over (REQ-AB-14). False without any ship.
func all_lost() -> bool:
	return not ships.is_empty() and alive_count() == 0


## The speed factor of wave `n` (REQ-AB-9): 10 % more for each wave.
static func wave_speed(n: int) -> float:
	return 1.0 + SPEED_PER_WAVE * float(n - 1)


## The time between two asteroids in wave `n` with `ships_alive` living ships at the factor `spawn` (REQ-AB-9).
static func spawn_every(n: int, ships_alive: int, spawn := 1.0) -> float:
	var every := SPAWN_BASE / (1.0 + SPAWN_PER_WAVE * float(n - 1)) / (1.0 + SPAWN_PER_PLAYER * float(maxi(ships_alive, 1) - 1))
	return maxf(every / spawn, SPAWN_MIN)


## The chance weights of the three sizes in wave `n`: [small, medium, large]. Big asteroids come more often in later waves.
static func size_weights(n: int) -> Array[int]:
	var large := mini(20 + 3 * (n - 1), 45)
	var small := maxi(40 - 3 * (n - 1), 15)
	return [small, 100 - large - small, large]


## The x of the beams of a ship with `n` lasers, relative to the ship (REQ-AB-11).
static func laser_offsets(n: int) -> Array[float]:
	var out: Array[float] = []
	for i in n:
		out.append((float(i) - float(n - 1) * 0.5) * LASER_GAP)
	return out


## The seconds left of the phase now.
func phase_left() -> float:
	return (WAVE_TIME if phase == Phase.WAVE else REST_TIME) - phase_time


## Moves everything by `dt` seconds. `tilts` is slot -> the tilt of the phone to the right, -1 to 1 (REQ-AB-2). A ship steers
## in every phase; the rest runs when `running` is true (the countdown steers only).
func tick(dt: float, rng: RandomNumberGenerator, tilts: Dictionary, running := true) -> void:
	events.clear()
	for s in ships.values():
		if s.alive:
			steer(s, float(tilts.get(s.slot, 0.0)), dt)
	if not running:
		return
	for s in ships.values():
		s.grace = maxf(0.0, s.grace - dt)
	_tick_returns(dt)
	_tick_waves(dt, rng)
	_fire(dt)
	for b in beams:
		b.y -= BEAM_SPEED * dt
	beams = beams.filter(func(b: Beam) -> bool: return b.y > -BEAM_R * 2.0)
	_move_asteroids(dt)
	_hit_asteroids()
	_tick_upgrades(dt, rng)
	_ship_contacts()


## A ship that is out comes back after OUT_TIME with a force field, as long as another ship is flying (REQ-AB-13). When the
## last ship is lost the game is over and nothing comes back.
func _tick_returns(dt: float) -> void:
	if alive_count() == 0:
		return
	for s in ships.values():
		if s.alive:
			continue
		s.out_time += dt
		if s.out_time >= OUT_TIME:
			s.alive = true
			s.shield = true
			events.append({"t": "ship_back", "slot": s.slot, "x": s.x, "y": SHIP_Y})


## Moves one ship by its tilt (REQ-AB-2): the speed follows the tilt smoothly, and the ship stays on the screen.
func steer(s: Ship, tilt_x: float, dt: float) -> void:
	var target := 0.0 if absf(tilt_x) < TILT_DEADZONE else clampf(tilt_x, -1.0, 1.0) * SHIP_SPEED
	s.vx = lerpf(s.vx, target, minf(SHIP_SMOOTH * dt, 1.0))
	s.x = clampf(s.x + s.vx * dt, EDGE, REF_AREA.x - EDGE)


func _tick_waves(dt: float, rng: RandomNumberGenerator) -> void:
	phase_time += dt
	if phase == Phase.WAVE:
		_spawn_timer += dt
		var every := spawn_every(wave, alive_count(), _spawn)
		while _spawn_timer >= every:
			_spawn_timer -= every
			spawn(rng)
		if phase_time >= WAVE_TIME:   # REQ-AB-8: after 30 s the wave is over and the players rest.
			phase = Phase.REST
			phase_time = 0.0
			for s in ships.values():
				if s.alive:
					scores[s.slot] += WAVE_BONUS * wave
			for a in asteroids:
				a.leaving = true   # REQ-AB-8: the screen is empty in the rest.
			events.append({"t": "wave_end", "wave": wave})
	elif phase_time >= REST_TIME:
		phase = Phase.WAVE
		phase_time = 0.0
		wave += 1
		_spawn_timer = 0.0
		events.append({"t": "wave_start", "wave": wave})


## Adds one asteroid at the top, at a random place (REQ-AB-6, 9).
func spawn(rng: RandomNumberGenerator) -> Asteroid:
	var w := size_weights(wave)
	var roll := rng.randi_range(0, 99)
	var size := 0
	for i in w.size():
		roll -= w[i]
		if roll < 0:
			size = i
			break
	var info: Dictionary = SIZES[size]
	var a := _make(size, rng.randf_range(float(info.radius), REF_AREA.x - float(info.radius)), -float(info.radius), rng)
	a.vx = rng.randf_range(-40.0, 40.0) * wave_speed(wave) * _speed
	return a


func _make(size: int, x: float, y: float, rng: RandomNumberGenerator) -> Asteroid:
	var info: Dictionary = SIZES[size]
	var a := Asteroid.new()
	a.size = size
	a.x = x
	a.y = y
	a.radius = info.radius
	a.hp = info.hp
	a.vy = BASE_SPEED * float(info.speed) * wave_speed(wave) * _speed
	a.look = rng.randi_range(0, 3)
	asteroids.append(a)
	return a


## Every living ship fires by itself, one beam for each laser (REQ-AB-4, 11).
func _fire(dt: float) -> void:
	for s in ships.values():
		if not s.alive:
			continue
		s.fire_left -= dt
		if s.fire_left > 0.0:
			continue
		s.fire_left = FIRE_EVERY if s.fire_left < -FIRE_EVERY else s.fire_left + FIRE_EVERY
		for dx in laser_offsets(s.lasers):
			var b := Beam.new()
			b.x = s.x + dx
			b.y = SHIP_Y - SHIP_R
			b.owner = s.slot
			beams.append(b)
		events.append({"t": "shot", "slot": s.slot})


func _move_asteroids(dt: float) -> void:
	for a in asteroids:
		a.age += dt
		if a.leaving:
			a.vy = maxf(a.vy, FLY_OFF_SPEED)
		a.x += a.vx * dt
		a.y += a.vy * dt
		if a.x < a.radius and a.vx < 0.0 or a.x > REF_AREA.x - a.radius and a.vx > 0.0:
			a.vx = -a.vx
	asteroids = asteroids.filter(func(a: Asteroid) -> bool: return a.y < REF_AREA.y + a.radius + 4.0)


## A beam that touches an asteroid does 1 damage and is gone. An asteroid with no life left breaks (REQ-AB-5, 7).
func _hit_asteroids() -> void:
	var spent: Array[Beam] = []
	for b in beams:
		for a in asteroids:
			if a.hp > 0 and not a.leaving and Vector2(b.x - a.x, b.y - a.y).length() <= a.radius + BEAM_R:
				a.hp -= 1
				spent.append(b)
				if a.hp <= 0:
					_break(a, b.owner)
				break
	if not spent.is_empty():
		beams = beams.filter(func(b: Beam) -> bool: return not spent.has(b))
		asteroids = asteroids.filter(func(a: Asteroid) -> bool: return a.hp > 0)


## `a` is destroyed by the ship `owner`: the points go to it and a big asteroid leaves two smaller pieces (REQ-AB-7).
func _break(a: Asteroid, owner: int) -> void:
	var info: Dictionary = SIZES[a.size]
	if scores.has(owner):
		scores[owner] += int(info.points)
	events.append({"t": "kill", "slot": owner, "size": a.size, "x": a.x, "y": a.y, "points": int(info.points)})
	var piece := int(info.split)
	if piece < 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a.x * 31.0 + a.y * 17.0) + a.size   # The same asteroid in the same place gives the same pieces.
	for dir in [-1, 1]:
		var p := _make(piece, a.x + dir * float(SIZES[piece].radius) * 0.6, a.y, rng)
		p.vx = dir * SPLIT_SPEED * _speed
		p.vy = maxf(p.vy, a.vy * 0.9)


func _tick_upgrades(dt: float, rng: RandomNumberGenerator) -> void:
	_upgrade_timer -= dt
	if _upgrade_timer <= 0.0 and alive_count() > 0:
		if upgrades.size() < UPGRADE_MAX_ON_SCREEN:
			var u := Upgrade.new()
			u.kind = SHIELD if rng.randi_range(0, 1) == 0 else WEAPON
			u.x = rng.randf_range(EDGE, REF_AREA.x - EDGE)
			u.y = -UPGRADE_R
			upgrades.append(u)
			events.append({"t": "upgrade_drop", "kind": u.kind})
		_upgrade_timer = rng.randf_range(UPGRADE_MIN, UPGRADE_MAX)
	for u in upgrades:
		u.y += UPGRADE_SPEED * dt
	upgrades = upgrades.filter(func(u: Upgrade) -> bool: return u.y < REF_AREA.y + UPGRADE_R)
	var taken: Array[Upgrade] = []
	for u in upgrades:
		for s in ships.values():
			if s.alive and Vector2(u.x - s.x, u.y - SHIP_Y).length() <= UPGRADE_R + SHIP_R:
				_apply(s, u)
				taken.append(u)
				break
	if not taken.is_empty():
		upgrades = upgrades.filter(func(u: Upgrade) -> bool: return not taken.has(u))


## The upgrade `u` is taken by `s` (REQ-AB-10, 11): a force field, or one more laser up to 4. One that cannot be used gives
## points.
func _apply(s: Ship, u: Upgrade) -> void:
	var used := true
	if u.kind == SHIELD:
		used = not s.shield
		s.shield = true
	else:
		used = s.lasers < MAX_LASERS
		s.lasers = mini(s.lasers + 1, MAX_LASERS)
	if not used:
		scores[s.slot] += UPGRADE_SPARE
	events.append({"t": "upgrade_taken", "slot": s.slot, "kind": u.kind, "used": used})


## An asteroid that touches a ship (REQ-AB-12, 13): a force field takes the hit and goes away, and the asteroid breaks into dust
## (no points, no pieces). Without a force field the ship is lost. A force field that popped in this tick also takes the other
## asteroids that touch the ship in the same tick (the two pieces of a large asteroid cost one force field, not the ship).
func _ship_contacts() -> void:
	var gone: Array[Asteroid] = []
	var popped := {}
	for a in asteroids:
		if a.leaving:
			continue
		for s in ships.values():
			if not s.alive or (s.grace > 0.0 and not popped.has(s.slot)):
				continue
			if Vector2(a.x - s.x, a.y - SHIP_Y).length() <= a.radius + SHIP_R * 0.8:
				if s.shield or popped.has(s.slot):
					if s.shield:
						events.append({"t": "shield_pop", "slot": s.slot, "x": a.x, "y": a.y})
					s.shield = false
					s.grace = GRACE_TIME
					popped[s.slot] = true
					gone.append(a)
				else:
					s.alive = false
					s.out_time = 0.0
					s.shield = false
					events.append({"t": "ship_lost", "slot": s.slot, "x": s.x, "y": SHIP_Y})
				break
	if not gone.is_empty():
		asteroids = asteroids.filter(func(a: Asteroid) -> bool: return not gone.has(a))
