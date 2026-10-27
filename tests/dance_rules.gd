extends SceneTree
## The rules of Freeze Dance, without a screen: the songs, the energy of a phone, dancing, the freeze with its grace time, the
## points, the move and the rest, "back in", the levels and the light tiles (REQ-FD-1 to 8, 11, 12). Run:
##   godot --headless --path . --script tests/dance_rules.gd -- --role=controller

const DanceRules = preload("res://scripts/game/freeze_dance/dance_rules.gd")
const DanceLook = preload("res://scripts/game/freeze_dance/dance_look.gd")

const DT := 1.0 / 60.0

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
	_energy()
	_response()
	_songs()
	_dancing_and_points()
	_grace_and_moves()
	_hard_stop()
	_sit_out()
	_back_in()
	_end()
	_levels()
	_lights()
	_pictures()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _rules(difficulty := "medium", slots := [0, 1], seed_value := 5) -> DanceRules:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var r := DanceRules.new()
	r.setup(difficulty, slots, rng)
	return r


## Steps `seconds` with the raw energies `energies` (slot -> energy, or a Callable(rules) -> Dictionary). Returns the events.
func _run(r: DanceRules, seconds: float, energies: Variant) -> Array:
	var events := []
	for i in roundi(seconds / DT):
		var e: Dictionary = energies.call(r) if energies is Callable else energies
		events.append_array(r.tick(DT, e))
	return events


## Steps until the event `type` comes (at most 60 s) and returns it, or {}.
func _until(r: DanceRules, type: String, energies: Variant, events_out := []) -> Dictionary:
	for i in 3600:
		var e: Dictionary = energies.call(r) if energies is Callable else energies
		var found := {}
		for ev in r.tick(DT, e):   # All events of the step are kept, also the ones after the one that is waited for.
			events_out.append(ev)
			if found.is_empty() and String(ev.type) == type:
				found = ev
		if not found.is_empty():
			return found
	return {}


func _of(events: Array, type: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return String(e.type) == type)


## REQ-FD-4
func _energy() -> void:
	print("dance: energy")
	var r := _rules()
	_run(r, 1.0, {0: 3.0, 1: 0.0})
	_check(r.dancers[0].energy > 2.9 and r.dancers[0].energy <= 3.0, "the smoothed energy follows a steady 3.0 within a second")
	_check(r.dancers[1].energy == 0.0, "the energy of a still phone stays 0")
	var meter := DanceRules.Meter.new()
	var still := 0.0
	for i in 120:
		still = meter.update(Vector3.ZERO, Vector3(3.0, -4.0, 8.0), DT)
	_check(still < 0.01, "a phone at rest reads 0 whatever the direction of gravity")
	var tilted := 0.0
	for i in 60:
		tilted = meter.update(Vector3.ZERO, Vector3(-5.0, 2.0, 8.0), DT)
	_check(tilted < 0.5, "after a new pose is held for a second the energy is 0 again (no estimate of gravity to lag)")
	var shaken := 0.0
	for i in 30:
		var push := 6.0 if i % 4 < 2 else -6.0
		shaken = maxf(shaken, meter.update(Vector3.ZERO, Vector3(-5.0, 2.0, 8.0 + push), DT))
	_check(shaken > 0.8, "a shake of 6 m/s2 gives a clear energy (%.1f)" % shaken)
	var turning := DanceRules.Meter.new().update(Vector3(2.5, 0.0, 0.0), Vector3(0.0, 0.0, 9.81), DT)
	_check(is_equal_approx(turning, 2.5), "a turn of 2.5 rad/s with no shake reads 2.5")
	var r2 := _rules()
	r2.tick(DT, {0: 10.0})
	_check(r2.dancers[0].energy < 2.0, "one frame of a shake does not make the smoothed energy jump (about 0.12 s time constant)")


