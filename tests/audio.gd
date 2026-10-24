extends SceneTree
## The audio of the TV app (docs/AUDIO_PLAN.md): the synthesizer, the songs and effects, the Sound manager, the volume rows
## of the Settings screen and the HAPTICS switch of the phone. Headless Godot has no real audio output, so the tests
## check the data and the behavior, not how it sounds (manual test 18). Run:
##   godot --headless --path . --script tests/audio.gd -- --role=tv

const Synth = preload("res://scripts/audio/synth.gd")
const Songs = preload("res://scripts/audio/songs.gd")
const Slow = preload("res://tests/slow_run.gd")
const Registry = preload("res://scripts/game/registry.gd")

var RoundClock: GDScript
var ControllerSettings: GDScript
var Haptics: GDScript
var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run()


func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


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
	Haptics = load("res://scripts/game/haptics.gd")
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
	_effect_shapes()
	_loudness_and_songs(sound, app)
	await _menu_song_start(sound)
	await _menu_keys(sound, app)
	await _settings_sweep(sound, app)
	await _settings_reload(sound, app)
	_haptic_switch_calls(app)
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
	_check(pcm.decode_s16(0) == 32767 and pcm.decode_s16(2) == -32767 and pcm.decode_s16(4) == 0,
			"samples are clipped to 16 bits")
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
	sound.apply_settings()
	var m := AudioServer.get_bus_index("Music")
	var f := AudioServer.get_bus_index("SFX")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(m), sound.step_db(3) + sound.MUSIC_TRIM_DB)
			and is_equal_approx(AudioServer.get_bus_volume_db(f), sound.step_db(6)),
			"Music and Effects set the volume of their buses")
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


## The Music and Effects rows change the setting, save it and apply it.
func _settings_rows(sound: Node, app: Node) -> void:
	var old: Dictionary = app.settings.duplicate()
	app.go_settings()
	await _frames(3)
	var screen: Control = app.current_screen()
	var rows: Array = screen._rows
	_check(rows.size() == 5, "the Settings screen has 5 rows (debug, invert, music, effects, language), no Mute (issue #49)")
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
	# Language (issue #49): Left and Right pick a language from the list, OK goes to the next; the language is saved.
	app.set_language("en")
	var lang_before: String = app.settings.language
	ev = InputEventAction.new()
	ev.action = "ui_right"
	ev.pressed = true
	rows[4].gui_input.emit(ev)
	_check(app.settings.language == "he", "Right on Language gives Hebrew (was %s)" % lang_before)
	ev = InputEventAction.new()
	ev.action = "ui_left"
	ev.pressed = true
	rows[4].gui_input.emit(ev)
	_check(app.settings.language == "en", "Left on Language gives English again")
	rows[4].pressed.emit()
	_check(app.settings.language == "he", "OK on Language goes to the next language")
	app.set_language("en")
	var cfg := ConfigFile.new()
	cfg.load(app.SETTINGS_FILE)
	_check(cfg.get_value("settings", "music_volume", -1) == 0 and cfg.get_value("settings", "sfx_volume", -1) == 3,
			"the volumes are saved")
	# An old settings file with mute = true keeps its silence: the Mute row is gone (issue #49).
	cfg.set_value("settings", "mute", true)
	cfg.set_value("settings", "music_volume", 7)
	cfg.set_value("settings", "sfx_volume", 8)
	cfg.save(app.SETTINGS_FILE)
	app._load_settings()
	_check(app.settings.music_volume == 0 and app.settings.sfx_volume == 0,
			"an old file with mute = true loads as Music 0 and Effects 0")
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
	_check(screen._haptics.text == "HAPTICS: ON", "the switch shows ON")
	screen._haptics.pressed.emit()
	_check(app.settings.haptics == false and screen._haptics.text == "HAPTICS: OFF", "OK turns haptics off")
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


# ---------------------------------------------------------------------------------------------------------------------
# Test 18 in the digital domain (what the ear and the meter app of the manual test measure, read from the samples).
# ---------------------------------------------------------------------------------------------------------------------

