extends RefCounted
## The pictures of Tennis (REQ-TN-2, 3): a pixel court seen from behind the near baseline. The court is drawn in a simple
## perspective (`Proj`), the players are small pixel people made of rectangles (`draw_person()`), and the stands are one picture
## that is made once. Everything is drawn in 1920x1080 units on the pixel layer, so it comes out as sharp pixels.
## The court is in meters: x across (positive to the right of the near team), y along (the near baseline is at negative y).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Palette = preload("res://scripts/game/palette.gd")
const Minigame = preload("res://scripts/game/minigame.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Sim = preload("res://scripts/game/tennis/tennis_sim.gd")

const SPARK_TIME := 0.4            # A green hit shows its sparks this long (s).
const SPARK_COLORS := [Color("fcfcfc"), Color("ffd23c")]
const HUD_H := Minigame.HUD_BAR_H  # The black bar on top (the title and the leader chip), drawn by the shell (REQ-GM-45a).
const DEPTH_C := 16.0             # The eye is this far (m) behind the near baseline.
const K_DEPTH := 13370.0          # Screen y of a point on the floor: HORIZON + K_DEPTH / z (units at 1920 x 1080).
const HORIZON := 44.0
const K_SIDE := 2200.0            # Units per meter at z = 1.
const BOARD_BACK := 3.0           # The ad boards stand this far (m) behind the far baseline.
const BOARD_H := 1.0
const STANDS_Y0 := Minigame.HUD_BAR_H
const STANDS_PX_H := 60           # The stands picture is 480 x 60 world pixels.

const GRASS := Color("2f7d4d")
const COURT := Color("3a6db0")
const COURT_LIGHT := Color("4a7fc1")
const LINE := Color("f4f4f4")
const BOARD := Color("2a2a3a")
const BOARD_EDGE := Color("5a5a72")
const NET_DARK := Color("1c1c24")
const NET_MESH := Color("3c3c4c")
const BALL := Color("f4e04a")
const SKINS := [Color("f2c9a0"), Color("d9a074"), Color("a8704a"), Color("7a4a2e")]
const HAIRS := [Color("3a2410"), Palette.HAIR_BLOND, Color("1a1a1a"), Color("8a3b1e")]
const SHORTS := Color("f4f4f4")
const SHOE := Color("f4f4f4")
const RACKET_FRAME := Color("c43c3c")
const RACKET_STRINGS := Color("dcdcf0")
const HANDLE := Color("8a5a2a")
const MACHINE := Color("f06aa8")
const MACHINE_DARK := Color("b83c78")

static var _stands_tex: ImageTexture


## The perspective of a screen of `size`: a point of the court (x, y in m) and a height h (m) become a screen point.
class Proj:
	var k := 1.0
	var cx := 960.0

	func _init(size: Vector2) -> void:
		k = size.x / 1920.0
		cx = size.x * 0.5

	func z(y: float) -> float:
		return DEPTH_C + y + Sim.HALF_L

	## Units per meter at the court depth `y`.
	func scale(y: float) -> float:
		return K_SIDE * k / z(y)

	func at(x: float, y: float, h := 0.0) -> Vector2:
		var zz := z(y)
		var s := K_SIDE * k / zz
		return Vector2(cx + x * s, (HORIZON + K_DEPTH / zz) * k - h * s)


# ---- The hall: stands, boards, floor ----

## The whole background: the floor, the stands and the ad boards at the far end. The black bar on top is drawn last.
static func draw_hall(ci: CanvasItem, size: Vector2, p: Proj) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), GRASS)
	var board_foot := p.at(0.0, Sim.HALF_L + BOARD_BACK).y
	var board_top := p.at(0.0, Sim.HALF_L + BOARD_BACK, BOARD_H).y
	ci.draw_rect(Rect2(0.0, 0.0, size.x, board_top), UiTheme.BG)
	if _stands_tex == null:
		_stands_tex = ImageTexture.create_from_image(_stands_image())
	var stands_h := board_top - STANDS_Y0 * p.k
	ci.draw_texture_rect(_stands_tex, Rect2(0.0, STANDS_Y0 * p.k, size.x, stands_h), false)
	ci.draw_rect(Rect2(0.0, board_top, size.x, board_foot - board_top), BOARD)
	ci.draw_rect(Rect2(0.0, board_top, size.x, 8.0), BOARD_EDGE)
	ci.draw_rect(Rect2(0.0, board_foot - 8.0, size.x, 8.0), UiTheme.BG)
	for i in range(1, 6):   # The boards are blank: only the seams between them show.
		var x := size.x * float(i) / 6.0
		ci.draw_rect(Rect2(Shell.snap(Vector2(x, board_top)), Vector2(4.0, board_foot - board_top)), BOARD_EDGE)


