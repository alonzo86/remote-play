extends RefCounted
## The rules of Freeze Dance: the songs, the check of the motion of a phone, the points, the players that move and the
## light tiles of the floor (REQ-FD-1 to 8, 11, 12). Pure logic: it draws nothing and uses no nodes, so the rules can be tested
## without a screen. The game feeds it the energy of every phone each tick and reads the events that come back.

enum Phase { MUSIC, FREEZE, REST, DONE }

const SONGS := 6
const POINTS := 10
const REST := 2.0
const WIGGLE_MIN := 2.0       # Smoothed energy of a phone that dances (turn in rad/s plus a part of the shake in m/s2).
const DANCE_NEED := 1.5       # Seconds of dancing in the music that make a dance (REQ-FD-5).
const SMOOTH := 0.12          # Time constant (s) of the smoothing of the energy.
const ACCEL_WEIGHT := 0.25
const GRAVITY_TAU := 0.25     # Time constant (s) of the slow part of the acceleration that is taken away as gravity.
const ROWS := 8               # The tiles of the floor.
const COLS := 16
const FREEZE_CAP := 2.0       # At the stop the smoothed energy is cut to this many times `still_limit`.
const LIT_SHARE := 0.35
const LIGHT_STEP := 0.5       # Seconds between two sets of lit tiles.
## First guesses (docs/games/freeze_dance.md, Test 31). Medium is the base.
const LEVELS := {
	"easy": {"music_min": 7.0, "music_max": 10.0, "freeze": 2.0, "grace": 1.2, "still_limit": 1.6},
	"medium": {"music_min": 5.0, "music_max": 10.0, "freeze": 3.0, "grace": 0.9, "still_limit": 1.1},
	"hard": {"music_min": 4.0, "music_max": 8.0, "freeze": 4.0, "grace": 0.8, "still_limit": 0.8},
}

class Dancer:
	var energy := 0.0          # Smoothed.
	var dance_time := 0.0      # Seconds of dancing in the music of this song.
	var moved := false         # Moved in the freeze of this song: out of the floor until the next song (REQ-FD-8).

	## True when the player is on the floor and is checked.
	func plays() -> bool:
		return not moved

var level := LEVELS.medium
var phase: Phase = Phase.MUSIC
var song := 1                    # 1 to SONGS.
var phase_time := 0.0            # Seconds in the phase.
var dancers := {}                # slot -> Dancer
var music_lengths: Array[float] = []
var _rng := RandomNumberGenerator.new()


func setup(difficulty: String, slots: Array, rng: RandomNumberGenerator) -> void:
	level = LEVELS.get(difficulty, LEVELS.medium)
	_rng = rng
	dancers.clear()
	for s in slots:
		dancers[s] = Dancer.new()
	music_lengths.clear()
	for i in SONGS:   # Drawn at once, so that "BACK IN" can tell the time of a song that comes later.
		music_lengths.append(snappedf(_rng.randf_range(level.music_min, level.music_max), 0.1))
	phase = Phase.MUSIC
	song = 1
	phase_time = 0.0
	_begin_song()


func remove(slot: int) -> void:
	dancers.erase(slot)


## The energy of one phone from its raw readings (REQ-FD-4). The shake is the acceleration minus its slow part (a low-pass of
## 0.25 s), so no estimate of the direction of gravity is needed and a phone held at any angle, or turned a moment ago, reads 0
## when it is still.
class Meter:
	var _slow := Vector3.ZERO
	var _started := false

	func update(gyro: Vector3, accel: Vector3, delta: float) -> float:
		if not _started:
			_slow = accel
			_started = true
		_slow = _slow.lerp(accel, 1.0 - exp(-delta / GRAVITY_TAU))
		return gyro.length() + ACCEL_WEIGHT * (accel - _slow).length()


func music_length() -> float:
	return music_lengths[song - 1]


## Seconds left in the phase.
func phase_left() -> float:
	match phase:
		Phase.MUSIC:
			return maxf(music_length() - phase_time, 0.0)
		Phase.FREEZE:
			return maxf(float(level.freeze) - phase_time, 0.0)
		Phase.REST:
			return maxf(REST - phase_time, 0.0)
	return 0.0


## True when the phase of the freeze is past the grace time: a move counts now.
func is_checking() -> bool:
	return phase == Phase.FREEZE and phase_time >= float(level.grace)