## Test 31 steps 3b, 4a: a wiggle of two turns a second (3 rad/s at the peak, about 14 degrees) makes the dancer dance within
## 0.5 s and a still phone puts the arms down within 1.0 s. The drawing dances at half the wiggle level (`freeze_dance_game.gd`).
func _response() -> void:
	print("dance: the dancer follows the wiggle")
	var r := _rules("medium", [0])
	var meter := DanceRules.Meter.new()
	var gravity := Vector3(0.0, 0.0, 9.81)
	for i in 30:
		r.tick(DT, {0: meter.update(Vector3.ZERO, gravity, DT)})
	_check(r.dancers[0].energy < 0.05, "a phone held still before the wiggle reads 0")
	var t_up := -1.0
	var t := 0.0
	for i in int(5.0 / DT):
		t += DT
		var turn := 3.0 * sin(TAU * 2.0 * t)
		r.tick(DT, {0: meter.update(Vector3(turn, 0.0, 0.0), gravity, DT)})
		if t_up < 0.0 and r.dancers[0].energy >= DanceRules.WIGGLE_MIN * 0.5:
			t_up = t
	_check(t_up > 0.0 and t_up <= 0.5, "the dancer lifts its arms %.2f s after the wiggle starts (0.5 s or less)" % t_up)
	_check(r.dancers[0].dance_time >= DanceRules.DANCE_NEED,
				"5 s of that wiggle count as a dance, 1.5 s of dancing are needed (%.1f s)" % r.dancers[0].dance_time)
	var t_down := -1.0
	t = 0.0
	for i in int(3.0 / DT):
		t += DT
		r.tick(DT, {0: meter.update(Vector3.ZERO, gravity, DT)})
		if t_down < 0.0 and r.dancers[0].energy < DanceRules.WIGGLE_MIN * 0.5:
			t_down = t
	_check(t_down > 0.0 and t_down <= 1.0, "the arms are down %.2f s after the phone is held still (1.0 s or less)" % t_down)


## REQ-FD-1
func _songs() -> void:
	print("dance: songs")
	var r := _rules()
	_check(r.music_lengths.size() == DanceRules.SONGS and DanceRules.SONGS == 6, "a round has 6 songs")
	var in_range := true
	for l in r.music_lengths:
		in_range = in_range and l >= 5.0 and l <= 10.0
	_check(in_range, "the music of each song on Medium lasts 5 to 10 s")
	var seed_nine := _rules("medium", [0], 9).music_lengths
	_check(_rules("medium", [0], 9).music_lengths == seed_nine, "the same seed gives the same songs")
	_check(_rules("medium", [0], 10).music_lengths != seed_nine, "another seed gives other songs")
	_check(r.phase == DanceRules.Phase.MUSIC and r.song == 1, "the round starts with the music of the first song, at once")
	var ev := []
	var f := _until(r, "freeze", {}, ev)
	_check(not f.is_empty() and absf(r.phase_time) < 0.05 and r.phase == DanceRules.Phase.FREEZE,
			"the freeze starts when the music ends")
	var total := 0.0
	r = _rules()
	var slot_events := []
	var frames := 0
	while r.phase != DanceRules.Phase.DONE and frames < 60 * 200:
		slot_events.append_array(r.tick(DT, {}))
		frames += 1
	total = float(frames) * DT
	var expected := 0.0
	for l in r.music_lengths:
		expected += l + float(r.level.freeze) + DanceRules.REST
	_check(absf(total - expected) < 0.5, "a whole round lasts the music, the freeze and the rest of the 6 songs (%.1f s)" % total)
	_check(_of(slot_events, "song").size() == 5 and _of(slot_events, "freeze").size() == 6 and _of(slot_events, "done").size() == 1,
			"5 song starts, 6 freezes and one done")


