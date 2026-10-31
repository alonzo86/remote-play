extends SceneTree
## The tile pictures of the Games screen (assets/tiles/<id>.png, REQ-FL-20, test 12 of docs/MANUAL_TESTS.md), read as files:
## every game has one, 16:9 and opaque, it is imported and packed in every export, and its colors are the ones of the game
## (the ground, the 4 player colors, the objects of the game). A look change that leaves a stale tile fails here; make the tiles
## again with tools/make_tiles.gd. Run:
##   godot --headless --path . --script tests/tiles.gd -- --role=controller
## It reads PNG files with `Image`, so it needs no display and no autoload.

const Protocol = preload("res://scripts/core/protocol.gd")
const Registry = preload("res://scripts/game/registry.gd")
var SumoLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var BumperLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var HockeyLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var DanceLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var BlastLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var TennisLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var GolfLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var TowerLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var BowlingLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
const MazeBoard = preload("res://scripts/game/maze/maze_board.gd")
var RaceLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var BananaLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var MoleLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).
var PaintLook: GDScript   # Loaded in _initialize: this script needs the App autoload (#276).

const TOL := 0.06   # Per channel. The tile is made from a 1920x1080 picture, scaled down, so edges are blended.

var _fails := 0
var _checks := 0


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	SumoLook = load("res://scripts/game/sumo_bumpers/sumo_look.gd")
	BumperLook = load("res://scripts/game/bumper_cars/bumper_look.gd")
	HockeyLook = load("res://scripts/game/air_hockey/air_hockey_look.gd")
	DanceLook = load("res://scripts/game/freeze_dance/dance_look.gd")
	BlastLook = load("res://scripts/game/asteroid_blast/blast_look.gd")
	TennisLook = load("res://scripts/game/tennis/tennis_look.gd")
	GolfLook = load("res://scripts/game/mini_golf/golf_look.gd")
	TowerLook = load("res://scripts/game/tower_builder/tower_look.gd")
	BowlingLook = load("res://scripts/game/bowling/bowling_look.gd")
	RaceLook = load("res://scripts/game/marble_race/race_look.gd")
	BananaLook = load("res://scripts/game/snowball_splat/banana_look.gd")
	MoleLook = load("res://scripts/game/whack_a_mole/mole_look.gd")
	PaintLook = load("res://scripts/game/paint_grab/paint_look.gd")
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## Pixels of `img` within `tol` of `c` in each channel.
func _count(img: Image, c: Color, tol := TOL) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if absf(p.r - c.r) <= tol and absf(p.g - c.g) <= tol and absf(p.b - c.b) <= tol:
				n += 1
	return n


## The share of the pixels that are near one of `colors`.
func _share(img: Image, colors: Array, tol := TOL) -> float:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			for c in colors:
				if absf(p.r - c.r) <= tol and absf(p.g - c.g) <= tol and absf(p.b - c.b) <= tol:
					n += 1
					break
	return float(n) / float(img.get_width() * img.get_height())


## Areas (pixels) of the 4-connected groups of pixels that are near `c`, the biggest first.
func _blobs(img: Image, c: Color, tol := TOL) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			var p := img.get_pixel(x, y)
			if absf(p.r - c.r) <= tol and absf(p.g - c.g) <= tol and absf(p.b - c.b) <= tol:
				mask[y * w + x] = 1
	var areas: Array = []
	for start in w * h:
		if mask[start] != 1:
			continue
		var stack: Array[int] = [start]
		mask[start] = 2
		var area := 0
		while not stack.is_empty():
			var i: int = stack.pop_back()
			area += 1
			var x := i % w
			var y := i / w
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx >= 0 and ny >= 0 and nx < w and ny < h and mask[ny * w + nx] == 1:
					mask[ny * w + nx] = 2
					stack.append(ny * w + nx)
		areas.append(area)
	areas.sort()
	areas.reverse()
	return areas