static func _hash(a: int, b: int, c: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791)) >> 3


## The stands: rows of seats with a few people in them, 480 x 60 world pixels. Made once.
static func _stands_image() -> Image:
	var img := Image.create(480, STANDS_PX_H, false, Image.FORMAT_RGBA8)
	img.fill(Color("181828"))
	var shirts := [Palette.SLOTS[0], Palette.SLOTS[2], Palette.SLOTS[1], Color("f4f4f4"), Color("b05cd8"), Color("f8b800")]
	var rows := STANDS_PX_H / 6
	for r in rows:
		var y := r * 6
		var seat: Color = Color("2b4a8b") if r % 2 == 0 else Color("243f78")
		img.fill_rect(Rect2i(0, y + 4, 480, 2), seat.darkened(0.3))
		for sx in range(0, 480, 8):
			img.fill_rect(Rect2i(sx + 1, y + 2, 6, 2), seat)
			if _hash(sx / 8, r, 5) % 3 == 0:
				continue
			var shirt: Color = shirts[_hash(sx / 8, r, 9) % shirts.size()]
			var skin: Color = SKINS[_hash(sx / 8, r, 2) % SKINS.size()]
			var hair: Color = HAIRS[_hash(sx / 8, r, 7) % HAIRS.size()]
			img.fill_rect(Rect2i(sx + 2, y + 2, 4, 2), shirt)
			img.fill_rect(Rect2i(sx + 3, y, 2, 2), skin)
			img.set_pixel(sx + 3, y, hair)
			img.set_pixel(sx + 4, y, hair)
	return img


# ---- The court ----

static func _quad(ci: CanvasItem, p: Proj, x0: float, x1: float, y0: float, y1: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p.at(x0, y0), p.at(x1, y0), p.at(x1, y1), p.at(x0, y1)]), color)


static func _line(ci: CanvasItem, p: Proj, a: Vector2, b: Vector2) -> void:
	var s := p.scale((a.y + b.y) * 0.5)
	var w := maxf(4.0, roundf(0.09 * s / 4.0) * 4.0)
	ci.draw_line(p.at(a.x, a.y), p.at(b.x, b.y), LINE, w)


## The court with its lines: the doubles court, the singles sidelines, the service lines and the middle line.
static func draw_court(ci: CanvasItem, p: Proj) -> void:
	var hl := Sim.HALF_L
	var dw := Sim.HALF_W_DOUBLES
	var sw := Sim.HALF_W_SINGLES
	_quad(ci, p, -dw - 1.6, dw + 1.6, -hl - 1.6, hl + 1.6, COURT.darkened(0.25))
	_quad(ci, p, -dw, dw, -hl, hl, COURT)
	_quad(ci, p, -sw, sw, -Sim.SERVICE, Sim.SERVICE, COURT_LIGHT)
	_line(ci, p, Vector2(-dw, -hl), Vector2(dw, -hl))
	_line(ci, p, Vector2(-dw, hl), Vector2(dw, hl))
	_line(ci, p, Vector2(-dw, -hl), Vector2(-dw, hl))
	_line(ci, p, Vector2(dw, -hl), Vector2(dw, hl))
	_line(ci, p, Vector2(-sw, -hl), Vector2(-sw, hl))
	_line(ci, p, Vector2(sw, -hl), Vector2(sw, hl))
	_line(ci, p, Vector2(-sw, -Sim.SERVICE), Vector2(sw, -Sim.SERVICE))
	_line(ci, p, Vector2(-sw, Sim.SERVICE), Vector2(sw, Sim.SERVICE))
	_line(ci, p, Vector2(0.0, -Sim.SERVICE), Vector2(0.0, Sim.SERVICE))
	_line(ci, p, Vector2(0.0, -hl), Vector2(0.0, -hl + 0.3))
	_line(ci, p, Vector2(0.0, hl), Vector2(0.0, hl - 0.3))


