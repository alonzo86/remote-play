extends RefCounted
## The pictures of Tower Builder (REQ-TB-18): a sunny valley (banded sky, a sun, snowy mountains, green hills, trees, striped
## grass with flowers), a wooden base, a crane that swings a brick, soft bricks in the slot colors and a height ruler (the
## approved mock of 2026-10-23). Drawn in the pixel view with shapes in 1920x1080 units; one world pixel is `Shell.WORLD_PIXEL`.

const Stack = preload("res://scripts/game/tower_builder/tower_stack.gd")
const Minigame = preload("res://scripts/game/minigame.gd")

const SKY := [Color("46c0ff"), Color("5cccff"), Color("78d8ff"), Color("96e2ff"), Color("b9ecff"), Color("ffecc8"),
		Color("ffdeaa")]
const SKY_BAND := 160.0          # The height of one band of the sky.
const SKY_TOP := Minigame.HUD_BAR_H  # Under the black bar of the HUD.
const SUN := Color("ffdc50")
const SUN_GLOW := Color("fff0aa")
const CLOUD := Color("ffffff")
const CLOUD_SHADE := Color("dcebfa")
const MOUNTAIN := Color("96a0dc")
const SNOW := Color("ffffff")
const HILL := Color("46aa5a")
const TREE := Color("1e7832")
const TRUNK := Color("6e4628")
const GRASS_A := Color("3caa3c")
const GRASS_B := Color("329632")
const GRASS_EDGE := Color("6ec85a")
const BASE_WOOD := Color("96643a")
const BASE_DARK := Color("6e4628")
const CRANE := Color("78502a")
const ROPE := Color("ffffff")
const OUTLINE := Color("000000")
const RULER := Color("ffffff")
const RULER_TICK := Color("ffc828")
const RUBBLE_Y := 880.0          # The bottom of a brick that lies on the grass.
const GRASS_TOP := 816.0         # Where the grass starts (behind the base).
const HORIZON := 800.0
const CRANE_Y := 132.0           # The arm of the crane.
const HANG_Y := 190.0            # The middle of the brick that hangs from the crane.
const RULER_X := 1700.0
const RULER_W := 16.0

const CLOUDS := [Vector2(180.0, 220.0), Vector2(1180.0, 200.0), Vector2(620.0, 330.0), Vector2(1700.0, 420.0)]
const TREES := [60.0, 260.0, 470.0, 1330.0, 1540.0, 1800.0]
const FLOWERS := [Vector2(120.0, 860.0), Vector2(380.0, 900.0), Vector2(1480.0, 870.0), Vector2(1760.0, 910.0),
		Vector2(1330.0, 940.0)]
const FLOWER_COLORS := [Color("ff5a78"), Color("ffdc3c"), Color("ffffff")]


## The sky, the sun, the clouds (they drift with `time`), the mountains, the hills, the trees and the grass.
static func draw_scene(ci: CanvasItem, area: Vector2, time: float) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, area), OUTLINE)
	for i in SKY.size():
		ci.draw_rect(Rect2(0.0, SKY_TOP + SKY_BAND * i, area.x, SKY_BAND), SKY[i])
	ci.draw_circle(Vector2(1390.0, 380.0), 88.0, SUN_GLOW)
	ci.draw_circle(Vector2(1390.0, 380.0), 64.0, SUN)
	for i in CLOUDS.size():
		_cloud(ci, Vector2(fposmod(CLOUDS[i].x + time * (6.0 + 3.0 * i), area.x + 400.0) - 200.0, CLOUDS[i].y))
	var x := 0.0
	while x < area.x:
		var h := mountain_height(x)
		ci.draw_rect(Rect2(x, HORIZON - h, 8.0, h), MOUNTAIN)
		if h > 250.0:
			ci.draw_rect(Rect2(x, HORIZON - h, 8.0, 16.0), SNOW)
		x += 8.0
	x = 0.0
	while x < area.x:
		var hh := hill_height(x)
		ci.draw_rect(Rect2(x, GRASS_TOP - hh, 8.0, hh + 24.0), HILL)
		x += 8.0
	for tx in TREES:
		_tree(ci, tx)
	var gx := 0.0
	var i := 0
	while gx < area.x:
		ci.draw_rect(Rect2(gx, GRASS_TOP, 96.0, area.y - GRASS_TOP), GRASS_A if i % 2 == 0 else GRASS_B)
		gx += 96.0
		i += 1
	ci.draw_rect(Rect2(0.0, GRASS_TOP, area.x, 8.0), GRASS_EDGE)
	for k in FLOWERS.size():
		var p: Vector2 = FLOWERS[k]
		ci.draw_rect(Rect2(p.x, p.y, 12.0, 12.0), FLOWER_COLORS[k % FLOWER_COLORS.size()])
		ci.draw_rect(Rect2(p.x + 4.0, p.y + 12.0, 4.0, 16.0), TREE)


