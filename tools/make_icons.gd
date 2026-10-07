extends SceneTree
## Draws the launcher icons and the Android TV banner from flat shapes. No external assets.
## Run:  godot --headless --path . --script tools/make_icons.gd
## Output: assets/icons/*.png  (the files are committed, so this is only needed after a design change)

const BG := Color("14161c")
const YELLOW := Color("ffd166")
const RED := Color("e63946")
const TEAL := Color("2a9d8f")
const PANEL := Color("2b3140")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/icons")
	_save(_phone_icon(192, true), "icon_192")
	_save(_phone_icon(432, false), "adaptive_foreground_432", true)
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(BG)
	_save(bg, "adaptive_background_432")
	_save(_banner(320, 180), "banner")
	quit()


func _save(img: Image, name: String, _transparent := false) -> void:
	var path := "res://assets/icons/%s.png" % name
	img.save_png(ProjectSettings.globalize_path(path))
	print("wrote ", path)


func _rect(img: Image, x: float, y: float, w: float, h: float, c: Color, r := 0.0) -> void:
	# Filled rounded rectangle.
	for py in range(int(y), int(y + h)):
		for px in range(int(x), int(x + w)):
			var dx := maxf(maxf(x + r - px, px - (x + w - r)), 0.0)
			var dy := maxf(maxf(y + r - py, py - (y + h - r)), 0.0)
			if dx * dx + dy * dy <= r * r and px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, c)


func _disc(img: Image, cx: float, cy: float, rad: float, c: Color) -> void:
	_rect(img, cx - rad, cy - rad, rad * 2.0, rad * 2.0, c, rad)


func _phone_icon(size: int, with_bg: bool) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(BG if with_bg else Color(0, 0, 0, 0))
	var s := float(size)
	# For the adaptive icon keep the artwork inside the central 66 percent.
	var k := 0.7 if not with_bg else 0.9
	var w := s * 0.34 * k
	var h := s * 0.76 * k
	var x := (s - w) * 0.5
	var y := (s - h) * 0.5
	_rect(img, x, y, w, h, YELLOW, w * 0.16)
	_rect(img, x + w * 0.12, y + h * 0.07, w * 0.76, h * 0.06, BG, w * 0.03)
	_disc(img, s * 0.5, y + h * 0.68, w * 0.22, BG)
	return img


func _banner(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	# A TV with a ball and a maze corner, and a phone beside it.
	_rect(img, 28, 34, 170, 112, PANEL, 10)
	_rect(img, 38, 44, 150, 92, BG, 6)
	_rect(img, 58, 60, 70, 8, YELLOW)
	_rect(img, 58, 60, 8, 56, YELLOW)
	_rect(img, 58, 108, 110, 8, YELLOW)
	_disc(img, 96, 88, 9, RED)
	_rect(img, 100, 146, 22, 12, PANEL)
	_rect(img, 80, 156, 62, 6, PANEL, 3)
	_rect(img, 232, 40, 60, 100, YELLOW, 10)
	_rect(img, 242, 48, 40, 5, BG, 2)
	_disc(img, 262, 112, 11, BG)
	_disc(img, 262, 72, 8, TEAL)
	return img