## The net across the whole doubles court with a post at each side, and the white band on top.
static func draw_net(ci: CanvasItem, p: Proj) -> void:
	var post_x := Sim.HALF_W_DOUBLES + 0.9
	var top_l := p.at(-post_x, 0.0, Sim.NET_H)
	var top_r := p.at(post_x, 0.0, Sim.NET_H)
	var foot_l := p.at(-post_x, 0.0)
	var foot_r := p.at(post_x, 0.0)
	ci.draw_colored_polygon(PackedVector2Array([top_l, top_r, foot_r, foot_l]), NET_DARK)
	var s := p.scale(0.0)
	var cols := 40
	for i in range(1, cols):
		var x := lerpf(top_l.x, top_r.x, float(i) / float(cols))
		ci.draw_line(Vector2(x, top_l.y), Vector2(x, foot_l.y), NET_MESH, 2.0)
	var rows := 5
	for j in range(1, rows):
		var y := lerpf(top_l.y, foot_l.y, float(j) / float(rows))
		ci.draw_line(Vector2(top_l.x, y), Vector2(top_r.x, y), NET_MESH, 2.0)
	ci.draw_line(top_l, top_r, LINE, maxf(4.0, roundf(0.06 * s / 4.0) * 4.0))
	for side in [-1.0, 1.0]:
		var pt: Vector2 = p.at(post_x * side, 0.0)
		var ph := 1.07 * s
		ci.draw_rect(Rect2(Shell.snap(pt - Vector2(6.0, ph)), Vector2(12.0, ph)), UiTheme.OUTLINE)
		ci.draw_rect(Rect2(Shell.snap(pt - Vector2(2.0, ph)), Vector2(4.0, ph)), BOARD_EDGE)


# ---- The people ----

## A rectangle in meters around `foot` (x to the right, h up), moved to the world pixel grid and at least one pixel big.
static func _r(foot: Vector2, s: float, x0: float, x1: float, h0: float, h1: float) -> Rect2:
	var a := Shell.snap(foot + Vector2(minf(x0, x1) * s, -maxf(h0, h1) * s))
	var b := Shell.snap(foot + Vector2(maxf(x0, x1) * s, -minf(h0, h1) * s))
	return Rect2(a, Vector2(maxf(4.0, b.x - a.x), maxf(4.0, b.y - a.y)))


static func _draw_parts(ci: CanvasItem, parts: Array) -> void:
	for part in parts:
		ci.draw_rect((part[0] as Rect2).grow(4.0), UiTheme.OUTLINE)
	for part in parts:
		ci.draw_rect(part[0], part[1])


