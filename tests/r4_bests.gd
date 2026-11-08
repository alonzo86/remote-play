extends SceneTree
## Test 20 steps 9a to 9d and 10, the whole way from the TV to the phone: two simulated phones with a profile and one guest
## finish a round of each game that has a personal best (Banana Party, Paint Grab, Star Shield, Bowling, Car Race on a
## fixed track). The result goes over the network to each phone, the phone logic of the App (`_on_result`) keeps the best, and
## the waiting screen and the pad say NEW BEST! and BEFORE: with the old best:
##   round 1 a first score: NEW BEST!, no BEFORE (9a);
##   round 2 a worse score: no NEW BEST!, the best stays (9b);
##   round 3 a better score: NEW BEST! and BEFORE: the score of round 1 (9b, 9c; a race time in seconds);
##   the guest never sees a best (9d);
##   after a restart of the app (the file is read again, a new client, the same profile) the next better score says BEFORE: the
##   best from before the restart; the key does not name a TV (10).
## Bowling with Rails On has no best and no NEW BEST! (23.7b).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r4_bests.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")
const Lang = preload("res://scripts/core/lang.gd")

const PATHS := ["user://test_r4_bests_a.cfg", "user://test_r4_bests_b.cfg"]

## id, script, props, the key, the scores of the 3 rounds (a time in seconds for the race), the unit of the stored value.
const GAMES := [
	{"id": "snowball_splat", "path": "res://scripts/game/snowball_splat/snowball_splat_game.gd", "props": {"difficulty": "medium"},
			"key": "snowball_splat|medium", "scores": [100.0, 60.0, 130.0, 160.0], "unit": 1.0},
	{"id": "paint_grab", "path": "res://scripts/game/paint_grab/paint_grab_game.gd", "props": {"difficulty": "medium", "seed": 7},
			"key": "paint_grab|medium", "scores": [12.0, 8.0, 15.0, 18.0], "unit": 1.0, "tiles": true},
	{"id": "asteroid_blast", "path": "res://scripts/game/asteroid_blast/asteroid_blast_game.gd", "props": {"difficulty": "medium"},
			"key": "asteroid_blast|medium", "scores": [800.0, 500.0, 1200.0, 1500.0], "unit": 1.0},
	{"id": "bowling", "path": "res://scripts/game/bowling/bowling_game.gd", "props": {"difficulty": "medium"},
			"key": "bowling|medium", "scores": [120.0, 80.0, 150.0, 180.0], "unit": 1.0},
	{"id": "marble_race", "path": "res://scripts/game/marble_race/marble_race.gd",
			"props": {"difficulty": "medium", "track_seed": 42}, "key": "marble_race|medium|4",
			"scores": [41.2, 50.0, 39.5, 37.0], "unit": 1000.0},
]