## True when the player is out of the floor now: has moved in the freeze of this song (REQ-FD-8).
func is_out(slot: int) -> bool:
	var d: Dancer = dancers.get(slot)
	return d != null and not d.plays()


## The seconds until the song where the player plays again, or -1 when the player is not out or the song is after the last one
## (REQ-FD-8).
func back_in(slot: int) -> float:
	var d: Dancer = dancers.get(slot)
	if d == null or d.plays():
		return -1.0
	var left := 0.0
	var returns := song + 1   # The song where the player plays again.
	match phase:
		Phase.MUSIC:
			left = phase_left() + float(level.freeze) + REST
		Phase.FREEZE:
			left = phase_left() + REST
		_:
			left = phase_left()
	return left if returns <= SONGS else -1.0


## One step. `energies` is slot -> the raw energy of the phone (`energy_of()`). Returns the events of the step, in order:
## {"type": "freeze"}, {"type": "moved", "slot"}, {"type": "held", "slot", "points"}, {"type": "song", "song"},
## {"type": "done"}.
func tick(delta: float, energies: Dictionary) -> Array:
	var events := []
	if phase == Phase.DONE:
		return events
	var k := 1.0 - exp(-delta / SMOOTH)
	for s in dancers:
		var d: Dancer = dancers[s]
		d.energy = lerpf(d.energy, float(energies.get(s, 0.0)), k)
	phase_time += delta
	match phase:
		Phase.MUSIC:
			for s in dancers:
				var d: Dancer = dancers[s]
				if d.plays() and d.energy >= WIGGLE_MIN:
					d.dance_time += delta
			if phase_time >= music_length():
				phase = Phase.FREEZE
				phase_time = 0.0
				for s in dancers:   # A hard wiggle must not still read as a move when the grace ends (REQ-FD-6).
					var d: Dancer = dancers[s]
					d.energy = minf(d.energy, FREEZE_CAP * float(level.still_limit))
				events.append({"type": "freeze"})
		Phase.FREEZE:
			if is_checking():
				for s in dancers:
					var d: Dancer = dancers[s]
					if d.plays() and d.energy > float(level.still_limit):
						d.moved = true
						events.append({"type": "moved", "slot": s})
			if phase_time >= float(level.freeze):
				for s in dancers:
					var d: Dancer = dancers[s]
					if d.plays():
						events.append({"type": "held", "slot": s, "points": POINTS if d.dance_time >= DANCE_NEED else 0})
				phase = Phase.REST
				phase_time = 0.0
		Phase.REST:
			if phase_time >= REST:
				if song >= SONGS:
					phase = Phase.DONE
					events.append({"type": "done"})
				else:
					song += 1
					phase = Phase.MUSIC
					phase_time = 0.0
					_begin_song()
					events.append({"type": "song", "song": song})
	return events


## The start of a song: every player is back on the floor with no dance.
func _begin_song() -> void:
	for s in dancers:
		var d: Dancer = dancers[s]
		d.moved = false
		d.dance_time = 0.0


## The set of lit floor tiles of a step of the lights, as `Vector2i(row, col)` in a Dictionary (used as a set). Each tile is lit
## with the probability `LIT_SHARE`, never a tile that shares a side with a lit one, in a random order that comes from `step`
## only, so a test and a replay see the same floor. A quarter of the floor that got no tile gets one (REQ-FD-12).
static func lit_tiles(step: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (step + 1) + 13
	var cells: Array[Vector2i] = []
	for r in ROWS:
		for c in COLS:
			cells.append(Vector2i(r, c))
	for i in range(cells.size() - 1, 0, -1):   # Fisher-Yates with the seeded generator.
		var j := rng.randi_range(0, i)
		var t := cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var lit := {}
	for cell in cells:
		if rng.randf() < LIT_SHARE and _free_around(lit, cell):
			lit[cell] = true
	for quarter in 4:
		var r0 := (quarter / 2) * (ROWS / 2)
		var c0 := (quarter % 2) * (COLS / 2)
		var has := false
		for r in range(r0, r0 + ROWS / 2):
			for c in range(c0, c0 + COLS / 2):
				has = has or lit.has(Vector2i(r, c))
		if not has:
			for cell in cells:
				if cell.x >= r0 and cell.x < r0 + ROWS / 2 and cell.y >= c0 and cell.y < c0 + COLS / 2 and _free_around(lit, cell):
					lit[cell] = true
					break
	return lit


static func _free_around(lit: Dictionary, cell: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if lit.has(cell + d):
			return false
	return true
