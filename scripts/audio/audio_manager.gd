extends Node
## Autoload "Sound": the music and the sound effects of the TV app (docs/AUDIO_PLAN.md, section 3).
## Only the TV makes sound. On the phone every call does nothing, so the media volume of the phone has no effect.
## It is before "App" in the autoload list: `App.apply_audio_settings()` is called when the settings are loaded.

const Synth = preload("res://scripts/audio/synth.gd")
const Songs = preload("res://scripts/audio/songs.gd")

signal sfx_played(id: String)

const POOL_SIZE := 8
const MIN_GAP_MS := 40          # The same effect twice in this time is one sound.
const DUCK := 0.3               # Music level under a menu (a share of the full level).
const WAIT_FOR_GO := 3600.0      # Seconds: "until the countdown ends".
const FADE := 0.5               # Seconds of a music fade in or out.
const SILENT_DB := -60.0
const MUSIC_TRIM_DB := -6.0     # The songs peak near full scale; this keeps them under the effects and avoids clipping.
const STEP_USEC := 3000        # Time a frame may spend on making a song.
const CHUNK := 4000            # Samples converted before the time is checked.
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

## Where the sound is made. False on the phone.
var enabled := false
## The song that should play (or is being made ready). "" when none.
var wanted_music := ""
## With no audio device (the "Dummy" driver of a headless run) a song is not made: nobody can hear it, and making it
## would slow the frames of the tests. The audio test turns this off.
var skip_without_output := true

var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _pool_id: Array[String] = []
var _pool_ms: Array[int] = []
var _effects := {}              # id -> events (made once)
var _streams := {}              # id -> AudioStreamWAV, effects and songs
var _last_ms := {}              # effect id -> tick of its last start
var _job := {}                  # song id -> the song that is being made, in steps (see `_make_step`)
var _start_ms := 0              # The song starts at this tick (the countdown of a game).
var _ducked := false
var _fade: Tween


func _ready() -> void:
	enabled = Role.is_tv()
	if not enabled:
		set_process(false)
		return
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	add_child(_music)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_pool.append(p)
		_pool_id.append("")
		_pool_ms.append(0)
	_effects = Songs.effects()


## The volume of a setting step (0 to 10) in dB. 0 is silent. A curve, so the steps sound even.
static func step_db(step: int) -> float:
	if step <= 0:
		return -80.0
	return linear_to_db(pow(float(clampi(step, 0, 10)) / 10.0, 2.0))


## Applies the settings Music, Effects and Mute (REQ-FL-64).
func apply_settings() -> void:
	if not enabled:
		return
	var s: Dictionary = App.settings
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), step_db(int(s.get("music_volume", 7))) + MUSIC_TRIM_DB)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), step_db(int(s.get("sfx_volume", 8))))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), bool(s.get("mute", false)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), bool(s.get("mute", false)))


# ---- Music ----

## Plays the song `id` in a loop. The same song again does not restart it. The song is made in steps over some frames, so a menu
## does not wait. `delay` is in seconds: a game starts its song at the end of the countdown.
func music(id: String, delay := 0.0) -> void:
	var before := wanted_music
	wanted_music = id
	if not enabled:
		return
	if id == "" or not Songs.SONGS.has(id):
		stop_music()
		return
	if before == id and (_music.playing or _job.has(id) or _streams.has(id)):
		return   # The same song again does not restart it.
	if skip_without_output and AudioServer.get_driver_name() == "Dummy":
		return
	if _music.playing:
		_fade_to(SILENT_DB, 0.25)
	_start_ms = Time.get_ticks_msec() + int(delay * 1000.0)
	if not _streams.has(id) and not _job.has(id):
		var events := Songs.events(id)
		var buf := PackedFloat32Array()
		buf.resize(int(Songs.length(id) * Synth.RATE))
		var pcm := PackedByteArray()
		pcm.resize(buf.size() * 2)
		_job[id] = {"events": events, "buf": buf, "pcm": pcm, "mixed": 0, "converted": 0}


