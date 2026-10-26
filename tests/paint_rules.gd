extends SceneTree
## The rules of Paint Grab, without a screen: the floor, the difficulty, the pictures under the floor and the bonus pots
## (REQ-PG-2, 4, 5, 20 to 23). Run: godot --headless --path . --script tests/paint_rules.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const PaintFloor = preload("res://scripts/game/paint_grab/paint_floor.gd")
const PaintPicture = preload("res://scripts/game/paint_grab/paint_picture.gd")
const PaintPots = preload("res://scripts/game/paint_grab/paint_pots.gd")
const PaintLook = preload("res://scripts/game/paint_grab/paint_look.gd")

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
	_paint_floor()
	_paint_levels()
	_paint_pictures()
	_paint_pots()
	_pot_pictures()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## The floor (REQ-PG-2, 4, 5, 21).
func _paint_floor() -> void:
	print("paint floor")
	var f := PaintFloor.new(4, 3, 100.0)
	_check(f.total() == 12 and f.size() == Vector2(400, 300) and f.count(0) == 0, "an empty floor of 4 x 3 tiles")
	_check(f.cell_at(Vector2(0, 0)) == Vector2i(0, 0) and f.cell_at(Vector2(399, 299)) == Vector2i(3, 2)
			and f.cell_at(Vector2(150, 250)) == Vector2i(1, 2), "a point gives its tile")
	_check(f.cell_at(Vector2(-1, 10)) == Vector2i(-1, -1) and f.cell_at(Vector2(400, 10)) == Vector2i(-1, -1),
			"a point outside the floor gives no tile")
	_check(f.paint(Vector2i(1, 1), 0) == PaintFloor.Result.NEW and f.owner_of(Vector2i(1, 1)) == 0 and f.count(0) == 1,
			"a free tile is painted")
	_check(f.paint(Vector2i(1, 1), 0) == PaintFloor.Result.SAME and f.count(0) == 1,
			"the same player painting again changes nothing")
	_check(f.paint(Vector2i(1, 1), 2) == PaintFloor.Result.TAKEN and f.owner_of(Vector2i(1, 1)) == 2
			and f.count(0) == 0 and f.count(2) == 1, "the tile of another player is taken, and the counts follow (REQ-PG-4)")
	f.paint(Vector2i(0, 0), 0)
	f.paint(Vector2i(2, 0), 0)
	f.paint(Vector2i(3, 0), 0)
	_check(f.percent(0) == 25 and f.percent(2) == 8 and f.percent(3) == 0,
			"the share of the floor in percent, rounded down (REQ-PG-21)")


## The difficulty of Paint Grab (REQ-PG-20, 21).
func _paint_levels() -> void:
	print("paint grab difficulty")
	var lv: Dictionary = load("res://scripts/game/paint_grab/paint_grab_game.gd").LEVELS
	_check(lv.easy.cols < lv.medium.cols and lv.medium.cols < lv.hard.cols and lv.easy.rows < lv.medium.rows
			and lv.medium.rows < lv.hard.rows, "the floor grows with the difficulty")
	_check(lv.easy.speed < lv.medium.speed and lv.medium.speed < lv.hard.speed and lv.medium.speed == 1.0,
			"the blobs are faster with the difficulty, Medium is the base")
	_check(lv.easy.cols == 12 and lv.easy.rows == 7 and lv.medium.cols == 16 and lv.medium.rows == 9 and lv.hard.cols == 20
			and lv.hard.rows == 11, "the floor is 12 x 7, 16 x 9 and 20 x 11 tiles on Easy, Medium and Hard (REQ-PG-20)")
	_check(lv.easy.speed == 0.8 and lv.medium.speed == 1.0 and lv.hard.speed == 1.25,
			"the blob speed is 0.8, 1.0 and 1.25 of Medium (REQ-PG-20)")
	_check(not lv.easy.has("tiers") and not lv.medium.has("tiers") and not lv.hard.has("tiers"),
			"no level has medal tiers (REQ-GM-73)")


