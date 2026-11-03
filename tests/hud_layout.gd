extends SceneTree
## The HUD of every game with 4 simulated phones (real clients on loopback, as in tests/multi_phone.gd), in English and in Hebrew:
## where the title, the timer box, the leader chip, the hint and the countdown stand (REQ-GM-46, 47o),
## read from
## the boxes the game really draws (`Shell.recorder`, because the HUD is drawn with draw_* and has no node). It replaces the
## "look at the screen with 4 long names" parts of manual tests 16 (item 7), 17 (item 6) and 19. Run:
##   godot --headless --path . --script tests/hud_layout.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Shell = preload("res://scripts/game/shell.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

## id -> [script, props, has leader chip, has timer in this run]. A game with its own score card (Mini Golf,
## Pin Pals)
## and the maze (no score, REQ-MZ-10) have no leader chip. Sheep Herding has a team chip instead (tests/smoke_sheep.gd).
const GAMES := {
	"snowball_splat": ["res://scripts/game/snowball_splat/snowball_splat_game.gd", {"difficulty": "medium"}, true, true],
	"whack_a_mole": ["res://scripts/game/whack_a_mole/whack_a_mole_game.gd", {"difficulty": "medium"}, true, true],
	"paint_grab": ["res://scripts/game/paint_grab/paint_grab_game.gd", {"difficulty": "medium"}, true, true],
	"bumper_cars": ["res://scripts/game/bumper_cars/bumper_cars_game.gd", {"difficulty": "medium"}, true, true],
	"sheep_herding": ["res://scripts/game/sheep_herding/sheep_herding_game.gd", {"difficulty": "medium"}, false, true],
	"sumo_bumpers": ["res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd", {"difficulty": "medium"}, true, false],
	"asteroid_blast": ["res://scripts/game/asteroid_blast/asteroid_blast_game.gd", {"difficulty": "medium"}, true, false],
	"tennis": ["res://scripts/game/tennis/tennis_game.gd", {"difficulty": "medium"}, true, false],
	"marble_race": ["res://scripts/game/marble_race/marble_race.gd", {"track_choice": "3", "difficulty": "easy"}, true, true],
	"maze": ["res://scripts/game/maze/maze_game.gd", {}, false, true],
	"mini_golf": ["res://scripts/game/mini_golf/mini_golf_game.gd", {"difficulty": "medium", "holes": "1"}, false, false],
	# Tower Builder has a turn timer but no countdown before the first turn (the 5th value, REQ-GM-35, REQ-TB-11).
	"tower_builder": ["res://scripts/game/tower_builder/tower_builder_game.gd", {"difficulty": "medium"}, true, true, false],
	"bowling": ["res://scripts/game/bowling/bowling_game.gd", {"difficulty": "medium"}, false, false],
	# Freeze Dance has no countdown and no timer box: the song counter stands in its place (REQ-FD-3, REQ-GM-47o).
	"freeze_dance": ["res://scripts/game/freeze_dance/freeze_dance_game.gd", {"difficulty": "medium"}, true, false],
}
## Names with 10 letters, and two equal names with 12 (the TV makes them different). Slot colors come from the server.
const NAMES := ["Abcdefghij", "Klmnopqrst", "Twinsssssss", "Twinsssssss"]
const MARGIN := 60.0
const SCREEN := Rect2(0, 0, 1920, 1080)
## The black bar at the top: the title, the timer and the leader chip stand inside it (REQ-MR-40).
const HUD_BAR_H := 112.0

var _checks := 0
var _fails := 0
var _seq := [0, 0, 0, 0]
var _clients: Array = []
var _log: Array = []          # Every box the shell drew on the game: {kind, rect, info, frame, lang}
var _game: Control
var _app: Node
## id -> {"en": positions, "he": ...} of the objects at the start (REQ-GM-47o: the world is not mirrored)
var _countdown_pos := {}


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A check for a problem of the game that is known: it counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL (known bug) (%s) %s" % [issue, what])


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	await _run()
	Shell.recorder = Callable()
	Lang.set_language("en", root)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## `--only=maze,tennis` runs these games only (to look at one game while working on it).
