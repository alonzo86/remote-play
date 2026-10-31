extends RefCounted
## The look of Star Shield (REQ-AB-17): a pixel night sky with stars that drift down, round gray asteroids with craters in
## three
## sizes, small ships in the player colors, round pickups and bright beams. Everything is drawn in screen units on the pixel layer
## (one world pixel is `Shell.WORLD_PIXEL` units). The pictures are built from code.

const Shell = preload("res://scripts/game/shell.gd")
const Palette = preload("res://scripts/game/palette.gd")
const PixelArt = preload("res://scripts/game/pixel_art.gd")

const PX := 4.0                       # One world pixel in screen units (`Shell.WORLD_PIXEL`).
const OUTLINE := Color("101018")
const SKY_TOP := Color("0a0a1e")
const SKY_BOTTOM := Color("1c1244")
const SKY_BANDS := 8
const VIEW := Vector2(480.0, 270.0)   # The pixel view in world pixels.
const STAR_COUNT := 66
const STAR_SPEEDS := [6.0, 12.0, 22.0]   # World pixels per second of the three star layers.
const STAR_COLORS := [Color("5a5a8c"), Color("9a9ad2"), Color("fcfcfc")]
const ROCK_LIGHT := Color("b8b0a8")
const ROCK_MID := Color("8c847c")
const ROCK_DARK := Color("5e5852")
const ROCK_CRATER := Color("4a4540")
const SHIELD_COLOR := Color("4cb4ff")
const WEAPON_COLOR := Color("ff9a2e")
const SHIELD_RING := Color("8ad4ff")
const FLAME_A := Color("ffd23c")
const FLAME_B := Color("ff6a2c")
const SPARKS := [Color("fcfcfc"), Color("ffd23c"), Color("ff9a2e"), Color("ff5a4d")]
const EXPLODE_TIME := 0.6
const SCALE := 2

## A ship: 7x7 sprite pixels, each 2x2 world pixels, so 14x14 before the outline. `k` is the hull (player color), `w` the light
## nose and wing tips, `c` the cockpit glass.
const SHIP := [
	"...w...",
	"..kwk..",
	"..kck..",
	".kkkkk.",
	"kkkkkkk",
	"kwkkkwk",
	"w.k.k.w",
]
## The glyphs of the pickups, 7x7 world pixels: a shield and the beam of the weapon.
const GLYPH_SHIELD := [
	"wwwwwww",
	"wwwwwww",
	"wwwwwww",
	".wwwww.",
	".wwwww.",
	"..www..",
	"...w...",
]
const GLYPH_WEAPON := [
	"...w...",
	"..www..",
	".wwwww.",
	"...w...",
	"...w...",
	"...w...",
	"...w...",
]
const ICON_RADIUS := 7                # World pixels: the pickup is a disc of 15 pixels.


## The sky: bands of dark blue from the top to the bottom of `area`.
static func draw_sky(ci: CanvasItem, area: Vector2) -> void:
	var h := ceilf(area.y / float(SKY_BANDS))
	for i in SKY_BANDS:
		ci.draw_rect(Rect2(0.0, h * i, area.x, h + 1.0), SKY_TOP.lerp(SKY_BOTTOM, float(i) / float(SKY_BANDS - 1)))


## The stars: `STAR_COUNT` pixels in the same places every game, in three layers that drift down at different speeds.
## Returns the star `i` after `t` seconds as `{x, y, layer}` in world pixels.
static func star_at(i: int, t: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + i
	var layer := i % STAR_SPEEDS.size()
	var x := rng.randi_range(0, int(VIEW.x) - 1)
	var y0 := rng.randi_range(0, int(VIEW.y) - 1)
	return {"x": x, "y": int(fposmod(float(y0) + t * float(STAR_SPEEDS[layer]), VIEW.y)), "layer": layer}


static func draw_stars(ci: CanvasItem, t: float) -> void:
	for i in STAR_COUNT:
		var s := star_at(i, t)
		ci.draw_rect(Rect2(float(s.x) * PX, float(s.y) * PX, PX, PX), STAR_COLORS[s.layer])


## A far, dark world in the top right of the sky, so the sky is not only stars. It is small and dim, with no outline and no ring,
## so that it does not look like a target (issue #138).
static func draw_planet(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color("241a3d"))
	ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.7, Color("2e2250"))


## The picture of an asteroid of `size` (0 to 2) in one of 4 `look`s, with a one-pixel outline. The shape is a circle with a rough
## edge, light from the top left, and 2 to 4 craters. The same arguments always give the same picture.
static func asteroid_image(size: int, look: int, radius_units: float) -> Image:
	var r := int(roundf(radius_units / PX))
	var d := r * 2 + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 * (size + 1) + 17 * look
	var bumps: Array[float] = []
	for i in 12:
		bumps.append(rng.randf_range(-0.12, 0.08))
	var craters: Array[Vector3] = []
	for i in 2 + size:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(0.0, 0.55) * float(r)
		craters.append(Vector3(cos(a) * dist, sin(a) * dist, maxf(1.5, rng.randf_range(0.14, 0.26) * float(r))))
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dx := float(x - r)
			var dy := float(y - r)
			var dist2 := Vector2(dx, dy).length()
			var ang := fposmod(atan2(dy, dx), TAU)
			var edge := float(r) * (1.0 + bumps[int(ang / TAU * 12.0) % 12])
			if dist2 > edge:
				continue
			var shade := (dx + dy) / float(r)   # -2 (light corner) to 2 (dark corner)
			var col := ROCK_LIGHT if shade < -0.5 else (ROCK_MID if shade < 0.55 else ROCK_DARK)
			for c in craters:
				if Vector2(dx - c.x, dy - c.y).length() <= c.z:
					col = ROCK_CRATER
			img.set_pixel(x, y, col)
	return PixelArt.outlined(img, OUTLINE)


