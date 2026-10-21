extends SceneTree
## Test 20 (profiles), the TV side, with 4 simulated phones that have a profile (real clients on the loopback):
## - 1b and 17b: in every game the name tags of the countdown and the leader chip hold the color square, then the avatar, then the
##   name, in this order and in English and in Hebrew (a chip is always laid out left to right), and each chip is wide enough
##   for the whole name, also a Hebrew name of 10 letters;
## - 4a: the phones `Sam` and `sam` are SAM and SAM 2 on the Players list;
## - 4b: a name of 10 letters in Latin and in Hebrew is whole in the Players list and on the Connect screen, in both languages;
## - 6a2: a phone whose Wi-Fi goes away without a close (a relay cuts the link) pauses the game with its name in 5 s or less.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r4_tv_profiles.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Shell = preload("res://scripts/game/shell.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const TcpRelay = preload("res://tests/tcp_relay.gd")

## id -> [script, props, has a leader chip]. The games with their own score card (Mini Golf, Pin Pals) and the maze have no
## leader chip.
const GAMES := {
	"snowball_splat": ["res://scripts/game/snowball_splat/snowball_splat_game.gd", {"difficulty": "medium"}, true],
	"paint_grab": ["res://scripts/game/paint_grab/paint_grab_game.gd", {"difficulty": "medium"}, true],
	"sumo_bumpers": ["res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd", {"difficulty": "medium"}, true],
	"asteroid_blast": ["res://scripts/game/asteroid_blast/asteroid_blast_game.gd", {"difficulty": "medium"}, true],
	"tennis": ["res://scripts/game/tennis/tennis_game.gd", {"difficulty": "medium"}, true],
	"marble_race": ["res://scripts/game/marble_race/marble_race.gd", {"track_choice": "3", "difficulty": "easy"}, true],
	"maze": ["res://scripts/game/maze/maze_game.gd", {}, false],
	"mini_golf": ["res://scripts/game/mini_golf/mini_golf_game.gd", {"difficulty": "medium", "holes": "1"}, false],
	"bowling": ["res://scripts/game/bowling/bowling_game.gd", {"difficulty": "medium"}, false],
}
## The profiles of the 4 phones: a name of 10 letters, a Hebrew name of 10 letters, and two names that differ in case.
const PHONES := [
	{"id": "a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0", "name": "Abcdefghij", "av": 5},
	{"id": "a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1", "name": "אבגדהוזחטי", "av": 12},
	{"id": "a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2a2", "name": "Sam", "av": 20},
	{"id": "a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3", "name": "sam", "av": 31},
]
const EDGE := 60.0
const RELAY_PORT := 47990

var _checks := 0
var _fails := 0
var _app: Node
var _game: Control
var _clients: Array = []
var _seq := [0, 0, 0, 0]
var _log: Array = []   # Every box the shell drew on the game: {kind, rect, info, frame}


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A known bug: it counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


func _initialize() -> void:
	await _run()
	Shell.recorder = Callable()
	Lang.set_language("en", root)
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


## The first `n` phones stream a flat phone for `seconds`.
func _stream(seconds: float, n: int = 4) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in n:
			if is_instance_valid(_clients[i]):
				_clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO,
						Vector3(0, 0, 9.81), 0, 0, Vector2.ZERO))
				_seq[i] += 1
		await _frames(1)


func _on_box(kind: String, ci: CanvasItem, rect: Rect2, info: Dictionary) -> void:
	if ci == _game:
		_log.append({"kind": kind, "rect": rect, "info": info, "frame": Engine.get_process_frames()})


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


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	load("res://scripts/game/game_settings.gd").clear()
	_app.set_language("en", false)
	_app.go_games()   # The phones join in a menu: they keep their profile.
	await _frames(3)
	for i in 4:
		var c := ControllerClient.new()
		c.set_profile(PHONES[i].id, PHONES[i].name, PHONES[i].av)
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, _app.server.room_code)
		_clients.append(c)
		await _wait_until(func(): return _app.server.connected_slots().size() >= i + 1, 4000)
	await _frames(3)
	var players: Array = _app.server.players
	_check(_app.server.connected_slots().size() == 4 and players.all(func(p): return p.has_profile()),
			"4 simulated phones with a profile joined")
	_check(players[0].player_name == "Abcdefghij" and players[1].player_name == PHONES[1].name
			and players[2].player_name == "Sam" and players[3].player_name == "sam 2",
			"the TV names are Abcdefghij, the Hebrew name, Sam and sam 2")
	Shell.recorder = _on_box
	for id in GAMES:
		await _play(id)
	Shell.recorder = Callable()
	await _lists()
	await _relay_cut()
	for c in _clients:
		if is_instance_valid(c):
			c.leave()


