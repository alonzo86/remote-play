extends SceneTree
## Pixel checks of the four newest games on real rendered frames (the render lane, like tests/pixel_render.gd; it needs a GL
## driver and a display, so it is not in tests/suites.txt). Run it like this:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##       --script tests/pixel_games.gd -- --role=tv
## What it checks (docs/MANUAL_TESTS.md tests 22, 23, 25 and 26): the machine half of the item "put the tile next to the game
## screen" (the main colors of the tile are colors of the game screen: 1b), and for Star Shield that the edges of the ship
## and of an asteroid are steps of square pixels (22.12f). The part "the tile and the game show the same four things" stays
## manual (REQ-GM-49).

const Protocol = preload("res://scripts/core/protocol.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Shell = preload("res://scripts/game/shell.gd")

const SIZE_HD := Vector2i(1920, 1080)
const SIZE_4K := Vector2i(3840, 2160)
const BAR := 112   # The black HUD bar of the games (px at 1920x1080).

var _checks := 0
var _fails := 0
var _app: Node


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## REQ-GM-45a (issue #123): every game has the black bar at the top, from the left edge to the right edge, in English and in
## Hebrew.
## The columns at the two edges are black in the whole height of the bar (the title and the timer start 60 units from the edge).
func _bars(k: int) -> void:
	var Lang = load("res://scripts/core/lang.gd")
	for code in ["en", "he"]:
		Lang.set_language(code, root)
		var not_black := []
		for spec in Registry.all():
			_fake_phones(2)
			await _start_game(String(spec.id))
			await _seconds(0.6)
			var shot := await _capture()
			var bad := 0
			for y in range(4 * k, (BAR - 4) * k, 6):
				for x in [3 * k, shot.get_width() - 4 * k]:
					if shot.get_pixel(x, y).to_html(false) != "000000":
						bad += 1
			if bad > 0:
				not_black.append("%s (%d)" % [spec.id, bad])
			_app.go_menu()
			await _frames(3)
		_check(not_black.is_empty(), "%s: the black bar reaches both edges in every game %s" % [code, str(not_black)])
	Lang.set_language("en", root)


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _capture() -> Image:
	await _frames(3)
	var img := root.get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _px(img: Image, x: int, y: int) -> int:
	return img.get_pixel(x, y).to_rgba32() | 0xff


## The slots 0 to n-1 are phones that are present, as if they had joined (no network).
func _fake_phones(n: int) -> void:
	for i in Protocol.MAX_PLAYERS:
		var p: PlayerInput = _app.server.players[i]
		if i < n:
			p.state = PlayerInput.State.CONNECTED
			p.raw_name = "Phone %d" % (i + 1)
			p.player_name = p.raw_name
		else:
			p.state = PlayerInput.State.EMPTY


func _start_game(id: String) -> Node:
	_app.go(Registry.load_script(id), {"difficulty": "medium"})
	await _frames(3)
	return _app.current_screen()


## The number of color changes inside a block of `s` x `s` screen pixels (a smoothed or shifted picture has them).
func _soft_edges(img: Image, s: int, area: Rect2i, step := 3) -> int:
	var bad := 0
	for y in range(area.position.y, area.end.y, step):
		var prev := _px(img, area.position.x, y)
		for x in range(area.position.x + 1, area.end.x):
			var c := _px(img, x, y)
			if c != prev and x % s != 0:
				bad += 1
				if bad < 6:
					print("    soft edge at ", x, ",", y)
			prev = c
	for x in range(area.position.x, area.end.x, step):
		var prev := _px(img, x, area.position.y)
		for y in range(area.position.y + 1, area.end.y):
			var c := _px(img, x, y)
			if c != prev and y % s != 0:
				bad += 1
				if bad < 6:
					print("    soft edge at ", x, ",", y)
			prev = c
	return bad


## The `n` most common colors of an image (quantized to 5 bits a channel), as colors.
func _dominant(img: Image, n: int) -> Array[Color]:
	var counts := {}
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			var key := (int(c.r8) >> 3) << 10 | (int(c.g8) >> 3) << 5 | (int(c.b8) >> 3)
			counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var out: Array[Color] = []
	for i in mini(n, keys.size()):
		var key: int = keys[i]
		out.append(Color8(((key >> 10) & 31) * 8 + 4, ((key >> 5) & 31) * 8 + 4, (key & 31) * 8 + 4))
	return out


func _close(a: Color, b: Color, tol: int) -> bool:
	return absi(a.r8 - b.r8) <= tol and absi(a.g8 - b.g8) <= tol and absi(a.b8 - b.b8) <= tol


## 1b (the machine half): at least 3 of the 6 main colors of the tile are main colors of the game screen (the countdown).
func _tile_colors(id: String, shot: Image) -> void:
	var tile := Image.load_from_file(ProjectSettings.globalize_path("res://assets/tiles/%s.png" % id))
	if tile == null:
		_check(false, "%s: the tile file loads" % id)
		return
	tile.convert(Image.FORMAT_RGBA8)
	var tile_top := _dominant(tile, 6)
	var screen_top := _dominant(shot, 12)
	var near := 0
	for t in tile_top:
		for s in screen_top:
			if _close(t, s, 40):
				near += 1
				break
	print("    tile colors of ", id, ": ", tile_top.map(func(c: Color): return c.to_html(false)))
	print("    screen colors of ", id, ": ", screen_top.map(func(c: Color): return c.to_html(false)))
	_check(near >= 3, "%s: 3 of the 6 main colors of the tile are main colors of the game screen (%d)" % [id, near])


func _run() -> void:
	await _frames(5)
	if DisplayServer.get_name() == "headless":
		print("  FAIL this suite needs a GL driver and a display (run it under xvfb-run with --rendering-driver opengl3)")
		quit(1)
		return
	_app = root.get_node("App")
	if _app.overlay.visible:
		_app.toggle_overlay()
	var win := root.size
	if win != SIZE_HD and win != SIZE_4K:
		print("  FAIL the window must be 1920x1080 or 3840x2160 (use --resolution), it is ", win)
		quit(1)
		return
	var k := win.x / 1920
	for id in ["asteroid_blast", "bowling", "tennis", "mini_golf"]:
		print(id)
		_fake_phones(2)
		await _start_game(id)
		await _seconds(1.0)
		var shot := await _capture()
		_tile_colors(id, shot)
		if id == "asteroid_blast":
			# 12f: the ships and the asteroids are drawn in the pixel world: the color changes only at the borders of a block.
			await _seconds(2.5)
			shot = await _capture()
			var soft := _soft_edges(shot, int(Shell.WORLD_PIXEL) * k, Rect2i(0, BAR * k, 1920 * k, (1080 - BAR) * k))
			_check(soft == 0, "asteroid_blast: the world changes color only at the borders of its %dx%d blocks (%d soft)"
					% [int(Shell.WORLD_PIXEL) * k, int(Shell.WORLD_PIXEL) * k, soft])
		_app.go_menu()
		await _frames(3)
	await _bars(k)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
