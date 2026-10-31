extends SceneTree
## Banana Party, second part of what Test 10 checked by hand and a machine can check: the most animals on the screen with one
## phone on each difficulty (10.10c, REQ-SS-20), the closed happy eyes of a hit animal and the own cheer of each kind (10.4c,
## REQ-SS-13), and the gold crown of the golden monkey king (10.5a, REQ-SS-25). The game is stepped by hand (`Sim`). Run:
##   godot --headless --path . --script tests/auto_banana_b.gd -- --role=tv
## What stays manual: the water, the hearts and the sparkles of the cheers are drawn directly on the screen, and the six names.

const Sim = preload("res://tests/sim_b.gd")
const PuffField = preload("res://scripts/game/snowball_splat/puff_field.gd")
const BananaLook = preload("res://scripts/game/snowball_splat/banana_look.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")

var _fails := 0
var _checks := 0
var Game
var sim


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _run() -> void:
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	Game = load("res://scripts/game/snowball_splat/snowball_splat_game.gd")
	sim = Sim.new(self)
	GameSettings.clear()
	await sim.join(1)
	sim.settle(0, Sim.FLAT)
	await _animal_limit()
	_closed_eyes()
	_cheers()
	_crown()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## Starts a round, steps out the countdown with the phone flat and returns the game at GO.
func _play(props := {}) -> Control:
	var game: Control = await sim.start(Game, props)
	var p = sim.app.server.players[0]
	sim.settle(0, Sim.FLAT)
	p.recenter()
	sim.through_countdown(game, {0: Sim.FLAT})
	return game


## 10.10c: one player alone, a whole round of 60 s on each difficulty, the animals counted at every frame (the golden monkey does
## not count): never more than 5 on Easy, 4 on Medium and 3 on Hard, and that number is reached at least once (REQ-SS-20: the
## base 4, 3, 2 plus one player). The numbers are written here on purpose, not read from `PuffField.LEVELS`.
func _animal_limit() -> void:
	print("banana: the most animals with 1 player")
	var limits := {"easy": 5, "medium": 4, "hard": 3}
	for d in limits:
		var game: Control = await _play({"seed": 3, "difficulty": d})
		var most := 0
		var ticks := 0
		while not game.is_over and ticks < 3600:
			game._game_tick(Sim.DT)
			ticks += 1
			var regular := 0
			for a in game._field.puffs:
				if a.kind != PuffField.BONUS_KIND:
					regular += 1
			most = maxi(most, regular)
		_check(ticks >= 3590 and most <= int(limits[d]) and most == int(limits[d]),
				"%s: in %d frames (a round of 60 s) the most animals at once were %d, the limit is %d" % [d, ticks, most, limits[d]])


## Where the picture `img` has the closed eye `^`: the pixels (x, y + 1), (x + 1, y) and (x + 2, y + 1) are the black outline.
func _is_caret(img: Image, x: int, y: int) -> bool:
	for p in [Vector2i(x, y + 1), Vector2i(x + 1, y), Vector2i(x + 2, y + 1)]:
		var c := img.get_pixelv(p)
		if c.a < 1.0 or not c.is_equal_approx(BananaLook.OUTLINE):
			return false
	return true


## 10.4c: the picture of a hit animal has closed eyes `^` (3 pixels of the black outline for each eye) in the places where the
## animal that is not hit has open eyes. The monkeys, the orangutan, the sloth and the gorilla have two eyes, the lemur and the
## elephant show one (REQ-SS-13).
func _closed_eyes() -> void:
	print("banana: closed eyes")
	var eyes := {"monkey": 2, "lemur": 1, "orangutan": 2, "sloth": 2, "gorilla": 2, "elephant": 1, "golden": 2}
	var detail: Array = []
	var all_ok := true
	for kind in eyes:
		var open: Image = BananaLook.animal_image(kind, false, 1)
		var happy: Image = BananaLook.animal_image(kind, true, 1)
		var found := 0
		var same_size: bool = open.get_size() == happy.get_size()
		if same_size:
			for y in happy.get_height() - 1:
				for x in happy.get_width() - 2:
					if _is_caret(happy, x, y) and not _is_caret(open, x, y):
						found += 1
		detail.append("%s %d" % [kind, found])
		all_ok = all_ok and same_size and found >= int(eyes[kind])
	_check(all_ok, "a hit animal has a closed eye ^ that the open picture has not, for each of the 7 kinds: %s" % str(detail))