var _checks := 0
var _fails := 0
var _app: Node
var _stored_of := {}   # Paint Grab: the tiles of a round -> the value stored for them (REQ-PG-31, percent of the picture).
var _rigs: Array = []   # {client, store, last_best, got}: a phone with the profile store and the message of its App
var _pad_script: GDScript


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_until(cond: Callable, max_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _clean_files() -> void:
	for p in PATHS:
		for f in [p, p + ".bak"]:
			if FileAccess.file_exists(f):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## A phone: a client with a profile (or the guest when `p_name` is empty) and its own profile store. The results that reach the
## client go through `App._on_result` with the client and the store of this phone, like on a real phone.
func _make_rig(index: int, p_name: String, path: String) -> Dictionary:
	var store := ProfileStore.new(path)
	var client := ControllerClient.new()
	root.add_child(client)
	if p_name != "":
		var p = store.create(p_name, index + 2)
		client.set_profile(p.id, p.player_name, p.avatar)
	var rig := {"client": client, "store": store, "last_best": {}, "got": []}
	client.result_received.connect(func(key: String, v: int): _deliver(rig, key, v))
	client.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
	return rig


func _deliver(rig: Dictionary, key: String, v: int) -> void:
	rig.got.append([key, v])
	var keep_client = _app.client
	var keep_profiles = _app.profiles
	var keep_best = _app.last_best
	_app.client = rig.client
	_app.profiles = rig.store
	_app.last_best = rig.last_best
	_app._on_result(key, v)
	rig.last_best = _app.last_best
	_app.client = keep_client
	_app.profiles = keep_profiles
	_app.last_best = keep_best


## What the phone shows after the round: the pad line (NEW BEST!, the score, BEFORE) and the game id above it. The waiting
## screen shows no NEW BEST! any more (REQ-GM-100): the pad shows it only while the result of the game is open, so the rig
## client is put in the phase "playing" for the look (it is joined; the result menu is open).
func _phone_shows(rig: Dictionary) -> Dictionary:
	var keep_client = _app.client
	var keep_best = _app.last_best
	var keep_phase: String = rig.client.phase
	_app.client = rig.client
	_app.last_best = rig.last_best
	rig.client.phase = "playing"
	var out := {"best": "", "detail": "", "pad": "", "game": ""}
	var best: Dictionary = _app.current_best()
	if not best.is_empty():
		out.pad = _pad_script.best_line(best)
		out.best = "NEW BEST!"
		out.detail = out.pad.trim_prefix("NEW BEST! ")
		out.game = ProfileKeys.game_of(best.key)
	rig.client.phase = keep_phase
	_app.client = keep_client
	_app.last_best = keep_best
	return out


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_pad_script = load("res://scripts/ui/controller_pad.gd")
	_clean_files()
	load("res://scripts/game/game_settings.gd").clear()
	_app.go_games()   # Phones that join in a menu keep their profile.
	await _frames(3)
	_rigs = [_make_rig(0, "Maya", PATHS[0]), _make_rig(1, "Noam", PATHS[1]), _make_rig(2, "", "user://unused.cfg")]
	await _wait_until(func(): return _app.server.connected_slots().size() == 3, 4000)
	await _frames(3)
	var players: Array = _app.server.players
	_check(players[0].has_profile() and players[1].has_profile() and not players[2].has_profile(),
			"two phones with a profile and one guest are in the room")
	for g in GAMES:
		await _game(g)
	await _restart()
	await _rails_on()
	for rig in _rigs:
		rig.client.leave()
		rig.client.queue_free()
	_clean_files()


## Starts the game and finishes it with these scores for the three phones, then waits for the results to arrive.
func _round(g: Dictionary, scores: Array) -> void:
	_app.go(load(g.path), g.props.duplicate())
	await _frames(3)
	var game: Control = _app.current_screen()
	for rig in _rigs:
		rig.last_best = {}   # A new round clears the message (the App does it when the phase turns to playing).
		rig.got.clear()
	if g.get("tiles", false):
		# Paint Grab counts tiles, the best is the percent of the picture (REQ-PG-31): ask the game (the seed fixes it).
		for sc in g.scores:
			_stored_of[sc] = game.best_value(sc)   # The key is the score; only Paint Grab fills it.
	if g.id == "marble_race":
		for s in 3:
			game._racers[s].finish_time = scores[s]
		game._open_results()
	else:
		for s in 3:
			game._board.set_score(s, scores[s])
		game.open_results(game._board)
	await _wait_until(func(): return _rigs[0].got.size() >= 1 and _rigs[1].got.size() >= 1, 3000)
	await _frames(20)


## The whole number a profile stores for a round `score` of game `g`.
func _value(g: Dictionary, score: float) -> int:
	return int(_stored_of[score]) if g.get("tiles", false) else roundi(score * float(g.unit))


func _stored(rig: Dictionary, key: String) -> int:
	var p = rig.store.profiles[0] if not rig.store.profiles.is_empty() else null
	return int(p.bests.get(key, 0)) if p != null else 0


func _game(g: Dictionary) -> void:
	print(g.id)
	var key: String = g.key
	# Round 1: a first score.
	await _round(g, [g.scores[0], g.scores[0], g.scores[0]])
	var first: int = _value(g, g.scores[0])
	var worse: int = _value(g, g.scores[1])
	var better: int = _value(g, g.scores[2])
	_check(not g.get("tiles", false) or (worse < first and first < better),
			"9: %s: the stored values keep the order of the scores (%d < %d < %d)" % [g.id, worse, first, better])
	var shown: Dictionary = await _phone_shows(_rigs[0])
	_check(_rigs[0].got == [[key, first]] and _rigs[1].got == [[key, first]],
			"9a %s: both phones with a profile get the key and the score: %s %s" % [g.id, str(_rigs[0].got), str(_rigs[1].got)])
	_check(shown.best == "NEW BEST!" and shown.detail == ProfileKeys.format(key, first),
			"9a %s: the waiting screen says NEW BEST! with the score (REQ-FL-79): '%s' '%s'" % [g.id, shown.best, shown.detail])
	_check(String(shown.pad).begins_with("NEW BEST! " + ProfileKeys.format(key, first)) and not String(shown.pad).contains("BEFORE"),
			"9a %s: the pad line has no BEFORE for a first score: '%s'" % [g.id, shown.pad])
	var shown_b: Dictionary = await _phone_shows(_rigs[1])
	_check(shown_b.best == "NEW BEST!", "9a %s: the second phone says NEW BEST! too" % g.id)
	# 9d: the guest gets nothing and shows nothing.
	var guest: Dictionary = await _phone_shows(_rigs[2])
	_check(_rigs[2].got.is_empty() and guest.best == "" and guest.detail == "" and guest.pad == "",
			"9d %s: the guest phone gets no result and shows nothing about a best" % g.id)
	# Round 2: a worse score.
	await _round(g, [g.scores[1], g.scores[1], g.scores[1]])
	shown = await _phone_shows(_rigs[0])
	_check(_rigs[0].got == [[key, worse]] and shown.best == "" and shown.detail == ""
			and _stored(_rigs[0], key) == first,
			"9b %s: a worse round (%d) says nothing and the best stays %d" % [g.id, worse, _stored(_rigs[0], key)])
	# Round 3: a better score. BEFORE is the first score.
	await _round(g, [g.scores[2], g.scores[2], g.scores[2]])
	shown = await _phone_shows(_rigs[0])
	var before := "BEFORE: " + ProfileKeys.format(key, first).to_upper()
	_check(shown.best == "NEW BEST!" and String(shown.detail).begins_with(ProfileKeys.format(key, better))
			and String(shown.detail).contains(before),
			"9b/9c %s: the next better round shows '%s' with the old best: '%s'" % [g.id, before, shown.detail])
	_check(_stored(_rigs[0], key) == better and String(shown.pad).contains(before),
			"and the phone keeps the new best %d" % better)
	if g.id == "marble_race":
		_check(String(shown.detail).contains("41.20 S") and String(shown.detail).begins_with("39.50 s"),
				"9c: the times of the race are in seconds: '%s'" % shown.detail)
	guest = await _phone_shows(_rigs[2])
	_check(_rigs[2].got.is_empty() and guest.best == "", "9d %s: the guest still shows nothing" % g.id)


## 10: close the app and open it again (the file is read again, a new client with the same profile) and play the same game.
func _restart() -> void:
	print("after a restart of the app")
	var g: Dictionary = GAMES[1]   # Paint Grab
	var key: String = g.key
	var old: int = _value(g, g.scores[2])
	var maya = _rigs[0].store.profiles[0]
	var pid: String = maya.id
	_check(key.split("|").size() == 2 and not key.contains(_app.server.room_code),
			"10: the key '%s' names the game and the level, not a TV" % key)
	# The app is closed: the phone leaves, the store object is gone.
	_rigs[0].client.leave()
	_rigs[0].client.queue_free()
	await _wait_until(func(): return not _app.server.players[0].is_present(), 3000)
	_app.go_games()   # The TV is in a menu again: a phone that joins keeps its profile.
	await _frames(3)
	var reopened := ProfileStore.new(PATHS[0])
	reopened.load_from_disk()
	_check(reopened.find(pid) != null and int(reopened.find(pid).bests.get(key, 0)) == old,
			"10: the best %d is in the file after the restart" % old)
	# The app opens again and joins (another TV: the key has no room code, so it is the same best).
	var client := ControllerClient.new()
	root.add_child(client)
	client.set_profile(pid, maya.player_name, maya.avatar)
	var rig := {"client": client, "store": reopened, "last_best": {}, "got": []}
	client.result_received.connect(func(k: String, v: int): _deliver(rig, k, v))
	client.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
	await _wait_until(func(): return _app.server.players[0].is_present() and _app.server.players[0].profile_id == pid, 4000)
	_rigs[0] = rig
	await _frames(3)
	var score: float = g.scores[3]
	await _round(g, [score, g.scores[0], g.scores[0]])
	var shown: Dictionary = await _phone_shows(rig)
	_check(shown.best == "NEW BEST!" and String(shown.detail).contains("BEFORE: " + str(old)),
			"10: the next better round says BEFORE: %d, the best from before the restart: '%s'" % [old, shown.detail])


## 23.7b: Bowling with Rails On has no key, so the phones get no result and show no NEW BEST!.
func _rails_on() -> void:
	print("Bowling with Rails On")
	var g: Dictionary = GAMES[3]
	_app.go(load(g.path), {"difficulty": "medium", "rails": "on"})
	await _frames(3)
	var game: Control = _app.current_screen()
	for rig in _rigs:
		rig.last_best = {}
		rig.got.clear()
	for s in 3:
		game._board.set_score(s, 250.0)
	game.open_results(game._board)
	await _frames(25)
	var shown: Dictionary = await _phone_shows(_rigs[0])
	_check(game.best_key() == "" and _rigs[0].got.is_empty() and _rigs[1].got.is_empty() and shown.best == "" and shown.pad == "",
			"23.7b: with Rails On no result is sent and the phone shows no NEW BEST!")
