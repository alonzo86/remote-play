extends SceneTree
## Draws the medal sheet `assets/medals/medals.png`: three medals of 16 x 16 px in one row, gold, silver and bronze (the order of
## `Medal.TIERS`), on a transparent background, with a red and blue ribbon, a 1 px dark outline and no antialiasing. Like the
## avatars, the sheet is an asset that is drawn at a whole-number scale with the nearest filter (`scripts/ui/medal.gd`).
## Run:  godot --headless --path . --script tools/make_medals.gd   (then --import once, so Godot makes the .import file)

const CELL := 16
const OUTLINE := Color("000000")
const RIBBON_RED := Color("f83800")
const RIBBON_BLUE := Color("0058f8")

## [light, base, dark] for gold, silver and bronze.
const TIERS: Array = [
	[Color("fcf0a0"), Color("f8b800"), Color("b87800")],
	[Color("fcfcfc"), Color("bcbcbc"), Color("7c7c7c")],
	[Color("e0a070"), Color("b8662c"), Color("7c3c14")],
]


func _initialize() -> void:
	var sheet := Image.create(CELL * TIERS.size(), CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for i in TIERS.size():
		for y in CELL:
			for x in CELL:
				var c := _pixel(x, y, TIERS[i])
				if c.a > 0.0:
					sheet.set_pixel(i * CELL + x, y, c)
	DirAccess.make_dir_recursive_absolute("res://assets/medals")
	sheet.save_png(ProjectSettings.globalize_path("res://assets/medals/medals.png"))
	print("wrote res://assets/medals/medals.png")
	quit()


## One pixel of a medal: the ribbon above, then a round medal with an outline, a dark ring, a light spot at the upper left and a
## plus in the middle.
func _pixel(x: int, y: int, c: Array) -> Color:
	var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8.0, 9.5))
	var dx := absi(x - 8) if x >= 8 else absi(x - 7)
	var dy := absi(y - 9) if y >= 9 else absi(y - 8)
	var out: Color = c[1]   # The base color.
	if d > 6.5:
		out = Color(0, 0, 0, 0)
		if y < 5 and x >= 4 and x <= 6:
			out = RIBBON_RED
		elif y < 5 and x >= 9 and x <= 11:
			out = RIBBON_BLUE
	elif d > 5.5:
		out = OUTLINE
	elif d > 4.2 or (dx == 0 and dy <= 2) or (dy == 0 and dx <= 2):
		out = c[2]
	elif x + y < 15 and d > 2.8:
		out = c[0]
	return out