## A tennis player with his feet at `foot` on a screen, `s` units per meter. `look`: `shirt` (the slot color), `slot`, `back`
## (seen from behind: the near team), `hand` (+1: the racket hand is on the right of the screen, -1: on the left), `pose`
## ("idle", "run", "hit" or "serve"), `phase` (a time for the legs) and `toss` (the free hand is up).
static func draw_person(ci: CanvasItem, foot: Vector2, s: float, look: Dictionary) -> void:
	var slot := int(look.get("slot", 0))
	var back: bool = look.get("back", true)
	var m: float = look.get("hand", 1.0)
	var pose: String = look.get("pose", "idle")
	var shirt: Color = look.get("shirt", Color.WHITE)
	var skin: Color = SKINS[slot % SKINS.size()]
	var hair: Color = HAIRS[(slot + 1) % HAIRS.size()]
	var phase := float(look.get("phase", 0.0))
	var run := pose == "run"
	var bob := absf(sin(phase * 9.0)) * 0.05 if run else 0.0
	var f := foot - Vector2(0.0, bob * s)
	var shadow := Rect2(Shell.snap(foot + Vector2(-0.3 * s, -0.04 * s)), Vector2(maxf(8.0, 0.6 * s), maxf(4.0, 0.1 * s)))
	ci.draw_rect(shadow, Color(0.0, 0.0, 0.0, 0.35))
	var swing := sin(phase * 9.0) * 0.1 if run else 0.0
	var parts: Array = []
	for sx in [-1.0, 1.0]:
		var lift := maxf(0.0, swing * sx) * 1.2
		parts.append([_r(f, s, sx * 0.09 - 0.07, sx * 0.09 + 0.07, 0.1 + lift, 0.82), skin])
		parts.append([_r(f, s, sx * 0.09 - 0.1, sx * 0.09 + 0.1, lift, 0.12 + lift), SHOE])
	parts.append([_r(f, s, -0.2, 0.2, 0.78, 1.0), SHORTS])
	parts.append([_r(f, s, -0.22, 0.22, 1.0, 1.46), shirt])
	parts.append([_r(f, s, -0.12, 0.12, 1.48, 1.74), skin])
	var free_up: bool = look.get("toss", false)
	if free_up:
		parts.append([_r(f, s, -m * 0.34, -m * 0.24, 1.2, 1.95), skin])
	else:
		parts.append([_r(f, s, -m * 0.32, -m * 0.22, 1.0, 1.4), skin])
	var racket: Array = []
	if pose == "hit" or pose == "serve":
		var up := 0.5 if pose == "serve" else 0.0
		parts.append([_r(f, s, m * 0.22, m * 0.7, 1.28 + up, 1.4 + up), skin])
		racket.append([_r(f, s, m * 0.7, m * 0.86, 1.3 + up, 1.38 + up), HANDLE])
		racket.append([_r(f, s, m * 0.86, m * 1.26, 1.12 + up, 1.56 + up), RACKET_FRAME])
	else:
		parts.append([_r(f, s, m * 0.22, m * 0.32, 0.95, 1.38), skin])
		racket.append([_r(f, s, m * 0.3, m * 0.4, 0.8, 1.0), HANDLE])
		racket.append([_r(f, s, m * 0.28, m * 0.62, 0.95, 1.34), RACKET_FRAME])
	_draw_parts(ci, parts)
	if back:
		ci.draw_rect(_r(f, s, -0.14, 0.14, 1.58, 1.8), hair)
	else:
		ci.draw_rect(_r(f, s, -0.14, 0.14, 1.66, 1.8), hair)
		ci.draw_rect(_r(f, s, -0.1, -0.05, 1.56, 1.62), UiTheme.OUTLINE)
		ci.draw_rect(_r(f, s, 0.05, 0.1, 1.56, 1.62), UiTheme.OUTLINE)
	_draw_parts(ci, racket)
	var head: Rect2 = racket[racket.size() - 1][0]
	ci.draw_rect(head.grow(-8.0) if minf(head.size.x, head.size.y) > 20.0 else head.grow(-4.0), RACKET_STRINGS)


## The middle of the head of a player, (the place of the 'great' plate).
static func head_pos(foot: Vector2, s: float) -> Vector2:
	return foot - Vector2(0.0, 1.9 * s)


## The umpire's chair at the side of the net, with the umpire on top (REQ-TN-2): a blue steel frame with cross braces, a step
## ladder, a seat with a shade board, a small net-side table and an umpire in a white shirt and a blue cap.
static func draw_tower(ci: CanvasItem, p: Proj) -> void:
	var x := -(Sim.HALF_W_DOUBLES + 1.8)
	var foot := p.at(x, 0.0)
	var s := p.scale(0.0)
	var steel := Color("3c5a9a")
	var steel_dark := Color("26396a")
	var seat := Color("f4f4f4")
	var parts: Array = []
	# The four legs seen from behind are two, with a cross brace between them and a foot plate on the ground.
	for sx in [-0.5, 0.5]:
		parts.append([_r(foot, s, sx - 0.06, sx + 0.06, 0.0, 2.3), steel])
		parts.append([_r(foot, s, sx - 0.14, sx + 0.14, 0.0, 0.08), steel_dark])
	for h in [0.5, 1.2, 1.9]:
		parts.append([_r(foot, s, -0.5, 0.5, h, h + 0.07), steel_dark])
	# The step ladder on the court side: two rails and rungs.
	for sx in [0.62, 0.9]:
		parts.append([_r(foot, s, sx - 0.03, sx + 0.03, 0.0, 1.3), steel_dark])
	for h in [0.3, 0.65, 1.0]:
		parts.append([_r(foot, s, 0.62, 0.9, h, h + 0.05), steel])
	# The seat, the arm rests and the back with the shade board on top.
	parts.append([_r(foot, s, -0.62, 0.62, 2.3, 2.42), seat])
	parts.append([_r(foot, s, -0.62, -0.5, 2.42, 2.7), steel])
	parts.append([_r(foot, s, 0.5, 0.62, 2.42, 2.7), steel])
	parts.append([_r(foot, s, -0.5, 0.5, 2.42, 3.0), Color("c8d4ec")])
	# The umpire: legs, white shirt, arms on the rests, head with a blue cap.
	parts.append([_r(foot, s, -0.2, 0.2, 2.42, 2.6), Color("e0e0e8")])
	parts.append([_r(foot, s, -0.22, 0.22, 2.6, 3.0), seat])
	parts.append([_r(foot, s, -0.36, -0.22, 2.62, 2.9), SKINS[1]])
	parts.append([_r(foot, s, 0.22, 0.36, 2.62, 2.9), SKINS[1]])
	parts.append([_r(foot, s, -0.12, 0.12, 3.0, 3.26), SKINS[1]])
	parts.append([_r(foot, s, -0.15, 0.15, 3.22, 3.34), steel])
	parts.append([_r(foot, s, -0.15, 0.22, 3.2, 3.24), steel_dark])
	_draw_parts(ci, parts)


