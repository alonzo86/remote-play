extends SceneTree
## Personal bests (FD-22, REQ-GM-98 to 101): which game has a key, what a finished round sends to a phone with a profile, and
## what a phone does with it. Run by tests/run_all.sh and tools/coverage.sh:
##   godot --headless --path . --script tests/smoke_bests.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")

const ID_A := "9f2c4e7a1b3d5f60718293a4b5c6d7e8"
const ID_B := "00112233445566778899aabbccddeeff"
const PATH := "user://test_bests.cfg"

var _checks := 0
var _fails := 0
var _app: Node


func _initialize() -> void:
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## Games need the App autoload, so the scripts are loaded when a test runs, not when this file is read.
func _paint() -> GDScript:
	return load("res://scripts/game/paint_grab/paint_grab_game.gd")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	await _keys()
	await _round()
	_store()


## The key of each game (REQ-GM-98). The games are made but not played.
func _keys() -> void:
	print("the key of each game")
	var paint_game = _paint()
	var Snow = load("res://scripts/game/snowball_splat/snowball_splat_game.gd")
	var Race = load("res://scripts/game/marble_race/marble_race.gd")
	var Maze = load("res://scripts/game/maze/maze_game.gd")
	var Sumo = load("res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd")
	var Blast = load("res://scripts/game/asteroid_blast/asteroid_blast_game.gd")
	var keys := {}
	_app.go(Snow, {"difficulty": "hard"})
	await _frames(2)
	keys.snow = _app.current_screen().best_key()
	_app.go(paint_game, {"difficulty": "easy"})
	await _frames(2)
	keys.paint = _app.current_screen().best_key()
	_check(keys.snow == "snowball_splat|hard" and keys.paint == "paint_grab|easy",
			"Snowball Splat and Paint Grab use the game and the difficulty")
	_app.go(Blast, {"difficulty": "hard"})
	await _frames(2)
	keys.blast = _app.current_screen().best_key()
	_check(keys.blast == "asteroid_blast|hard", "Galaxy Protector uses the game and the difficulty (REQ-AB-18)")
	_app.go(Race, {"difficulty": "medium", "track_seed": 42})
	await _frames(2)
	var race: Control = _app.current_screen()
	keys.race = race.best_key()
	_check(race.best_key() == "marble_race|medium|4" and race.best_value(41.2344) == 41234,
			"a fixed track of the race has a key with its number, and a time is saved in milliseconds")
	_app.go(Race, {"difficulty": "hard", "track_seed": 123456})
	await _frames(2)
	_check(_app.current_screen().best_key() == "", "a random track has no key (REQ-MR-56)")
	_app.go(Maze, {})
	await _frames(2)
	var maze_key: String = _app.current_screen().best_key()
	_app.go(Sumo, {})
	await _frames(2)
	_check(maze_key == "" and _app.current_screen().best_key() == "", "Treasure Maze and Sumo Bumpers have no personal best")
	var all_known := true
	for k in [keys.snow, keys.paint, keys.race, keys.blast]:
		all_known = all_known and ProfileKeys.number_of(k) > 0
	_check(all_known, "every key that a game gives is in the table of the profile code")


## A round with two profile phones and one guest: only a finished player with a profile and a score gets a result.
func _round() -> void:
	print("the result of a round")
	var paint_game = _paint()
	_app.go_games()   # Phones that join in a menu keep their profile; in a round they are guests.
	await _frames(2)
	var got := [[], [], []]
	var clients: Array = []
	for i in 3:
		var c := ControllerClient.new()
		root.add_child(c)
		if i < 2:
			c.set_profile([ID_A, ID_B][i], "Sim%d" % i, i)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		c.result_received.connect(func(key: String, v: int): got[i].append([key, v]))
		clients.append(c)
	var t0 := Time.get_ticks_msec()
	while _app.server.connected_slots().size() < 3 and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	_app.go(paint_game, {"difficulty": "medium"})
	await _frames(3)
	var game: Control = _app.current_screen()
	game._board.set_score(0, 12.0)
	game._board.set_score(1, 0.0)    # A score of 0 sends nothing.
	game._board.set_score(2, 9.0)    # A guest sends nothing.
	game.open_results(game._board)
	await _frames(20)
	_check(got[0] == [["paint_grab|medium", 12]], "a finished player with a profile gets the key and the score: %s" % str(got[0]))
	_check(got[1].is_empty(), "a score of 0 sends nothing")
	_check(got[2].is_empty(), "a guest gets nothing")
	got[0].clear()
	# The phone ignores a result for another profile and a message that is wrong.
	clients[0]._handle({"t": "result", "pid": ID_B, "key": "paint_grab|medium", "v": 50}, 0)
	clients[0]._handle({"t": "result", "pid": ID_A, "key": "", "v": 50}, 0)
	clients[0]._handle({"t": "result", "pid": ID_A, "key": "paint_grab|medium", "v": "x"}, 0)
	_check(got[0].is_empty(), "a result of another profile, with no key or with a text for a value is ignored")
	clients[2]._handle({"t": "result", "pid": "", "key": "paint_grab|medium", "v": 5}, 0)
	_check(got[2].is_empty(), "a guest phone ignores a result")
	for c in clients:
		c.leave()
		c.queue_free()
	await _frames(3)


func _store() -> void:
	print("the best of a profile")
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	var s := ProfileStore.new(PATH)
	var p = s.create("Maya", 1)
	var first := s.record_best(p.id, "paint_grab|easy", 10)
	_check(first.new_best and first.old == 0 and p.bests["paint_grab|easy"] == 10, "the first score is a new best")
	_check(not s.record_best(p.id, "paint_grab|easy", 8).new_best and p.bests["paint_grab|easy"] == 10,
			"a worse score changes nothing")
	_check(not s.record_best(p.id, "paint_grab|easy", 10).new_best, "the same score is not a new best")
	var better := s.record_best(p.id, "paint_grab|easy", 14)
	_check(better.new_best and better.old == 10 and p.bests["paint_grab|easy"] == 14,
			"a better score is a new best and tells the old one")
	s.record_best(p.id, "marble_race|easy|1", 30000)
	var race_key := "marble_race|easy|1"
	_check(s.record_best(p.id, race_key, 29000).new_best and not s.record_best(p.id, race_key, 31000).new_best
			and p.bests[race_key] == 29000, "for a race a lower time is better")
	var none := [s.record_best(p.id, "maze|easy", 5), s.record_best(p.id, "paint_grab|easy", 0),
			s.record_best(p.id, "paint_grab|easy", 4500000000), s.record_best("nobody", "paint_grab|easy", 99)]
	_check(not none.any(func(r: Dictionary) -> bool: return r.new_best),
			"an unknown key, a score of 0, a score out of range and an unknown profile change nothing")
	var again := ProfileStore.new(PATH)
	again.load_from_disk()
	_check(again.find(p.id).bests == p.bests, "the bests are saved to the file")
	_check(ProfileKeys.format("marble_race|easy|1", 12345) == "12.35 s" and ProfileKeys.format("paint_grab|easy", 340) == "340",
			"a time is shown in seconds, a score as it is")
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
