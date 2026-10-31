extends SceneTree
## The sprite outline that the look files of the games share (issue #294): one pixel of the given color around the colored
## pixels, never inside the picture, never at a corner, and the picture itself is not changed.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/pixel_art.gd -- --role=tv

const PixelArt = preload("res://scripts/game/pixel_art.gd")

const LINE := Color("101018")
const RED := Color("ff0000")

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
	_single_pixel()
	_shapes()
	_untouched()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _single_pixel() -> void:
	print("one pixel")
	var src := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	src.set_pixel(0, 0, RED)
	var out := PixelArt.outlined(src, LINE)
	_check(out.get_size() == Vector2i(3, 3), "the picture is 2 pixels wider and higher")
	_check(out.get_pixel(1, 1) == RED, "the colored pixel keeps its color")
	var plus := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]
	var ok := true
	for p in plus:
		ok = ok and out.get_pixelv(p) == LINE
	_check(ok, "the 4 neighbors (left, right, up, down) get the line")
	var corners := true
	for p in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]:
		corners = corners and out.get_pixelv(p).a == 0.0
	_check(corners, "the corners stay empty")


func _shapes() -> void:
	print("a ring and a hole")
	# A 3 x 3 ring of red with an empty middle: the middle pixel touches colored pixels, so it gets the line too.
	var src := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	for y in 3:
		for x in 3:
			if x != 1 or y != 1:
				src.set_pixel(x, y, RED)
	var out := PixelArt.outlined(src, LINE)
	_check(out.get_pixel(2, 2) == LINE, "an empty pixel inside the picture with colored neighbors gets the line")
	_check(out.get_pixel(1, 1) == RED and out.get_pixel(3, 3) == RED, "the colored pixels keep their color")
	# The line is one pixel wide: a pixel two steps away from the color stays empty.
	var wide := Image.create(5, 1, false, Image.FORMAT_RGBA8)
	wide.set_pixel(0, 0, RED)
	var o2 := PixelArt.outlined(wide, LINE)
	_check(o2.get_pixel(2, 1) == LINE and o2.get_pixel(3, 1).a == 0.0, "the line is one pixel wide (the line pixels do not spread)")
	# A half transparent pixel (alpha above 0) counts as colored.
	var soft := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	soft.set_pixel(0, 0, Color(1, 0, 0, 0.2))
	_check(PixelArt.outlined(soft, LINE).get_pixel(0, 1) == LINE, "a pixel with a little alpha counts as colored")
	var empty := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	var o3 := PixelArt.outlined(empty, LINE)
	var any := false
	for y in 4:
		for x in 4:
			any = any or o3.get_pixel(x, y).a > 0.0
	_check(not any, "an empty picture has no line")


func _untouched() -> void:
	print("the source")
	var src := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	src.set_pixel(0, 0, RED)
	var before := src.get_data()
	PixelArt.outlined(src, LINE)
	_check(src.get_data() == before and src.get_size() == Vector2i(2, 2), "the source picture is not changed")