const DEFAULT_MUSIC_STEP := 7   # App.settings default music_volume
const DEFAULT_SFX_STEP := 8     # App.settings default sfx_volume


func _db(x: float) -> float:
	return 20.0 * log(maxf(x, 1e-9)) / log(10.0)


func _rms(buf: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in buf:
		sum += v * v
	return sqrt(sum / maxf(float(buf.size()), 1.0))


func _peak(buf: PackedFloat32Array) -> float:
	var p := 0.0
	for v in buf:
		p = maxf(p, absf(v))
	return p


func _max_step(buf: PackedFloat32Array) -> float:
	var m := 0.0
	for i in range(1, buf.size()):
		m = maxf(m, absf(buf[i] - buf[i - 1]))
	return m


## The start frequencies of the events of an effect, in the order of their start time.
func _notes(id: String) -> Array:
	var ev: Array = Songs.effects()[id].duplicate()
	ev.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return ev.map(func(e): return float(e.f0))


func _rising(f: Array) -> bool:
	for i in range(1, f.size()):
		if f[i] <= f[i - 1]:
			return false
	return f.size() > 1


func _falling(f: Array) -> bool:
	for i in range(1, f.size()):
		if f[i] >= f[i - 1]:
			return false
	return f.size() > 1


## 18.2b to 2e, 5a, 8a, 8b: the shape of the effects (the number of notes and whether they rise or fall).
func _effect_shapes() -> void:
	var fx := Songs.effects()
	var select := _notes("select")
	_check(select.size() == 2 and _rising(select), "select (OK) is a run of 2 notes, rising")
	var back := _notes("back")
	_check(back.size() == 2 and _falling(back), "back is a run of 2 notes, falling")
	_check(_notes("join").size() == 3 and _rising(_notes("join")), "join is a run of 3 notes, rising")
	_check(_notes("leave").size() == 3 and _falling(_notes("leave")), "leave is a run of 3 notes, falling")
	var denied := _notes("denied")
	_check(denied.size() == 1 and denied[0] < float(select.min()) and Songs.effect_length(fx["denied"]) <= 0.2,
			"denied is one note, lower than the select notes, 0.2 s or shorter")
	# The countdown: GO is higher and longer than a count beep.
	_check(_notes("go")[0] > _notes("count")[0] and Songs.effect_length(fx["go"]) > Songs.effect_length(fx["count"]),
			"GO is higher and longer than a count beep")
	# The result sounds: the winner fanfare rises and is 2 s or shorter; the tie sound is another sound.
	var win := _notes("win")
	_check(win.size() >= 4 and win[-1] > win[0] and Songs.effect_length(fx["win"]) <= Songs.MAX_FANFARE,
			"win is a rising jingle of %d s or shorter" % int(Songs.MAX_FANFARE))
	_check(fx["win"] != fx["tie"] and Songs.effect_length(fx["tie"]) <= Songs.MAX_FANFARE, "tie is not the fanfare of win")
	_check(_notes("move").size() == 1 and Songs.effect_length(fx["move"]) <= 0.05, "move (the cursor) is one short blip")


## 18.1b, 5c, 5d, 6c in the digital domain: the samples of every song and effect, with the bus gains of the default levels.
func _loudness_and_songs(sound: Node, app: Node) -> void:
	var bufs := {}
	var ids := Songs.SONGS.keys()
	for id in ids:
		bufs[id] = Synth.mix(Songs.events(id), Songs.length(id))
	# 18.1b: no click at the start (the first sample is silent, and the player fades in), and none at the loop point.
	var menu: PackedFloat32Array = bufs["menu"]
	_check(absf(menu[0]) < 0.02, "the menu song starts from silence (first sample %.4f)" % menu[0])
	for id in ids:
		var b: PackedFloat32Array = bufs[id]
		var seam := absf(b[0] - b[b.size() - 1])
		_check(absf(b[0]) < 0.02 and absf(b[b.size() - 1]) < 0.02 and seam <= _max_step(b),
				"song %s: the loop point has no jump (first %.4f, last %.4f)" % [id, b[0], b[b.size() - 1]])
		var stream: AudioStreamWAV = Synth.stream_from_pcm(Synth.to_pcm16(b), true)
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_begin == 0 and stream.loop_end == b.size(),
				"song %s: the loop covers the whole buffer (loop_end %d = %d samples)" % [id, stream.loop_end, b.size()])
		_check(_peak(b) <= 1.0, "song %s does not clip (peak %.2f)" % [id, _peak(b)])
	# The stream that the manager builds in steps is the same samples as the plain mix.
	if sound._streams.has("menu"):
		_check(sound._streams["menu"].data == Synth.to_pcm16(menu), "the menu song made in steps equals the plain mix")
	# 18.5d: eleven different songs; no game plays the menu song.
	var distinct := true
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if Synth.to_pcm16(bufs[ids[i]]) == Synth.to_pcm16(bufs[ids[j]]):
				distinct = false
				print("  same samples: %s %s" % [ids[i], ids[j]])
	_check(distinct and ids.size() == 13, "all %d songs have different samples" % ids.size())
	var bad_ids: Array[String] = []
	for g in Registry.all():
		if String(g.id) == "menu" or not Songs.SONGS.has(String(g.id)):
			bad_ids.append(String(g.id))
	_check(bad_ids.is_empty() and Registry.all().size() == 12, "each of the 12 games has its own song id, not `menu`")
	# 18.6c: the effects are 3 to 9 dB above the music at the default levels (the plan: about 6 dB). Bus gains are applied.
	var music_db: float = _db(_rms(menu)) + sound.step_db(DEFAULT_MUSIC_STEP) + sound.MUSIC_TRIM_DB
	var fx := Songs.effects()
	for id in ["select", "count", "win"]:
		var b := Synth.mix(fx[id], Songs.effect_length(fx[id]) + 0.02)
		var above: float = _db(_rms(b)) + sound.step_db(DEFAULT_SFX_STEP) - music_db
		_check(above >= 3.0 and above <= 9.0, "effect %s is %.1f dB above the music at the default levels (3 to 9)" % [id, above])
	var out_of_range := ""
	for id in fx:
		var b := Synth.mix(fx[id], Songs.effect_length(fx[id]) + 0.02)
		_check(_peak(b) <= 1.0, "effect %s does not clip (peak %.2f)" % [id, _peak(b)])
		var above: float = _db(_rms(b)) + sound.step_db(DEFAULT_SFX_STEP) - music_db
		if above < 3.0 or above > 9.0:
			out_of_range += " %s %.1f;" % [id, above]
	print("  effects outside 3 to 9 dB above the music (RMS):%s" % out_of_range)
	# AUDIO_PLAN "Mix": music is quieter than effects (about 6 dB), so a hit is always heard. Every effect follows it.
	_check(out_of_range == "", "every effect is 3 to 9 dB above the music at the default levels (outside:%s)" % out_of_range)
	# The default levels are the ones that the checks above assume.
	_check(int(app.settings.music_volume) == DEFAULT_MUSIC_STEP and int(app.settings.sfx_volume) == DEFAULT_SFX_STEP,
			"the test ran at the default levels (Music %d, Effects %d)" % [DEFAULT_MUSIC_STEP, DEFAULT_SFX_STEP])


