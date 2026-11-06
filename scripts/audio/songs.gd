extends RefCounted
## The songs and the sound effects (docs/AUDIO_PLAN.md, sections 2 and 4). Everything is data: a song is a tempo, four
## chords and two lead phrases of 16 beats. `events()` turns it into synth events, so a change is a text change.
## All songs are original. Do not copy a known melody.

const Synth = preload("res://scripts/audio/synth.gd")

const BARS := 16            # Every song is 4 sections of 4 bars: A, B, A, B.
const BEATS_PER_BAR := 4
const SECTION_BEATS := 16

## id -> song. `prog`: the 4 chords of a section, a bar each, as 3 note names. `lead`: voice and duty of the melody.
## `drums`: "pop", "drive", "light" or "march". Lead phrases are "NOTE:beats" tokens; "-" is a rest.
const SONGS := {
	"menu": {"bpm": 112, "lead_duty": 0.5, "drums": "pop",
		"prog": [["C3", "E3", "G3"], ["A2", "C3", "E3"], ["F2", "A2", "C3"], ["G2", "B2", "D3"]],
		"a": "E5:1 G5:0.5 E5:0.5 C5:1 E5:1  A4:1 C5:0.5 E5:0.5 A5:1.5 -:0.5  A5:1 G5:0.5 F5:0.5 A5:1 C6:1  B5:1 G5:1 D5:1 -:1",
		"b": "G5:1.5 E5:0.5 G5:1 C6:1  A5:1 E5:1 C5:1 A4:1  F5:1 A5:1 C6:1 A5:1  D6:1 B5:1 G5:2"},
	"maze": {"bpm": 120, "lead_duty": 0.25, "drums": "light",
		"prog": [["A2", "C3", "E3"], ["F2", "A2", "C3"], ["C3", "E3", "G3"], ["G2", "B2", "D3"]],
		"a": ("A4:0.5 C5:0.5 E5:1 C5:0.5 -:0.5 A4:1  F4:0.5 A4:0.5 C5:1 A4:0.5 -:0.5 F4:1  " +
				"E4:0.5 G4:0.5 C5:1 G4:0.5 -:0.5 E4:1  D5:1 B4:0.5 G4:0.5 B4:1 -:1"),
		"b": "E5:1 D5:0.5 C5:0.5 B4:1 A4:1  C5:1 A4:1 F4:1 -:1  G4:1 E5:1 D5:1 C5:1  B4:1 D5:1 G5:1 -:1"},
	"marble_race": {"bpm": 150, "lead_duty": 0.25, "drums": "drive",
		"prog": [["E3", "G3", "B3"], ["C3", "E3", "G3"], ["G2", "B2", "D3"], ["D3", "F#3", "A3"]],
		"a": ("E5:0.5 G5:0.5 B5:0.5 G5:0.5 E5:0.5 G5:0.5 B5:1  C5:0.5 E5:0.5 G5:0.5 E5:0.5 C5:0.5 E5:0.5 G5:1  " +
				"B4:0.5 D5:0.5 G5:0.5 D5:0.5 B4:0.5 D5:0.5 G5:1  A4:0.5 D5:0.5 F#5:0.5 D5:0.5 A4:0.5 D5:0.5 A5:1"),
		"b": ("B5:1 G5:0.5 E5:0.5 B5:1 G5:1  G5:1 E5:0.5 C5:0.5 G5:1 E5:1  " +
				"D6:1 B5:0.5 G5:0.5 D6:1 B5:1  A5:1 F#5:0.5 D5:0.5 A5:2")},
	"paint_grab": {"bpm": 128, "lead_duty": 0.5, "drums": "pop",
		"prog": [["C3", "E3", "G3"], ["G2", "B2", "D3"], ["A2", "C3", "E3"], ["F2", "A2", "C3"]],
		"a": ("C5:0.5 -:0.5 C5:0.5 E5:0.5 G5:1 E5:1  B4:0.5 -:0.5 B4:0.5 D5:0.5 G5:1 D5:1  " +
				"A4:0.5 -:0.5 A4:0.5 C5:0.5 E5:1 C5:1  A4:0.5 C5:0.5 F5:1 E5:1 -:1"),
		"b": "E5:1 G5:1 E5:1 C5:1  D5:1 G5:1 B5:1 G5:1  C5:1 E5:1 A5:1 E5:1  F5:1 A5:1 C6:2"},
	"sumo_bumpers": {"bpm": 132, "lead_duty": 0.125, "drums": "march",
		"prog": [["D3", "F3", "A3"], ["Bb2", "D3", "F3"], ["F2", "A2", "C3"], ["C3", "E3", "G3"]],
		"a": "D4:1 -:0.5 D4:0.5 F4:1 A4:1  Bb4:1 -:0.5 Bb4:0.5 A4:1 F4:1  C5:1 -:0.5 C5:0.5 A4:1 F4:1  G4:1 E4:1 G4:1 -:1",
		"b": "A4:1 A4:0.5 A4:0.5 D5:2  D5:1 D5:0.5 D5:0.5 F5:2  C5:1 C5:0.5 C5:0.5 A4:2  G4:2 E4:1 -:1"},
	"snowball_splat": {"bpm": 124, "lead_duty": 0.5, "drums": "light",
		"prog": [["F2", "A2", "C3"], ["D3", "F3", "A3"], ["Bb2", "D3", "F3"], ["C3", "E3", "G3"]],
		"a": ("C6:0.5 A5:0.5 F5:0.5 A5:0.5 C6:2  D6:0.5 A5:0.5 F5:0.5 A5:0.5 D6:2  " +
				"D6:0.5 Bb5:0.5 F5:0.5 Bb5:0.5 D6:2  E6:0.5 C6:0.5 G5:0.5 C6:0.5 E6:1 -:1"),
		"b": "A5:1 C6:1 F6:2  F6:1 D6:1 A5:2  Bb5:1 D6:1 F6:2  E6:1 C6:1 G5:2"},
	"asteroid_blast": {"bpm": 140, "lead_duty": 0.125, "drums": "march",
		"prog": [["A2", "C3", "E3"], ["F2", "A2", "C3"], ["G2", "B2", "D3"], ["E2", "G#2", "B2"]],
		"a": ("A4:0.5 C5:0.5 E5:0.5 C5:0.5 A5:1 E5:1  F4:0.5 A4:0.5 C5:0.5 A4:0.5 F5:1 C5:1  " +
				"G4:0.5 B4:0.5 D5:0.5 B4:0.5 G5:1 D5:1  E5:0.5 G#5:0.5 B5:0.5 G#5:0.5 E5:2"),
		"b": "E5:1 A5:1 C6:2  C6:1 A5:1 F5:2  D5:1 G5:1 B5:2  B5:1 G#5:1 E5:2"},
	"bowling": {"bpm": 110, "lead_duty": 0.5, "drums": "light",
		"prog": [["C3", "E3", "G3"], ["F2", "A2", "C3"], ["A2", "C3", "E3"], ["G2", "B2", "D3"]],
		"a": "G4:0.5 C5:0.5 E5:1 G5:1 E5:1  F4:0.5 A4:0.5 C5:1 F5:1 C5:1  E4:0.5 G4:0.5 C5:1 E5:1 C5:1  D5:1 B4:1 G4:1 -:1",
		"b": "E5:1 D5:0.5 E5:0.5 G5:2  A5:1 G5:1 F5:1 E5:1  G5:1 E5:1 D5:1 C5:1  D5:1 G4:1 C5:2"},
	"tennis": {"bpm": 118, "lead_duty": 0.25, "drums": "light",
		"prog": [["G2", "B2", "D3"], ["E3", "G3", "B3"], ["C3", "E3", "G3"], ["D3", "F#3", "A3"]],
		"a": "B4:1 D5:0.5 G5:0.5 B5:1 G5:1  G4:1 B4:0.5 E5:0.5 G5:1 E5:1  E5:1 G5:0.5 C6:0.5 E6:1 C6:1  D5:1 F#5:1 A5:1 -:1",
		"b": "D6:1 B5:0.5 G5:0.5 D6:1 B5:1  E6:1 B5:0.5 G5:0.5 E6:1 B5:1  C6:1 E6:1 G6:1 E6:1  F#6:1 D6:1 A5:2"},
	"air_hockey": {"bpm": 136, "lead_duty": 0.25, "drums": "drive",
		"prog": [["E3", "G3", "B3"], ["C3", "E3", "G3"], ["D3", "F#3", "A3"], ["B2", "D#3", "F#3"]],
		"a": ("E5:0.5 B4:0.5 E5:0.5 G5:0.5 B5:1 G5:1  C5:0.5 G4:0.5 C5:0.5 E5:0.5 G5:1 E5:1  " +
				"D5:0.5 A4:0.5 D5:0.5 F#5:0.5 A5:1 F#5:1  B4:0.5 D#5:0.5 F#5:0.5 D#5:0.5 B5:2"),
		"b": "G5:1 E5:1 B4:2  E5:1 C5:1 G4:2  F#5:1 D5:1 A4:2  D#5:1 F#5:1 B5:2"},
	"tower_builder": {"bpm": 116, "lead_duty": 0.5, "drums": "light",
		"prog": [["D3", "F#3", "A3"], ["G2", "B2", "D3"], ["A2", "C#3", "E3"], ["D3", "F#3", "A3"]],
		"a": "F#5:0.5 A5:0.5 D6:1 A5:1 F#5:1  G5:0.5 B5:0.5 D6:1 B5:1 G5:1  A5:0.5 C#6:0.5 E6:1 C#6:1 A5:1  D6:1 A5:1 F#5:2",
		"b": "D5:1 F#5:1 A5:1 F#5:1  B4:1 D5:1 G5:1 D5:1  C#5:1 E5:1 A5:1 E5:1  D5:1 F#5:1 D6:2"},
	"mini_golf": {"bpm": 104, "lead_duty": 0.5, "drums": "light",
		"prog": [["F2", "A2", "C3"], ["G2", "Bb2", "D3"], ["C3", "E3", "G3"], ["F2", "A2", "C3"]],
		"a": "A4:0.5 C5:0.5 F5:1 A5:1 F5:1  G4:0.5 Bb4:0.5 D5:1 G5:1 D5:1  A4:0.5 C5:0.5 E5:1 G5:1 E5:1  F5:1 E5:1 C5:1 -:1",
		"b": "C6:1 A5:0.5 F5:0.5 A5:2  D6:1 Bb5:0.5 G5:0.5 Bb5:2  E6:1 C6:0.5 G5:0.5 C6:2  A5:1 F5:1 F5:2"},
	"whack_a_mole": {"bpm": 120, "lead_duty": 0.25, "drums": "pop",
		"prog": [["C3", "E3", "G3"], ["A2", "C3", "E3"], ["F2", "A2", "C3"], ["G2", "B2", "D3"]],
		"a": ("G5:0.5 -:0.5 E5:0.5 -:0.5 C5:1 E5:1  E5:0.5 -:0.5 C5:0.5 -:0.5 A4:1 C5:1  " +
				"A4:0.5 -:0.5 C5:0.5 -:0.5 F5:1 A5:1  G5:1 D5:0.5 -:0.5 B4:1 -:1"),
		"b": "C6:1 G5:0.5 E5:0.5 G5:1 C6:1  A5:1 E5:0.5 C5:0.5 E5:1 A5:1  F5:1 A5:0.5 C6:0.5 A5:1 F5:1  D6:1 B5:1 G5:2"},
	"bumper_cars": {"bpm": 126, "lead_duty": 0.25, "drums": "pop",
		"prog": [["C3", "E3", "G3"], ["F2", "A2", "C3"], ["A2", "C3", "E3"], ["G2", "B2", "D3"]],
		"a": ("C5:0.5 E5:0.5 G5:1 E5:0.5 G5:0.5 C6:1  A4:0.5 C5:0.5 E5:1 C5:0.5 E5:0.5 A5:1  " +
				"F4:0.5 A4:0.5 C5:1 A4:0.5 C5:0.5 F5:1  G4:0.5 B4:0.5 D5:1 G5:1 -:1"),
		"b": "E5:1 G5:1 C6:1 G5:1  C6:1 A5:1 E5:1 C5:1  A5:1 F5:1 C5:1 F5:1  D5:1 G5:1 B5:2"},
	"sheep_herding": {"bpm": 100, "lead_duty": 0.5, "drums": "light",
		"prog": [["C3", "E3", "G3"], ["F2", "A2", "C3"], ["G2", "B2", "D3"], ["C3", "E3", "G3"]],
		"a": "E5:1 E5:0.5 G5:0.5 E5:1 C5:1  A4:1 A4:0.5 C5:0.5 A4:1 F4:1  G4:1 G4:0.5 B4:0.5 D5:1 B4:1  C5:2 E5:1 -:1",
		"b": "G5:1 E5:0.5 G5:0.5 C6:2  A5:1 F5:0.5 A5:0.5 C6:2  B5:1 G5:0.5 B5:0.5 D6:2  C6:1 G5:1 E5:2"},
	"freeze_dance": {"bpm": 124, "lead_duty": 0.25, "drums": "drive",
		"prog": [["A2", "C3", "E3"], ["D3", "F3", "A3"], ["G2", "B2", "D3"], ["C3", "E3", "G3"]],
		"a": ("E5:0.5 -:0.5 E5:0.5 G5:0.5 A5:1 G5:0.5 E5:0.5  D5:0.5 -:0.5 D5:0.5 F5:0.5 A5:1 F5:1  " +
				"D5:0.5 -:0.5 D5:0.5 G5:0.5 B5:1 G5:0.5 D5:0.5  E5:0.5 -:0.5 G5:0.5 E5:0.5 C5:1 -:1"),
		"b": "A5:1 G5:0.5 E5:0.5 A5:1 C6:1  A5:1 F5:0.5 D5:0.5 F5:1 A5:1  B5:1 G5:0.5 D5:0.5 G5:1 B5:1  C6:1 B5:0.5 A5:0.5 G5:1 E5:1"},
}