func _only() -> PackedStringArray:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			return a.substr(7).split(",")
	return PackedStringArray()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _stream(seconds: float, n: int = 4) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in n:
			if is_instance_valid(_clients[i]):
				_clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO,
						Vector3(0, 0, 9.81), 0, 0, Vector2.ZERO))
				_seq[i] += 1
		await _frames(1)


func _join(n: int) -> void:
	for i in n:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		_clients.append(c)
		var joined := Time.get_ticks_msec()
		while _app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	var slots: Array = _app.server.connected_slots()
	for i in slots.size():
		_app.server.players[slots[i]].player_name = NAMES[i]


func _on_box(kind: String, ci: CanvasItem, rect: Rect2, info: Dictionary) -> void:
	if ci == _game:
		_log.append({"kind": kind, "rect": rect, "info": info, "frame": Engine.get_process_frames(), "lang": Lang.current()})


## The boxes of the last frame that drew (after `frames` frames), by kind.
func _snap(frames := 2) -> Dictionary:
	_log.clear()
	await _frames(frames)
	var last := -1
	for e in _log:
		last = maxi(last, int(e.frame))
	var out := {}
	for e in _log:
		if int(e.frame) == last:
			if not out.has(e.kind):
				out[e.kind] = []
			out[e.kind].append(e)
	return out


func _one(snap: Dictionary, kind: String) -> Dictionary:
	var list: Array = snap.get(kind, [])
	return list[0] if list.size() == 1 else {}


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	load("res://scripts/game/game_settings.gd").clear()
	Shell.recorder = _on_box
	await _join(4)
	_check(_app.server.connected_slots().size() == 4, "4 simulated phones joined")
	var only := _only()
	for id in GAMES:
		if only.is_empty() or id in only:
			await _play(id)
	if only.is_empty() or "marble_race" in only:
		await _race_places()
	if only.is_empty() or "tennis" in only:
		await _tennis_solo_timer()
	for c in _clients:
		if is_instance_valid(c):
			c.leave()


## One game: the start (the countdown only in a game with a timer, REQ-GM-35) in English and in Hebrew, the same game
## started in Hebrew, then the round with the chip and the timer.
func _play(id: String) -> void:
	var spec: Array = GAMES[id]
	# A game with a visible timer has the countdown (unless the 5th value says no); the others start at once.
	var timed: bool = spec[4] if spec.size() > 4 else spec[3]
	Lang.set_language("en", root)
	_app.go(load(spec[0]), spec[1].duplicate())
	_game = _app.current_screen()
	await _stream(0.9)
	var en := await _snap()
	_countdown_checks(id, en, "en", timed)
	# The same running game, now in Hebrew: nothing in the world moves.
	Lang.set_language("he", root)
	var he := await _snap()
	_countdown_checks(id, he, "he", timed)
	await _stream(4.2)   # Through 2, 1 and GO, still in Hebrew (the log keeps the GO word).
	_go_word_checks(id, timed)
	# Hebrew from the start gives the same world.
	_app.go(load(spec[0]), spec[1].duplicate())
	_game = _app.current_screen()
	await _stream(0.9)
	var he_start := await _snap()
	_world_not_mirrored(id)
	await _stream(3.6)
	_game.open_menu("minigame.end_game_ask", [["minigame.resume", _game.close_menu]])   # The ticks stop, so the scores stay.
	await _round_checks(id, spec)
	_game.close_menu()


