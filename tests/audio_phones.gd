extends SceneTree
## Test 18 with simulated phones (real clients on loopback that stream sensor values and listen to the TV): the join and leave
## sounds, the music under the pause menu and under the card of a lost phone, the sounds of a result, and the haptics of the
## phone (the phone side is `Haptics.on_message`, which the pad calls; the motor call is replaced here by a recorder).
## It checks the digital side (the volume of the music player, the signals of the Sound manager, the calls of the motor), not
## how it sounds in the room (manual test 18). Run:
##   godot --headless --path . --script tests/audio_phones.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Songs = preload("res://scripts/audio/songs.gd")
const Slow = preload("res://tests/slow_run.gd")

const PAINT := "res://scripts/game/paint_grab/paint_grab_game.gd"
const MAZE := "res://scripts/game/maze/maze_game.gd"

var Haptics: GDScript
var Scoreboard: GDScript
var _checks := 0
var _fails := 0
var _seq := [0, 0]
var _clients: Array = []
var _vib: Array = []         # [ms, tick] of every call of the motor
var _arrived: Array = [[], []]   # [ms, tick] of every haptic message that reached a phone
var _sounds: Array = []      # [id, tick] of every effect that started on the TV


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


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## The first `n` phones stream `accel` for `seconds`. A phone in `silent` sends nothing.
func _stream(seconds: float, n := 2, accel := Vector3(0, 0, 9.81), silent: Array = []) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in n:
			if not silent.has(i) and is_instance_valid(_clients[i]):
				_clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO, accel,
						0, 0, Vector2.ZERO))
				_seq[i] += 1
		await _frames(1)


func _ids() -> Array:
	return _sounds.map(func(s): return s[0])


func _lean(deg: float) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(-sin(a), 0.0, cos(a)) * 9.81


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var app: Node = root.get_node("App")
	var sound: Node = root.get_node("Sound")
	Haptics = load("res://scripts/game/haptics.gd")
	Scoreboard = load("res://scripts/game/scoreboard.gd")
	load("res://scripts/game/game_settings.gd").clear()
	sound.skip_without_output = false   # The headless run has no audio device; the songs are made anyway.
	sound.sfx_played.connect(func(id: String) -> void: _sounds.append([id, Time.get_ticks_msec()]))
	Haptics.vibrate_call = func(ms: int) -> void: _vib.append([ms, Time.get_ticks_msec()])
	var old_settings: Dictionary = app.settings.duplicate()
	app.settings.haptics = true
	await _join_and_leave(app)
	await _paint_with_haptics(app, sound)
	await _pause_and_lost_phone(app, sound)
	await _results(app, sound)
	await _haptics_off(app)
	await _maze_wall(app)
	Haptics.vibrate_call = Callable()
	app.settings.merge(old_settings, true)
	app.save_settings()
	for c in _clients:
		if is_instance_valid(c):
			c.leave()


func _connect_phone(app: Node, i: int) -> void:
	var c := ControllerClient.new()
	c.player_name = "Sim%d" % i
	root.add_child(c)
	c.haptic_requested.connect(func(ms: int) -> void:
		_arrived[i].append([ms, Time.get_ticks_msec()])
		Haptics.on_message(ms))   # What the pad of the phone does with the message (REQ-FL-66).
	c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	if _clients.size() > i:
		_clients[i] = c
	else:
		_clients.append(c)
	var joined := Time.get_ticks_msec()
	while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
		await process_frame


## 18.2d: a phone that joins gives `join`, a phone that leaves gives `leave`.
func _join_and_leave(app: Node) -> void:
	app.go_games()
	await _frames(3)
	_sounds.clear()
	await _connect_phone(app, 0)
	await _wait(0.2)
	_check(_ids().count("join") == 1 and not _ids().has("leave"),
			"REQ-FL-65b: a phone that joins plays `join` once (got %s)" % str(_ids()))
	await _connect_phone(app, 1)
	await _wait(0.2)
	_sounds.clear()
	_clients[1].leave()
	await _wait(0.4)
	_check(_ids().has("leave") and not _ids().has("join"), "REQ-FL-65b: a phone that leaves plays `leave` (got %s)" % str(_ids()))
	await _connect_phone(app, 1)
	await _wait(0.2)


