extends RefCounted
## The bonus pots of Paint Grab (REQ-PG-23): now and then a pot lands on a tile. The first blob that rolls over it paints a whole
## patch for its player: the gold pot a 3 x 3 patch around the
## tile, the rainbow roller the whole row. One pot is on the floor at a
## time. Pure logic: it draws nothing and uses no nodes.

const GOLD := "gold"
const ROLLER := "roller"
const WEIGHTS := {GOLD: 60, ROLLER: 40}
const FIRST := 8.0         # The first pot lands after this many seconds of play, then after GAP_MIN to GAP_MAX.
const GAP_MIN := 9.0
const GAP_MAX := 15.0
const LIFE := 9.0          # A pot that nobody takes goes away after this many seconds ...
const BLINK := 2.0         # ... and blinks in the last BLINK seconds.
const FAR := 3             # A pot lands at least this many tiles (in a straight line or on the diagonal) away from every blob.


class Pot:
	var kind := ""
	var cell := Vector2i.ZERO
	var age := 0.0

	func is_blinking() -> bool:
		return age > LIFE - BLINK


var pots: Array[Pot] = []
var _timer := FIRST


func reset() -> void:
	pots.clear()
	_timer = FIRST


## Moves the time. `blob_cells` are the tiles under the blobs, a pot
## does not land near them (REQ-PG-23). Returns the new pot or null.
func tick(dt: float, rng: RandomNumberGenerator, cols: int, rows: int, blob_cells: Array, allowed := Callable()) -> Pot:
	for i in range(pots.size() - 1, -1, -1):
		pots[i].age += dt
		if pots[i].age >= LIFE:
			pots.remove_at(i)
	if not pots.is_empty():
		return null
	_timer -= dt
	if _timer > 0.0:
		return null
	var pot := _land(rng, cols, rows, blob_cells, allowed)
	_timer = rng.randf_range(GAP_MIN, GAP_MAX) if pot != null else 1.0   # No free tile: try again in a second.
	return pot


func _land(rng: RandomNumberGenerator, cols: int, rows: int, blob_cells: Array, allowed: Callable) -> Pot:
	var free: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			var ok := not allowed.is_valid() or bool(allowed.call(Vector2i(x, y)))   # `allowed` limits the tiles (the picture).
			for b in blob_cells:
				if maxi(absi(b.x - x), absi(b.y - y)) < FAR:
					ok = false
					break
			if ok:
				free.append(Vector2i(x, y))
	if free.is_empty():
		return null
	var pot := Pot.new()
	pot.cell = free[rng.randi_range(0, free.size() - 1)]
	pot.kind = GOLD if rng.randi_range(0, 99) < int(WEIGHTS[GOLD]) else ROLLER
	pots.append(pot)
	return pot


## The pot on tile `c`, taken off the floor, or null.
func take_at(c: Vector2i) -> Pot:
	for p in pots:
		if p.cell == c:
			pots.erase(p)
			return p
	return null


## The tiles that a pot of `kind` on `cell` paints, inside a floor of `cols` x `rows` (REQ-PG-23).
static func patch(kind: String, cell: Vector2i, cols: int, rows: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if kind == ROLLER:
		for x in cols:
			out.append(Vector2i(x, cell.y))
		return out
	for y in range(maxi(cell.y - 1, 0), mini(cell.y + 2, rows)):
		for x in range(maxi(cell.x - 1, 0), mini(cell.x + 2, cols)):
			out.append(Vector2i(x, y))
	return out


## The smallest block of tiles that holds the patch of a pot (REQ-PG-23): the frame that the game draws around the tiles it will
## paint. A rectangle in tiles.
static func bounds(kind: String, cell: Vector2i, cols: int, rows: int) -> Rect2i:
	var tiles := patch(kind, cell, cols, rows)
	var lo := Vector2i(cols, rows)
	var hi := Vector2i.ZERO
	for c in tiles:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)
