extends RefCounted
## A small chip synthesizer (docs/AUDIO_PLAN.md, section 3). It turns a list of events into 16-bit mono samples.
## Four kinds of voice, like an old arcade chip: pulse waves (duty 12.5%, 25%, 50%), a triangle and noise.
## It is pure code: no node, no scene, no file. The same events give the same bytes.

const RATE := 16000
const PULSE := 0
const TRIANGLE := 1
const NOISE := 2
const ATTACK := 0.004   # seconds. A hard start clicks.
const RELEASE := 0.012  # seconds at the end of an event. A hard stop clicks.

const _SEMITONE := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


## Frequency in Hz of a note name such as "C4", "F#5" or "Bb3". A4 is 440 Hz. "-" and "" give 0 (a rest).
static func hz(note: String) -> float:
	if note == "-" or note == "":
		return 0.0
	var semi: int = _SEMITONE[note[0]]
	var i := 1
	if note[i] == "#":
		semi += 1
		i += 1
	elif note[i] == "b":
		semi -= 1
		i += 1
	var octave := int(note.substr(i))
	var midi := 12 * (octave + 1) + semi
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


## One event: `t` start and `dur` length in seconds, pitch slide from `f0` to `f1` in Hz, `vol` 0 to 1, `duty` for pulse.
static func event(t: float, voice: int, f0: float, f1: float, dur: float, vol := 0.5, duty := 0.5) -> Dictionary:
	return {"t": t, "voice": voice, "f0": f0, "f1": f1, "dur": dur, "vol": vol, "duty": duty}


## Mixes the events into floats in the range -1 to 1. `length` is in seconds. An event that ends after `length` is cut.
static func mix(events: Array, length: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(length * RATE))
	mix_into(buf, events, 0, events.size())
	return buf


## Adds the events `from` up to `to` (not included) to `buf`. A long song is made in steps, so a frame does not wait for it.
static func mix_into(buf: PackedFloat32Array, events: Array, from: int, to: int) -> void:
	for k in range(from, to):
		var e: Dictionary = events[k]
		var start := int(float(e.t) * RATE)
		var count := mini(int(float(e.dur) * RATE), buf.size() - start)
		if count <= 0 or float(e.f0) <= 0.0:
			continue
		_voice(buf, start, count, e)


static func _voice(buf: PackedFloat32Array, start: int, count: int, e: Dictionary) -> void:
	var voice: int = e.voice
	var f0: float = e.f0
	var f1: float = e.f1 if float(e.f1) > 0.0 else f0
	var vol: float = e.vol
	var duty: float = e.duty
	var phase := 0.0
	var lfsr := 0x7FFF
	var noise_out := 1.0
	var noise_acc := 0.0
	var att := ATTACK * RATE
	var rel := minf(RELEASE * RATE, float(count) * 0.5)
	for i in count:
		var f := f0 + (f1 - f0) * float(i) / float(count)
		var v := 0.0
		match voice:
			PULSE:
				phase = fmod(phase + f / RATE, 1.0)
				v = 1.0 if phase < duty else -1.0
			TRIANGLE:
				phase = fmod(phase + f / RATE, 1.0)
				v = 4.0 * absf(phase - 0.5) - 1.0
			_:
				# Noise: a 15-bit shift register. `f` is how many steps it makes in a second.
				noise_acc += f / RATE
				while noise_acc >= 1.0:
					noise_acc -= 1.0
					var bit := (lfsr ^ (lfsr >> 1)) & 1
					lfsr = (lfsr >> 1) | (bit << 14)
					noise_out = 1.0 if (lfsr & 1) == 0 else -1.0
				v = noise_out
		# A short attack, then a decay over the event, and a release at the end.
		var env := minf(float(i) / att, 1.0) * (1.0 - 0.45 * float(i) / float(count))
		if i > count - rel:
			env *= float(count - i) / rel
		buf[start + i] += v * vol * env


## 16-bit little-endian mono bytes of the samples. A value outside -1 to 1 is clipped.
static func to_pcm16(buf: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	pcm16_into(bytes, buf, 0, buf.size())
	return bytes


## Converts the samples `from` up to `to` (not included) into `bytes`, which has the size of `buf` times 2.
static func pcm16_into(bytes: PackedByteArray, buf: PackedFloat32Array, from: int, to: int) -> void:
	for i in range(from, to):
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))


## Renders the events to a stream. A looping stream repeats from the start (a song).
static func stream(events: Array, length: float, loop := false) -> AudioStreamWAV:
	return stream_from_pcm(to_pcm16(mix(events, length)), loop)


static func stream_from_pcm(pcm: PackedByteArray, loop := false) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = pcm
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = pcm.size() / 2
	return s
