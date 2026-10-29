extends SceneTree
## Pixel checks on real rendered frames (the render lane). It needs a GL driver and a display, so it is not in
## tests/suites.txt: the CI job `pixels` runs it under xvfb with the software driver (llvmpipe). Run it like this:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##       --script tests/pixel_render.gd -- --role=tv
## Add --resolution 3840x2160 for the 4K run (a whole number scale of 2); the screen of xvfb must be that big.
## The phones are made without a network (the
## slots are set to CONNECTED), so the run does not need port 47801.
## What it checks (docs/AUTOMATED_TESTS.md): sharp pixels, no smoothing and integer scaling (Test 16 item 2), the Car Race
## cars, obstacles, themes and HUD on the screen (Test 9 item 1), the Banana Party jungle (Test 10 item 11) and the game tiles
## (Test 12 item 2).

const Protocol = preload("res://scripts/core/protocol.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Registry = preload("res://scripts/game/registry.gd")
const RaceLook = preload("res://scripts/game/marble_race/race_look.gd")
const BananaLook = preload("res://scripts/game/snowball_splat/banana_look.gd")
const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")

const SIZE_HD := Vector2i(1920, 1080)
const SIZE_4K := Vector2i(3840, 2160)
const BAR := 112                # The black HUD bar of the games (px at 1920x1080).
const MARGIN := 60              # The TV safe margin.

var _checks := 0
var _fails := 0
var _bugs := 0
var _skips := 0
var _app: Node


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A check that fails because of a real bug that has an issue (or needs one). It counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, "  (the bug is fixed: turn this into _check)")
	else:
		_bugs += 1
		_fails += 1
		print("  FAIL (known bug) (", issue, ") ", what)


func _skip(what: String) -> void:
	_skips += 1
	print("  SKIP ", what)


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


# ---- Pictures ----

## The picture of the window now, as RGBA8.
func _capture() -> Image:
	await _frames(3)
	var img := root.get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _rgb(c: Color) -> int:
	return c.to_rgba32() | 0xff


func _px(img: Image, x: int, y: int) -> int:
	return img.get_pixel(x, y).to_rgba32() | 0xff


## The world pixels of a capture: one pixel for each block of `s` x `s` screen pixels (the pixel at the middle of the block).
func _world_of(img: Image, s: int) -> Image:
	var w := img.get_width() / s
	var h := img.get_height() / s
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			out.set_pixel(x, y, img.get_pixel(x * s + s / 2, y * s + s / 2))
	return out


## Sharp pixels: seen along rows and columns, the color changes only at the borders of a block of `s` screen pixels. A smoothed
## or shifted picture has in-between colors, so it changes inside a block. `skip` is a rectangle that is not looked at (full
## resolution text). Rows and columns are sampled (`step`). Returns the number of changes inside a block.
func _soft_edges(img: Image, s: int, area: Rect2i, skip: Rect2i, step := 3) -> int:
	var bad := 0
	for y in range(area.position.y, area.end.y, step):
		var prev := _px(img, area.position.x, y)
		for x in range(area.position.x + 1, area.end.x):
			var c := _px(img, x, y)
			if c != prev and x % s != 0 and not skip.has_point(Vector2i(x, y)):
				bad += 1
				if bad < 6:
					print("    soft edge at ", x, ",", y)
			prev = c
	for x in range(area.position.x, area.end.x, step):
		var prev := _px(img, x, area.position.y)
		for y in range(area.position.y + 1, area.end.y):
			var c := _px(img, x, y)
			if c != prev and y % s != 0 and not skip.has_point(Vector2i(x, y)):
				bad += 1
				if bad < 6:
					print("    soft edge at ", x, ",", y)
			prev = c
	return bad