## Seconds in one loop of a song.
static func length(id: String) -> float:
	return float(BARS * BEATS_PER_BAR) * 60.0 / float(SONGS[id].bpm)


## Beats of a phrase string: the sum of its tokens.
static func phrase_beats(phrase: String) -> float:
	var total := 0.0
	for tok in phrase.split(" ", false):
		total += float(tok.get_slice(":", 1))
	return total


## The synth events of a whole loop: the lead, a bass, an arpeggio and the drums.
static func events(id: String) -> Array:
	var song: Dictionary = SONGS[id]
	var beat := 60.0 / float(song.bpm)
	var ev: Array = []
	for section in 4:
		var t0 := float(section * SECTION_BEATS) * beat
		_lead(ev, String(song.a if section % 2 == 0 else song.b), t0, beat, float(song.lead_duty))
		for bar in 4:
			var tb := t0 + float(bar * BEATS_PER_BAR) * beat
			_bar(ev, song.prog[bar], tb, beat, String(song.drums))
	return ev


static func _lead(ev: Array, phrase: String, t0: float, beat: float, duty: float) -> void:
	var t := t0
	for tok in phrase.split(" ", false):
		var dur := float(tok.get_slice(":", 1)) * beat
		var f := Synth.hz(tok.get_slice(":", 0))
		if f > 0.0:
			ev.append(Synth.event(t, Synth.PULSE, f, f, dur * 0.9, 0.22, duty))
		t += dur