## REQ-FD-5, 7
func _dancing_and_points() -> void:
	print("dance: dancing and points")
	var r := _rules("medium", [0, 1, 2])
	var ev := []
	var dancing := func(_r: DanceRules) -> Dictionary: return {0: 4.0, 1: 4.0 if _r.phase_time < 0.9 else 0.0, 2: 1.0}
	_until(r, "freeze", dancing, ev)
	_check(r.dancers[0].dance_time >= DanceRules.DANCE_NEED, "a player that wiggled through the music has danced")
	_check(r.dancers[1].dance_time < DanceRules.DANCE_NEED, "a player that wiggled for less than 1.5 s has not danced")
	_check(r.dancers[2].dance_time == 0.0, "an energy of 1.0 is below the wiggle level (2.0) and is not dancing")
	var held := []
	_until(r, "held", {}, held)
	held.append_array(_run(r, float(r.level.freeze), {}))
	var pts := {}
	for e in _of(held, "held"):
		pts[int(e.slot)] = int(e.points)
	_check(pts.get(0, -1) == 10, "a player who danced and holds still gets 10 points")
	_check(pts.get(1, -1) == 0 and pts.get(2, -1) == 0,
			"a player who held still but did not dance gets nothing, and nothing is taken away")
	_check(_of(held, "moved").is_empty(), "nobody moved")


## REQ-FD-6
func _grace_and_moves() -> void:
	print("dance: grace and moves")
	var r := _rules("medium", [0, 1])
	var ev := []
	_until(r, "freeze", {0: 4.0, 1: 4.0}, ev)   # Both dance.
	var t_move := -1.0
	var moved := []
	for i in 600:
		for e in r.tick(DT, {0: 5.0, 1: 0.0}):   # Player 0 keeps shaking in the freeze, player 1 stops.
			if String(e.type) == "moved":
				moved.append(e)
				t_move = r.phase_time
		if r.phase != DanceRules.Phase.FREEZE:
			break
	_check(moved.size() == 1 and int(moved[0].slot) == 0, "only the player that goes on shaking has moved, once")
	_check(t_move >= float(r.level.grace) and t_move < float(r.level.grace) + 0.1,
			"the move counts after the grace time of 0.9 s (Medium), not before (%.2f s)" % t_move)
	_check(not r.dancers[1].moved and r.dancers[0].moved, "the state says who moved")
	# A small tremor stays below the limit.
	var r2 := _rules("medium", [0])
	_until(r2, "freeze", {0: 4.0})
	var ev2 := _run(r2, 3.2, {0: 0.5})
	_check(_of(ev2, "moved").is_empty() and _of(ev2, "held").size() == 1 and int(_of(ev2, "held")[0].points) == 10,
			"a tremor (energy 0.5) is not a move and the player scores")
	# A move at the very end of the freeze counts, too.
	var r3 := _rules("medium", [0])
	_until(r3, "freeze", {0: 4.0})
	var late := func(_r: DanceRules) -> Dictionary: return {0: 6.0 if _r.phase_time > 2.0 else 0.0}
	var ev3 := _run(r3, 3.2, late)
	_check(_of(ev3, "moved").size() == 1, "a move late in the freeze (after 2 s) counts")
	var r4 := _rules("medium", [0])
	_check(not r4.is_checking(), "the music is not checked")


## REQ-FD-8
## REQ-FD-6: a hard wiggle that stops on cue is not a move, even on Hard (grace 0.8 s).
func _hard_stop() -> void:
	print("dance: stop after a hard wiggle")
	var r := _rules("hard", [0, 1])
	_until(r, "freeze", {0: 30.0, 1: 30.0})
	var ev := _run(r, float(r.level.freeze) + 0.1, {0: 0.0, 1: 0.0})
	_check(_of(ev, "moved").is_empty() and _of(ev, "held").size() == 2,
			"a player who stops at the stop is held, after 30 rad/s of wiggle")
	var r2 := _rules("hard", [0, 1])
	_until(r2, "freeze", {0: 30.0, 1: 30.0})
	var ev2 := _run(r2, float(r2.level.freeze) + 0.1, {0: 30.0, 1: 0.0})
	_check(_of(ev2, "moved").size() == 1 and int(_of(ev2, "moved")[0].slot) == 0, "a player who goes on shaking still moves")


