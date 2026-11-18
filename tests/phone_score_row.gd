extends SceneTree
## The live score row of the phone (issue #474, REQ-FL-67, REQ-FL-62): the TV sends the score as data (`k` the key and `x` the
## numbers) next to the text `v`, and the phone writes it in its own language. Run:
##   godot --headless --path . --script tests/phone_score_row.gd -- --role=controller
## Parts: (1) in every game the score is data that the phone writes in its language, TV English and phone Hebrew and the reverse;
## (2) a TV of an older build (only `v`) and data that is not valid keep `v`; (3) the message over a real TV server.

const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Lang = preload("res://scripts/core/lang.gd")
const ResultText = preload("res://scripts/core/result_text.gd")
const STUB_HOST := "res://tests/stub_game_host.gd"

var PORT := 47000 + OS.get_process_id() % 900
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
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _wait_until(cond: Callable, max_ms := 3000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _run() -> void:
	await process_frame
	await _every_game()
	_old_tv_and_bad_data()
	await _over_the_wire()


## The `score` message as a phone reads it: through JSON, so the numbers are floats as on the wire.
func _wire(rank: int, of: int, text: String, spec: Array) -> Dictionary:
	var msg := {"t": "score", "rank": rank, "of": of, "v": text}
	if spec.size() == 2:
		msg["k"] = String(spec[0])
		msg["x"] = spec[1]
	return JSON.parse_string(JSON.stringify(msg))


## Every game, both ways: the row on the phone is the score of the game in the language of the phone, the chip text of the TV is
## in the language of the TV, and `k` is a key that the phone accepts.
func _every_game() -> void:
	print("the score row is written in the language of the phone, in every game")
	var bad: Array[String] = []
	var units := {}
	var data_games := 0
	for pair in [["en", "he"], ["he", "en"]]:   # [language of the TV, language of the phone]
		for g in Registry.all():
			var host = load(STUB_HOST).new()
			var slots: Array[int] = [0, 1, 2]
			host.slots = slots
			var game = load(String(g.path)).new()
			game.game_host = host
			root.add_child(game)
			game.visible = false
			if game._pixel_layer != null:
				game._pixel_layer.visible = false
			await process_frame
			if String(g.id) == "mini_golf":
				game.rules.setup(slots, 3)   # Mini Golf: the strokes of the row.
			for entry in [{"slot": 0, "score": 3.0, "rank": 1, "finished": true},
					{"slot": 1, "score": 1.0, "rank": 2, "finished": true}, {"slot": 2, "score": 0.0, "rank": 3, "finished": false}]:
				Lang.set_language(pair[0])
				var tv_text: String = game._score_label(entry)
				var spec: Array = game._score_spec(entry)
				Lang.set_language(pair[1])
				var c := ControllerClient.new()
				c._handle(_wire(entry.rank, 3, tv_text, spec), Time.get_ticks_msec())
				var want := ResultText.spec_text(spec) if spec.size() == 2 else ""
				if not entry.finished and (spec.size() != 0 or tv_text != ""):
					bad.append("%s: an unfinished player has a score %s / %s" % [g.id, tv_text, str(spec)])
				if entry.finished and spec.size() == 2:
					data_games += 1
					if not ResultText.KINDS.has(String(spec[0])) or want == "":
						bad.append("%s sends the key %s that the phone cannot write" % [g.id, str(spec)])
					if c.score_text != want:
						bad.append("%s %s>%s: the phone shows '%s', wanted '%s'" % [g.id, pair[0], pair[1], c.score_text, want])
					if tv_text != want and c.score_text == tv_text:   # Only a score that differs by language (a unit).
						bad.append("%s %s>%s: the phone shows the text of the TV '%s'" % [g.id, pair[0], pair[1], tv_text])
					Lang.set_language(pair[0])
					if ResultText.spec_text(spec) != tv_text:
						bad.append("%s: the chip of the TV '%s' is not the text of its data" % [g.id, tv_text])
					Lang.set_language(pair[1])
					if pair[1] == "he" and String(spec[0]) != "num":
						units[String(g.id)] = c.score_text
				elif entry.finished and c.score_text != tv_text.substr(0, 12):
					bad.append("%s: no data, the phone must show v: '%s'" % [g.id, c.score_text])
				c.free()
			Lang.set_language("en")
			game.queue_free()
			await process_frame
	_check(bad.is_empty(), "every game: the phone writes the score of its data, the chip stays in the TV language: %s" % str(bad))
	_check(data_games > 0 and units.has("marble_race") and String(units.get("marble_race", "")).ends_with("ש׳"),
			"the race time on a Hebrew phone ends with the Hebrew unit: %s" % str(units.get("marble_race", "")))
	var latin: Array = []
	for id in units:
		for english in [" s", "BRICK", "GOAL", "sheep", "point", "star"]:
			if String(units[id]).contains(english):
				latin.append(id)
	_check(latin.is_empty(), "a Hebrew phone shows no English unit in the score row: %s" % str(units))


## An older TV (only `v`) and data that is not valid: the phone keeps `v` and no value is a script error.
func _old_tv_and_bad_data() -> void:
	print("an old TV and bad data keep v")
	Lang.set_language("he")
	var c := ControllerClient.new()
	var now := Time.get_ticks_msec()
	c._handle({"t": "score", "rank": 1, "of": 2, "v": "4.22 s"}, now)
	_check(c.score_text == "4.22 s", "a TV of an older build (only v): the phone shows v as it comes")
	c._handle({"t": "score", "rank": 1, "of": 2, "v": "4.22 s", "k": "result.seconds_2", "x": [4.22]}, now)
	_check(c.score_text == Lang.f("result.seconds_2", [4.22]) and c.score_text != "4.22 s",
			"valid data: the phone writes the time in Hebrew: %s" % c.score_text)
	c._handle({"t": "score", "rank": 1, "of": 2, "v": "2 / 7", "k": "mini_golf.leader_score", "x": [2, 7]}, now)
	_check(c.score_text == Lang.f("mini_golf.leader_score", [2, 7]), "Mini Golf strokes: %s" % c.score_text)
	for bad in [{"k": "nope", "x": [1]}, {"k": "result.seconds_2", "x": []}, {"k": "sheep_herding.count", "x": [1]},
			{"k": "result.seconds_2", "x": "4"}, {"k": "result.seconds_2", "x": {"a": 1}}, {"k": "result.seconds_2", "x": ["a"]},
			{"k": "result.seconds_2", "x": [null]}, {"k": 5, "x": [1]}, {"k": ["num"], "x": [1]}, {"k": "num"}, {"x": [1]},
			{"k": "result.seconds_2", "x": [INF]}, {"k": "result.seconds_2", "x": [NAN]}, {"k": "x".repeat(100000), "x": [1]},
			{"k": "result.points", "x": [[1]]}]:
		var msg := {"t": "score", "rank": 1, "of": 2, "v": "7 s"}
		msg.merge(bad)
		c._handle(msg, now)
		_check(c.score_text == "7 s", "invalid data keeps v: %s" % str(bad).left(60))
	# A huge number is no error and no long text; too many numbers are cut to the first two.
	for k in ["result.seconds_1", "result.seconds_2", "result.points", "num", "mini_golf.leader_score", "paint_grab.percent"]:
		c._handle({"t": "score", "rank": 1, "of": 2, "v": "x", "k": k, "x": [1.0e300, 1.0e300, 5, 6, 7]}, now)
		_check(c.score_text.length() <= 60 and not c.score_text.contains("\n"),
				"%s with 1e300: at most 60 characters: %d" % [k, c.score_text.length()])
	c._handle({"t": "score", "rank": 1, "of": 2, "v": "x", "k": "result.points", "x": [3, 5, 6, 7, 8]}, now)
	_check(c.score_text == Lang.f("result.points", [3]), "too many numbers: the first ones are used")
	c.free()
	Lang.set_language("en")


## A real TV server and phone: the TV in English, the phone in Hebrew.
func _over_the_wire() -> void:
	print("the score row over a real TV server")
	var app: Node = root.get_node("App")
	var client: ControllerClient = app.client
	var server := TvServer.new()
	server.port = PORT
	root.add_child(server)
	server.start({})
	server.set_phase("menu")
	client.connect_to("127.0.0.1", PORT, server.room_code)
	await _wait_until(func(): return client.state == ControllerClient.State.CONNECTED)
	server.set_phase("playing")
	await _wait_until(func(): return client.phase == "playing")
	var slot: int = client.slot
	Lang.set_language("he")
	server.send_score(slot, 1, 2, "4.22 s", ResultText.spec("result.seconds_2", [4.22]))
	await _wait_until(func(): return client.score_text != "")
	_check(client.score_text == Lang.f("result.seconds_2", [4.22]) and client.score_text != "4.22 s" and client.score_rank == 1
			and client.score_of == 2, "over the wire the Hebrew phone writes the time in Hebrew: %s" % client.score_text)
	_check(server._score_sent[slot].get("k") == "result.seconds_2" and server._score_sent[slot].get("v") == "4.22 s",
			"the message has the data and v")
	server.send_score(slot, 1, 2, "9", [])   # No data: no k and no x, v only.
	await _wait_until(func(): return client.score_text == "9")
	_check(not server._score_sent[slot].has("k") and not server._score_sent[slot].has("x") and client.score_text == "9",
			"a score without data sends v only and the phone shows it")
	Lang.set_language("en")
	client.leave()
	server.stop()
	server.queue_free()
