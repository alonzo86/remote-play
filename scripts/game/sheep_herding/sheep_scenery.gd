extends RefCounted
## The things that stand around in the field of Sheep Herding (REQ-SH-16): a pond, trees, pines, hay stacks, bales, rocks and
## bushes, scattered over the whole field and not only at the edges. Pure logic. The same seed gives the same field, so Restart
## keeps it. The circles of the tall things are `blockers`: they only keep a sheep or a dog from starting on a thing, and
## nothing is blocked by them (REQ-SH-4); bushes and flowers have none.
## The places that must stay open (the dogs at the start, the sheep at the start, the way to the gate
## and the pen) are `keep_free`.

const SheepLook = preload("res://scripts/game/sheep_herding/sheep_look.gd")

const POND := "pond"
const TREE := "tree"
const PINE := "pine"
const HAY := "hay"
const BALES := "bales"
const ROCK := "rock"
const BUSH := "bush"

## kind -> {count, r (the blocker radius, 0 for a thing that is only drawn), gap (the least distance to another thing)}.
const KINDS := {
	POND: {"count": 1, "r": 0.0, "gap": 260.0},
	TREE: {"count": 7, "r": 18.0, "gap": 190.0},
	PINE: {"count": 4, "r": 16.0, "gap": 190.0},
	HAY: {"count": 3, "r": 38.0, "gap": 200.0},
	BALES: {"count": 2, "r": 40.0, "gap": 200.0},
	ROCK: {"count": 3, "r": 26.0, "gap": 170.0},
	BUSH: {"count": 6, "r": 0.0, "gap": 110.0},
}
const POND_SIZE := Vector2(240.0, 128.0)   # The pond is an ellipse. Its blockers are circles along its long side.
const FLOWERS := 28
const EDGE := 8.0                          # A picture stays this far inside the field (REQ-SH-16).
const POND_OUTLINE := 4.0                  # The black line around the pond (one world pixel).
const FLOWER_SIZE := Vector2(8.0, 4.0)

static var _sizes: Dictionary = {}         # kind -> the size of its picture on the screen, cached.

var items: Array[Dictionary] = []          # {kind, pos}: `pos` is the foot (the middle of the pond).
var blockers: Array[Dictionary] = []       # {pos, r}
var flowers: Array[Dictionary] = []        # {pos, color: int}: the index of a flower color, drawn by `SheepLook`.


## Makes the field. `field` is the grass, `keep_free` the rectangles that stay empty of blockers, `keep_clear` the rectangles that
## stay empty of everything (the pen and the barn).
func generate(field: Rect2, keep_free: Array[Rect2], keep_clear: Array[Rect2], rng: RandomNumberGenerator) -> void:
	items.clear()
	blockers.clear()
	flowers.clear()
	for kind in KINDS:   # The big things first, so that they find room.
		var spec: Dictionary = KINDS[kind]
		for n in int(spec.count):
			var p: Variant = _place(kind, spec, field, keep_free, keep_clear, rng)
			if p == null:
				continue
			items.append({"kind": kind, "pos": p})
			blockers.append_array(_blockers_of(kind, p, spec))
	for i in FLOWERS:
		var p := Vector2(rng.randf_range(field.position.x + EDGE, field.end.x - EDGE - FLOWER_SIZE.x),
				rng.randf_range(field.position.y + EDGE, field.end.y - EDGE - FLOWER_SIZE.y))
		if not _touches_any(Rect2(p, FLOWER_SIZE), keep_clear):
			flowers.append({"pos": p, "color": rng.randi_range(0, 2)})


func _place(kind: String, spec: Dictionary, field: Rect2, keep_free: Array[Rect2], keep_clear: Array[Rect2],
		rng: RandomNumberGenerator) -> Variant:
	var pic := picture_size(kind)
	var x_lo := field.position.x + EDGE + pic.x * 0.5
	var x_hi := field.end.x - EDGE - pic.x * 0.5
	var y_lo := field.position.y + EDGE + (pic.y * 0.5 if kind == POND else pic.y)
	var y_hi := field.end.y - EDGE - (pic.y * 0.5 if kind == POND else 0.0)
	if x_hi < x_lo or y_hi < y_lo:
		return null   # The picture does not fit in the field: the thing is left out.
	for i in 600:
		var p := Vector2(rng.randf_range(x_lo, x_hi), rng.randf_range(y_lo, y_hi))
		if _touches_any(picture_rect(kind, p), keep_clear) or _blocks_free_place(kind, p, spec, keep_free):
			continue
		var squeeze := 1.0 if i < 300 else (0.75 if i < 450 else 0.5)   # A crowded field lets the things stand closer.
		var apart := true
		for it in items:
			var gap := (maxf(float(spec.gap), float(KINDS[it.kind].gap)) * 0.5 + 40.0) * squeeze
			if p.distance_to(it.pos) < gap:
				apart = false
				break
		if apart:
			return p
	return null   # No room: the thing is left out.


## The size of the picture of a kind on the screen: the pond with its black line, the others from their image (REQ-SH-16).
static func picture_size(kind: String) -> Vector2:
	if kind == POND:
		return POND_SIZE + Vector2.ONE * 2.0 * POND_OUTLINE
	if not _sizes.has(kind):
		_sizes[kind] = Vector2(SheepLook.image(kind).get_size()) * SheepLook.WORLD_PIXEL
	return _sizes[kind]


## The rectangle that the whole picture of a thing covers when it is at `pos`: the pond is centered on `pos`, the other things
## stand with the middle of the bottom edge (the foot) on `pos`.
static func picture_rect(kind: String, pos: Vector2) -> Rect2:
	var sz := picture_size(kind)
	if kind == POND:
		return Rect2(pos - sz * 0.5, sz)
	return Rect2(pos - Vector2(sz.x * 0.5, sz.y), sz)


## True when a thing of this kind at `p` would block (with any of its blockers) a place that must stay open.
func _blocks_free_place(kind: String, p: Vector2, spec: Dictionary, keep_free: Array[Rect2]) -> bool:
	for b in _blockers_of(kind, p, spec):
		for r in keep_free:
			if r.grow(float(b.r)).has_point(b.pos):
				return true
	return false


## The circles that a thing of this kind at `p` blocks with: three along the pond, one for a tree, a pine, a hay stack, bales or a
## rock, none for a bush.
func _blockers_of(kind: String, p: Vector2, spec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind == POND:
		for dx in [-72.0, 0.0, 72.0]:
			out.append({"pos": p + Vector2(dx, 0.0), "r": 58.0})
	elif float(spec.r) > 0.0:
		out.append({"pos": p - Vector2(0.0, float(spec.r) * 0.5), "r": float(spec.r)})
	return out


static func _touches_any(picture: Rect2, rects: Array[Rect2]) -> bool:
	for r in rects:
		if r.intersects(picture):
			return true
	return false