## The picture of a ship in `color`. `frame` 0 or 1 is the flame of the engine under it (two sizes).
static func ship_image(color: Color, frame: int) -> Image:
	var w := SHIP[0].length() * SCALE
	var h := SHIP.size() * SCALE
	var src := Image.create(w, h + 3 * SCALE, false, Image.FORMAT_RGBA8)
	var colors := {"k": color, "w": Color("fcfcfc"), "c": Palette.COCKPIT_CYAN}
	for y in SHIP.size():
		for x in SHIP[y].length():
			var ch: String = SHIP[y][x]
			if colors.has(ch):
				src.fill_rect(Rect2i(x * SCALE, y * SCALE, SCALE, SCALE), colors[ch])
	var fx := (SHIP[0].length() / 2) * SCALE   # The flame under the middle of the hull.
	src.fill_rect(Rect2i(fx, h, SCALE, SCALE), FLAME_A)
	src.fill_rect(Rect2i(fx, h + SCALE, SCALE, SCALE * (1 + frame)), FLAME_B)
	return PixelArt.outlined(src, OUTLINE)


## The round picture of a pickup: `kind` is "shield" or "weapon".
static func pickup_image(kind: String) -> Image:
	var d := ICON_RADIUS * 2 + 1
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var base := SHIELD_COLOR if kind == "shield" else WEAPON_COLOR
	for y in d:
		for x in d:
			if Vector2(x - ICON_RADIUS, y - ICON_RADIUS).length() <= float(ICON_RADIUS) + 0.3:
				img.set_pixel(x, y, base)
	var glyph: Array = GLYPH_SHIELD if kind == "shield" else GLYPH_WEAPON
	var off := (d - glyph.size()) / 2
	for y in glyph.size():
		for x in glyph[y].length():
			if glyph[y][x] == "w":
				img.set_pixel(off + x, off + y, Color.WHITE)
	return PixelArt.outlined(img, OUTLINE)


## A beam in the color of its ship: a bar with a white core, drawn at the middle `c`.
static func draw_beam(ci: CanvasItem, c: Vector2, color: Color) -> void:
	var p := Shell.snap(c)
	ci.draw_rect(Rect2(p.x - PX * 1.5, p.y - PX * 3.5, PX * 3.0, PX * 7.0), OUTLINE)
	ci.draw_rect(Rect2(p.x - PX, p.y - PX * 3.0, PX * 2.0, PX * 6.0), color)
	ci.draw_rect(Rect2(p.x - PX * 0.5, p.y - PX * 2.0, PX, PX * 4.0), Color.WHITE)


## The force field: a ring around the ship that blinks a little (`t` in seconds).
static func draw_shield(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	var col := SHIELD_RING if int(t * 6.0) % 2 == 0 else Color("c8ecff")
	ci.draw_circle(c, r, Color(SHIELD_RING.r, SHIELD_RING.g, SHIELD_RING.b, 0.18))
	ci.draw_arc(c, r, 0.0, TAU, 32, OUTLINE, PX * 2.0)
	ci.draw_arc(c, r, 0.0, TAU, 32, col, PX)


## One step of an explosion at `age` seconds: sparks fly out from `c`. `scale` is 1.0 for a medium asteroid.
## Returns the number of sparks drawn (0 when the explosion is over).
static func draw_explosion(ci: CanvasItem, c: Vector2, age: float, scale: float) -> int:
	if age >= EXPLODE_TIME:
		return 0
	var t := age / EXPLODE_TIME
	var step := floorf(t * 4.0)   # 4 steps, like the other pixel effects.
	var n := 10
	var reach := (24.0 + 70.0 * scale) * (0.35 + 0.65 * (step + 1.0) / 4.0)
	for i in n:
		var dir := Vector2.from_angle(float(i) / float(n) * TAU + 0.3)
		var p := Shell.snap(c + dir * reach * (0.8 + 0.4 * float(i % 3) / 2.0))
		var sz := PX * (3.0 - minf(step, 2.0))
		ci.draw_rect(Rect2(p - Vector2.ONE * sz * 0.5, Vector2.ONE * sz), SPARKS[mini(int(step), SPARKS.size() - 1)])
	var core := PX * (6.0 - step * 1.5) * scale
	if core > 0.0:
		ci.draw_rect(Rect2(Shell.snap(c) - Vector2.ONE * core * 0.5, Vector2.ONE * core), SPARKS[0] if step < 2.0 else SPARKS[1])
	return n
