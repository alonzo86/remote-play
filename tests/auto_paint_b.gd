extends SceneTree
## Paint Grab, second part of what Test 14 checked by hand and a machine can check: a blob that really rolls over 5 free tiles
## paints them in its color and the phone is told the new count (14.4a), and a blob that rolls over the tile of another player
## makes exactly one buzz, on the phone of the player that took it (14.4c). The game is stepped by hand (`SimInput`); the two
## phones are real clients on the loopback, so the count on the phone is the message that the phone got. Run:
##   godot --headless --path . --script tests/auto_paint_b.gd -- --role=tv
## The motor of a real phone is Test 18.

const SimInput = preload("res://tests/sim_input.gd")
const PaintLook = preload("res://scripts/game/paint_grab/paint_look.gd")

const DT := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _app: Node
var _game_script: GDScript
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


## A game of Paint Grab in play (the countdown is over), stepped by hand. All phones are held flat.
func _play(difficulty := "medium", seed_value := 7) -> Control:
	for p in _app.server.players:
		SimInput.set_tilt(p, Vector2.ZERO)
	var game := SimInput.start_game(_app, _game_script, {"difficulty": difficulty, "seed": seed_value})
	game._picture.fill(1)   # These checks are about rolling and painting: every tile is a picture tile (REQ-PG-24 has its own test).
	game._picture_total = game._picture.size()
	SimInput.to_play(game, func() -> bool: return game._round.is_counting())
	return game


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_game_script = load("res://scripts/game/paint_grab/paint_grab_game.gd")
	_clients = await SimInput.connect_phones(self, _app, 2)
	_check(_app.server.connected_slots().size() == 2, "2 simulated phones joined")
	await _five_free_tiles()
	await _take_by_rolling()
	for c in _clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## 14.4a: roll over 5 free tiles. Each of the 5 tiles belongs to the blob and is drawn in the hue of its color (the hidden picture
## makes a tile lighter or darker, never another color, REQ-PG-22), and the count on the phone goes from 0 to 5 (REQ-PG-4, 13).
func _five_free_tiles() -> void:
	print("rolling over 5 free tiles")
	var game := _play()
	game._bodies.erase(1)   # The second blob stays out of the way.
	await _frames(15)
	var before: String = _clients[0].score_text
	var body = game._bodies[0]
	body.pos = Vector2(50.0, 350.0)   # The middle of the tile (0, 3).
	body.vel = Vector2.ZERO
	SimInput.set_tilt(_app.server.players[0], Vector2(0.5, 0.0))
	var steps := 0
	while game.floor_map.count(0) < 5 and steps < 600:
		game._process(DT)
		steps += 1
	await _frames(15)
	var after: String = _clients[0].score_text
	var color: Color = game.player(0).color
	var other: Color = game.player(1).color
	var owned := true
	var hue_ok := true
	for c in 5:
		owned = owned and game.floor_map.owner_of(Vector2i(c, 3)) == 0
		var part: int = game._picture[3 * game.floor_map.cols + c]
		var shown: Color = PaintLook.painted(part, color)
		hue_ok = hue_ok and absf(shown.h - color.h) < 0.01 and absf(shown.h - other.h) > 0.05
	_check(owned and game.floor_map.count(0) == 5 and steps < 600,
			"after rolling over 5 free tiles the tiles (0..4, 3) are the tiles of the blob, and it has exactly 5 (%d frames)" % steps)
	_check(hue_ok, "each of the 5 tiles is drawn in the hue of the blob, not in the hue of the other blob")
	_check(before == "0" and after == "5" and _clients[0].score_rank == 1,
			"the count on the phone goes from '%s' to '%s' (place %d)" % [before, after, _clients[0].score_rank])


## 14.4c: the blob of player 0 rolls over free tiles and then over a tile of player 1. Exactly one buzz of 20 ms comes, on the
## phone of player 0 (the one that took the tile) and none on the phone of player 1. A free tile buzzes nobody.
func _take_by_rolling() -> void:
	print("taking a tile by rolling")
	var game := _play()
	var rec := SimInput.record_haptics(game)
	var a = game._bodies[0]
	var b = game._bodies[1]
	b.pos = (Vector2(5, 3) + Vector2(0.5, 0.5)) * 100.0
	b.vel = Vector2.ZERO
	a.pos = Vector2(60.0, 750.0)   # A free tile far away.
	a.vel = Vector2.ZERO
	game._process(DT)   # Player 1 paints the tile (5, 3).
	b.pos = Vector2(1450.0, 850.0)
	a.pos = Vector2(250.0, 350.0)   # The middle of the tile (2, 3), then to the right over (3, 3), (4, 3), (5, 3) and (6, 3).
	a.vel = Vector2.ZERO
	var owner_before: int = game.floor_map.owner_of(Vector2i(5, 3))
	SimInput.set_tilt(_app.server.players[0], Vector2(0.5, 0.0))
	SimInput.run_until(game, func() -> bool: return a.pos.x >= 750.0, 5.0)
	_check(owner_before == 1 and game.floor_map.owner_of(Vector2i(5, 3)) == 0 and game.floor_map.owner_of(Vector2i(6, 3)) == 0,
			"the tile (5, 3) was the tile of player 1 and now it is the tile of the blob that rolled over it")
	_check(rec.log == [[0, 20]], "exactly one buzz of 20 ms came, on the phone that took the tile, none on the other: %s"
			% str(rec.log))