## The pictures under the floor of Paint Grab (REQ-PG-22).
func _paint_pictures() -> void:
	print("paint pictures")
	_check(PaintPicture.count() == 30, "there are 30 pictures (REQ-PG-22)")
	var shapes_ok := true
	var names := {}
	var shapes_seen := {}
	for i in PaintPicture.count():
		var rows: Array = PaintPicture.SHAPES[i][1]
		shapes_ok = shapes_ok and rows.size() == PaintPicture.FULL_ROWS
		var body := 0
		var eyes := 0
		for r in rows:
			shapes_ok = shapes_ok and String(r).length() == PaintPicture.HALF_COLS and String(r).replace(".", "").replace("#",
					"").replace("o", "").replace("e", "") == ""
			body += String(r).count("#")
			eyes += String(r).count("e")
		shapes_ok = shapes_ok and body >= 10 and body <= 44   # A picture is neither a dot nor the whole floor.
		names[PaintPicture.name_of(i)] = true
		shapes_seen[str(rows)] = true
	_check(shapes_ok, "every picture has 9 rows of 6 known letters, 10 to 44 body tiles")
	_check(names.size() == 30 and shapes_seen.size() == 30, "the 30 pictures have different names and different shapes")
	var sym_ok := true
	var sizes_ok := true
	for i in PaintPicture.count():
		for dims in [Vector2i(12, 7), Vector2i(16, 9), Vector2i(20, 11)]:
			var k := PaintPicture.kinds_for(i, dims.x, dims.y)
			sizes_ok = sizes_ok and k.size() == dims.x * dims.y
			for y in dims.y:
				for x in dims.x:
					sym_ok = sym_ok and k[y * dims.x + x] == k[y * dims.x + (dims.x - 1 - x)]
	_check(sizes_ok and sym_ok, "every picture fits the floors of Easy, Medium and Hard and is symmetric on each (REQ-PG-22)")
	var plain := PaintPicture.kinds_for(0, 16, 9)
	var flipped := PaintPicture.kinds_for(0, 16, 9, true)
	var swapped := PaintPicture.kinds_for(0, 16, 9, false, true)
	var flip_ok := true
	var swap_ok := true
	for y in 9:
		for x in 16:
			flip_ok = flip_ok and flipped[y * 16 + x] == plain[(8 - y) * 16 + x]
			var a: int = plain[y * 16 + x]
			var b: int = swapped[y * 16 + x]
			swap_ok = swap_ok and b == (PaintPicture.ACCENT if a == PaintPicture.BODY else PaintPicture.BODY
					if a == PaintPicture.ACCENT else a)
	_check(flip_ok and swap_ok and plain != flipped and plain != swapped,
			"a picture can be turned upside down and body and accent can be swapped (REQ-PG-22)")
	var seen := {}
	for seed_value in 200:
		seen[PaintPicture.pick(_rng(seed_value))] = true
	_check(seen.size() >= 25 and PaintPicture.pick(_rng(5)) == PaintPicture.pick(_rng(5)),
			"a random round gets many different pictures, and the same seed gets the same one: %d seen" % seen.size())
	var col := Protocol.PLAYER_COLORS[0]
	var tones := [PaintLook.painted(PaintPicture.EMPTY, col), PaintLook.painted(PaintPicture.BODY, col),
			PaintLook.painted(PaintPicture.ACCENT, col), PaintLook.painted(PaintPicture.EYE, col)]
	_check(tones[1] == col and tones[0] != tones[1] and tones[2] != tones[1] and tones[3].s < tones[1].s - 0.3,
			"a painted tile keeps the shade of its part of the picture in the color of the player")
	var plain_body := PaintLook.ghost(PaintPicture.BODY, Color("3a1c97"))
	_check(plain_body != PaintLook.ghost(PaintPicture.EMPTY, Color("3a1c97"))
			and PaintLook.ghost(PaintPicture.EYE, Color("3a1c97")).v > plain_body.v,
			"a tile that nobody painted shows a faint ghost of the picture")