func _sit_out() -> void:
	print("dance: sit out")
	var r := _rules("medium", [0, 1])
	var ev := []
	_until(r, "freeze", {0: 4.0, 1: 4.0}, ev)
	var shake := func(_r: DanceRules) -> Dictionary: return {0: 6.0, 1: 0.0}
	_until(r, "moved", shake, ev)
	_check(not r.dancers[0].plays() and r.dancers[1].plays(), "the mover leaves the floor at once")
	var freeze_ev := _run(r, float(r.level.freeze), {0: 6.0, 1: 0.0})
	_check(_of(freeze_ev, "held").size() == 1 and int(_of(freeze_ev, "held")[0].slot) == 1,
			"the mover gets no points event, the other player does")
	_until(r, "song", {0: 6.0, 1: 0.0})
	_check(r.song == 2 and r.dancers[0].plays(), "the mover does not sit out: back on the floor in the next song")
	_check(r.dancers[0].dance_time == 0.0, "the dance of a returning player begins at 0")
	var ev2 := []
	_until(r, "freeze", {0: 6.0, 1: 4.0}, ev2)
	var ev3 := _run(r, float(r.level.freeze), {0: 6.0, 1: 0.0})
	_check(_of(ev3, "moved").size() == 1 and int(_of(ev3, "moved")[0].slot) == 0,
			"in the next song the player is checked again and moves again")
	var r2 := _rules("medium", [0])
	r2.remove(0)
	_check(r2.dancers.is_empty(), "a player that leaves is removed")
	_check(_run(r2, 30.0, {}).size() > 0, "the round goes on with nobody")


## REQ-FD-8: the seconds on the bench.
func _back_in() -> void:
	print("dance: back in")
	var r := _rules("medium", [0, 1])
	_check(r.back_in(0) == -1.0 and r.back_in(99) == -1.0, "a player on the floor, or unknown, has no back-in time")
	_until(r, "freeze", {0: 4.0, 1: 4.0})
	_run(r, 1.0, {0: 0.0, 1: 0.0})
	_until(r, "moved", func(_r: DanceRules) -> Dictionary: return {0: 6.0, 1: 0.0})
	var freeze_left := r.phase_left()
	var expect := freeze_left + DanceRules.REST
	_check(absf(r.back_in(0) - expect) < 0.01, "a mover is back at the start of the next song (%.1f s)" % r.back_in(0))
	_check(r.back_in(1) == -1.0, "the player that held still has none")
	_run(r, 1.0, {})
	_check(r.back_in(0) < expect - 0.9, "the time goes down")
	_until(r, "song", {})
	_check(r.back_in(0) == -1.0, "in the next song the player is on the floor: no time")
	# Moving in the last song: nothing to wait for.
	var last := _rules("medium", [0])
	for k in DanceRules.SONGS - 1:
		_until(last, "song", {})
	_check(last.song == DanceRules.SONGS, "this is the last song")
	_until(last, "freeze", {0: 4.0})
	_until(last, "moved", {0: 6.0})
	_check(last.back_in(0) == -1.0, "a mover in the last song has no back-in time: nothing is left to play")
	_check(last.is_out(0) and not _rules("medium", [0]).is_out(0) and not last.is_out(99),
			"but it is still out of the floor, so the bench can show it (REQ-FD-8)")
	var fifth := _rules("medium", [0])
	for k in DanceRules.SONGS - 2:
		_until(fifth, "song", {})
	_until(fifth, "freeze", {0: 4.0})
	_until(fifth, "moved", {0: 6.0})
	_check(fifth.back_in(0) > 0.0, "a mover in the 5th song is back for the 6th")
	var fourth := _rules("medium", [0])
	for k in 2:
		_until(fourth, "song", {})
	_until(fourth, "freeze", {0: 4.0})
	_until(fourth, "moved", {0: 6.0})
	_check(fourth.back_in(0) > 0.0, "a mover in the 3rd song is back for the 4th")