## Prepares the song of a game: it is made now, and it starts at GO (`start_queued_music()`, called by `RoundClock`).
## A song that plays already (a restart) goes on.
func music_at_go(id: String) -> void:
	music(id, WAIT_FOR_GO)


## GO: the queued song starts now (REQ-FL-65a).
func start_queued_music() -> void:
	if _start_ms > Time.get_ticks_msec():
		_start_ms = Time.get_ticks_msec()


func stop_music() -> void:
	wanted_music = ""
	if enabled and _music.playing:
		_fade_to(SILENT_DB, FADE)


## Lowers the music under a menu and brings it back (REQ-FL-65). It does not stop the song.
func duck(on: bool) -> void:
	_ducked = on
	if enabled and _music.playing:
		_fade_to(_target_db(), 0.2)


func _target_db() -> float:
	return linear_to_db(DUCK) if _ducked else 0.0


func _fade_to(db: float, seconds: float) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", db, seconds)
	if db <= SILENT_DB:
		_fade.tween_callback(_music.stop)


## Makes the song in steps of about 3 ms a frame: first the events are mixed, then the samples become 16-bit bytes.
## The work is on the main thread (a thread would share state with the tests that count lines, and a TV box has few cores).
func _make_step(id: String) -> void:
	var job: Dictionary = _job[id]
	var until := Time.get_ticks_usec() + STEP_USEC
	var events: Array = job.events
	var buf: PackedFloat32Array = job.buf
	while job.mixed < events.size() and Time.get_ticks_usec() < until:
		Synth.mix_into(buf, events, job.mixed, job.mixed + 1)
		job.mixed += 1
	var pcm: PackedByteArray = job.pcm
	while job.mixed >= events.size() and job.converted < buf.size() and Time.get_ticks_usec() < until:
		var to := mini(job.converted + CHUNK, buf.size())
		Synth.pcm16_into(pcm, buf, job.converted, to)
		job.converted = to
	if job.mixed >= events.size() and job.converted >= buf.size():
		_streams[id] = Synth.stream_from_pcm(pcm, true)
		_job.erase(id)


func _process(_delta: float) -> void:
	for id in _job.keys():
		_make_step(id)
	if wanted_music != "" and _streams.has(wanted_music) and Time.get_ticks_msec() >= _start_ms \
			and not (_music.playing and _music.get_meta("id", "") == wanted_music):
		_music.stream = _streams[wanted_music]
		_music.set_meta("id", wanted_music)
		_music.volume_db = SILENT_DB
		_music.play()
		_fade_to(_target_db(), FADE)


# ---- Effects ----

## Plays the effect `id` (docs/AUDIO_PLAN.md, section 4). `pitch` is a factor (a player can have its own pitch).
## The same effect twice in 40 ms is one sound. When all players are busy, the oldest one that is not a protected
## effect is cut. Returns true when the effect started.
func sfx(id: String, pitch := 1.0) -> bool:
	if not enabled or not _effects.has(id):
		return false
	var now := Time.get_ticks_msec()
	if _last_ms.has(id) and now - int(_last_ms[id]) < MIN_GAP_MS:
		return false
	var slot := _free_player()
	if slot < 0:
		return false
	_last_ms[id] = now
	if not _streams.has(id):
		_streams[id] = Synth.stream(_effects[id], Songs.effect_length(_effects[id]) + 0.02)
	var p := _pool[slot]
	p.stream = _streams[id]
	p.pitch_scale = pitch
	p.play()
	_pool_id[slot] = id
	_pool_ms[slot] = now
	sfx_played.emit(id)
	return true


## The index of a free player, or the oldest player with an effect that may be cut, or -1.
func _free_player() -> int:
	var oldest := -1
	for i in _pool.size():
		if not _pool[i].playing:
			return i
		if Songs.PROTECTED.has(_pool_id[i]):
			continue
		if oldest < 0 or _pool_ms[i] < _pool_ms[oldest]:
			oldest = i
	return oldest
