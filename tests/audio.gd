extends SceneTree
## The audio of the TV app (docs/AUDIO_PLAN.md): the synthesizer, the songs and effects, the Sound manager, the volume rows
## of the Settings screen and the HAPTICS switch of the phone. Headless Godot has no real audio output, so the tests
## check the data and the behavior, not how it sounds (manual test 18). Run:
##   godot --headless --path . --script tests/audio.gd -- --role=tv

const Synth = preload("res://scripts/audio/synth.gd")
const Songs = preload("res://scripts/audio/songs.gd")
const Registry = preload("res://scripts/game/registry.gd")

var RoundClock: GDScript
var ControllerSettings: GDScript
var _checks := 0
var _fails := 0


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


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	await _frames(3)
	RoundClock = load("res://scripts/game/round_clock.gd")   # These use the autoloads, so they load at run time.
	ControllerSettings = load("res://scripts/ui/controller_settings.gd")
	_synth()
	_songs()
	_effects()
	_code_uses_known_effects()
	var sound: Node = root.get_node("Sound")
	var app: Node = root.get_node("App")
	await _manager(sound, app)
	await _round_clock(sound)
	await _time_low(sound)
	await _game_song_at_go(sound)
	await _denied(sound, app)
	await _settings_rows(sound, app)
	await _phone_haptics(app)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _synth() -> void:
	_check(is_equal_approx(Synth.hz("A4"), 440.0), "A4 is 440 Hz")
	_check(absf(Synth.hz("C4") - 261.63) < 0.01, "C4 is 261.63 Hz")
	_check(absf(Synth.hz("F#5") - 739.99) < 0.01 and absf(Synth.hz("Bb3") - 233.08) < 0.01, "sharp and flat names")
	_check(Synth.hz("-") == 0.0, "a rest has no frequency")
	# A pulse of 500 Hz for 0.1 s has 50 periods: 50 rising edges.
	var buf := Synth.mix([Synth.event(0.02, Synth.PULSE, 500.0, 500.0, 0.1, 0.5, 0.5)], 0.2)
	var edges := 0
	for i in range(1, buf.size()):
		if buf[i - 1] <= 0.0 and buf[i] > 0.0:
			edges += 1
	_check(absi(edges - 50) <= 1, "a 500 Hz pulse for 0.1 s has 50 periods (got %d)" % edges)
	_check(buf[10] == 0.0 and buf[buf.size() - 10] == 0.0, "silence before and after the event")
	var end_idx := int(0.12 * Synth.RATE)
	_check(absf(buf[end_idx - 1]) < 0.02, "the event ends near zero, so there is no click")
	_check(buf.size() == int(0.2 * Synth.RATE), "the buffer has the length that was asked")
	var pcm := Synth.to_pcm16(PackedFloat32Array([2.0, -2.0, 0.0]))
	_check(pcm.decode_s16(0) == 32767 and pcm.decode_s16(2) == -32767 and pcm.decode_s16(4) == 0, "samples are clipped to 16 bits")
	var ev := [Synth.event(0.0, Synth.NOISE, 8000.0, 4000.0, 0.05, 0.3)]
	var first := Synth.to_pcm16(Synth.mix(ev, 0.05))
	_check(first == Synth.to_pcm16(Synth.mix(ev, 0.05)), "the same events give the same bytes (noise too)")
	var s := Synth.stream(ev, 0.05, true)
	_check(s.loop_mode == AudioStreamWAV.LOOP_FORWARD and s.loop_end == int(0.05 * Synth.RATE) and s.mix_rate == Synth.RATE,
			"a looping stream repeats the whole buffer")


func _songs() -> void:
	var ids := Songs.SONGS.keys()
	_check(ids.has("menu"), "there is a menu song")
	for g in Registry.all():
		_check(Songs.SONGS.has(String(g.id)), "game %s has a song" % g.id)
	for id in ids:
		var song: Dictionary = Songs.SONGS[id]
		_check(Songs.phrase_beats(String(song.a)) == 16.0 and Songs.phrase_beats(String(song.b)) == 16.0,
				"song %s: both lead phrases are 16 beats" % id)
		_check(song.prog.size() == 4, "song %s: four chords" % id)
		var len := Songs.length(id)
		var last := 0.0
		for e in Songs.events(id):
			last = maxf(last, float(e.t) + float(e.dur))
		_check(last <= len + 0.001 and last > len - 1.0, "song %s: the events fill the loop (%.1f s)" % [id, len])
		_check(len >= 20.0 and len <= 40.0, "song %s: the loop is 20 to 40 s" % id)


func _effects() -> void:
	var fx := Songs.effects()
	for id in fx:
		var length := Songs.effect_length(fx[id])
		var limit := Songs.MAX_FANFARE if id in ["win", "tie"] else Songs.MAX_EFFECT
		_check(length > 0.0 and length <= limit + 0.0001, "effect %s is %.2f s (limit %.1f)" % [id, length, limit])
	for id in Songs.PROTECTED:
		_check(fx.has(id), "the protected effect %s exists" % id)