func _end() -> void:
	print("dance: end")
	var r := _rules("medium", [0])
	var ev := []
	var guard := 0
	while r.phase != DanceRules.Phase.DONE and guard < 60 * 200:
		ev.append_array(r.tick(DT, {0: 4.0 if r.phase == DanceRules.Phase.MUSIC else 0.0}))
		guard += 1
	_check(r.phase == DanceRules.Phase.DONE and r.song == DanceRules.SONGS, "after the rest of the 6th song the round is done")
	var points := 0
	for e in _of(ev, "held"):
		points += int(e.points)
	_check(points == 60, "a player that dances and holds still in all 6 songs gets 60 points")
	_check(r.tick(DT, {0: 9.0}).is_empty(), "nothing happens after the round")
	_check(r.phase_left() == 0.0, "no time is left")


## REQ-FD-11
func _levels() -> void:
	print("dance: levels")
	var e := DanceRules.LEVELS.easy
	var m := DanceRules.LEVELS.medium
	var h := DanceRules.LEVELS.hard
	_check(float(e.freeze) < float(m.freeze) and float(m.freeze) < float(h.freeze), "the freeze is longer from Easy to Hard")
	_check(float(e.grace) > float(m.grace) and float(m.grace) >= float(h.grace), "Easy has the most time to stop")
	_check(float(e.still_limit) > float(m.still_limit) and float(m.still_limit) > float(h.still_limit), "Easy has the loosest check")
	_check(float(e.music_max) >= float(h.music_max) and float(e.music_min) > float(h.music_min), "Hard has the shortest music")
	_check(DanceRules.new().level == m, "Medium is the base")
	var r := _rules("hard", [0])
	_check(r.level == h and _rules("nonsense", [0]).level == m, "setup takes the level, an unknown one is Medium")
	var ok := true
	for l in _rules("easy", [0]).music_lengths:
		ok = ok and l >= 7.0 and l <= 10.0
	_check(ok, "Easy music lasts 7 to 10 s")
	# Test 31 steps 8a to 8c: the measured length of the freeze and of the music of each level, over the whole round.
	var spans := {"easy": [1.7, 2.3, 7.0, 10.0], "medium": [2.7, 3.3, 5.0, 10.0], "hard": [3.7, 4.3, 4.0, 8.0]}
	for d in spans:
		var rr := _rules(d, [0])
		var freezes: Array[float] = []
		var musics: Array[float] = []
		var t_music := 0.0
		var t_freeze := 0.0
		var in_freeze := false
		for i in int(300.0 / DT):
			var evs := rr.tick(DT, {0: 0.0})
			if rr.phase == DanceRules.Phase.MUSIC:
				t_music += DT
			for ev in evs:
				if String(ev.type) == "freeze":
					musics.append(t_music)
					t_music = 0.0
					in_freeze = true
					t_freeze = 0.0
			if in_freeze and rr.phase == DanceRules.Phase.FREEZE:
				t_freeze += DT
			elif in_freeze:
				freezes.append(t_freeze)
				in_freeze = false
			if rr.phase == DanceRules.Phase.DONE:
				break
		var span: Array = spans[d]
		var freeze_ok := freezes.size() == 6
		for f in freezes:
			freeze_ok = freeze_ok and f >= span[0] and f <= span[1]
		var music_ok := musics.size() == 6
		for m_len in musics:
			music_ok = music_ok and m_len >= span[2] and m_len <= span[3]
		var round_to_tenth := func(v: float) -> float: return snappedf(v, 0.1)
		_check(freeze_ok, "%s: all 6 freezes last %.1f to %.1f s (%s)" % [d, span[0], span[1], str(freezes.map(round_to_tenth))])
		_check(music_ok, "%s: all 6 songs last %.0f to %.0f s (%s)" % [d, span[2], span[3], str(musics.map(round_to_tenth))])
	# A tremor of 1.3 passes on Easy, fails on Medium and Hard.
	var verdicts := []
	for d in ["easy", "medium", "hard"]:
		var rr := _rules(d, [0])
		_until(rr, "freeze", {0: 4.0})
		verdicts.append(_of(_run(rr, 5.0, {0: 1.3}), "moved").size())
	_check(verdicts == [0, 1, 1], "an energy of 1.3 is still on Easy, a move on Medium and Hard")