## Where the opaque pixels of `sprite` fit best in `world` near `near` (the top left, world pixels), searching `radius` pixels
## around. Returns {hits, total, at}: how many opaque pixels have exactly the color of the sprite.
func _find_sprite(world: Image, sprite: Image, near: Vector2i, radius: int) -> Dictionary:
	var opaque: Array = []
	for y in sprite.get_height():
		for x in sprite.get_width():
			var c := sprite.get_pixel(x, y)
			if c.a > 0.5:
				opaque.append([x, y, _rgb(c)])
	var best := {"hits": -1, "total": opaque.size(), "at": near}
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var at := near + Vector2i(dx, dy)
			if at.x < 0 or at.y < 0 or at.x + sprite.get_width() > world.get_width() \
					or at.y + sprite.get_height() > world.get_height():
				continue
			var hits := 0
			for o in opaque:
				if _px(world, at.x + o[0], at.y + o[1]) == o[2]:
					hits += 1
			if hits > best.hits:
				best = {"hits": hits, "total": opaque.size(), "at": at}
	return best


## The pixels of `img` inside `rect` whose color is not in `allowed` (a Dictionary of rgba32 -> true). Returns {count, example}.
func _foreign(img: Image, rect: Rect2i, allowed: Dictionary) -> Dictionary:
	var count := 0
	var example := ""
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := _px(img, x, y)
			if not allowed.has(c):
				count += 1
				if example == "":
					example = "#%06x at %d,%d" % [c >> 8, x, y]
	return {"count": count, "example": example}


## The number of pixels in `rect` that have a color of `colors` (rgba32 -> true).
func _count_colors(img: Image, rect: Rect2i, colors: Dictionary) -> int:
	var n := 0
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if colors.has(_px(img, x, y)):
				n += 1
	return n


## The box around all pixels of `img` in `rect` that are not the background `bg` (rgba32). Empty when there are none.
func _ink_box(img: Image, rect: Rect2i, bg: int) -> Rect2i:
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-1, -1)
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _px(img, x, y) != bg:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return Rect2i()
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _ui_palette() -> Dictionary:
	var d := {}
	for c in [UiTheme.BG, UiTheme.TEXT, UiTheme.TEXT_DIM, UiTheme.ACCENT, UiTheme.FRAME, UiTheme.OK, UiTheme.BAD,
			UiTheme.SLOT_EMPTY]:
		d[_rgb(c)] = true
	return d


## The size of the window picture: 1920x1080 or 3840x2160 (the run is started with --resolution).
func _window() -> Vector2i:
	return root.size


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


func _start_game(id: String, props: Dictionary) -> Node:
	_app.go(Registry.load_script(id), props)
	await _frames(3)
	return _app.current_screen()


## The TextureRect that shows the low resolution world of a pixel game.
func _world_view(game: Node) -> TextureRect:
	for c in game.get_children():
		if c is TextureRect:
			return c
	return null


# ---- Test 16 item 2: sharp pixels ----

## One picture of the menu items (all roles and states) on the TV background: every pixel of every item is a color of the
## arcade palette. A text that is smoothed has gray in-between colors.
func _sharp_items(tag: String) -> void:
	var layer := ColorRect.new()
	layer.color = UiTheme.BG
	layer.size = Vector2(1920, 1080)
	layer.theme = UiTheme.make()
	root.add_child(layer)
	var kinds := {"": "Item", "danger": "Danger", "quiet": "Quiet"}
	var y := 80.0
	for role in kinds:
		var x := 80.0
		for state in ["normal", "focus", "disabled"]:
			var b: Button = UiKit.item("%s %s" % [kinds[role], state], func(): pass, UiTheme.SIZE_ITEM, role)
			b.disabled = state == "disabled"
			b.position = Vector2(x, y)
			b.custom_minimum_size = Vector2(560, 90)
			b.size = Vector2(560, 90)
			layer.add_child(b)
			if state == "focus":
				b.grab_focus()
			x += 600.0
		y += 140.0
	await _frames(5)
	var img := await _capture()
	var scale := float(img.get_width()) / 1920.0
	var pal := _ui_palette()
	var bad_total := 0
	var example := ""
	var ink_total := 0
	var ink := {_rgb(UiTheme.TEXT): true, _rgb(UiTheme.BAD): true, _rgb(UiTheme.ACCENT): true, _rgb(UiTheme.TEXT_DIM): true}
	for b in layer.get_children():
		var r: Rect2 = b.get_global_rect()
		var px := Rect2i(Vector2i((r.position * scale).round()), Vector2i((r.size * scale).round()))
		var f := _foreign(img, px, pal)
		bad_total += int(f.count)
		if example == "":
			example = String(f.example)
		ink_total += _count_colors(img, px, ink)
	_check(ink_total > 2000, "%s: the menu items have text pixels (%d)" % [tag, ink_total])
	_check(bad_total == 0, "%s: every pixel of 9 menu items is a color of the arcade palette, no smoothing (%d foreign, %s)"
			% [tag, bad_total, example])
	layer.queue_free()
	await _frames(2)