## The friendly ball machine of a rally (REQ-TN-15), pink with two eyes. `squash` 0..1 after it sent a ball.
static func draw_machine(ci: CanvasItem, p: Proj, pos: Vector2, squash: float) -> void:
	var foot := p.at(pos.x, pos.y)
	var s := p.scale(pos.y)
	var sq := 0.1 * maxf(0.0, 1.0 - squash * 4.0)
	var parts: Array = []
	parts.append([_r(foot, s, -0.45, 0.45, 0.0 + sq, 0.9 - sq), MACHINE])
	parts.append([_r(foot, s, -0.45, 0.45, 0.0, 0.25), MACHINE_DARK])
	parts.append([_r(foot, s, -0.15, 0.15, 0.9 - sq, 1.2 - sq), MACHINE_DARK])
	_draw_parts(ci, parts)
	for sx in [-0.2, 0.2]:
		ci.draw_rect(_r(foot, s, sx - 0.08, sx + 0.08, 0.5, 0.7), Color.WHITE)
		ci.draw_rect(_r(foot, s, sx - 0.03, sx + 0.03, 0.54, 0.64), UiTheme.OUTLINE)


# ---- The ball ----

## The shadow of the ball on the court: it shows how high the ball is.
static func draw_ball_shadow(ci: CanvasItem, p: Proj, pos: Vector3) -> void:
	var at := p.at(pos.x, pos.y)
	var s := p.scale(pos.y)
	var w := maxf(12.0, 0.26 * s)
	ci.draw_rect(Rect2(Shell.snap(at - Vector2(w * 0.5, 2.0)), Vector2(w, 8.0)), Color(0.0, 0.0, 0.0, 0.4))


## The ball: yellow with a thin black border (REQ-TN-3).
static func draw_ball(ci: CanvasItem, p: Proj, pos: Vector3) -> void:
	var c := p.at(pos.x, pos.y, maxf(pos.z, 0.0) + 0.1)
	var r := maxf(12.0, 0.11 * p.scale(pos.y))
	Shell.pixel_ball(ci, c, r, BALL)


## A green hit (REQ-TN-6): 8 square sparks of 1 to 2 world pixels fly out from `c` in 4 steps and fall off. Returns how many were
## drawn (0 when `age` is past SPARK_TIME).
static func draw_sparks(ci: CanvasItem, c: Vector2, age: float) -> int:
	if age >= SPARK_TIME:
		return 0
	var step := floorf(age / SPARK_TIME * 4.0)
	var reach := 20.0 + 18.0 * step
	var sz := Shell.WORLD_PIXEL * (2.0 if step < 2.0 else 1.0)
	var n := 8
	for i in n:
		var dir := Vector2.from_angle(float(i) / float(n) * TAU + 0.4)
		var at := Shell.snap(c + dir * reach * (0.8 + 0.4 * float(i % 2)))
		ci.draw_rect(Rect2(at, Vector2.ONE * sz), SPARK_COLORS[(i + int(step)) % 2])
	Shell.record("spark", ci, Rect2(Shell.snap(c), Vector2.ONE * reach), {"n": n})
	return n