## REQ-FD-12
func _lights() -> void:
	print("dance: light tiles")
	var no_neighbours := true
	var quarters_ok := true
	var total := 0
	for step in 60:
		var lit := DanceRules.lit_tiles(step)
		total += lit.size()
		for cell in lit:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if lit.has(cell + d):
					no_neighbours = false
		for quarter in 4:
			var has := false
			for cell in lit:
				if int(cell.x / (DanceRules.ROWS / 2)) == quarter / 2 and int(cell.y / (DanceRules.COLS / 2)) == quarter % 2:
					has = true
			quarters_ok = quarters_ok and has
	_check(no_neighbours, "no two light tiles share a side, in 60 steps (corners may touch)")
	_check(quarters_ok, "every quarter of the floor has a light tile in each of the 60 steps")
	var share := float(total) / 60.0 / float(DanceRules.ROWS * DanceRules.COLS)
	_check(share > 0.18 and share < 0.35,
			"about a third of the tiles at most are lit (%.0f %%): no two sides touch" % (share * 100.0))
	var three := DanceRules.lit_tiles(3)
	_check(DanceRules.lit_tiles(3) == three, "the same step gives the same floor")
	_check(DanceRules.lit_tiles(3) != DanceRules.lit_tiles(4), "the next step gives another floor")
	var inside := true
	for cell in DanceRules.lit_tiles(7):
		inside = inside and cell.x >= 0 and cell.x < DanceRules.ROWS and cell.y >= 0 and cell.y < DanceRules.COLS
	_check(inside, "all lit tiles are on the floor")


## REQ-FD-12, 13: the pictures and the places.
func _pictures() -> void:
	print("dance: pictures and places")
	var area := Vector2(1920.0, 1080.0)
	for count in [1, 2, 3, 4]:
		var feet := []
		for i in count:
			feet.append(DanceLook.place(i, count, area))
		var apart := true
		for i in count:
			for j in range(i + 1, count):
				var dx := absf(float(feet[i].x) - float(feet[j].x))
				apart = apart and dx > float(DanceLook.IMG.x) * 3.0 * 4.0 * 0.9
		_check(apart, "%d dancers: nobody stands inside another (the places are wider than a dancer)" % count)
		var big := true
		var inside := true
		for f in feet:
			var h := float(DanceLook.IMG.y) * int(f.scale) * 4.0
			big = big and h >= 160.0
			inside = inside and float(f.x) > 120.0 and float(f.x) < 1800.0 and float(f.y) < 1080.0 - 60.0 and float(f.y) - h > 112.0
		_check(big, "%d dancers: a dancer is 160 px high or more" % count)
		_check(inside, "%d dancers: all stand inside the screen, under the HUD bar and above the stage lip" % count)
	var img := DanceLook.dancer_image(Color("ff5050"), 1)
	_check(img.get_size() == Vector2i(14, 20), "a dancer is a picture of 14 x 20 pixels")
	_check(img.get_pixel(5, 12).is_equal_approx(Color("ff5050")) and img.get_pixel(0, 0).a == 0.0,
			"the body has the color of the slot, the corner is clear")
	var up := DanceLook.dancer_image(Color("ff5050"), 1)
	var down := DanceLook.dancer_image(Color("ff5050"), 0)
	_check(up.get_pixel(2, 5).a == 1.0 and down.get_pixel(2, 5).a == 0.0, "pose 1 lifts the left arm, pose 0 has the arms down")
	var dim := DanceLook.dancer_image(Color("ff5050"), 0, true)
	_check(dim.get_pixel(5, 12).r < 0.4, "a dancer on the bench is dim")
	var corners := DanceLook.tile_corners(0, 0, area)
	var near := DanceLook.tile_corners(DanceRules.ROWS - 1, 0, area)
	_check(corners.size() == 4 and (corners[1].x - corners[0].x) < (near[1].x - near[0].x),
			"a tile in the back is narrower than a tile in the front (perspective)")