## The bonus pots of Paint Grab (REQ-PG-23).
func _paint_pots() -> void:
	print("paint pots")
	var gold := PaintPots.patch(PaintPots.GOLD, Vector2i(5, 4), 16, 9)
	var corner := PaintPots.patch(PaintPots.GOLD, Vector2i(0, 0), 16, 9)
	var row := PaintPots.patch(PaintPots.ROLLER, Vector2i(3, 6), 16, 9)
	var row_ok := row.size() == 16
	for c in row:
		row_ok = row_ok and c.y == 6
	_check(gold.size() == 9 and gold.has(Vector2i(4, 3)) and gold.has(Vector2i(6, 5)) and corner.size() == 4 and row_ok,
			"the gold pot paints 3 x 3 tiles (4 in a corner), the roller the whole row (REQ-PG-23)")
	var pots := PaintPots.new()
	var rng := _rng(3)
	_check(pots.tick(PaintPots.FIRST - 1.0, rng, 16, 9, []) == null and pots.pots.is_empty(), "no pot before the first 8 s")
	var first := pots.tick(1.5, rng, 16, 9, [])
	_check(first != null and pots.pots.size() == 1, "the first pot lands after 8 s")
	var exact := PaintPots.new()
	_check(exact.tick(PaintPots.FIRST - 0.1, _rng(4), 16, 9, []) == null and exact.tick(0.2, _rng(4), 16, 9, []) != null
			and PaintPots.FIRST == 8.0, "the first pot lands between 7.9 s and 8.1 s of play, not 1 s earlier or later")
	var gaps_ok := true
	var lo_gap := 1.0e9
	var hi_gap := 0.0
	for seed_value in 40:
		var gp := PaintPots.new()
		var gr := _rng(seed_value)
		gp.tick(PaintPots.FIRST, gr, 16, 9, [])
		gp.pots.clear()   # Taken at once.
		var waited := 0.0
		while gp.pots.is_empty() and waited < 30.0:
			gp.tick(0.1, gr, 16, 9, [])
			waited += 0.1
		lo_gap = minf(lo_gap, waited)
		hi_gap = maxf(hi_gap, waited)
		gaps_ok = gaps_ok and waited >= 8.9 and waited <= 15.1
	_check(gaps_ok and hi_gap - lo_gap > 2.0, "the next pot comes 9 to 15 s after the last one, and the wait varies: %.1f to %.1f s"
			% [lo_gap, hi_gap])
	var most := pots.pots.size()
	for i in 240:   # Two minutes in half seconds: pots land, wait and go away.
		pots.tick(0.5, rng, 16, 9, [])
		most = maxi(most, pots.pots.size())
	_check(most == 1, "only one pot is on the floor at a time, and more land later: most at once = %d" % most)
	var gone := PaintPots.new()
	var pot := gone.tick(PaintPots.FIRST, rng, 16, 9, [])
	pot.age = PaintPots.LIFE - PaintPots.BLINK + 0.1
	_check(pot.is_blinking(), "a pot blinks in its last 2 s")
	gone.tick(PaintPots.BLINK, rng, 16, 9, [])
	_check(gone.pots.is_empty(), "a pot that nobody takes goes away after 9 s")
	var bg := PaintPots.bounds(PaintPots.GOLD, Vector2i(5, 4), 16, 9)
	var bc := PaintPots.bounds(PaintPots.GOLD, Vector2i(0, 0), 16, 9)
	var br := PaintPots.bounds(PaintPots.ROLLER, Vector2i(3, 6), 16, 9)
	_check(bg == Rect2i(4, 3, 3, 3) and bc == Rect2i(0, 0, 2, 2) and br == Rect2i(0, 6, 16, 1),
			"the frame of a pot holds exactly the tiles it paints: 3 x 3, 2 x 2 in a corner, the whole row (REQ-PG-23)")
	var frame_ok := true
	for kind in [PaintPots.GOLD, PaintPots.ROLLER]:
		for cell in [Vector2i(0, 0), Vector2i(15, 8), Vector2i(7, 4), Vector2i(0, 8)]:
			var box := PaintPots.bounds(kind, cell, 16, 9)
			var tiles := PaintPots.patch(kind, cell, 16, 9)
			frame_ok = frame_ok and tiles.size() == box.size.x * box.size.y
			for t in tiles:
				frame_ok = frame_ok and box.has_point(t)
	_check(frame_ok, "the frame has as many tiles as the patch and holds every one, at the corners and the middle")
	var near_ok := true
	var kinds_seen := {}
	for seed_value in 60:
		var p := PaintPots.new()
		var landed := p.tick(PaintPots.FIRST, _rng(seed_value), 16, 9, [Vector2i(8, 4), Vector2i(2, 2)])
		kinds_seen[landed.kind] = true
		near_ok = near_ok and maxi(absi(landed.cell.x - 8), absi(landed.cell.y - 4)) >= PaintPots.FAR \
				and maxi(absi(landed.cell.x - 2), absi(landed.cell.y - 2)) >= PaintPots.FAR
	_check(near_ok, "a pot never lands near a blob (REQ-PG-23)")
	_check(kinds_seen.size() == 2, "both pots come, over many rounds")
	var taken := PaintPots.new()
	var landed2 := taken.tick(PaintPots.FIRST, _rng(9), 16, 9, [])
	var elsewhere := Vector2i((landed2.cell.x + 5) % 16, landed2.cell.y)
	_check(taken.take_at(elsewhere) == null and taken.pots.size() == 1 and taken.take_at(landed2.cell) == landed2
			and taken.pots.is_empty(),
			"a pot is taken only by a blob on its tile, and then it is gone")
	var again := taken.tick(0.5, _rng(9), 16, 9, [])
	_check(again == null, "the next pot comes after 9 to 15 s, not at once")
	var crowded := PaintPots.new()
	_check(crowded.tick(PaintPots.FIRST, _rng(1), 3, 3, [Vector2i(1, 1)]) == null and crowded.pots.is_empty(),
			"on a floor where every tile is near a blob, no pot lands")


## The pictures of the pots (REQ-PG-23).
func _pot_pictures() -> void:
	print("pot pictures")
	var gold := PaintLook.pot_image(PaintPots.GOLD)
	var roller := PaintLook.pot_image(PaintPots.ROLLER)
	_check(gold.get_width() == PaintLook.POT_SIZE and gold.get_height() == PaintLook.POT_SIZE
			and roller.get_width() == PaintLook.POT_SIZE,
			"a pot is 11 x 11 world pixels with its outline")
	_check(gold.get_pixel(0, 0).a == 0.0 and gold.get_pixel(5, 6).is_equal_approx(PaintLook.GOLD)
			and roller.get_pixel(3, 5).is_equal_approx(Color("e63946"))
			and roller.get_pixel(1, 5).is_equal_approx(PaintLook.OUTLINE),
			"the gold pot is gold, the roller has the four stripes, and both have a black outline")