## Every id that the code plays exists (a typo would play nothing), and every effect is played somewhere.
func _code_uses_known_effects() -> void:
	var known := Songs.effects()
	var called := {}      # id -> file, from Sound.sfx("id") and _sound("id")
	var named := {}       # id -> file, any string "id" outside songs.gd (an id in a condition or a parameter)
	var rx := RegEx.create_from_string('(?:Sound\\.sfx|_sound)\\("([a-z_0-9]+)"')
	for f in _gd_files("res://scripts"):
		var text := FileAccess.get_file_as_string(f)
		for m in rx.search_all(text):
			called[m.get_string(1)] = f
		if not f.ends_with("songs.gd"):
			for id in known:
				if text.contains('"%s"' % id):
					named[id] = f
	_check(called.size() >= 15, "the scan found the effects the games play (%d)" % called.size())
	for id in called:
		_check(known.has(id), "effect %s played in %s exists" % [id, String(called[id]).get_file()])
	var unused: Array[String] = []
	for id in known:
		if not named.has(id):
			unused.append(id)
	_check(unused.is_empty(), "every effect is played by the code: unused %s" % str(unused))


func _gd_files(dir: String) -> Array[String]:
	var r: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			r.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		r.append_array(_gd_files(dir + "/" + d))
	return r