## The logo screen: the logo picture is the source picture scaled by a whole number with nearest filtering (every block is
## the color of its source pixel), and the hint text and the language names use only palette colors.
func _sharp_logo(tag: String) -> void:
	_app.go_logo()
	await _seconds(1.6)   # The logo has dropped (0.5 s), the confetti is gone (0.35 s + 0.9 s), the hint shows (0.8 s).
	var screen: Control = _app.current_screen()
	var pic: TextureRect = null
	for n in screen.find_children("*", "TextureRect", true, false):
		if n.texture != null:
			pic = n
	_check(pic != null, "%s: the logo screen has the logo picture" % tag)
	if pic == null:
		return
	var img := await _capture()
	var scale := float(img.get_width()) / 1920.0
	var src: Image = pic.texture.get_image()
	var rect: Rect2 = pic.get_global_rect()
	var fit: float = minf(rect.size.x / src.get_width(), rect.size.y / src.get_height())
	# REQ-FL-50: the file has 4x4 file pixels for each logo pixel, so that the screen shows 3x3 screen pixels (a whole number).
	var uniform := true
	for y in range(0, src.get_height(), 4):
		for x in range(0, src.get_width(), 4):
			var c := src.get_pixel(x, y)
			for d in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3)]:
				var o := src.get_pixel(x + d.x, y + d.y)
				if not (o == c or (o.a == 0.0 and c.a == 0.0)):   # the import may change the color of a clear pixel
					uniform = false
	_check(uniform and is_equal_approx(fit * 4.0 * scale, roundf(fit * 4.0 * scale)),
			"%s: a logo pixel is a whole number of screen pixels (4x4 file blocks, scale %.2f gives %.2f px per logo pixel)"
			% [tag, fit * scale, fit * scale * 4.0])
	# Nearest filter: no pixel of the logo has a color that the file does not have (a smoothed picture has in-between colors),
	# and every screen pixel is the file pixel that it is above.
	var colors := {_rgb(UiTheme.BG): true}
	for y in range(0, src.get_height(), 2):
		for x in range(0, src.get_width(), 2):
			colors[_rgb(src.get_pixel(x, y))] = true
	var drawn := Vector2(src.get_size()) * fit
	var origin := Vector2i(((rect.position + (rect.size - drawn) * 0.5) * scale).round())
	var logo_px := Rect2i(origin, Vector2i((drawn * scale).round()))
	var foreign := _foreign(img, logo_px, colors)
	_check(foreign.count == 0, "%s: the logo has no color that its file does not have, no smoothing (%d foreign, %s)"
			% [tag, foreign.count, foreign.example])
	var best := 0.0
	var step := 2
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var hits := 0
			var n := 0
			for y in range(0, logo_px.size.y, step):
				for x in range(0, logo_px.size.x, step):
					var c := src.get_pixel(clampi(int((x + 0.5) / (fit * scale)), 0, src.get_width() - 1),
							clampi(int((y + 0.5) / (fit * scale)), 0, src.get_height() - 1))
					if c.a < 0.999:
						continue
					n += 1
					if _px(img, origin.x + dx + x, origin.y + dy + y) == _rgb(c):
						hits += 1
			best = maxf(best, float(hits) / float(maxi(n, 1)))
	_check(best > 0.97, "%s: the logo on the screen is the file by nearest sampling (%.1f%% of the opaque pixels)"
			% [tag, best * 100.0])
	# The hint line and the language buttons.
	var pal := _ui_palette()
	var texts := 0
	var bad := 0
	var example := ""
	var seen_ink := 0
	var ink := {_rgb(UiTheme.TEXT_DIM): true, _rgb(UiTheme.TEXT): true, _rgb(UiTheme.ACCENT): true}
	var nodes := screen.find_children("*", "Label", true, false)
	nodes.append_array(screen.find_children("*", "Button", true, false))
	for attempt in 12:   # The hint blinks: look again until it is on.
		texts = 0
		bad = 0
		seen_ink = 0
		example = ""
		for n in nodes:
			var r: Rect2 = n.get_global_rect()
			var px := Rect2i(Vector2i((r.position * scale).round()), Vector2i((r.size * scale).round()))
			var f := _foreign(img, px, pal)
			bad += int(f.count)
			if example == "" and f.count > 0:
				example = String(f.example)
			seen_ink += _count_colors(img, px, ink)
			texts += 1
		if seen_ink > 0 or bad > 0:
			break
		await _seconds(0.15)
		img = await _capture()
	_check(texts > 0 and seen_ink > 0 and bad == 0, "%s: the logo screen texts use palette colors only (%d texts, %d foreign, %s)"
			% [tag, texts, bad, example])