## 18.5a (one game), 18.6b, 18.10c: Paint Grab with Haptics ON: 3, 2, 1 and GO sound, every phone buzzes 60 ms at GO,
## and the buzz comes within 100 ms of the GO sound on loopback (the part that belongs to the app).
func _paint_with_haptics(app: Node, sound: Node) -> void:
	_sounds.clear()
	_vib.clear()
	_arrived = [[], []]
	sound._streams.erase("paint_grab")
	app.go(load(PAINT), {"difficulty": "medium"})
	await _frames(3)
	await _stream(2.5, 2)
	_check(_vib.is_empty(), "no buzz in 3, 2, 1")
	await _stream(1.5, 2)
	var beeps: Array = _ids().filter(func(id): return id == "count" or id == "go")
	_check(beeps == ["count", "count", "go"], "3, 2, 1: two count beeps, then GO (got %s)" % str(beeps))
	_check(_vib.map(func(v): return v[0]) == [60, 60], "Haptics ON: each of the 2 phones buzzes 60 ms at GO (got %s)" % str(_vib))
	var go_ms := -1
	for s in _sounds:
		if s[0] == "go":
			go_ms = s[1]
	var worst := 0
	for v in _vib:
		worst = maxi(worst, absi(int(v[1]) - go_ms))
	_check(go_ms > 0 and worst <= 100, "the buzz comes within 100 ms of the GO sound (%d ms on loopback)" % worst)
	await _stream(3.0, 2, _lean(20.0))
	var game: Control = app.current_screen()
	_check(not game.is_over and _clients[0].score_of == 2,
			"the game runs and the phones get their place (%d of %d)" % [_clients[0].score_rank, _clients[0].score_of])


## Waits until the song of the game plays (and the fade-in is over). The phones keep streaming.
func _wait_music(sound: Node, id: String) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		if sound._music.playing and sound.wanted_music == id and sound._music.volume_db > -1.0:
			return true
		await _stream(0.1, 2)
	return false


## 18.7a, 7b, 7c: the pause menu and the card of a lost phone lower the music by 8 to 13 dB; Resume brings it back in a ramp.
func _pause_and_lost_phone(app: Node, sound: Node) -> void:
	var game: Control = app.current_screen()
	_check(await _wait_music(sound, "paint_grab"), "the song of the game plays after GO")
	var full: float = sound._music.volume_db
	var bus_before := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	# 7a: OK does nothing in the game (issue #228); the pause menu is opened by code.
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _stream(0.5, 2)
	_check(not game.is_paused(), "OK in the game does nothing")
	game.open_menu("minigame.end_game_ask", game.pause_entries())
	await _stream(0.5, 2)
	_check(game.is_paused(), "the pause menu is open")
	var ducked: float = sound._music.volume_db
	_check(sound._music.playing and full - ducked >= 8.0 and full - ducked <= 13.0,
			"the pause menu lowers the music by %.1f dB (8 to 13) and the music goes on" % (full - ducked))
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), bus_before),
			"the volume setting (the bus) is not changed by the pause menu")
	# 7b: Resume. The volume comes back within 2 dB in 1 s, and in a ramp: no jump of more than 3 dB between two frames.
	var t0 := Time.get_ticks_msec()
	game.menu_buttons()[0].pressed.emit()
	var samples: Array = []
	while Time.get_ticks_msec() - t0 < 1000:
		samples.append([Time.get_ticks_msec() - t0, float(sound._music.volume_db)])
		await _stream(0.001, 2)
		await _frames(1)
	var back_ms := -1
	var jump := 0.0
	var monotone := true
	for k in samples.size():
		if back_ms < 0 and absf(float(samples[k][1]) - full) <= 2.0:
			back_ms = int(samples[k][0])
		if k > 0:
			jump = maxf(jump, absf(float(samples[k][1]) - float(samples[k - 1][1])))
			monotone = monotone and float(samples[k][1]) >= float(samples[k - 1][1]) - 0.01
	_check(not game.is_paused() and back_ms >= 0 and back_ms <= 1000 and absf(float(sound._music.volume_db) - full) <= 2.0,
			"Resume brings the music back within 2 dB (after %d ms)" % back_ms)
	_check(back_ms >= 20 and jump <= 3.0 and monotone,
			"the volume comes back in a ramp, not in one step (%d ms, biggest step %.2f dB)" % [back_ms, jump])
	# 7c: a phone that goes silent (lost Wi-Fi) pauses the game with the card, and the music is lowered in the same way.
	app.server.peer_timeout_ms = 2500
	_clients[1].set_process(false)
	var waited := Time.get_ticks_msec()
	while not game.is_paused() and Time.get_ticks_msec() - waited < 9000:
		await _stream(0.2, 2, Vector3(0, 0, 9.81), [1])
	await _stream(0.5, 2, Vector3(0, 0, 9.81), [1])
	_check(game.is_paused() and game.menu_buttons().size() >= 1, "a silent phone pauses the game with a card")
	var lost: float = sound._music.volume_db
	_check(sound._music.playing and full - lost >= 8.0 and full - lost <= 13.0,
			"the card of the lost phone lowers the music by %.1f dB (8 to 13)" % (full - lost))
	_clients[1].set_process(true)
	await _stream(1.5, 2)
	for b in game.menu_buttons():
		if b.text == "minigame.resume":
			b.pressed.emit()
	await _stream(0.6, 2)
	_check(absf(float(sound._music.volume_db) - full) <= 2.0,
			"the music is back after the card closes (%.1f dB)" % float(sound._music.volume_db))