func _key(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
	await _frames(2)


## 18.1a, 1b: a cold start of the menu song: ready in 5 s, and it fades in from silence (no click).
func _menu_song_start(sound: Node) -> void:
	sound.stop_music()
	await _wait(0.7)
	sound._streams.erase("menu")
	sound.skip_without_output = false
	var t0 := Time.get_ticks_msec()
	sound.music("menu")
	while not sound._music.playing and Time.get_ticks_msec() - t0 < 30000:
		await _frames(1)
	var ms := Time.get_ticks_msec() - t0
	var start_db: float = sound._music.volume_db
	_check(sound._music.playing and sound.wanted_music == "menu" and ms <= int(Slow.limit(5000.0)),
			"the menu song plays %d ms after the start (5000 or less)" % ms)
	_check(start_db <= -40.0, "the menu song starts at %.0f dB and fades in, so it does not click" % start_db)
	await _wait(0.8)
	_check(sound._music.volume_db > -3.0, "the fade-in reaches the full level (%.1f dB)" % sound._music.volume_db)


## 18.1c, 2a, 2b, 2c: the song goes on across screens; cursor moves, OK and Back make their sounds.
func _menu_keys(sound: Node, app: Node) -> void:
	var stream: AudioStream = sound._music.stream
	var last := float(sound._music.get_playback_position())
	var stayed := true
	var advanced := true
	for go in ["go_connect", "go_games", "go_settings"]:
		app.call(go)
		await _wait(0.25)
		stayed = stayed and sound._music.stream == stream and sound._music.playing and sound.wanted_music == "menu"
		var pos := float(sound._music.get_playback_position())
		advanced = advanced and pos > last
		last = pos
	_check(stayed, "Connect, Games and Settings keep the same menu song playing")
	_check(advanced, "the song position only goes forward across the screens (no restart from its first note)")
	var ids: Array[String] = []
	var cb := func(id: String): ids.append(id)
	sound.sfx_played.connect(cb)
	for i in 5:
		await _key("ui_down")
		await _wait(0.06)
	_check(ids.count("move") == 5 and ids.size() == 5,
			"5 presses of Down make 5 `move` blips and nothing else (got %s)" % str(ids))
	# OK on a row: `select`. The row 'invert tilt' is a switch; the setting is put back.
	var screen: Control = app.current_screen()
	var old_invert = app.settings.invert_tilt
	screen._rows[1].grab_focus()
	await _frames(2)
	ids.clear()
	await _key("ui_accept")
	await _wait(0.06)
	_check(ids.has("select"), "OK on an item plays `select` (got %s)" % str(ids))
	app.settings.invert_tilt = old_invert
	ids.clear()
	await _key("ui_cancel")
	await _wait(0.06)
	_check(ids.has("back"), "Back plays `back` (got %s)" % str(ids))
	sound.sfx_played.disconnect(cb)
	app.go_settings()
	await _frames(3)


## The texts of the Labels in a Settings row: the title first, then the help and the value.
func _row_texts(row: Control) -> Array:
	return row.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _press_on(row: Button, action: String) -> void:
	row.grab_focus()
	await _key(action)


## 18.3a to 3d: the rows, the whole Music sweep, a sample at each Effects change, and the silent Effects.
func _settings_sweep(sound: Node, app: Node) -> void:
	var old: Dictionary = app.settings.duplicate()
	app.go_settings()
	await _frames(3)
	var screen: Control = app.current_screen()
	var rows: Array = screen._rows
	var lang = load("res://scripts/core/lang.gd")
	var titles := rows.map(func(r: Control) -> String: return String(_row_texts(r)[0]))
	_check(titles[2] in ["settings.music", lang.t("settings.music")] and titles[3] in ["settings.effects",
			lang.t("settings.effects")],
			"the Settings rows 3 and 4 are Music and Effects (%s)" % str(titles))
	_check(rows.size() == 5 and not titles.has("settings.mute") and not titles.has(lang.t("settings.mute")),
			"the Settings screen has 5 rows and no Mute row (issue #49)")
	var labels_ok := true
	for r in rows:
		labels_ok = labels_ok and _row_texts(r).size() == 2   # The name and the value: no explanation text.
	_check(labels_ok, "every Settings row is a name and a value, with no explanation text (issue #49)")
	# 3b: Left until 0, then Right 10 times: +1 for each press, the bus follows, and it is silent at 0.
	var music_bus := AudioServer.get_bus_index("Music")
	for i in 11:
		await _press_on(rows[2], "ui_left")
	_check(int(app.settings.music_volume) == 0 and AudioServer.get_bus_volume_db(music_bus) <= -80.0,
			"Music at 0 is silent (bus %.0f dB)" % AudioServer.get_bus_volume_db(music_bus))
	var steps_ok := true
	var rising := true
	var db := {0: AudioServer.get_bus_volume_db(music_bus)}
	for v in range(1, 11):
		await _press_on(rows[2], "ui_right")
		steps_ok = steps_ok and int(app.settings.music_volume) == v
		db[v] = AudioServer.get_bus_volume_db(music_bus)
		rising = rising and float(db[v]) > float(db[v - 1])
	_check(steps_ok, "Right x10 raises Music by 1 for each press, from 0 to 10")
	_check(rising and float(db[2]) < float(db[5]) and float(db[5]) < float(db[10]),
			"the Music bus rises with every step (2: %.1f, 5: %.1f, 10: %.1f dB)" % [db[2], db[5], db[10]])
	_check(_row_texts(rows[2]).has("10 / 10"), "the Music row shows 10 / 10")
	# 3c: one sample (`select`) for each change of Effects.
	var ids: Array[String] = []
	var cb := func(id: String): ids.append(id)
	await _wait(0.06)   # The same effect twice in 40 ms is one sound.
	sound.sfx_played.connect(cb)
	await _press_on(rows[3], "ui_left")
	await _wait(0.06)
	var after_left := ids.count("select")
	await _press_on(rows[3], "ui_right")
	await _wait(0.06)
	sound.sfx_played.disconnect(cb)
	_check(after_left == 1 and ids.count("select") == 2,
			"each change of Effects plays one sample (selects: %d then %d)" % [after_left, ids.count("select")])
	# 3d: Effects at 0 is silent; Effects at 6 plays again.
	var sfx_bus := AudioServer.get_bus_index("SFX")
	for i in 11:
		await _press_on(rows[3], "ui_left")
	_check(int(app.settings.sfx_volume) == 0 and AudioServer.get_bus_volume_db(sfx_bus) <= -80.0,
			"Effects at 0 is silent (bus %.0f dB)" % AudioServer.get_bus_volume_db(sfx_bus))
	for i in 6:
		await _press_on(rows[3], "ui_right")
	_check(int(app.settings.sfx_volume) == 6 and absf(AudioServer.get_bus_volume_db(sfx_bus) - sound.step_db(6)) < 0.01
			and sound.step_db(6) > -20.0, "Effects at 6 is audible again (bus %.1f dB)" % AudioServer.get_bus_volume_db(sfx_bus))
	app.settings.merge(old, true)
	app.save_settings()
	sound.apply_settings()


## 18.3e: Music 4 and Effects 6 are saved; the next start reads them and sets the buses (what `App._ready` does).
func _settings_reload(sound: Node, app: Node) -> void:
	var old: Dictionary = app.settings.duplicate()
	app.settings.music_volume = 4
	app.settings.sfx_volume = 6
	app.save_settings()
	app.settings.music_volume = 9
	app.settings.sfx_volume = 1
	app._load_settings()
	sound.apply_settings()
	_check(int(app.settings.music_volume) == 4 and int(app.settings.sfx_volume) == 6,
			"the next start reads Music 4 and Effects 6")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),
			sound.step_db(4) + sound.MUSIC_TRIM_DB)
			and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), sound.step_db(6)),
			"and the buses are at the volumes of Music 4 and Effects 6")
	app.settings.merge(old, true)
	app.save_settings()
	sound.apply_settings()


## 18.10b: the switch calls the motor for 40 ms when it turns ON, and a message from the TV reaches the motor only when ON.
func _haptic_switch_calls(app: Node) -> void:
	var calls: Array = []
	Haptics.vibrate_call = func(ms: int) -> void: calls.append(ms)
	var old: bool = app.settings.haptics
	app.settings.haptics = false
	var screen: Control = ControllerSettings.new()
	app.add_child(screen)
	screen._haptics.pressed.emit()   # OFF -> ON
	_check(app.settings.haptics == true and calls == [40], "turning Haptics ON vibrates once for 40 ms (got %s)" % str(calls))
	Haptics.on_message(60)
	_check(calls == [40, 60], "with Haptics ON a message of 60 ms from the TV vibrates 60 ms (got %s)" % str(calls))
	screen._haptics.pressed.emit()   # ON -> OFF
	Haptics.on_message(60)
	_check(app.settings.haptics == false and calls == [40, 60],
			"with Haptics OFF, turning it off and a message do not vibrate (got %s)" % str(calls))
	screen.queue_free()
	Haptics.vibrate_call = Callable()
	app.settings.haptics = old
	app.save_settings()