## Both sizes: the screens are drawn with the same sharp pixels at 1920x1080 and at 3840x2160 (a whole number, 2).
func _sharp_ui() -> void:
	print("sharp pixels of the menus (REQ-FL-50, Test 16 item 2)")
	var tag := "%dx%d" % [_window().x, _window().y]
	await _sharp_items(tag)
	await _sharp_logo(tag)


# ---- Test 9 item 1: Car Race ----

## Puts the cars on a straight piece before the third post, like the tile picture does, and lets the camera arrive.
func _race_scene(game: Node) -> void:
	var track = game.track
	var arc: float = track.bumpers[2][0] if track.bumpers.size() > 2 else 40.0
	var slots: Array = game.participants
	for i in slots.size():
		var a := arc - 7.0 + (i % 2) * 2.2
		var side := (float(i) - (slots.size() - 1) * 0.5) * 1.5
		var r = game._racers[slots[i]]
		r.pos = track.point_at(a) + game._perp(track.dir_at(a)) * side
		r.vel = Vector2.ZERO
	await _seconds(1.6)


func _race_theme(theme: String, size: Vector2i) -> void:
	var s := size.x / 480   # Screen pixels of one world pixel.
	var k := size.x / 1920   # Screen pixels of one unit of the 1920x1080 design.
	var tag := "%s %dx%d" % [theme, size.x, size.y]
	var game: Node = await _start_game("marble_race", {"track_choice": "1", "difficulty": "hard", "race_theme": theme})
	while not game._round.is_playing():
		await process_frame   # The countdown (3 s) is over.
	await _seconds(1.0)   # GO has gone.
	await _race_scene(game)
	var look: Dictionary = RaceLook.look(theme)
	var img := await _capture()
	var world := _world_of(img, s)
	# The ground and the road have the colors of the theme, not of another one.
	var mine := {}
	for key in ["ground_a", "ground_b", "road_a", "road_b"]:
		mine[_rgb(look[key])] = true
	var area := Rect2i(0, BAR * k, size.x, size.y - BAR * k)
	var n_mine := _count_colors(img, area, mine)
	_check(n_mine > area.get_area() / 2, "%s: more than half of the world has the ground and road colors of the theme (%.0f%%)"
			% [tag, 100.0 * n_mine / area.get_area()])
	var others := {}
	for other in RaceLook.THEMES:
		if other != theme:
			for key in ["ground_a", "ground_b"]:
				others[_rgb(RaceLook.THEMES[other][key])] = true
	_check(_count_colors(img, area, others) == 0, "%s: no ground color of another theme is on the screen" % tag)
	# Sharp: color changes only at the borders of the blocks of the 480x270 view. The text at the bottom right is full resolution.
	var skip := Rect2i(size.x - 400 * k, size.y - 130 * k, 400 * k, 130 * k)
	var soft := _soft_edges(img, s, area, skip)
	_check(soft == 0, "%s: the world changes color only at the borders of its %dx%d blocks, nearest filter, whole scale (%d soft)"
			% [tag, s, s, soft])
	# The cars: each one is its sprite, in its own color, 11x16 world pixels (44x64 at 1080p), outline included.
	var body_colors := {}
	var all_cars := true
	var detail := ""
	var size_ok := true
	for slot in game.participants:
		var color: Color = game.player(slot).color
		var sprite := RaceLook.car_image(color)
		size_ok = size_ok and sprite.get_size() == Vector2i(11, 16)
		var at: Vector2i = Vector2i(game._screen(game._racers[slot].pos) / 4.0) - sprite.get_size() / 2
		var m := _find_sprite(world, sprite, at, 4)
		if m.hits != m.total:
			all_cars = false
			detail += " slot %d %d/%d" % [slot, m.hits, m.total]
		body_colors[_rgb(color)] = true
	_check(size_ok, "%s: a car sprite is 11x16 world pixels = %dx%d screen pixels" % [tag, 11 * s, 16 * s])
	_check(all_cars, "%s: every car is on the screen with all its opaque pixels in the exact sprite colors%s" % [tag, detail])
	_check(body_colors.size() == game.participants.size(), "%s: the %d cars have different colors" % [tag, game.participants.size()])
	# An obstacle of the theme: its sprite is on the screen with its own colors and size.
	var found := 0
	var tried := 0
	var fails := ""
	for i in game._bumpers.size():
		var spot: Vector2 = game._screen(game._bumpers[i])
		if spot.x < 140.0 or spot.x > 1780.0 or spot.y < 260.0 or spot.y > 940.0:
			continue
		var near_car := false
		for slot in game.participants:
			if game._screen(game._racers[slot].pos).distance_to(spot) < 120.0:
				near_car = true
		if near_car:
			continue
		var sprite := RaceLook.obstacle_image(theme, game._bumper_kinds[i])
		var m := _find_sprite(world, sprite, Vector2i(spot / 4.0) - sprite.get_size() / 2, 4)
		tried += 1
		if m.hits == m.total:
			found += 1
		else:
			fails += " %s %d/%d" % [game._bumper_kinds[i], m.hits, m.total]
	_check(tried > 0 and found == tried, "%s: %d obstacle(s) in view, each with all its pixels in the exact sprite colors%s"
			% [tag, tried, fails])
	await _race_hud(game, tag, size)
	_app.go_menu()
	await _frames(3)