## 18.8a to 8d: the sound of a result, then silence, then the menu song after Back to menu.
func _results(app: Node, sound: Node) -> void:
	# A winner (2 phones).
	var tag := await _result_run(app, [[0, 50.0], [1, 20.0]])
	_check(tag == "win", "a winner plays `win` and not `tie` (got %s)" % tag)
	_check(sound._music.playing == false or sound._music.volume_db < -20.0, "the game song is stopped or fading on the result")
	# 8c: after the jingle there is no music and no sound (the jingle is 2 s or shorter).
	await _wait(3.5)
	_check(await _silent(sound), "3.5 s after the result: no music and no effect plays")
	await _wait(6.5)
	_check(await _silent(sound), "10 s after the result: still no music and no effect")
	# 8d: Back to menu brings the menu song.
	var game: Control = app.current_screen()
	var back: Button
	for b in game.menu_buttons():
		if b.text == "minigame.back_to_menu":
			back = b
	_check(back != null, "the result menu has Back to menu")
	var t0 := Time.get_ticks_msec()
	var menu_limit := int(Slow.limit(5000.0, 4.0))   # The song is made in steps: the instrumented copy is slower.
	back.pressed.emit()
	while not (sound._music.playing and String(sound._music.get_meta("id", "")) == "menu") \
			and Time.get_ticks_msec() - t0 < menu_limit:
		await _frames(1)
	_check(sound.wanted_music == "menu" and sound._music.playing and String(sound._music.get_meta("id", "")) == "menu"
			and Time.get_ticks_msec() - t0 <= menu_limit, "Back to menu: the menu song plays again (%d ms, %d or less)"
			% [Time.get_ticks_msec() - t0, menu_limit])
	# 8b: a tie, a round with no score; 8a: a single player with a score wins (no medal, no medal title).
	tag = await _result_run(app, [[0, 30.0], [1, 30.0]])
	_check(tag == "tie", "a tie plays `tie` and not `win` (got %s)" % tag)
	tag = await _result_run(app, [[0, 30.0], [1, 30.0]], 2, true)
	_check(tag == "win", "a team win (two winners, team_won) plays `win` and not `tie` (got %s)" % tag)
	tag = await _result_run(app, [])
	_check(tag == "tie", "a round over with no score plays `tie` (got %s)" % tag)
	tag = await _result_run(app, [[0, 100.0]], 1)
	_check(tag == "win", "a solo round with a score plays `win` (got %s)" % tag)