static func _bar(ev: Array, chord: Array, t: float, beat: float, drums: String) -> void:
	var root := Synth.hz(String(chord[0])) * 0.5
	var fifth := Synth.hz(String(chord[2])) * 0.5
	# Bass: a triangle, eighth notes, root and fifth.
	for i in 8:
		var f := root if i % 4 != 3 else fifth
		ev.append(Synth.event(t + float(i) * beat * 0.5, Synth.TRIANGLE, f, f, beat * 0.45, 0.4))
	# Arpeggio: a thin pulse, eighth notes, up through the chord.
	for i in 8:
		var f := Synth.hz(String(chord[i % 3])) * 2.0
		ev.append(Synth.event(t + float(i) * beat * 0.5, Synth.PULSE, f, f, beat * 0.3, 0.07, 0.125))
	for i in 4:
		var tt := t + float(i) * beat
		match drums:
			"pop", "march":
				if i % 2 == 0:
					ev.append(Synth.event(tt, Synth.NOISE, 900.0, 200.0, 0.07, 0.3))   # kick
				else:
					ev.append(Synth.event(tt, Synth.NOISE, 8000.0, 6000.0, 0.06, 0.12))   # snare
				if drums == "pop":
					ev.append(Synth.event(tt + beat * 0.5, Synth.NOISE, 12000.0, 12000.0, 0.025, 0.06))
			"drive":
				ev.append(Synth.event(tt, Synth.NOISE, 900.0, 200.0, 0.06, 0.28))
				ev.append(Synth.event(tt + beat * 0.5, Synth.NOISE, 12000.0, 12000.0, 0.025, 0.07))
			_:
				ev.append(Synth.event(tt + beat * 0.5, Synth.NOISE, 12000.0, 12000.0, 0.025, 0.06))


