extends SceneTree
## Sumo Bumpers, second part of what Test 15 checked by hand and a machine can check (REQ-SB-8, 11, 15): a slow touch and a fast
## hit between two real bumpers (the buzz of the phones), the drift of the clouds in 10 s of game time, the body colors of the
## penguins as the 4 slot colors, and the world view that is made of whole, sharp pixels at 1080p and at 4K. The game is stepped
## by hand (`SimInput`), so the result does not depend on the speed of the machine. Run:
##   godot --headless --path . --script tests/auto_sumo_b.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const SumoLook = preload("res://scripts/game/sumo_bumpers/sumo_look.gd")
const SumoArena = preload("res://scripts/game/sumo_bumpers/sumo_arena.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _app: Node
var _sumo: GDScript
var _clients: Array = []


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A match in play (round 1, the countdown is over), stepped by hand. All phones are held flat.
func _play(difficulty := "medium") -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	var game := SimInput.start_game(_app, _sumo, {"difficulty": difficulty})
	SimInput.to_play(game, func() -> bool: return game.phase == game.Phase.COUNT)
	return game


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_sumo = load("res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd")
	_clients = await SimInput.connect_phones(self, _app, 3)
	_check(_app.server.connected_slots().size() == 3, "3 simulated phones joined")
	_slow_and_fast_touch()
	_clouds_in_ten_seconds()
	_penguin_body_colors()
	await _sharp_view()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## 15.4b: two bumpers that roll into each other, once slowly (about 100 px/s) and once fast (400 px/s): the slow touch buzzes
## nobody, the fast hit buzzes both of them once and the third phone never (REQ-SB-8: the limit is 300 px/s). The bumpers
## really collide (the game steps them), nothing is called by hand but the start speed. The real motor of a phone is Test 18.
func _slow_and_fast_touch() -> void:
	print("a slow touch and a fast hit")
	for case in [[100.0, 0], [400.0, 1]]:
		var game := _play()
		var a = game._bodies[0]
		var b = game._bodies[1]
		a.pos = Vector2(-40.0, 0.0)   # 80 px between the middles, the bumpers touch at 68 px (two radii).
		b.pos = Vector2(40.0, 0.0)
		a.vel = Vector2(case[0], 0.0)
		b.vel = Vector2.ZERO
		game._bodies[2].pos = Vector2(0.0, 250.0)   # The third bumper stays out of the way.
		game._bodies[2].vel = Vector2.ZERO
		var rec := SimInput.record_haptics(game)
		var seen := {"push": 0.0}   # A lambda gets a copy of a plain variable, so the result goes in a Dictionary.
		SimInput.run(game, 0.5, DT, func(_t: float) -> void:
			seen.push = maxf(seen.push, b.vel.length()))
		var hit_speed: float = seen.push
		_check(hit_speed > 0.3 * float(case[0]) and a.pos.distance_to(b.pos) >= 2.0 * SumoArena.BUMPER_R - 0.01
				and game._alive.size() == 3,
				"a bumper that rolls at %.0f px/s into a bumper that stands pushes it (it reached %.0f px/s) and nobody falls"
				% [case[0], hit_speed])
		if case[1] == 0:
			_check(rec.log.is_empty(), "the slow touch (%.0f px/s) buzzes nobody: %s" % [case[0], str(rec.log)])
		else:
			_check(rec.ms_of(0) == [20] and rec.ms_of(1) == [20] and rec.ms_of(2).is_empty() and rec.log.size() == 2,
					"the fast hit (%.0f px/s) buzzes both phones once for 20 ms and the third phone never: %s" % [case[0],
							str(rec.log)])


## 15.11c: after 10 seconds of game time every cloud has moved to the right, and the fastest one by 4 % to 6.5 % of the view
## (REQ-SB-15: 2 to 3 world pixels per second, the view is 480 world pixels wide). The slowest cloud (1.5) is a known bug that
## `tests/auto_sumo.gd` lists.
func _clouds_in_ten_seconds() -> void:
	print("the clouds after 10 s")
	var game := _play()
	var before: float = game._sky_time
	SimInput.run(game, 10.0)
	var passed: float = game._sky_time - before
	_check(absf(passed - 10.0) < 0.05, "the sky clock advanced %.2f s in 10 s of game time" % passed)
	var shares: Array = []
	for i in SumoLook.CLOUDS.size():
		var span := SumoLook.VIEW_W + float(SumoLook.CLOUDS[i][2]) * 2.0
		var moved := fposmod(SumoLook.cloud_x(i, game._sky_time) - SumoLook.cloud_x(i, before), span)   # To the right, with the wrap.
		shares.append(100.0 * moved / SumoLook.VIEW_W)
	var in_range := 0
	var too_fast := 0
	for s in shares:
		in_range += 1 if s >= 4.0 and s <= 6.5 else 0
		too_fast += 1 if s > 6.5 else 0
	_check(in_range >= 1 and too_fast == 0,
			"in 10 s at least one cloud moved by 4 %% to 6.5 %% of the view width and none moved more: %s" % str(shares.map(
					func(s: float) -> String: return "%.1f" % s)))


## The most common color of the penguin of `color` that is not the belly, the beak, the white of the eye or the outline.
func _body_color_of(color: Color) -> Dictionary:
	var counts := {}
	var img: Image = SumoLook.penguin_image(color, 0)
	var opaque := 0
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a == 0.0:
				continue
			opaque += 1
			if px.is_equal_approx(SumoLook.BELLY) or px.is_equal_approx(SumoLook.BEAK) or px.is_equal_approx(SumoLook.OUTLINE):
				continue
			var key := px.to_html(false)
			counts[key] = int(counts.get(key, 0)) + 1
	var best := ""
	for key in counts:
		if best == "" or int(counts[key]) > int(counts[best]):
			best = String(key)
	return {"color": Color(best), "share": float(counts.get(best, 0)) / float(maxi(opaque, 1))}


## 15.11f: the body of each penguin is the color of its slot (red, teal, orange, blue) and it is the main color of the picture,
## so a person names the penguin by the color of the phone. The 4 colors are far apart (delta E, `auto_sumo.gd`), so the
## nearest named color of every penguin is its own.
func _penguin_body_colors() -> void:
	print("the penguin colors")
	var names := ["red", "teal", "orange", "blue"]
	var named := {}
	for i in 4:
		named[names[i]] = Protocol.PLAYER_COLORS[i]
	var all_ok := true
	var detail: Array = []
	for i in 4:
		var body := _body_color_of(Protocol.PLAYER_COLORS[i])
		var nearest := ""
		var nearest_d := 1.0e9
		for n in named:
			var d := SimInput.delta_e(body.color, named[n])
			if d < nearest_d:
				nearest_d = d
				nearest = n
		all_ok = all_ok and body.color.is_equal_approx(Protocol.PLAYER_COLORS[i]) and float(body.share) >= 0.3 and nearest == names[i]
		detail.append("%s %s %.0f %%" % [names[i], body.color.to_html(false), 100.0 * float(body.share)])
	_check(all_ok, "the main color of each penguin is its slot color, 30 %% or more of the picture, and it names itself: %s"
			% str(detail))


## 15.11e (the machine half): the world is a 480x270 view with nearest filtering that is scaled to the screen by a whole number
## (4 at 1080p, 8 at 4K), and it is not smoothed (no multisampling). Each world pixel is a square of 4x4 or 8x8 screen pixels,
## so the island, the sky and the clouds have square steps. The pixels of a real frame are `pixel_render_b.gd`.
func _sharp_view() -> void:
	print("the sharp world view")
	var game := _play()
	for res in [Vector2i(1920, 1080), Vector2i(3840, 2160)]:
		root.size = res
		await _frames(4)
		var vp: SubViewport = game._pixel_viewport
		var view: TextureRect = null
		for c in game.get_children():
			if c is TextureRect:
				view = c
		var scale := game.size.x / float(vp.size.x)
		_check(vp.size == Vector2i(480, 270) and view != null and scale == floorf(scale) and scale == float(res.x / 480)
				and game.size.y / float(vp.size.y) == scale,
				"%dx%d: the world view is 480 x 270 and scaled by the whole number %.2f" % [res.x, res.y, scale])
		_check(view != null and view.texture is ViewportTexture and view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
				and vp.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
				and vp.msaa_2d == Viewport.MSAA_DISABLED,
				"%dx%d: the view is drawn with the nearest filter and without smoothing" % [res.x, res.y])
	root.size = Vector2i(1920, 1080)
	await _frames(3)