func _manager(sound: Node, app: Node) -> void:
	_check(sound.enabled, "the TV makes sound")
	_check(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0, "the buses Music and SFX exist")
	_check(sound.step_db(0) <= -80.0 and is_equal_approx(sound.step_db(10), 0.0) and sound.step_db(5) > sound.step_db(4),
			"the volume steps rise from silent to full")
	var old: Dictionary = app.settings.duplicate()
	app.settings.music_volume = 3
	app.settings.sfx_volume = 6
	app.settings.mute = true
	sound.apply_settings()
	var m := AudioServer.get_bus_index("Music")
	var f := AudioServer.get_bus_index("SFX")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(m), sound.step_db(3) + sound.MUSIC_TRIM_DB)
			and is_equal_approx(AudioServer.get_bus_volume_db(f), sound.step_db(6)),
			"Music and Effects set the volume of their buses")
	_check(AudioServer.is_bus_mute(m) and AudioServer.is_bus_mute(f), "Mute mutes both buses")
	app.settings.mute = false
	sound.apply_settings()
	_check(not AudioServer.is_bus_mute(m) and not AudioServer.is_bus_mute(f), "Mute off plays again")
	app.settings.merge(old, true)
	sound.apply_settings()
	# Effects: the same effect twice in 40 ms is one sound; an unknown id plays nothing.
	var played: Array[String] = []
	var cb := func(id: String): played.append(id)
	sound.sfx_played.connect(cb)
	await _wait(0.1)
	_check(sound.sfx("select"), "an effect starts")
	_check(not sound.sfx("select"), "the same effect again at once is dropped")
	_check(not sound.sfx("no_such_effect"), "an unknown effect plays nothing")
	await _wait(0.06)
	_check(sound.sfx("select"), "the same effect after the gap starts again")
	_check(played == ["select", "select"], "the signal names each effect that started")
	sound.sfx_played.disconnect(cb)
	sound.skip_without_output = false   # The headless run has no audio device; this test makes the song anyway.
	# Music: the menu song plays after it has been made in steps; the same song again does not restart it.
	sound.music("menu")
	var t0 := Time.get_ticks_msec()
	while not sound._music.playing and Time.get_ticks_msec() - t0 < 30000:
		await _frames(1)
	print("  (the menu song was ready after %d ms)" % (Time.get_ticks_msec() - t0))
	_check(sound._music.playing and sound._music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the menu song plays in a loop")
	var stream: AudioStream = sound._music.stream
	sound.music("menu")
	await _frames(2)
	_check(sound._music.stream == stream, "the same song again does not restart it")
	await _wait(0.7)
	sound.duck(true)
	await _wait(0.4)
	_check(absf(sound._music.volume_db - linear_to_db(sound.DUCK)) < 0.5, "a menu lowers the music")
	sound.duck(false)
	await _wait(0.4)
	_check(absf(sound._music.volume_db) < 0.5, "closing the menu brings it back")
	sound.stop_music()
	await _wait(0.7)
	_check(not sound._music.playing and sound.wanted_music == "", "stop_music ends the song")


func _round_clock(sound: Node) -> void:
	var ids: Array[String] = []
	var cb := func(id: String): ids.append(id)
	sound.sfx_played.connect(cb)
	var clock = RoundClock.new()
	for i in 3:
		await _wait(0.06)
		clock.tick(1.0)
	sound.sfx_played.disconnect(cb)
	_check(ids == ["count", "count", "go"], "the countdown beeps at 2, 1 and GO (got %s)" % str(ids))


## A timed round ticks in each of the last 5 seconds, and only then.
func _time_low(sound: Node) -> void:
	var ids: Array[String] = []
	var cb := func(id: String): ids.append(id)
	sound.sfx_played.connect(cb)
	var clock = RoundClock.new(0.0, 10.0)
	for sec in 10:
		await _wait(0.06)
		clock.tick(1.0)
	sound.sfx_played.disconnect(cb)
	_check(ids.count("time_low") == 5, "a 10 s round ticks 5 times, in the last 5 s (got %d)" % ids.count("time_low"))
	ids.clear()
	sound.sfx_played.connect(cb)
	var open = RoundClock.new(0.0, 0.0)
	for sec in 8:
		await _wait(0.06)
		open.tick(1.0)
	sound.sfx_played.disconnect(cb)
	_check(not ids.has("time_low"), "a round with no length does not tick")


## The song of a game is made behind the countdown and starts at GO (REQ-FL-65a), not before.
func _game_song_at_go(sound: Node) -> void:
	sound.stop_music()
	await _wait(0.7)
	sound.music_at_go("maze")
	var t0 := Time.get_ticks_msec()
	while not sound._streams.has("maze") and Time.get_ticks_msec() - t0 < 30000:
		await _frames(1)
	await _wait(0.3)
	_check(sound._streams.has("maze") and not sound._music.playing, "the song is ready, but it waits for GO")
	var clock = RoundClock.new(0.0, 0.0)
	clock.time = -0.5
	clock.tick(1.0)
	await _frames(3)
	_check(sound._music.playing and sound.wanted_music == "maze", "the song starts when the countdown ends")
	sound.stop_music()
	await _wait(0.7)


## OK on a game that does not fit the phones plays `denied` and starts nothing.
func _denied(sound: Node, app: Node) -> void:
	app.go_games()
	await _frames(3)
	var ids: Array[String] = []
	var cb := func(id: String): ids.append(id)
	sound.sfx_played.connect(cb)
	await _wait(0.1)
	app.current_screen()._on_tile(Registry.find("sumo_bumpers"))   # It needs 2 players; none is connected.
	sound.sfx_played.disconnect(cb)
	_check(ids == ["denied"] and app.current_screen().get_script().resource_path.ends_with("tv_games.gd"),
			"OK on a game that does not fit plays `denied` and stays on the Games screen")


## The Music and Effects rows change the setting, save it and apply it; Mute is a switch.
func _settings_rows(sound: Node, app: Node) -> void:
	var old: Dictionary = app.settings.duplicate()
	app.go_settings()
	await _frames(3)
	var screen: Control = app.current_screen()
	var rows: Array = screen._rows
	_check(rows.size() == 5, "the Settings screen has 5 rows (debug, invert, music, effects, mute)")
	app.settings.music_volume = 10
	rows[2].pressed.emit()
	_check(app.settings.music_volume == 0, "OK on Music after 10 goes back to 0")
	_check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) <= -80.0,
			"the new Music level is applied at once")
	app.settings.sfx_volume = 4
	var ev := InputEventAction.new()
	ev.action = "ui_right"
	ev.pressed = true
	rows[3].gui_input.emit(ev)
	_check(app.settings.sfx_volume == 5, "Right on Effects adds one")
	ev = InputEventAction.new()
	ev.action = "ui_left"
	ev.pressed = true
	rows[3].gui_input.emit(ev)
	rows[3].gui_input.emit(ev)
	_check(app.settings.sfx_volume == 3, "Left on Effects takes one away")
	rows[4].pressed.emit()
	_check(app.settings.mute == true and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "the Mute row mutes at once")
	rows[4].pressed.emit()
	_check(app.settings.mute == false and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "the Mute row again plays")
	var cfg := ConfigFile.new()
	cfg.load(app.SETTINGS_FILE)
	_check(cfg.get_value("settings", "music_volume", -1) == 0 and cfg.get_value("settings", "sfx_volume", -1) == 3,
			"the volumes are saved")
	app.settings.merge(old, true)
	app.save_settings()
	sound.apply_settings()


## REQ-FL-66: the phone has a HAPTICS switch, on by default, saved on the phone.
func _phone_haptics(app: Node) -> void:
	var old: bool = app.settings.haptics
	app.go(ControllerSettings)
	await _frames(3)
	var screen: Control = app.current_screen()
	app.settings.haptics = true
	screen._refresh()
	_check(screen._haptics.text == "Haptics: ON", "the switch shows ON")
	screen._haptics.pressed.emit()
	_check(app.settings.haptics == false and screen._haptics.text == "Haptics: OFF", "OK turns haptics off")
	var cfg := ConfigFile.new()
	cfg.load(app.SETTINGS_FILE)
	_check(cfg.get_value("settings", "haptics", true) == false, "the choice is saved")
	app.settings.haptics = true
	app._load_settings()
	_check(app.settings.haptics == false, "the saved choice is loaded at the next start")
	screen._haptics.pressed.emit()
	_check(app.settings.haptics == true, "OK turns haptics on again")
	app.settings.haptics = old
	app.save_settings()