# ---- Sound effects ----

## Effects whose sound may not be cut when the pool is full (docs/AUDIO_PLAN.md, section 3.2).
const PROTECTED := ["count", "go", "win", "tie"]

## Longest effect in seconds, fanfares excluded (a test checks it).
const MAX_EFFECT := 0.5
const MAX_FANFARE := 2.0


## The run of notes `names` (each `step` seconds), a pulse voice. For a rising or falling run.
static func _run(names: Array, step: float, vol := 0.35, duty := 0.5, hold := 0.9) -> Array:
	var ev: Array = []
	for i in names.size():
		var f := Synth.hz(String(names[i]))
		ev.append(Synth.event(float(i) * step, Synth.PULSE, f, f, step * hold, vol, duty))
	return ev


static func _blip(f0: float, f1: float, dur: float, vol := 0.35, duty := 0.5, t := 0.0) -> Dictionary:
	return Synth.event(t, Synth.PULSE, f0, f1, dur, vol, duty)


static func _noise(f0: float, f1: float, dur: float, vol := 0.3, t := 0.0) -> Dictionary:
	return Synth.event(t, Synth.NOISE, f0, f1, dur, vol)


## id -> synth events of the effect.
static func effects() -> Dictionary:
	var fx := {}
	# Shared (menus, countdown, results).
	fx["move"] = [_blip(1500.0, 1500.0, 0.03, 0.37)]
	fx["select"] = _run(["E5", "A5"], 0.045)
	fx["back"] = _run(["A5", "E5"], 0.045)
	fx["denied"] = [_blip(110.0, 90.0, 0.12, 0.3, 0.25)]
	fx["join"] = _run(["C5", "E5", "G5"], 0.065)
	fx["leave"] = _run(["G5", "E5", "C5"], 0.065)
	fx["pause"] = _run(["G5", "C5"], 0.05)
	fx["resume"] = _run(["C5", "G5"], 0.05)
	fx["count"] = [_blip(880.0, 880.0, 0.1, 0.35)]
	fx["go"] = [_blip(1320.0, 1320.0, 0.3, 0.25)]
	fx["time_low"] = [_blip(1000.0, 1000.0, 0.025, 0.4)]
	fx["win"] = _run(["C5", "E5", "G5", "C6", "G5", "C6"], 0.15, 0.33, 0.5, 1.0)
	fx["tie"] = _run(["E5", "G5", "E5"], 0.2, 0.3, 0.5, 1.0)
	# Treasure Maze.
	fx["maze_bump"] = [_blip(180.0, 120.0, 0.04, 0.33, 0.25)]
	fx["maze_exit"] = _run(["C5", "E5", "G5", "C6"], 0.09, 0.35)
	# Car Race.
	fx["marble_wall"] = [_noise(5000.0, 3000.0, 0.03, 0.36), _blip(700.0, 500.0, 0.03, 0.27, 0.25)]
	fx["marble_wall_hard"] = [_noise(6000.0, 3000.0, 0.04, 0.28), _blip(1000.0, 650.0, 0.04, 0.2, 0.25)]
	fx["marble_bumper"] = [_blip(300.0, 900.0, 0.12, 0.33, 0.25)]
	fx["marble_marble"] = [_noise(3000.0, 1800.0, 0.035, 0.34), _blip(400.0, 300.0, 0.035, 0.26, 0.25)]
	fx["marble_finish"] = _run(["G5", "C6", "E6", "G6"], 0.1, 0.35)
	# Paint Grab.
	fx["paint_tile"] = [_blip(600.0, 900.0, 0.03, 0.37)]
	fx["paint_steal"] = [_blip(900.0, 500.0, 0.06, 0.28)]
	fx["paint_bounce"] = [_blip(200.0, 420.0, 0.08, 0.3, 0.25)]
	fx["paint_edge"] = [_blip(160.0, 110.0, 0.04, 0.33, 0.25)]
	fx["paint_lead"] = _run(["E6", "A6"], 0.08, 0.3)
	# Sumo Bumpers.
	fx["sumo_bump"] = [_noise(2500.0, 800.0, 0.08, 0.24), _blip(220.0, 90.0, 0.08, 0.24, 0.25)]
	fx["sumo_dash"] = [_noise(2000.0, 9000.0, 0.15, 0.25)]
	fx["sumo_fall"] = [_blip(1200.0, 180.0, 0.5, 0.3)]
	fx["sumo_round_win"] = _run(["C5", "E5", "G5", "C6"], 0.1, 0.35)
	# Banana Party.
	fx["snow_throw"] = [_noise(6000.0, 12000.0, 0.07, 0.29)]
	fx["snow_hit"] = [_noise(4000.0, 1500.0, 0.1, 0.28), _blip(300.0, 700.0, 0.1, 0.3, 0.25, 0.08)]
	fx["snow_miss"] = [_noise(3000.0, 1500.0, 0.06, 0.3)]
	fx["snow_points"] = [_blip(1320.0, 1320.0, 0.05, 0.3), _blip(1760.0, 1760.0, 0.1, 0.3, 0.5, 0.05)]
	# Star Shield.
	fx["blast_boom"] = [_noise(3500.0, 500.0, 0.18, 0.21), _blip(160.0, 60.0, 0.18, 0.21, 0.25)]
	fx["blast_pickup"] = _run(["E5", "A5", "E6"], 0.06, 0.3)
	fx["blast_shield"] = [_blip(900.0, 300.0, 0.2, 0.3), _noise(2500.0, 800.0, 0.1, 0.2)]
	fx["blast_lost"] = [_noise(2500.0, 200.0, 0.45, 0.19), _blip(300.0, 40.0, 0.45, 0.18, 0.25)]
	fx["blast_wave"] = _run(["A4", "E5", "A5"], 0.1, 0.3)
	# Pin Pals.
	fx["bowl_turn"] = _run(["E5", "G5"], 0.08, 0.25)
	fx["bowl_throw"] = [_noise(1500.0, 5000.0, 0.25, 0.2)]
	fx["bowl_pins"] = [_noise(3000.0, 1500.0, 0.3, 0.24), _blip(300.0, 200.0, 0.12, 0.17, 0.25)]
	fx["bowl_strike"] = _run(["C5", "E5", "G5", "C6", "E6", "G6"], 0.075, 0.35, 0.5, 1.0)
	fx["bowl_spare"] = _run(["E5", "G5", "C6"], 0.08, 0.3)
	fx["bowl_gutter"] = [_blip(500.0, 120.0, 0.35, 0.25)]
	# Tennis.
	fx["tennis_toss"] = [_blip(500.0, 900.0, 0.18, 0.25)]
	fx["tennis_hit"] = [_noise(2500.0, 1200.0, 0.06, 0.3), _blip(500.0, 300.0, 0.06, 0.3, 0.25)]
	fx["tennis_great"] = [_noise(3500.0, 1500.0, 0.07, 0.35), _blip(800.0, 400.0, 0.08, 0.33, 0.25),
			_blip(1200.0, 1200.0, 0.08, 0.2, 0.5, 0.05)]
	fx["tennis_bounce"] = [_blip(260.0, 200.0, 0.04, 0.33, 0.25)]
	fx["tennis_net"] = [_noise(900.0, 300.0, 0.15, 0.3)]
	fx["tennis_out"] = [_blip(600.0, 250.0, 0.25, 0.28)]
	fx["tennis_point"] = _run(["C5", "E5", "G5"], 0.08, 0.3)
	fx["tennis_game"] = _run(["C5", "E5", "G5", "C6", "E6"], 0.09, 0.33)
	fx["tennis_fault"] = [_blip(300.0, 150.0, 0.3, 0.28, 0.25)]
	# Mini Golf.
	fx["golf_turn"] = _run(["F5", "A5"], 0.08, 0.25)
	fx["golf_putt"] = [_noise(2000.0, 1000.0, 0.05, 0.25), _blip(600.0, 350.0, 0.06, 0.28, 0.25)]
	fx["golf_wall"] = [_blip(300.0, 220.0, 0.05, 0.22, 0.25)]
	fx["golf_loop"] = [_blip(300.0, 1200.0, 0.5, 0.3, 0.25)]
	fx["golf_cannon"] = [_noise(500.0, 80.0, 0.35, 0.3), _blip(160.0, 60.0, 0.3, 0.3)]
	fx["golf_teleport"] = [_blip(1200.0, 300.0, 0.25, 0.3, 0.25)]
	fx["golf_splash"] = [_noise(3000.0, 600.0, 0.3, 0.21), _blip(700.0, 200.0, 0.25, 0.14)]
	fx["golf_hole"] = _run(["C5", "E5", "G5"], 0.08, 0.3)
	fx["golf_ace"] = _run(["C5", "E5", "G5", "C6", "E6", "G6"], 0.075, 0.35, 0.5, 1.0)
	# Whack-a-Mole.
	fx["mole_hit"] = [_noise(3000.0, 1200.0, 0.06, 0.26), _blip(220.0, 520.0, 0.12, 0.3, 0.25, 0.04)]
	fx["mole_miss"] = [_noise(2500.0, 1200.0, 0.05, 0.28)]
	# Freeze Dance. The stop is a soft "record stop", no alarm; a move is a funny boop, never sad (REQ-GM-81).
	fx["freeze_stop"] = [_blip(520.0, 90.0, 0.35, 0.3, 0.5), _noise(2400.0, 600.0, 0.12, 0.2)]
	fx["dance_points"] = [_blip(880.0, 880.0, 0.06, 0.3), _blip(1320.0, 1320.0, 0.12, 0.3, 0.5, 0.06)]
	fx["dance_out"] = [_blip(420.0, 300.0, 0.14, 0.25, 0.5), _blip(300.0, 380.0, 0.14, 0.25, 0.5, 0.14)]
	fx["mole_points"] = [_blip(1100.0, 1100.0, 0.05, 0.3), _blip(1650.0, 1650.0, 0.1, 0.3, 0.5, 0.05)]
	# Air Hockey.
	fx["hockey_hit"] = [_noise(2800.0, 1400.0, 0.05, 0.3), _blip(520.0, 320.0, 0.06, 0.3, 0.25)]
	fx["hockey_wall"] = [_blip(340.0, 260.0, 0.04, 0.28, 0.25)]
	fx["hockey_goal"] = _run(["C5", "E5", "G5", "C6"], 0.09, 0.35)
	# Bumper Cars.
	fx["car_bump"] = [_noise(2500.0, 800.0, 0.08, 0.24), _blip(180.0, 90.0, 0.1, 0.26, 0.5)]
	fx["car_star"] = _run(["E6", "A6"], 0.06, 0.25)
	# Sheep Herding.
	fx["sheep_baa"] = [_blip(500.0, 380.0, 0.12, 0.2, 0.5), _blip(380.0, 330.0, 0.1, 0.18, 0.5, 0.12)]
	fx["sheep_pen"] = _run(["E5", "G5", "C6"], 0.07, 0.3)
	fx["sheep_bump"] = [_blip(300.0, 200.0, 0.05, 0.25, 0.25)]
	# Tower Builder.
	fx["tower_drop"] = [_blip(520.0, 180.0, 0.18, 0.28, 0.25)]
	fx["tower_land"] = [_noise(1800.0, 500.0, 0.07, 0.26), _blip(220.0, 140.0, 0.08, 0.3, 0.25)]
	fx["tower_miss"] = [_blip(600.0, 120.0, 0.35, 0.28)]
	fx["tower_wobble"] = [_blip(330.0, 300.0, 0.1, 0.2), _blip(300.0, 330.0, 0.1, 0.2, 0.5, 0.12),
			_blip(330.0, 300.0, 0.1, 0.2, 0.5, 0.24)]
	fx["tower_crash"] = [_noise(3000.0, 300.0, 0.5, 0.25), _blip(180.0, 60.0, 0.4, 0.22, 0.25)]
	return fx


## Length in seconds of the effect (the end of its last event).
static func effect_length(events_of_fx: Array) -> float:
	var end := 0.0
	for e in events_of_fx:
		end = maxf(end, float(e.t) + float(e.dur))
	return end