## The height of the mountains at x: a few triangle waves added up, so there is no random number in the picture.
static func mountain_height(x: float) -> float:
	return 220.0 + 90.0 * absf(fposmod(x * 0.0021, 2.0) - 1.0) + 40.0 * absf(fposmod(x * 0.0073, 2.0) - 1.0)


static func hill_height(x: float) -> float:
	return 70.0 + 60.0 * absf(fposmod(x * 0.0013 + 0.4, 2.0) - 1.0)


static func _cloud(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_rect(Rect2(at.x, at.y, 136.0, 32.0), CLOUD)
	ci.draw_rect(Rect2(at.x + 24.0, at.y - 20.0, 72.0, 24.0), CLOUD)
	ci.draw_rect(Rect2(at.x + 16.0, at.y + 32.0, 104.0, 8.0), CLOUD_SHADE)


static func _tree(ci: CanvasItem, x: float) -> void:
	ci.draw_rect(Rect2(x + 12.0, GRASS_TOP - 52.0, 16.0, 56.0), TRUNK)
	ci.draw_rect(Rect2(x - 12.0, GRASS_TOP - 104.0, 64.0, 60.0), TREE)
	ci.draw_rect(Rect2(x, GRASS_TOP - 132.0, 40.0, 32.0), TREE)


## The wooden base of the tower.
static func draw_base(ci: CanvasItem) -> void:
	var r := Rect2(Stack.BASE_X - Stack.BASE_W * 0.5, Stack.GROUND_Y, Stack.BASE_W, RUBBLE_Y - Stack.GROUND_Y)
	ci.draw_rect(r, BASE_WOOD)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 8.0)), Color("c89660"))
	ci.draw_rect(Rect2(r.position.x, r.end.y - 8.0, r.size.x, 8.0), BASE_DARK)
	ci.draw_rect(r, OUTLINE, false, 4.0)


## A soft brick: the slot color, a light top edge, a dark bottom edge and a black outline. `rect` is the whole brick.
static func draw_brick(ci: CanvasItem, rect: Rect2, color: Color) -> void:
	ci.draw_rect(rect, color)
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 8.0)), color.lightened(0.3))
	ci.draw_rect(Rect2(rect.position.x, rect.end.y - 8.0, rect.size.x, 8.0), color.darkened(0.35))
	ci.draw_rect(rect, OUTLINE, false, 4.0)


## The rectangle of a brick of the tower at `level`.
static func brick_rect(level: int, x: float, w: float) -> Rect2:
	return Rect2(x - w * 0.5, Stack.level_top(level), w, Stack.BRICK_H)


## The crane: an arm across the top and a rope to the brick at `x`. The brick itself is drawn by the game.
static func draw_crane(ci: CanvasItem, x: float, brick_top: float) -> void:
	ci.draw_rect(Rect2(Stack.BASE_X - 460.0, CRANE_Y, 920.0, 16.0), CRANE)
	ci.draw_rect(Rect2(Stack.BASE_X - 460.0, CRANE_Y, 920.0, 4.0), Color("a07848"))
	ci.draw_rect(Rect2(x - 4.0, CRANE_Y + 16.0, 8.0, brick_top - CRANE_Y - 16.0), ROPE)
	ci.draw_rect(Rect2(x - 12.0, CRANE_Y + 8.0, 24.0, 24.0), CRANE)


## The height ruler at the right: a tick for each level, filled up to `height`.
static func draw_ruler(ci: CanvasItem, height: int, total: int) -> void:
	var top := Stack.level_top(total - 1)
	ci.draw_rect(Rect2(RULER_X, top, RULER_W, Stack.GROUND_Y - top), RULER)
	for i in total:
		var y := Stack.level_top(i)
		ci.draw_rect(Rect2(RULER_X - 12.0, y + Stack.BRICK_H - 4.0, RULER_W + 24.0, 4.0), RULER_TICK)
		if i < height:
			ci.draw_rect(Rect2(RULER_X, y, RULER_W, Stack.BRICK_H), RULER_TICK)
