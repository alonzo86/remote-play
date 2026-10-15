extends SceneTree
## Makes the launcher icons and the Android TV banner from the Sababi mascot and logo (`assets/logo/splash.png`, `logo.png`,
## FD-21).
## Run:  godot --headless --path . --script tools/make_icons.gd
## Output: assets/icons/*.png  (the files are committed, so this is only needed after a change of the logo)
## The mascot is cut out of the splash picture and enlarged by a whole number (nearest filter), so its pixels stay sharp.

const BG := Color("000000")   # UiTheme.BG: the black of every screen.


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/icons")
	var mascot := _mascot()
	_save(_icon(mascot, 192, 0.7), "icon_192")
	_save(_icon(mascot, 1024, 0.7), "icon_1024")   # The project icon (iOS builds it down to every size).
	# The adaptive icon: Android crops it to a circle or a rounded square, so the mascot stays inside the middle 66 percent.
	_save(_icon(mascot, 432, 0.5, Color(0, 0, 0, 0)), "adaptive_foreground_432")
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(BG)
	_save(bg, "adaptive_background_432")
	_save(_banner(320, 180), "banner")
	quit()


func _save(img: Image, name: String) -> void:
	var path := "res://assets/icons/%s.png" % name
	img.save_png(ProjectSettings.globalize_path(path))
	print("wrote ", path)


## The mascot of the splash picture, cut to its own box.
func _mascot() -> Image:
	var img: Image = (load("res://assets/logo/splash.png") as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img.get_region(img.get_used_rect())


## A square icon: the mascot in the middle, as large as a whole-number scale allows inside `share` of the side.
func _icon(mascot: Image, side: int, share: float, fill := BG) -> Image:
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	var k := maxi(1, floori(float(side) * share / float(maxi(mascot.get_width(), mascot.get_height()))))
	var m := mascot.duplicate() as Image
	m.resize(mascot.get_width() * k, mascot.get_height() * k, Image.INTERPOLATE_NEAREST)
	img.blend_rect(m, Rect2i(Vector2i.ZERO, m.get_size()), (Vector2i(side, side) - m.get_size()) / 2)
	return img


## The Android TV banner: the logo (mascot and word) in the middle of black. It is much smaller than the logo file, so it is
## smoothed.
func _banner(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	var logo: Image = (load("res://assets/logo/logo.png") as Texture2D).get_image()
	logo.convert(Image.FORMAT_RGBA8)
	logo = logo.get_region(logo.get_used_rect())
	var k := minf(float(w) * 0.85 / logo.get_width(), float(h) * 0.8 / logo.get_height())
	logo.resize(roundi(logo.get_width() * k), roundi(logo.get_height() * k), Image.INTERPOLATE_LANCZOS)
	img.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), (Vector2i(w, h) - logo.get_size()) / 2)
	return img