func _countdown_checks(id: String, snap: Dictionary, lang: String, timed: bool) -> void:
	var state := "%s in %s" % [id, "Hebrew" if lang == "he" else "English"]
	_chip_margin_checks(state, snap)
	var title := _one(snap, "title")
	_check(not title.is_empty(), "%s: the countdown shows one title" % state)
	if not title.is_empty():
		var r: Rect2 = title.rect
		if lang == "he":
			_check(r.get_center().x > 960.0 and is_equal_approx(r.end.x, 1920.0 - MARGIN),
					"%s: the title is at the top right, ending at the 60 px margin (%s)" % [state, str(r)])
		else:
			_check(is_equal_approx(r.position.x, MARGIN),
					"%s: the title is at the top left, at the 60 px margin (%s)" % [state, str(r)])
	# The players are known by the color of their objects: the countdown draws no name over them (removed 2026-10-21).
	_check(not snap.has("tag"), "%s: the countdown draws no name tags" % state)
	var named := false
	for kind in snap:
		for e in snap[kind]:
			named = named or (kind != "leader" and kind != "chip" and e.info.has("name") and _is_player_name(String(e.info.name)))
	_check(not named, "%s: no box of the countdown holds the name of a player" % state)
	var hint := _one(snap, "hint")
	if not hint.is_empty():
		var text_box: Rect2 = hint.rect.grow_individual(-32.0, -20.0, -32.0, -20.0)
		_check(float(hint.info.text_w) <= float(hint.info.max_w) + 0.01 and Rect2(MARGIN, 0, 1800, 1080).encloses(text_box),
				"%s: the hint fits its plate, and its text is inside the side margins (%s)" % [state, str(hint.rect)])
		_check(Rect2(MARGIN, MARGIN, 1800, 960).encloses(text_box), "%s: the hint text is inside the 60 px margin" % state)
		var covered: Array = []
		for c in snap.get("chip", []):
			if hint.rect.intersects(c.rect):
				covered.append(str(c.rect))
		_check(covered.is_empty(), "%s: the hint plate does not cover a chip (covered: %s)" % [state, str(covered)])
	var counts: Array = snap.get("countdown", [])   # Some games draw the number twice (a shadow below the number).
	if not timed:
		_check(counts.is_empty(), "%s: the game has no timer, so it draws no countdown (REQ-GM-35)" % state)
		return
	var count: Dictionary = counts.back() if not counts.is_empty() else {}
	_check(not count.is_empty() and Rect2(0, 0, 1920, 1080).encloses(count.rect),
			"%s: the countdown number is inside the screen (%s)" % [state, str(count.get("rect"))])


func _is_player_name(text: String) -> bool:
	for s in _game.participants:
		if _app.server.players[s].player_name == text:
			return true
	return false


## Hebrew only: the GO word and every number of the countdown that the log saw while the game ran in Hebrew (none in a
## game without a timer).
func _go_word_checks(id: String, timed: bool) -> void:
	var words := {}
	var inside := true
	for e in _log:
		if e.kind == "countdown" and e.lang == "he":
			words[e.info.text] = true
			inside = inside and Rect2(0, 0, 1920, 1080).encloses(e.rect)
	if not timed:
		_check(words.is_empty(),
				"%s in Hebrew: no timer, so no countdown number or GO word is drawn (%s)" % [id, str(words.keys())])
		return
	_check(not words.is_empty() and inside, "%s in Hebrew: the countdown numbers fit the screen (%s)" % [id, str(words.keys())])
	if id == "marble_race":   # Only Car Race shows the word GO; the other games go from 1 to the play.
		_check(words.has(Lang.t("marble_race.go").to_upper()) and words.has("\u05e6\u05d0\u05d5"),
				"marble_race in Hebrew (REQ-MR-3): the GO word is the Hebrew text '%s' (%s)" % [Lang.t("marble_race.go"), str(words.keys())])