## Starts a game with `n` phones, gives the scores, opens the result and returns "win", "tie", "both" or "none".
func _result_run(app: Node, scores: Array, n := 2, team := false) -> String:
	for i in range(1, 2):
		if i >= n and _clients[i].state == ControllerClient.State.CONNECTED:
			_clients[i].leave()
	await _wait(0.3)
	app.go(load(MAZE), {})
	await _frames(3)
	await _stream(0.3, n)
	var game: Control = app.current_screen()
	var slots: Array = game.participants.duplicate()
	var board = Scoreboard.new(slots)
	for s in scores:
		board.set_score(int(s[0]), float(s[1]))
	await _wait(0.1)
	_sounds.clear()
	game.team_won = team
	game.open_results(board)
	await _wait(0.1)
	var ids := _ids()
	var won := ids.has("win")
	var tied := ids.has("tie")
	# Phones that left come back for the next run.
	for i in 2:
		if _clients[i].state != ControllerClient.State.CONNECTED:
			await _connect_phone(app, i)
	return "both" if won and tied else ("win" if won else ("tie" if tied else "none"))


## True when the music does not play and no effect player plays.
func _silent(sound: Node) -> bool:
	if sound._music.playing:
		return false
	for p in sound._pool:
		if p.playing:
			return false
	return true


## 18.10d: Haptics OFF: no call of the motor, and the sound, the game and the score work as before.
func _haptics_off(app: Node) -> void:
	app.settings.haptics = false
	_sounds.clear()
	_vib.clear()
	_arrived = [[], []]
	app.go(load(PAINT), {"difficulty": "medium"})
	await _frames(3)
	await _stream(4.2, 2)
	await _stream(4.0, 2, _lean(20.0))
	var beeps: Array = _ids().filter(func(id): return id == "count" or id == "go")
	_check(_arrived[0].size() >= 1 and _arrived[1].size() >= 1,
			"the TV still sends the buzz at GO (the message reaches both phones)")
	_check(_vib.is_empty(), "Haptics OFF: the motor is never called (got %s)" % str(_vib))
	_check(beeps == ["count", "count", "go"], "Haptics OFF: the sounds of the countdown play as before (got %s)" % str(beeps))
	_check(_clients[0].score_of == 2 and app.current_screen().participants.size() == 2,
			"Haptics OFF: the game goes on and the phones get their place")
	app.settings.haptics = true


## 18.6b, 18.10c: a wall hit in Treasure Maze gives the sound and the buzz of 20 ms together.
func _maze_wall(app: Node) -> void:
	_sounds.clear()
	_vib.clear()
	if _clients[1].state == ControllerClient.State.CONNECTED:
		_clients[1].leave()
	await _wait(0.4)
	app.go(load(MAZE), {})
	await _frames(3)
	await _stream(3.5, 1)
	_vib.clear()
	_sounds.clear()
	# Lean to the four sides in turn: the ball hits a wall at some point, whatever the maze looks like.
	for v in [Vector3(-0.87, 0, 0.5), Vector3(0, 0.87, 0.5), Vector3(0.87, 0, 0.5), Vector3(0, -0.87, 0.5)]:
		await _stream(2.5, 1, v * 9.81)
	var bumps: Array = _sounds.filter(func(s): return s[0] == "maze_bump")
	var buzzes: Array = _vib.filter(func(v): return v[0] == 20)
	_check(bumps.size() >= 1 and buzzes.size() >= 1,
			"a wall hit plays `maze_bump` and buzzes 20 ms (%d sounds, %d buzzes)" % [bumps.size(), buzzes.size()])
	if bumps.size() >= 1 and buzzes.size() >= 1:
		var gap := 100000
		for b in bumps:
			for v in buzzes:
				gap = mini(gap, absi(int(b[1]) - int(v[1])))
		_check(gap <= 100, "the buzz comes within 100 ms of the wall sound (%d ms on loopback)" % gap)
