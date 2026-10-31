extends RefCounted
## Maze generator (iterative depth-first search) with a few extra openings.
## Walls are stored as two boolean grids:
##   h[y][x]: wall on the top edge of cell (x, y). y goes 0..rows.
##   v[y][x]: wall on the left edge of cell (x, y). x goes 0..cols.

var cols := 0
var rows := 0
var h: Array = []
var v: Array = []


func generate(p_cols: int, p_rows: int, rng: RandomNumberGenerator, extra_openings := 0.08) -> void:
	cols = p_cols
	rows = p_rows
	h = []
	v = []
	for y in rows + 1:
		var r := []
		r.resize(cols)
		r.fill(true)
		h.append(r)
	for y in rows:
		var r := []
		r.resize(cols + 1)
		r.fill(true)
		v.append(r)
	var seen := {}
	var stack: Array[Vector2i] = [Vector2i.ZERO]
	seen[Vector2i.ZERO] = true
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < cols and n.y < rows and not seen.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: Vector2i = options[rng.randi() % options.size()]
		_open_between(cur, next)
		seen[next] = true
		stack.append(next)
	# Extra openings make loops, so the race has more than one route.
	var n_extra := int(cols * rows * extra_openings)
	for i in n_extra:
		var c := Vector2i(rng.randi() % cols, rng.randi() % rows)
		var d: Vector2i = [Vector2i(1, 0), Vector2i(0, 1)][rng.randi() % 2]
		var n := c + d
		if n.x < cols and n.y < rows:
			_open_between(c, n)


func _open_between(a: Vector2i, b: Vector2i) -> void:
	if a.x != b.x:
		v[a.y][maxi(a.x, b.x)] = false
	else:
		h[maxi(a.y, b.y)][a.x] = false


## True when a path exists from the first cell to the last cell. Only the tests call it: they prove that every maze can be solved.
func is_solvable() -> bool:
	var seen := {Vector2i.ZERO: true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == Vector2i(cols - 1, rows - 1):
			return true
		if c.x + 1 < cols and not v[c.y][c.x + 1]:
			_push(queue, seen, Vector2i(c.x + 1, c.y))
		if c.x > 0 and not v[c.y][c.x]:
			_push(queue, seen, Vector2i(c.x - 1, c.y))
		if c.y + 1 < rows and not h[c.y + 1][c.x]:
			_push(queue, seen, Vector2i(c.x, c.y + 1))
		if c.y > 0 and not h[c.y][c.x]:
			_push(queue, seen, Vector2i(c.x, c.y - 1))
	return false


func _push(queue: Array[Vector2i], seen: Dictionary, c: Vector2i) -> void:
	if not seen.has(c):
		seen[c] = true
		queue.append(c)


## Wall rectangles in maze pixel coordinates (origin at top-left of the maze).
func wall_rects(cell: float, thickness: float) -> Array[Rect2]:
	var r: Array[Rect2] = []
	var t := thickness * 0.5
	for y in rows + 1:
		for x in cols:
			if h[y][x]:
				r.append(Rect2(x * cell - t, y * cell - t, cell + thickness, thickness))
	for y in rows:
		for x in cols + 1:
			if v[y][x]:
				r.append(Rect2(x * cell - t, y * cell - t, thickness, cell + thickness))
	return r