## The world is not mirrored (REQ-GM-47o): no node of the game has a negative scale.
func _world_not_mirrored(id: String) -> void:
	var bad: Array = []
	var nodes: Array = _game.find_children("*", "", true, false)
	nodes.append(_game)
	for n in nodes:
		if (n is Control and (n.scale.x < 0.0 or n.scale.y < 0.0)) or (n is Node2D and (n.scale.x < 0.0 or n.scale.y < 0.0)):
			bad.append(str(n.name))
		if n is Control and n.get("layout_direction") != null and n != _game and n.layout_direction == Control.LAYOUT_DIRECTION_RTL \
				and n is SubViewportContainer:
			bad.append(str(n.name))
	_check(bad.is_empty(), "%s: in Hebrew no node of the game world has a negative scale %s" % [id, str(bad)])


## The round itself, paused: the leader chip and the timer in both languages, with scores, a tie and a long score.
func _round_checks(id: String, spec: Array) -> void:
	var has_chip: bool = spec[2]
	var has_timer: bool = spec[3]
	var board = _game._scoreboard()
	var slots: Array = _game.participants
	# No scores yet: no leader chip while everybody is level (REQ-GM-46).
	if board != null and id != "marble_race":
		for s in slots:
			board.set_score(s, 0.0)
	for lang in ["en", "he"]:
		Lang.set_language(lang, root)
		var snap := await _snap()
		var state := "%s in %s" % [id, "Hebrew" if lang == "he" else "English"]
		_check(not snap.has("leader"), "%s: no leader chip while all players are level at 0" % state)
		_check(not snap.has("tag"), "%s: no name tags in the round" % state)
		_chip_margin_checks(state, snap)
		_row_checks(state, snap, lang, has_timer)
	if not has_chip:
		Lang.set_language("en", root)
		await _stream(0.1)
		_check(not (await _snap(30)).has("leader"), "%s: this game has no leader chip" % id)
		return
	var winner_slot: int = slots[slots.size() - 1]
	for lang in ["en", "he"]:
		Lang.set_language(lang, root)
		var state := "%s in %s" % [id, "Hebrew" if lang == "he" else "English"]
		_set_scores(id, slots, [10.0, 20.0, 30.0, 40.0])
		var leader := await _wait_leader(func(e: Dictionary) -> bool: return not e.info.tie)
		var lead_slot: int = winner_slot
		_check(not leader.is_empty() and leader.info.name == _app.server.players[lead_slot].player_name,
				"%s: the chip shows the leader '%s' within 60 frames (%s)" % [state, _app.server.players[lead_slot].player_name,
				str(leader.get("info", {}).get("name", "-"))])
		if leader.is_empty():
			continue
		_check(leader.info.score == _game.leader_text() and leader.info.color == _app.server.players[lead_slot].color,
				"%s: the chip has the score text '%s' and the color of the leader" % [state, _game.leader_text()])
		var snap := await _snap()
		_chip_margin_checks(state, snap)
		_row_checks(state, snap, lang, has_timer)
		_chip_edge_checks(state, snap, lang)
		# A long score still fits inside the chip, and the chip inside the margin (REQ-GM-46).
		if id != "marble_race":
			_game._scoreboard().set_score(lead_slot, 12345.0)
			var big := await _wait_leader(func(e: Dictionary) -> bool: return String(e.info.score).contains("12345"))
			_check(not big.is_empty() and _chip_fits(big),
					"%s: a score of 5 digits fits inside the chip and the chip inside the margin" % state)
		# A tie: the chip says TIE in the language of the TV, with a gray square (REQ-GM-46).
		# Tennis counts a tie between the teams (REQ-TN-13): the two players of one team are not a tie.
		_set_scores(id, slots, [10.0, 40.0, 40.0, 20.0] if id == "tennis" else [10.0, 20.0, 40.0, 40.0])
		var tie := await _wait_leader(func(e: Dictionary) -> bool: return e.info.tie)
		_check(not tie.is_empty() and tie.info.name == Lang.t("shell.tie") and tie.info.color == UiTheme.TEXT_DIM,
				"%s: a tie shows '%s' with a gray square" % [state, Lang.t("shell.tie")])
		if tie.is_empty():
			print("       no tie chip; last chip: ", str(_one(await _snap(), "leader")), " leaders: ", str(_game._scoreboard().leaders()))
		if lang == "he" and not tie.is_empty():
			_check(tie.info.name != "TIE" and tie.info.name.length() > 0, "Hebrew tie: the chip text is not the English text")
	Lang.set_language("en", root)