func _run() -> void:
	var ids: Array = []
	for g in Registry.GAMES:
		ids.append(g.id)
	_check(ids.size() == 15, "the registry has 15 games")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var all_resources := 0
	var excluded := false
	for line in presets.split("\n"):
		if line.begins_with("export_filter="):
			all_resources += 1 if line.contains("all_resources") else 0
		if line.begins_with("exclude_filter=") and (line.contains("assets") or line.contains("png") or line.contains("tiles")):
			excluded = true
	_check(all_resources == 5 and not excluded,
			"all 5 export presets pack all resources and exclude nothing under assets/ (the tiles are packed)")
	var images := {}
	for g in Registry.GAMES:
		var id: String = g.id
		var path: String = g.tile
		var imp := FileAccess.get_file_as_string(path + ".import")
		var img := Image.load_from_file(path)
		_check(path == "res://assets/tiles/%s.png" % id and imp.contains('importer="texture"') and imp.contains("compress/mode=0")
				and FileAccess.file_exists(path), "%s: the tile file exists and has a texture import file (lossless)" % id)
		_check(img != null and img.get_size() == Vector2i(640, 360), "%s: the tile is 640 x 360 (16:9)" % id)
		if img == null:
			continue
		images[id] = img
		var opaque := true
		for y in range(0, 360, 7):
			for x in range(0, 640, 7):
				opaque = opaque and img.get_pixel(x, y).a == 1.0
		_check(opaque, "%s: the tile has no transparent pixel" % id)
		var title := Registry.find(id)
		_check(int(title.min_players) >= 1 and int(title.max_players) <= 4 and int(title.max_players) >= int(title.min_players),
				"%s: the player range (%d to %d players) is shown under the tile" % [id, title.min_players, title.max_players])
	var pc: Array = Protocol.PLAYER_COLORS
	# Treasure Maze: 4 balls on the garden lawn with a hedge, and the chest.
	var maze: Image = images.maze
	var garden: Dictionary = MazeBoard.THEMES.garden
	_check(_share(maze, [garden.ground_a, garden.ground_b]) > 0.4 and _count(maze, garden.face) > 2000,
			"maze: the lawn of the garden is most of the picture and the hedge walls are there")
	_check(_count(maze, Color("f8b800")) > 15, "maze: the gold of the treasure chest is there")
	_players(maze, "maze", pc, 4, 30, 20)
	# Car Race: Track 1 on Hard, 4 cars on the candy road.
	var race: Image = images.marble_race
	var candy: Dictionary = RaceLook.THEMES.candy
	_check(_share(race, [candy.ground_a, candy.ground_b]) > 0.25 and _count(race, candy.road_a) > 3000
			and _count(race,
					candy.outline) > 100, "marble_race: the pink candy ground, the cream road and the dark outline of the posts")
	_players(race, "marble_race", pc, 4, 20, 8)
	# Banana Party: jungle, 4 cursors, bananas, animals.
	var banana: Image = images.snowball_splat
	_check(_share(banana, BananaLook.GROUND) > 0.3 and _count(banana, BananaLook.BANANA) > 20 and _count(banana,
			BananaLook.OUTLINE) > 200,
			"snowball_splat: the jungle ground, a banana and the black outline of an animal")
	_players(banana, "snowball_splat", pc, 4, 60, 10)
	# Paint Grab: 4 colors of paint on the floor.
	var paint: Image = images.paint_grab
	_players(paint, "paint_grab", pc, 4, 1000, 100)
	_check(_count(paint, Color("2a1070")) + _count(paint, Color("2a3a8c")) > 3000 and _count(paint, PaintLook.GOLD, 0.08) > 30,
			"paint_grab: the dark floor and the gold of the bonus pot")
	# Sumo Bumpers: the island, its rim, 4 penguins.
	var sumo: Image = images.sumo_bumpers
	_check(_share(sumo, [SumoLook.GRASS_A, SumoLook.GRASS_B]) > 0.03 and _count(sumo, SumoLook.RIM) > 100,
			"sumo_bumpers: the grass of the island and its rim")
	_players(sumo, "sumo_bumpers", pc, 4, 60, 20)
	# Bumper Cars: the steel floor, the red and white tent, gold stars, 4 cars.
	var bumper: Image = images.bumper_cars
	_check(_share(bumper, [BumperLook.FLOOR_A, BumperLook.FLOOR_B]) > 0.4 and _count(bumper, BumperLook.TENT_RED) > 200
			and _count(bumper, BumperLook.STAR_GOLD, 0.06) > 100,
			"bumper_cars: the steel floor, the red of the tent and the gold of the stars")
	_players(bumper, "bumper_cars", pc, 4, 60, 20)
	# Air Hockey: the white table with its rails and lines, a black puck, two mallets (the first two slot colors).
	var hockey: Image = images.air_hockey
	_check(_share(hockey, [HockeyLook.SURFACE]) > 0.5 and _count(hockey, HockeyLook.LINE_BLUE) > 150
			and _count(hockey, HockeyLook.LINE_RED) > 50 and _count(hockey, Color("0e0e14"), 0.03) > 30,
			"air_hockey: the white table, the blue and red lines and the black puck")
	_players(hockey, "air_hockey", pc, 2, 150, 60)
	# Freeze Dance: the dark floor with light tiles (never most of it), the mirror ball and 4 dancers in the slot colors.
	var dance: Image = images.freeze_dance
	_check(_share(dance, DanceLook.TILE_DARK + [DanceLook.HALL, DanceLook.WALL]) > 0.4 and _share(dance, [DanceLook.TILE_LIT]) > 0.08
			and _share(dance, [DanceLook.TILE_LIT]) < 0.4 and _count(dance, DanceLook.BALL, 0.05) > 30,
			"freeze_dance: a dark floor with light tiles and the mirror ball")
	_players(dance, "freeze_dance", pc, 4, 40, 15)
	# Star Shield: the night sky, 4 ships, asteroids of different sizes, a beam.
	var blast: Image = images.asteroid_blast
	var dark := 0
	for y in range(0, 360, 3):
		for x in range(0, 640, 3):
			var p := blast.get_pixel(x, y)
			dark += 1 if p.get_luminance() < 0.12 else 0
	_check(float(dark) / (120.0 * 214.0) > 0.6, "asteroid_blast: the night sky is most of the picture")
	_players(blast, "asteroid_blast", pc, 4, 60, 20)
	var rocks: Array = []
	for rc in [BlastLook.ROCK_LIGHT, BlastLook.ROCK_MID, BlastLook.ROCK_DARK]:
		rocks.append_array(_blobs(blast, rc, 0.04).filter(func(a: int) -> bool: return a >= 30))
	rocks.sort()
	_check(rocks.size() >= 3 and float(rocks[-1]) / float(rocks[0]) >= 3.0,
			"asteroid_blast: at least 3 asteroids and the biggest is 3 times the area of the smallest: %s" % str(rocks.slice(-6)))
	_check(_count(blast, BlastLook.WEAPON_COLOR, 0.08) > 10, "asteroid_blast: a beam of the weapon color")
	# Pin Pals: the lane, the pins (white), a ball.
	var bowling: Image = images.bowling
	var pins: Array = _blobs(bowling, Color("fcfcfc"), 0.06).filter(func(a: int) -> bool: return a >= 6)
	_check(_count(bowling, BowlingLook.FLOOR) > 3000 and pins.size() >= 10,
			"bowling: the lane and %d white blobs (10 pins and more)" % pins.size())
	_players(bowling, "bowling", pc, 2, 300, 50)
	# Tennis: grass, court, ball, players.
	var tennis: Image = images.tennis
	_check(_share(tennis, [TennisLook.GRASS]) > 0.1 and _share(tennis, [TennisLook.COURT, TennisLook.COURT_LIGHT]) > 0.1
			and _count(tennis, TennisLook.BALL) >= 5, "tennis: the grass, the court and the yellow ball")
	_players(tennis, "tennis", pc, 3, 100, 30)
	# Mini Golf: lawn, lake, windmill wood, ball, players.
	var golf: Image = images.mini_golf
	_check(_share(golf, [GolfLook.FAIR_A, GolfLook.FAIR_B, GolfLook.LAWN_A, GolfLook.LAWN_B]) > 0.1
			and _count(golf, GolfLook.WATER) > 3000 and _count(golf, GolfLook.WOOD) > 2000,
			"mini_golf: the fairway, the lake and the wood of the windmill")
	# The tile has no HUD chips (REQ-GM-49): only the golfer on its turn shows a player color.
	_players(golf, "mini_golf", pc, 1, 60, 20)
	# Tower Builder: the grass, the sky, the sun and the bricks of the slot colors (the tile has no HUD chips).
	var tower: Image = images.tower_builder
	_check(_share(tower, [TowerLook.GRASS_A, TowerLook.GRASS_B]) > 0.1 and _share(tower, TowerLook.SKY) > 0.2
			and _count(tower, TowerLook.SUN) > 600, "tower_builder: the sky, the sun and the grass")
	_players(tower, "tower_builder", pc, 2, 300, 60)
	# Whack-a-Mole: the lawn, the fence, the dirt of the holes, the fur of a mole and 2 rings of the players.
	var mole: Image = images.whack_a_mole
	_check(_share(mole, MoleLook.GRASS) > 0.3 and _count(mole, MoleLook.FENCE) > 100 and _count(mole, MoleLook.DIRT, 0.05) > 300
			and _count(mole, MoleLook.FUR, 0.05) > 300, "whack_a_mole: the lawn, the fence, the dirt of the holes and the fur of a mole")
	_players(mole, "whack_a_mole", pc, 2, 20, 5)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## At least `need` of the 4 player colors show with `min_px` pixels each and a blob of `min_blob` pixels or more.
func _players(img: Image, id: String, pc: Array, need: int, min_px: int, min_blob: int) -> void:
	var found := 0
	var detail: Array = []
	for i in 4:
		var n := _count(img, pc[i], 0.1)
		var blobs := _blobs(img, pc[i], 0.1)
		var ok: bool = n >= min_px and not blobs.is_empty() and blobs[0] >= min_blob
		found += 1 if ok else 0
		detail.append("%d/%d" % [n, blobs[0] if not blobs.is_empty() else 0])
	_check(found >= need, "%s: %d of the 4 player colors show (pixels/biggest blob, at least %d/%d): %s" % [id, need, min_px,
			min_blob, str(detail)])