## The HUD of the race, seen without the world (the pixel view is hidden): the bar, the title, the timer, the distance to the
## finish and the name of the track (9.1a, 9.1b, 9.1c).
func _race_hud(game: Node, tag: String, size: Vector2i) -> void:
	var img := await _capture_part(game, "hud")
	var k := size.x / 1920
	var bg := _rgb(UiTheme.BG)
	var title := _ink_box(img, Rect2i(0, 0, 480 * k, BAR * k), bg)
	var timer := _ink_box(img, Rect2i(500 * k, 0, 460 * k, BAR * k), bg)
	var finish := _ink_box(img, Rect2i(960 * k, 0, 960 * k, BAR * k), bg)
	_check(title.has_area() and timer.has_area() and finish.has_area(),
			"%s: the bar has the title, the timer and the distance to the finish (3 separate ink areas)" % tag)
	var title_text: String = Lang.t("registry.marble_race").to_upper()
	var title_w: float = UiTheme.font().get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x * k
	_check(absf(title.size.x - (title_w - 4.0 * k)) <= 8.0 * k,
			"%s: the title ink is as wide as the text %s: %d px, expected about %d"
			% [tag, title_text, title.size.x, int(title_w) - 4 * k])
	_check(finish.size.y >= 28 * k, "%s: the distance text is at least 28 px high (a 32 px font, %d px)" % [tag, finish.size.y])
	var plate := Rect2i(size.x - 380 * k, size.y - 100 * k, 380 * k, 100 * k)
	var name_box := _ink_box(img, plate, bg)
	_check(name_box.has_area(), "%s: the track name is in the bottom right corner" % tag)
	var track_title: String = game.track.title
	var name_w: float = UiTheme.font().get_string_size(track_title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x * k
	_check(absf(name_box.size.x - (name_w - 4.0 * k)) <= 8.0 * k,
			"%s: the track name ink is as wide as %s: %d px, expected about %d" % [tag, track_title, name_box.size.x, int(name_w) - 4 * k])
	_check(name_box.end.x <= (1920 - MARGIN) * k and name_box.end.y <= (1080 - MARGIN) * k,
			"%s: the track name is inside the 60 px margin (right %d of %d, bottom %d of %d)"
			% [tag, name_box.end.x, (1920 - MARGIN) * k, name_box.end.y, (1080 - MARGIN) * k])
	var all_hud := _ink_box(img, Rect2i(Vector2i.ZERO, size), bg)
	_check(all_hud.position.x >= MARGIN * k and all_hud.end.x <= (1920 - MARGIN) * k and all_hud.end.y <= (1080 - MARGIN) * k,
			"%s: all HUD pixels are 60 px from the left, right and bottom edge (box %s)" % [tag, str(all_hud)])


func _race() -> void:
	print("Car Race on the screen (Test 9 item 1, REQ-MR-44 to 48)")
	_fake_phones(4)
	for theme in ["candy", "space", "jungle"]:
		await _race_theme(theme, _window())


# ---- Test 10 item 11: the jungle of Banana Party ----

func _jungle() -> void:
	print("Banana Party jungle (Test 10 item 11, REQ-SS-12)")
	_fake_phones(4)
	var game: Node = await _start_game("snowball_splat", {"difficulty": "medium", "seed": 7})
	while not game._round.is_playing():
		await process_frame
	var field = game._field
	field.puffs.clear()
	field.bushes.clear()
	field._spawn_timer = 1000.0   # No new animal comes in the next seconds.
	field._bonus_timer = 1000.0
	var plan := [[0, "monkey", 520.0], [0, "lemur", 1300.0], [1, "sloth", 640.0], [1, "gorilla", 1420.0], [2, "elephant", 520.0],
			[2, "golden", 1500.0]]
	var animals: Array = []
	for p in plan:
		var a = field._add(p[0], p[1])
		a.x = p[2]
		a.age = 0.0   # The bob of the step is zero: the animal stands on the line of its lane.
		animals.append(a)
	game.set_process(false)   # Freeze the picture.
	game._request_redraw()
	await _frames(3)
	var shot := await _capture_part(game, "world")
	var k := _window().x / 1920
	var world := _world_of(shot, 4 * k)
	var bg := _rgb(UiTheme.BG)
	# The scene is under the bar: the first 112 px of the screen are the black of the shell bar (REQ-GM-45a).
	var screen := await _capture()
	var bar_foreign := _foreign(screen, Rect2i(0, 0, 1920 * k, BAR * k), _ui_palette())
	_check(int(bar_foreign.count) == 0, "jungle: the 112 px of the HUD bar hold no world pixel (%s)" % str(bar_foreign))
	# Sky, hills, ground and lanes in the jungle colors.
	var sky := {_rgb(BananaLook.SKY_TOP): true, _rgb(BananaLook.SKY_BOTTOM): true}
	_check(_count_colors(shot, Rect2i(0, BAR * k, 1920 * k, 400 * k), sky) > 1000,
			"jungle: the sky has its first and last band color")
	for lane in 3:
		var top := int(snappedf(1080.0 * float(BananaLook.LANE_EDGES[lane]), 4.0))
		var bottom := 1080 if lane == 2 else int(snappedf(1080.0 * float(BananaLook.LANE_EDGES[lane + 1]), 4.0))
		var share := _count_colors(shot, Rect2i(0, top * k, 1920 * k, (bottom - top) * k), {_rgb(BananaLook.GROUND[lane]): true})
		_check(share > (bottom - top) * 1920 * k * k / 2, "jungle: lane %d is mostly its ground color %s (%.0f%%)"
				% [lane + 1, BananaLook.GROUND[lane].to_html(false), 100.0 * share / ((bottom - top) * 1920 * k * k)])
	var soft := _soft_edges(shot, 4 * k, Rect2i(0, BAR * k, 1920 * k, (1080 - BAR) * k), Rect2i())
	_check(soft == 0, "jungle: the world changes color only at the borders of its %dx%d blocks (%d soft)" % [4 * k, 4 * k, soft])
	# Every animal is its picture, drawn on top of the scene and nothing on top of it.
	var area: Rect2 = game._area()
	var all_ok := true
	var detail := ""
	for a in animals:
		var sprite := BananaLook.animal_image(a.kind, false, a.dir)
		var c: Vector2 = PuffField.center_of(a, area)
		var m := _find_sprite(world, sprite, Vector2i(c / 4.0) - sprite.get_size() / 2, 4)
		if m.hits != m.total:
			all_ok = false
			detail += " %s %d/%d" % [a.kind, m.hits, m.total]
	_check(all_ok, "jungle: the 6 animals (3 lanes, both ways) are on the screen with all pixels in the exact sprite colors%s"
			% detail)
	_app.go_menu()
	await _frames(3)


## The picture of the game without the HUD ("world": the game node is made clear, the pixel view stays) or without the world
## ("hud": the pixel view is hidden).
func _capture_part(game: Node, part: String) -> Image:
	var view := _world_view(game)
	if part == "world":
		game.self_modulate = Color(1, 1, 1, 0)
	else:
		view.visible = false
	var img := await _capture()
	game.self_modulate = Color.WHITE
	view.visible = true
	return img


# ---- Test 12 item 2: the tiles ----

## The colors that the tile of a game must show: main colors of the world of the game, taken from its look.
func _tile_palette() -> Dictionary:
	var p := {}
	p["marble_race"] = [RaceLook.THEMES.candy.ground_a, RaceLook.THEMES.candy.ground_b, RaceLook.THEMES.candy.road_a]
	p["snowball_splat"] = BananaLook.GROUND + [BananaLook.SKY_BOTTOM, BananaLook.SKY_TOP]
	return p


func _tiles() -> void:
	print("game tiles (Test 12 item 2, REQ-GM-49)")
	var palette := _tile_palette()
	for g in Registry.all():
		var id := String(g.id)
		var path := ProjectSettings.globalize_path("res://assets/tiles/%s.png" % id)
		var img := Image.load_from_file(path)
		_check(img != null and img.get_size() == Vector2i(640, 360), "tile %s: a 640x360 picture" % id)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var top := _dominant(img, 6)
		print("    main colors of ", id, ": ", top.map(func(c: Color): return c.to_html(false)))
		if palette.has(id):
			var near := 0
			for t in top:
				for c in palette[id]:
					if _close(t, c, 40):
						near += 1
						break
			_check(near >= 2, "tile %s: 2 of its 6 main colors are colors of the game's look (%d)" % [id, near])
		# A tile shows the world only: the first 37 rows (the HUD bar of 112 px at 1080p) are not a black bar (REQ-GM-49).
		var black := 0
		for y in 37:
			for x in range(0, 640, 2):
				if _px(img, x, y) == _rgb(UiTheme.BG):
					black += 1
		var share := 100.0 * black / (37 * 320)
		_check(share < 60.0, "tile %s: the top rows show the world, not a black HUD bar (%.0f%% black)" % [id, share])


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


# ---- Run ----

## REQ-GM-45a (issue #123): every game has the black bar at the top from the left edge to the right edge, in English and in
## Hebrew. The two columns at the edges are black over the whole height of the bar (the title and the timer start 60 units from
## the edge).
func _bars() -> void:
	var win := _window()
	var k := win.x / 1920
	for code in ["en", "he"]:
		Lang.set_language(code, root)
		var not_black := []
		for spec in Registry.all():
			_fake_phones(2)
			await _start_game(String(spec.id), {"difficulty": "medium"})
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


func _run() -> void:
	await _frames(5)
	if DisplayServer.get_name() == "headless":
		print("  FAIL this suite needs a GL driver and a display (run it under xvfb-run with --rendering-driver opengl3)")
		quit(1)
		return
	print("renderer: ", RenderingServer.get_video_adapter_name(), ", display ", DisplayServer.get_name())
	_app = root.get_node("App")
	if _app.overlay.visible:
		_app.toggle_overlay()
	var win := _window()
	if win != SIZE_HD and win != SIZE_4K:
		print("  FAIL the window must be 1920x1080 or 3840x2160 (use --resolution), it is ", win)
		quit(1)
		return
	print("window ", win)
	var probe := await _capture()
	_check(probe.get_size() == win, "the picture of the window has the size of the window: %s" % str(probe.get_size()))
	await _sharp_ui()
	await _race()
	await _jungle()
	_tiles()
	await _bars()
	print("%d checks, %d failed, %d known bugs, %d skipped" % [_checks, _fails, _bugs, _skips])
	quit(1 if _fails > 0 else 0)