## The four scores of `slots` for the game: a score for a points game, a finish time for the race (60 s minus the points, so the
## player with the most points has the best time).
func _set_scores(id: String, slots: Array, pts: Array) -> void:
	if id == "marble_race":
		for k in slots.size():
			var r = _game._racers[slots[k]]
			r.finish_time = 60.0 - float(pts[k])
			r.arc = 100.0
		return
	var board = _game._scoreboard()
	for k in slots.size():
		board.set_score(slots[k], pts[k])


## Looks at the leader chip for up to 60 frames until `accept` says it is the one (the chip updates within 1 s, REQ-GM-46).
func _wait_leader(accept: Callable) -> Dictionary:
	for i in 60:
		var snap := await _snap(1)
		var l := _one(snap, "leader")
		if not l.is_empty() and accept.call(l):
			return l
	return {}


func _chip_fits(l: Dictionary) -> bool:
	var r: Rect2 = l.rect
	var f := UiTheme.font()
	var need := Shell.name_x(-1) + f.get_string_size(String(l.info.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1,
			Shell.CHIP_FONT).x \
			+ f.get_string_size(String(l.info.score).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, Shell.CHIP_FONT).x + Shell.CHIP_PAD
	return r.size.x >= need and r.position.x >= MARGIN - 0.01 and r.end.x <= 1920.0 - MARGIN + 0.01


func _chip_edge_checks(state: String, snap: Dictionary, lang: String) -> void:
	var l := _one(snap, "leader")
	if l.is_empty():
		return
	if lang == "he":
		_check(is_equal_approx(l.rect.position.x, MARGIN), "%s: the leader chip starts at the left margin (x %.0f)" % [state,
				l.rect.position.x])
	else:
		_check(is_equal_approx(l.rect.end.x, 1920.0 - MARGIN),
				"%s: the leader chip ends at the right margin (x %.0f)" % [state, l.rect.end.x])
	_check(_chip_fits(l), "%s: the whole name and score fit inside the chip, inside the margin (%s)" % [state, str(l.rect)])


## Issue #223: every chip the game draws (name and score chips, lists, the bench) is inside the 60 px margin of the 1920x1080
## screen: at the sides, at the bottom and, below the black bar, at the top. A chip in the bar (the leader chip) keeps the
## 60 px at the sides only, as the bar rule above says. Older TV boxes crop 2 to 5 percent of each edge.
func _chip_margin_checks(state: String, snap: Dictionary) -> void:
	var safe := Rect2(MARGIN, MARGIN, 1920.0 - 2.0 * MARGIN, 1080.0 - 2.0 * MARGIN)
	var bad: Array = []
	for e in snap.get("chip", []):
		var r: Rect2 = e.rect
		var in_bar: bool = r.end.y <= HUD_BAR_H
		var ok := r.position.x >= MARGIN - 0.01 and r.end.x <= safe.end.x + 0.01 and r.end.y <= safe.end.y + 0.01 \
				and (in_bar or r.position.y >= MARGIN - 0.01)
		if not ok:
			bad.append(str(r))
	_check(bad.is_empty(), "%s: every chip is inside the 60 px margin (outside: %s)" % [state, str(bad)])


## The title, the timer and the chip share one row, do not touch each other and stand inside the top bar (REQ-GM-46, 47o).
func _row_checks(state: String, snap: Dictionary, lang: String, has_timer: bool) -> void:
	var boxes: Array = []
	for kind in ["title", "timer", "leader", "status"]:
		for e in snap.get(kind, []):
			boxes.append(e)
	var one_row := true
	var apart := true
	var in_bar := true
	for i in boxes.size():
		var a: Rect2 = boxes[i].rect
		in_bar = in_bar and a.position.y >= 0.0 and a.end.y <= HUD_BAR_H and a.position.x >= MARGIN - 0.01 \
				and a.end.x <= 1920.0 - MARGIN + 0.01
		for j in range(i + 1, boxes.size()):
			var b: Rect2 = boxes[j].rect
			one_row = one_row and a.position.y < b.end.y and b.position.y < a.end.y
			apart = apart and not a.intersects(b)
	# Issue #223, REQ-GM-45c: the title has one baseline in every game, and the status text of the bar has another one.
	for t in snap.get("title", []):
		var base: float = t.rect.end.y - _line_h() + _ascent()   # The last line of a title on two lines.
		_check(is_equal_approx(base, Shell.TITLE_BASELINE),
				"%s: the title stands on the common baseline (y %.0f)" % [state, base])
	for st in snap.get("status", []):
		# Pin Pals: "FRAME 1/10" stands on the baseline of its title (REQ-BW-12); the other games use the status baseline.
		var want := Shell.TITLE_BASELINE if state.begins_with("bowling") else Shell.STATUS_BASELINE
		_check(is_equal_approx(st.rect.position.y + _ascent(), want),
				"%s: the status text stands on the common baseline (y %.0f)" % [state, st.rect.position.y + _ascent()])
		if state.begins_with("bowling"):
			for t in snap.get("title", []):
				_check(is_equal_approx(st.rect.end.y, t.rect.end.y) and is_equal_approx(st.rect.position.y, t.rect.position.y),
						"%s: the title and the FRAME text have the same top and bottom (one row)" % state)
	# Issue #301: the wave and the round texts of the bar go through Shell.status(), so the baseline check sees them.
	for gid in ["asteroid_blast", "sumo_bumpers"]:
		if state.begins_with(gid + " in"):
			_check(not snap.get("status", []).is_empty(),
					"%s: the text of the bar is drawn by Shell.status() (the check sees it)" % state)
	_check(one_row, "%s: the title, the timer and the chip share one row" % state)
	_check(apart, "%s: no HUD box touches another HUD box %s" % [state, str(boxes.map(func(e): return e.kind + str(e.rect)))])
	_check(in_bar, "%s: every HUD box is inside the top bar and the 60 px margin" % state)
	if has_timer:
		var t := _one(snap, "timer")
		_check(not t.is_empty(), "%s: the timer box is there" % state)
		if not t.is_empty():
			_timer_side(state, t, lang)


## REQ-GM-47o: the timer box has one place in every game: its left edge is at x 520 in English, and in Hebrew its right edge is
## at 1920 - 520 (`Shell.mx`). The value is the literal of the requirement, not a constant of a game.
const TIMER_LEFT := 520.0


func _timer_side(state: String, t: Dictionary, lang: String) -> void:
	var key := "timer_" + state.split(" ")[0]
	if lang == "en":
		_countdown_pos[key] = t.rect
		_check(is_equal_approx(t.rect.position.x, TIMER_LEFT),
				"%s: the timer box is at the one place of every game, x %.0f in English (is %.0f)" % [state, TIMER_LEFT, t.rect.position.x])
		return
	var en: Rect2 = _countdown_pos.get(key, Rect2())
	_check(is_equal_approx(t.rect.end.x, 1920.0 - TIMER_LEFT),
			"%s: the timer box ends at x %.0f in Hebrew (is %.0f)" % [state, 1920.0 - TIMER_LEFT, t.rect.end.x])
	if en.size == Vector2.ZERO:
		return
	_check(is_equal_approx(t.rect.end.x, 1920.0 - en.position.x),
			"%s: the timer box is mirrored (%.0f..%.0f in English, %.0f..%.0f in Hebrew)" % [state, en.position.x, en.end.x,
			t.rect.position.x, t.rect.end.x])


## Car Race: the place of each car decides the chip and the phone; a car that has not finished has no time.
func _race_places() -> void:
	Lang.set_language("en", root)
	var spec: Array = GAMES["marble_race"]
	_app.go(load(spec[0]), spec[1].duplicate())
	_game = _app.current_screen()
	await _stream(4.5)
	_game.open_menu("minigame.end_game_ask", [["minigame.resume", _game.close_menu]])
	var slots: Array = _game.participants
	# Nobody has finished: the first car in front leads, and the chip has a name and no time.
	for k in slots.size():
		_game._racers[slots[k]].arc = 50.0 + float(k) * 10.0
		_game._racers[slots[k]].finish_time = -1.0
	var lead := await _wait_leader(func(e: Dictionary) -> bool: return e.info.name == NAMES[3])
	_check(not lead.is_empty() and lead.info.score == "",
			"Car Race: before the finish the chip shows the car in front (%s) and no time"
			% str(lead.get("info", {}).get("name", "-")))
	var unfinished_label_empty := true
	for e in _game._scoreboard().ranking():
		unfinished_label_empty = unfinished_label_empty and _game._score_label(e) == ""
	_check(unfinished_label_empty, "Car Race: a car that has not finished has no time text")
	# The first car crosses the line: its time is on the chip.
	_game._racers[slots[3]].finish_time = 21.5
	var done := await _wait_leader(func(e: Dictionary) -> bool: return String(e.info.score) != "")
	_check(not done.is_empty() and String(done.info.score).contains("21.5"),
			"Car Race: after the finish the chip shows the time of the winner (%s)" % str(done.get("info", {}).get("score", "-")))
	# Every phone is told the place of its car.
	await _stream(0.6)
	var ok := true
	var places: Array = []
	for e in _game._scoreboard().ranking():
		var c = _clients[e.slot]
		ok = ok and c.score_rank == int(e.rank)
		places.append(e.rank)
	_check(ok, "Car Race: each phone is told the place of its car (%s)" % str(places))
	# There is no list of names at the left of the race (the names are in the chip only).
	var named := false
	for n in _game.find_children("*", "Label", true, false):
		for nm in NAMES:
			named = named or String(n.text).to_upper().contains(String(nm).to_upper())
	_check(not named, "Car Race: no list of player names in the race HUD")
	_game.close_menu()


## Tennis alone: the solo panel has a timer box, at the same side rule as the others.
func _tennis_solo_timer() -> void:
	for i in range(1, 4):
		_clients[i].leave()
	await _stream(0.8, 1)
	_app.go(load(GAMES["tennis"][0]), GAMES["tennis"][1].duplicate())
	_game = _app.current_screen()
	await _stream(4.6, 1)
	var en: Dictionary = {}
	for lang in ["en", "he"]:
		Lang.set_language(lang, root)
		var snap := await _snap()
		var t := _one(snap, "timer")
		_check(not t.is_empty(), "tennis alone in %s: the machine rally shows a timer box" % lang)
		if t.is_empty():
			continue
		if lang == "en":
			en = t
			_check(is_equal_approx(t.rect.position.x, TIMER_LEFT),
					"tennis alone: the timer box is at the one place of every game (x %.0f)" % TIMER_LEFT)
		else:
			_check(is_equal_approx(t.rect.end.x, 1920.0 - en.rect.position.x),
					"tennis alone: the timer box is mirrored in Hebrew")
	Lang.set_language("en", root)
	for i in range(1, 4):
		if _clients[i].state != ControllerClient.State.CONNECTED:
			_clients[i].connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
	await _stream(1.0, 1)


func _ascent() -> float:
	return UiTheme.font().get_ascent(32)


func _line_h() -> float:
	return UiTheme.font().get_height(32)