## 10.4c: the gorilla shakes, the sloth wiggles slowly, the lemur turns on the spot, the others stand where they are
## (the hit animation lasts 1 s, REQ-SS-13).
func _cheers() -> void:
	print("banana: the cheers")
	# The gorilla: a fast shake of 8 px to one side and the other, only in the middle of the animation.
	var flips := 0
	var last_sign := 0.0
	var peak := 0.0
	var outside_zero := true
	for i in 100:
		var age := float(i) * 0.01
		var pose: Dictionary = Game.cheer_pose("gorilla", age, age / Game.HIT_LIFE, 1)
		var dx: float = pose.dx
		if age <= 0.4 or age >= 0.8:
			outside_zero = outside_zero and dx == 0.0
		if dx != 0.0:
			peak = maxf(peak, absf(dx))
			if last_sign != 0.0 and signf(dx) != last_sign:
				flips += 1
			last_sign = signf(dx)
	_check(outside_zero and absf(peak - 8.0) < 0.001 and flips >= 4,
			"the gorilla shakes by 8 px, only between 0.4 s and 0.8 s, and changes the side %d times (4 or more)" % flips)
	# The sloth: a slow wiggle of 10 px, a side change about every 0.35 s.
	flips = 0
	last_sign = 0.0
	peak = 0.0
	for i in range(1, 100):
		var age := float(i) * 0.01
		var dx: float = Game.cheer_pose("sloth", age, age / Game.HIT_LIFE, 1).dx
		peak = maxf(peak, absf(dx))
		if signf(dx) != last_sign and last_sign != 0.0:
			flips += 1
		last_sign = signf(dx) if dx != 0.0 else last_sign
	_check(peak > 9.9 and peak <= 10.001 and flips >= 1 and flips <= 2,
			"the sloth wiggles by 10 px and changes the side only %d times in 1 s (slow: 2 at most)" % flips)
	# The lemur: after 0.4 s it faces the other way every 0.1 s, and it does not move sideways.
	var d1: Dictionary = Game.cheer_pose("lemur", 0.35, 0.35, 1)
	var d2: Dictionary = Game.cheer_pose("lemur", 0.45, 0.45, 1)
	var d3: Dictionary = Game.cheer_pose("lemur", 0.55, 0.55, 1)
	var d4: Dictionary = Game.cheer_pose("lemur", 0.65, 0.65, 1)
	var d5: Dictionary = Game.cheer_pose("lemur", 0.55, 0.55, -1)
	_check(d1.dir == 1 and d2.dir == 1 and d3.dir == -1 and d4.dir == 1 and d5.dir == 1 and d3.dx == 0.0,
			"the lemur faces right, right, left, right at 0.35, 0.45, 0.55, 0.65 s, and mirrored from the left")
	# The monkey, the orangutan, the elephant and the golden monkey stand where they are and keep their side.
	var still := true
	for kind in ["monkey", "orangutan", "elephant", "golden"]:
		for i in 11:
			var age := float(i) * 0.1
			var pose: Dictionary = Game.cheer_pose(kind, age, age / Game.HIT_LIFE, -1)
			still = still and pose.dx == 0.0 and pose.dir == -1
	_check(still, "the monkey, the orangutan, the elephant and the golden monkey do not move or turn in their cheer")


## The number of pixels of `img` in the rows `from` to `to` that are `gold` (a strong red, a good green, no blue).
func _gold_pixels(img: Image, from: int, to: int) -> int:
	var n := 0
	for y in range(from, mini(to + 1, img.get_height())):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 1.0 and c.r > 0.9 and c.g > 0.75 and c.b < 0.3:
				n += 1
	return n


## The number of pixels of `img` that have exactly the color `c`.
func _count_of(img: Image, c: Color) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).is_equal_approx(c):
				n += 1
	return n


## 10.5a (the crown): the golden monkey king that the field makes is the kind "golden" and its picture has a gold crown with a
## red and a blue jewel above the head, in the top rows. The plain monkey has none of it (REQ-SS-25).
func _crown() -> void:
	print("banana: the crown")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var field := PuffField.new()
	field.setup("medium")
	var king: PuffField.Puff = field.spawn_bonus(rng)
	_check(king != null and king.kind == "golden" and king.points == 100,
			"the bonus that the field makes is the golden monkey king with 100 points")
	var gold_img: Image = BananaLook.animal_image(king.kind if king != null else "golden", false, 1)
	var plain_img: Image = BananaLook.animal_image("monkey", false, 1)
	var crown := _gold_pixels(gold_img, 0, 2)
	_check(crown >= 12 and _gold_pixels(plain_img, 0, 2) == 0,
			"the golden monkey has %d gold pixels above the head (rows 0 to 2), the plain monkey has none" % crown)
	var jewels := _count_of(gold_img, Color("e6323c")) >= 1 and _count_of(gold_img, Color("3cb4e6")) >= 1
	_check(jewels and _count_of(plain_img, Color("e6323c")) == 0 and _count_of(plain_img, Color("3cb4e6")) == 0,
			"the crown has a red and a blue jewel, the plain monkey has none")