## One game: the countdown in English and in Hebrew, then (with a leader chip) the round with a leader.
func _play(id: String) -> void:
	var spec: Array = GAMES[id]
	print(id)
	Lang.set_language("en", root)
	_app.go(load(spec[0]), spec[1].duplicate())
	_game = _app.current_screen()
	await _stream(0.9)
	_tag_checks(id, await _snap(), "English")
	Lang.set_language("he", root)
	_tag_checks(id, await _snap(), "Hebrew")
	Lang.set_language("en", root)
	if not spec[2]:
		return
	await _stream(5.0)
	_game.open_menu("minigame.paused", [["minigame.resume", _game.close_menu]])   # The ticks stop, so the scores stay.
	var slots: Array = _game.participants
	for lang in ["en", "he"]:
		Lang.set_language(lang, root)
		var state := "%s in %s" % [id, "Hebrew" if lang == "he" else "English"]
		# The player with the Hebrew name leads, then the player with the Latin name of 10 letters.
		for lead in [1, 0]:
			var pts := [10.0, 10.0, 10.0, 10.0]
			pts[lead] = 40.0
			_set_scores(id, slots, pts)
			var p = _app.server.players[lead]
			var leader := await _wait_leader(func(e: Dictionary) -> bool: return not e.info.tie and e.info.name == p.player_name)
			_check(not leader.is_empty() and leader.info.name == p.player_name and leader.info.avatar == p.avatar,
					"%s: the leader chip shows '%s' with avatar %d" % [state, p.player_name, p.avatar])
			if not leader.is_empty():
				_chip_checks(state + " leader chip", leader.rect, String(leader.info.name), int(leader.info.avatar),
						String(leader.info.score))
	Lang.set_language("en", root)
	_game.close_menu()


## The chip of one player: the color square, the avatar and the name stand in this order from the left (the same in every
## language), and the chip holds the whole name (and the score).
func _chip_checks(state: String, rect: Rect2, player_name: String, avatar: int, score := "") -> void:
	var parts := Shell.chip_parts(avatar)
	_check(avatar >= 0 and parts.avatar_x >= 0.0, "%s: the chip has the avatar of the player (%d)" % [state, avatar])
	_check(parts.square_x < parts.avatar_x and parts.square_x + Shell.CHIP_SQUARE <= parts.avatar_x
			and parts.avatar_x + Shell.CHIP_AVATAR <= parts.name_x,
			"%s: color square (x %.0f), then avatar (x %.0f), then the name (x %.0f), left to right" % [state, parts.square_x,
			parts.avatar_x, parts.name_x])
	var font := UiTheme.font()
	var need: float = parts.name_x + font.get_string_size(player_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, Shell.CHIP_FONT).x \
			+ Shell.CHIP_PAD
	if score != "":
		need += 16.0 + font.get_string_size(score.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, Shell.CHIP_FONT).x
	_check(rect.size.x + 0.01 >= need and rect.position.x >= EDGE - 0.01 and rect.end.x <= 1920.0 - EDGE + 0.01,
			"%s: the chip is %.0f px wide for %.0f px of content and inside the 60 px edge" % [state, rect.size.x, need])


func _tag_checks(id: String, snap: Dictionary, lang: String) -> void:
	var tags: Array = snap.get("tag", [])
	var state := "%s countdown in %s" % [id, lang]
	_check(tags.size() == _game.participants.size(), "%s: one name tag for each of the %d players (%d)" % [state,
			_game.participants.size(), tags.size()])
	var seen := {}
	for t in tags:
		var slot := -1
		for s in _game.participants:
			if _app.server.players[s].player_name == String(t.info.name) and t.info.color == _app.server.players[s].color:
				slot = s
		_check(slot >= 0 and int(t.info.avatar) == _app.server.players[slot].avatar,
				"%s: the tag of '%s' holds the avatar of its player (%s)" % [state, t.info.name, str(t.info.avatar)])
		if slot >= 0:
			seen[slot] = true
			_chip_checks("%s, tag of %s" % [state, t.info.name], t.rect, String(t.info.name), int(t.info.avatar))
	_check(seen.size() == _game.participants.size(), "%s: each player has its own tag" % state)


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
	for i in 150:
		var snap := await _snap(1)
		var list: Array = snap.get("leader", [])
		if list.size() == 1 and accept.call(list[0]):
			return list[0]
	return {}


