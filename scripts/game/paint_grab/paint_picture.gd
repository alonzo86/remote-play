extends RefCounted
## The pictures of Paint Grab (REQ-PG-22): the floor hides a picture, a different one in each round. A picture is the left half
## of a symmetric shape, 6 columns by 9 rows, written as text; the right half is the mirror image and 2 empty columns on each side
## make the 16 x 9 floor. Pure logic: it draws nothing. Any floor size can show it (`kinds_for()` takes the nearest cell).
##
## The letters: `.` nothing (the background of the floor), `#` the body, `o` an accent, `e` an eye.

const EMPTY := 0
const BODY := 1
const ACCENT := 2
const EYE := 3
const FULL_COLS := 16
const FULL_ROWS := 9
const HALF_COLS := 6
const MARGIN := 2   # Empty columns at each side of the shape on the 16 x 9 floor.

## Name and the 9 rows of the left half. The right edge of a row is the middle of the picture.
const SHAPES := [
	["invader", ["......", "..#...", "...#..", "..####", ".##e##", "######", "#.####", "#.#...", "...##."]],
	["heart", ["......", ".###..", "#o###.", "######", "######", ".#####", "..####", "...###", ".....#"]],
	["house", ["......", "....##", "...###", "..####", ".#####", "######", "#o####", "#oo#ee", "######"]],
	["fish", ["....##", "...###", "..e###", "..####", ".#####", ".#####", "..####", "...###", "..#.##"]],
	["rocket", ["....##", "...###", "...###", "...#ee", "...###", "..####", ".o####", "##.###", "#...##"]],
	["tree", ["......", "....##", "..####", ".#####", "######", "..####", ".#####", "....##", "....oo"]],
	["flower", ["......", "..o.o.", "...o..", ".o.###", "..o###", "...#ee", "....##", "..o###", "...o.#"]],
	["cat", ["......", "#.....", "##..##", "######", "##e###", "######", ".#####", "..####", "..#..#"]],
	["owl", ["......", "#....#", "######", "#ee###", "#ee###", "######", ".o#o##", "..####", "...#.#"]],
	["star", ["......", "....##", "....##", "######", ".#####", "..####", "..e###", ".##.##", "##...#"]],
	["butterfly", ["......", "##...#", "###.##", "#o####", "######", ".#e###", "#o####", "##.###", "#....#"]],
	["crab", ["......", "#.....", "#.#..#", "######", ".#e###", ".#####", "#.#.#.", "#.#.#.", "......"]],
	["mushroom", ["......", "..####", ".#####", "#o####", "######", "#o###o", "...###", "...###", "..####"]],
	["robot", ["....##", "....oo", "..####", ".#####", ".#ee##", ".#####", "..####", ".o####", ".##..#"]],
	["ghost", ["......", "..####", ".#####", "######", "#ee###", "######", "######", "######", "#.#.##"]],
	["ship", ["......", "....##", "...###", "...###", "...###", "######", ".#####", "..####", "...###"]],
	["crown", ["......", "#.....", "#.#..#", "######", "#o#o##", "######", "######", "######", "......"]],
	["rabbit", ["...#..", "...#..", "..##..", "..##..", "..####", "..#e##", "..####", "...###", "..####"]],
	["penguin", ["......", "...###", "..####", "..#ee#", "..####", ".##oo#", ".#####", ".#####", "..#..#"]],
	["frog", ["......", "..#..#", "..e..e", "######", "######", "######", ".#.#.#", ".#.#.#", "#.#.#."]],
	["skull", ["......", "..####", ".#####", "######", "#ee###", "######", ".#####", "..#.#.", "..#.#."]],
	["cup", ["......", "......", ".o.o.o", "######", "#####.", ".#####", "..####", "...###", "######"]],
	["icecream", ["......", "...###", "..####", ".#####", ".##oo#", ".#####", "..####", "...###", "....##"]],
	["diamond", ["......", "....##", "...###", "..####", ".#####", "######", ".#####", "..####", "....##"]],
	["castle", ["......", "#.#.#.", "#####.", "######", "#o#oo#", "######", "##o###", "######", "######"]],
	["bee", ["......", "..o.o.", "...oo.", "o#####", "##e###", "o#####", ".#####", "..####", "...##."]],
	["spider", ["......", "#...#.", ".#..#.", "..####", "..#ee#", "#.####", "..####", "#.#..#", "#..#.."]],
	["turtle", ["......", "..####", ".#####", ".#o#o#", "######", "######", "#.#..#", "#.#..#", "......"]],
	["mask", ["......", "######", "######", "#ee.##", ".ee.##", "######", "###o##", "####oo", "..####"]],
	["sun", ["......", "...#.#", "....#.", "#.####", "..####", "#.####", "....#.", "...#.#", "......"]],
]


static func count() -> int:
	return SHAPES.size()


## The index of a picture for a new round, chosen with `rng` (REQ-PG-22).
static func pick(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, SHAPES.size() - 1)


static func name_of(index: int) -> String:
	return SHAPES[index][0]


## One cell of the full 16 x 9 picture: EMPTY, BODY, ACCENT or EYE.
static func cell(index: int, x: int, y: int) -> int:
	var half_x := x - MARGIN
	if half_x < 0 or half_x >= 2 * HALF_COLS:
		return EMPTY
	if half_x >= HALF_COLS:
		half_x = 2 * HALF_COLS - 1 - half_x   # The right half is the mirror image.
	match String(SHAPES[index][1][y])[half_x]:
		"#":
			return BODY
		"o":
			return ACCENT
		"e":
			return EYE
	return EMPTY


## The picture on a floor of `cols` x `rows` tiles, row after row: every tile takes the nearest cell of the 16 x 9 picture, so a
## bigger or a smaller floor shows the same picture, still symmetric.
## `flip` turns it upside down and `swap` swaps body and accent,
## so one shape has four looks.
static func kinds_for(index: int, cols: int, rows: int, flip := false, swap := false) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(cols * rows)
	for y in rows:
		for x in cols:
			var left := mini(x, cols - 1 - x)   # The right half of the floor is the mirror image of the left half, exactly.
			var sx := floori((float(left) + 0.5) * FULL_COLS / float(cols))
			if x > left:
				sx = FULL_COLS - 1 - sx
			var sy := floori((float(y) + 0.5) * FULL_ROWS / float(rows))
			if flip:
				sy = FULL_ROWS - 1 - sy
			var k := cell(index, sx, sy)
			if swap and k == BODY:
				k = ACCENT
			elif swap and k == ACCENT:
				k = BODY
			out[y * cols + x] = k
	return out