## The label of a name in the lists of the TV: the labels of `node` with this text.
func _name_labels(node: Node, shown: String) -> Array:
	return node.find_children("*", "Label", true, false).filter(func(l): return l.text == shown)


## Width of the text of `l` and the room it has.
func _fits(l: Label) -> bool:
	var need := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
	return l.size.x + 0.5 >= need and l.get_global_rect().position.x >= -0.5 and l.get_global_rect().end.x <= 1920.5


## 4a and 4b: the Players list and the Connect screen.
func _lists() -> void:
	print("the Players list and the Connect screen")
	for lang in ["en", "he"]:
		_app.set_language(lang, false)
		_app.go_games()
		await _frames(4)
		var games: Control = _app.current_screen()
		games._open_players()
		await _frames(4)
		var modal: Node = games._modal
		var state := "Players list in " + ("Hebrew" if lang == "he" else "English")
		_check(_name_labels(modal, "SAM").size() == 1 and _name_labels(modal, "SAM 2").size() == 1,
				"4a: %s shows SAM and SAM 2 (upper case)" % state)
		var latin := _name_labels(modal, "ABCDEFGHIJ")
		var hebrew := _name_labels(modal, String(PHONES[1].name))
		_check(latin.size() == 1 and hebrew.size() == 1,
				"4b: %s has the name of 10 Latin letters and the name of 10 Hebrew letters" % state)
		var whole: bool = latin.all(_fits) and hebrew.all(_fits)
		var widths := "(%s px for 400 px of text, %s px)" % [str(latin[0].size.x) if not latin.is_empty() else "-",
				str(hebrew[0].size.x) if not hebrew.is_empty() else "-"]
		_check(whole, "4b: %s: both names are whole %s" % [state, widths])
		games.on_back()
		await _frames(2)
		_app.go_connect()
		await _frames(4)
		var connect: Control = _app.current_screen()
		state = "Connect screen in " + ("Hebrew" if lang == "he" else "English")
		var latin2 := _name_labels(connect, "ABCDEFGHIJ")
		var hebrew2 := _name_labels(connect, String(PHONES[1].name))
		_check(latin2.size() == 1 and hebrew2.size() == 1 and latin2.all(_fits) and hebrew2.all(_fits),
				"4b: %s: the name of 10 Latin letters and the name of 10 Hebrew letters are whole" % state)
	_app.set_language("en", false)
	_app.go_games()
	await _frames(2)


## 6a2: a phone whose link goes away with no close (what switching the Wi-Fi off does). The relay drops every byte. The game is
## paused with a card that names the player within the timeout of the protocol (5 s).
func _relay_cut() -> void:
	print("Wi-Fi off: the card names the player")
	for c in _clients:
		c.leave()
	await _wait_until(func(): return _app.server.connected_slots().is_empty(), 4000)
	var relay: Node = TcpRelay.new()
	root.add_child(relay)
	relay.start(RELAY_PORT, Protocol.WS_PORT)
	var phone := ControllerClient.new()
	phone.set_profile("b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0", "Noam", 7)
	root.add_child(phone)
	phone.connect_to("127.0.0.1", RELAY_PORT, _app.server.room_code)
	var joined := await _wait_until(func(): return _app.server.connected_slots().size() == 1, 4000)
	_check(joined, "the phone joins through the relay")
	_app.server.peer_timeout_ms = Protocol.PEER_TIMEOUT_MS
	_app.go(load(GAMES.maze[0]))
	await _frames(4)
	var game: Control = _app.current_screen()
	await create_timer(3.6).timeout   # The countdown is over.
	_check(not game._hold, "the game runs before the cut")
	relay.cut()
	var t0 := Time.get_ticks_msec()
	await _wait_until(func(): return game._hold, 12000)
	var took := Time.get_ticks_msec() - t0
	await _frames(3)
	_check(game._hold and Protocol.PEER_TIMEOUT_MS <= 5000 and took <= Protocol.PEER_TIMEOUT_MS + 1500,
			"6a2: the game is paused %d ms after the link was cut (the timeout is %d ms)" % [took, Protocol.PEER_TIMEOUT_MS])
	var title: String = game._menu_box.find_children("*", "Label", true, false)[0].text
	_check(title == "NOAM LOST CONNECTION", "6a2: the pause card names the player: '%s'" % title)
	relay.restore()
	phone.leave()
	phone.queue_free()
	relay.stop()
	relay.queue_free()
	await _frames(5)
	for p in _app.server.players:
		if p.is_present():
			_app.server.drop_player(p.slot)
	_app.go_games()
	await _frames(2)
