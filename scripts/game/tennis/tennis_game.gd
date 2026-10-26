extends "res://scripts/game/minigame.gd"
## Tennis: 1 to 4 phones (REQ-TN-1 to 20). The players swing the phone to hit the ball, the characters run by themselves. The
## rules are in tennis_rules.gd, the ball in tennis_sim.gd, the match in tennis_match.gd and the pictures in tennis_look.gd.
## The game is for children too (REQ-GM-80 to 84): a bad swing gives a slow lob that stays in play, and nobody is hurt.

const Match = preload("res://scripts/game/tennis/tennis_match.gd")
const Look = preload("res://scripts/game/tennis/tennis_look.gd")
const Rules = preload("res://scripts/game/tennis/tennis_rules.gd")
const Sim = preload("res://scripts/game/tennis/tennis_sim.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const COUNTDOWN := 3.0
const END_DELAY := 2.2          # After the last point the court stays this long, then the result menu opens.
const HINT_TIME := 16.0         # The hint lines show this long at the start of the match.
const BANNER_TIME := 1.6
const GREAT_TIME := 0.8
const BUZZ_HIT_MS := 30
const BUZZ_GREAT_MS := 60
const PAUSE_GAP_MS := 400       # A gap between two ticks longer than this means the game was paused: swings are ignored.
const PANEL_W := 700.0
const PANEL_ROW := 60.0

## Set before the game starts (REQ-GM-93). `start_props` keeps them for Try again.
var difficulty := "medium"
var scoring := "real"

var play := Match.new()

var _board: Scoreboard
var _clock := RoundClock.new(0.0, 0.0)   # With the solo timer it gets the 3 s countdown in _game_ready().
var _haptics := Haptics.new()
var _time := 0.0
var _playing := 0.0             # Seconds since GO.
var _end_left := -1.0
var _banner := ""
var _banner_sub := ""
var _banner_left := 0.0
var _banner_color := UiTheme.ACCENT
var _great: Dictionary = {}     # slot -> seconds left of the GREAT! text over the player.
var _sparks: Array = []         # {pos: Vector3, age: float} of the green hits: a few pixel sparks at the racket (REQ-TN-6).
var _tick_ms := 0
var _wired: Array[int] = []     # The slots whose signals are connected, also the ones that left later.


## Only the solo machine rally shows a timer, so only it starts with the countdown (REQ-GM-35, REQ-TN-4).
func _has_countdown() -> bool:
	return participants.size() == 1


func _game_ready() -> void:
	var slots: Array[int] = []
	slots.assign(participants)
	play.setup(slots, scoring == "quick", difficulty, int(Time.get_ticks_msec()))
	_board = Scoreboard.new(participants)
	for s in participants:
		player(s).button_pressed.connect(_on_button.bind(s))
		player(s).swung.connect(_on_swing.bind(s))
		_wired.append(s)
	if _has_countdown():
		_clock = RoundClock.new(COUNTDOWN, 0.0)
	else:
		for s in participants:
			player(s).recenter()   # No countdown: the pose at the start is the middle of the aim (REQ-TN-7).


func _exit_tree() -> void:
	for s in _wired:
		var pl := player(s)
		if pl == null:
			continue
		var cb := _on_button.bind(s)
		if pl.button_pressed.is_connected(cb):
			pl.button_pressed.disconnect(cb)
		var sw := _on_swing.bind(s)
		if pl.swung.is_connected(sw):
			pl.swung.disconnect(sw)


func _on_player_left(slot: int) -> void:
	play.remove_player(slot)
	_board.remove(slot)
	_great.erase(slot)


# ---- The phones ----

func _on_button(bit: int, slot: int) -> void:
	if bit != Protocol.BTN_A or not _live():
		return
	play.press_a(slot)


func _on_swing(info: Dictionary, slot: int) -> void:
	if not _live() or Time.get_ticks_msec() - _tick_ms > PAUSE_GAP_MS:
		return
	var side := clampf(float(info.get("side", 0.0)), -1.0, 1.0)   # The side of the swing, not the tilt (REQ-TN-7).
	play.swing(slot, float(info.power), bool(info.down), side, float(info.hit_age_ms) / 1000.0)


## True while the match is on: not in the countdown (only the solo match has one), not over, not paused.
func _live() -> bool:
	return not is_over and not is_paused() and not _clock.is_counting() and not play.is_over()


# ---- The time ----

func _game_tick(delta: float) -> void:
	_time += delta
	_tick_ms = Time.get_ticks_msec()
	if is_over:
		return
	if _clock.is_counting():
		if _clock.tick(delta):
			for s in participants:
				player(s).recenter()   # The pose at GO is the middle of the aim (REQ-TN-7).
				App.server.haptic(s, 60)
		return
	_playing += delta
	_banner_left = maxf(0.0, _banner_left - delta)
	for s in _great.keys():
		_great[s] = float(_great[s]) - delta
		if float(_great[s]) <= 0.0:
			_great.erase(s)
	for sp in _sparks:
		sp.age = float(sp.age) + delta
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return float(sp.age) < Look.SPARK_TIME)
	if _end_left < 0.0:
		play.tick(delta)
		_handle_events(play.take_events())
		_sync_board()
		if play.is_over():
			_end_left = END_DELAY
	else:
		_end_left -= delta
		if _end_left <= 0.0:
			_finish()


func _handle_events(events: Array) -> void:
	for e in events:
		match String(e.t):
			"toss":
				Sound.sfx("tennis_toss")
			"hit":
				_on_hit(e)
			"bounce":
				Sound.sfx("tennis_bounce")
			"out":
				Sound.sfx("tennis_out")
				_show("tennis.out", "", UiTheme.TEXT, 1.0)
			"net":
				Sound.sfx("tennis_net")
				_show("tennis.net", "", UiTheme.TEXT, 1.0)
			"fault":
				Sound.sfx("tennis_fault")
				_show("tennis.fault", "", UiTheme.TEXT, Match.FAULT_PAUSE)
			"point":
				_on_point(e)
			"rally_over":
				_show(Lang.f("tennis.rally", [int(e.rally)]), "", UiTheme.ACCENT, Match.POINT_PAUSE)
				Sound.sfx("tennis_out")
			"time_up":
				_show("minigame.round_over", "", UiTheme.ACCENT, END_DELAY)
				Sound.sfx("tennis_game")
			"match_over":
				Sound.sfx("tennis_game")


func _on_hit(e: Dictionary) -> void:
	var slot := int(e.slot)
	var great: bool = e.green
	Sound.sfx("tennis_great" if great and slot >= 0 else "tennis_hit")   # The machine never gets the great sound.
	if slot < 0 or not participants.has(slot):
		return
	_haptics.pulse(slot, BUZZ_GREAT_MS if great else BUZZ_HIT_MS, 80)
	if great:
		_great[slot] = GREAT_TIME
		_sparks.append({"pos": e.get("pos", play.sim.pos), "age": 0.0})


func _on_point(e: Dictionary) -> void:
	var team := int(e.team)
	var names := _team_names(team)
	var sub := ""
	if e.status == "deuce":
		sub = Lang.t("tennis.deuce")
	elif e.status == "advantage":
		sub = Lang.f("tennis.advantage", [_team_names(play.rules.advantage_team())])
	if bool(e.game):
		Sound.sfx("tennis_game")
		_show(Lang.f("tennis.game_to", [names]), "", UiTheme.ACCENT, Match.GAME_PAUSE)
	else:
		Sound.sfx("tennis_point")
		_show(Lang.f("tennis.point_to", [names]), sub, UiTheme.ACCENT, Match.POINT_PAUSE)
	for s in play.rules.teams[team]:
		if participants.has(s):
			App.server.haptic(s, 80)


func _show(text: String, sub: String, color: Color, seconds: float) -> void:
	_banner = text
	_banner_sub = sub
	_banner_color = color
	_banner_left = maxf(BANNER_TIME * 0.5, seconds)


## The names of the players of a team, joined with " + ".
func _team_names(team: int) -> String:
	var names: Array = []
	for s in play.rules.teams[team]:
		if participants.has(s):
			names.append(player(s).player_name)
	return " + ".join(names)


## The board holds the games (Real) or the points (Quick) of each player; with 1 player the best rally (REQ-TN-17).
func _sync_board() -> void:
	if play.solo:
		for s in participants:
			_board.set_score(s, float(maxi(play.best_rally, play.rally)))
		return
	for s in participants:
		if play.rules.tally.has(s):
			_board.set_score(s, float(play.rules.tally[s]))


## The place of every player in a match of 2 to 4 players: a place belongs to the team, so the players of a team in front are 1
## and the others 2, and everybody is 1 when the teams are level (REQ-TN-13). Equal games share a place and the next place
## follows at once (1, 1, 2), unlike the ranks of REQ-GM-70.
func places() -> Dictionary:
	var scores := _scores()
	var out := {}
	for s in scores:
		var better := {}
		for o in scores:
			if scores[o] > scores[s]:
				better[scores[o]] = true
		out[s] = 1 + better.size()
	return out


## The games (Real) or points (Quick) of every player that is in the match, from the board that `_sync_board()` fills.
func _scores() -> Dictionary:
	var out := {}
	for s in participants:
		if _board.has(s):
			out[s] = int(_board.score(s))
	return out


## The most games (Real) or points (Quick) of one player; the leader chip shows nothing while it is 0.
func _best_tally() -> int:
	var best := 0
	for v in _scores().values():
		best = maxi(best, int(v))
	return best


func _publish_scores() -> void:
	if play.solo:
		super()
		return
	var pl := places()
	var teams_left := 0
	for t in play.rules.teams:
		teams_left += 1 if not t.is_empty() else 0
	var lead := _best_tally() > 0
	for s in pl:
		App.server.send_score(s, int(pl[s]) if lead else 0, teams_left if lead else 0, str(int(_board.score(s))))


func leader_text() -> String:
	if play.solo:
		return super()
	return str(_best_tally()) if _best_tally() > 0 else ""


## The leader chip shows the team in front with its games, or TIE when the teams are level (REQ-TN-13).
func draw_leader_chip(ci: CanvasItem) -> void:
	if play.solo:
		super(ci)
		return
	var best := _best_tally()
	if best <= 0:
		return
	var in_front := {}   # team -> the slots with the best score
	var scores := _scores()
	for s in scores:
		if scores[s] == best:
			var t := play.rules.team_of(s)
			if not in_front.has(t):
				in_front[t] = []
			in_front[t].append(s)
	if in_front.is_empty():
		return
	var chips: Array = []
	for t in in_front:
		var slots: Array = in_front[t]
		var names: Array = []
		for s in slots:
			names.append(player(s).player_name)
		chips.append({"player_name": " + ".join(names), "color": player(slots[0]).color,
				"avatar": player(slots[0]).avatar if slots.size() == 1 else -1})
	Shell.leader_chip(ci, Shell.area_width(ci), chips, leader_text())


## The match is over: one player sees the longest rally and no medal, more players the winners (REQ-TN-17, REQ-GM-73).
func _finish() -> void:
	for s in play.winners():
		if participants.has(s):
			App.server.haptic(s, 400)
	if play.solo:
		open_results(_board)
		return
	var names: Array = []
	for s in play.winners():
		if participants.has(s):
			names.append(player(s).player_name)
	var title := ""
	if not names.is_empty():
		title = Lang.f("result.winner", [" + ".join(names)])
		team_won = true   # Two winners of a team are a win for the sound, not a tie.
	open_results(_board, title)


func _scoreboard() -> Scoreboard:
	return _board


## No personal best for now: a rally and a games score need keys in the profile code (REQ-TN-17).
func best_key() -> String:
	return ""


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


func _foot(p: Look.Proj, c: Dictionary) -> Vector2:
	return p.at(c.pos.x, c.pos.y)


func _look_of(slot: int, c: Dictionary) -> Dictionary:
	var near := int(c.team) == 0
	var pose := "idle"
	var anim := float(c.anim)
	if anim < 0.4:
		pose = "serve" if play.serve_ball and anim < 0.4 and slot == play.server_slot() else "hit"
	elif (c.pos as Vector2).distance_to(c.target) > 0.05:
		pose = "run"
	return {"shirt": player(slot).color, "slot": slot, "back": near, "hand": 1.0 if near else -1.0, "pose": pose,
			"phase": play.time, "toss": play.phase == Match.Phase.TOSS and slot == play.server_slot()}


func _world_draw(ci: CanvasItem) -> void:
	var p := Look.Proj.new(size)
	Look.draw_hall(ci, size, p)
	Look.draw_court(ci, p)
	if play.phase == Match.Phase.RALLY:
		_draw_target(ci, p)
	Look.draw_tower(ci, p)
	var things: Array = [{"y": 0.0, "k": "net"}, {"y": -0.5, "k": "kid"}]
	if play.sim.active:
		Look.draw_ball_shadow(ci, p, play.sim.pos)
		things.append({"y": play.sim.pos.y, "k": "ball"})
	if play.solo:
		things.append({"y": play.machine_pos.y, "k": "machine"})
	for s in play.chars:
		if participants.has(s):
			things.append({"y": float(play.chars[s].pos.y), "k": "person", "slot": s})
	things.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y > b.y)
	for t in things:
		match String(t.k):
			"net":
				Look.draw_net(ci, p)
			"kid":
				Look.draw_ball_kid(ci, p)
			"ball":
				_draw_ball(ci, p)
			"machine":
				Look.draw_machine(ci, p, play.machine_pos, play.machine_anim)
			"person":
				var c = play.chars[t.slot]
				Look.draw_person(ci, _foot(p, c), p.scale(c.pos.y), _look_of(int(t.slot), c))
	for sp in _sparks:
		var sp_pos: Vector3 = sp.pos
		Look.draw_sparks(ci, p.at(sp_pos.x, sp_pos.y, maxf(sp_pos.z, 0.0) + 0.1), float(sp.age))
	ci.draw_rect(Rect2(0.0, 0.0, size.x, Look.HUD_H * size.y / 1080.0), UiTheme.BG)


func _draw_ball(ci: CanvasItem, p: Look.Proj) -> void:
	var pos: Vector3 = play.sim.pos
	if play.phase == Match.Phase.RALLY and not play.contact.is_empty() and _hits_pending():
		var c := p.at(pos.x, pos.y, maxf(pos.z, 0.0) + 0.1)
		var r := maxf(20.0, 0.17 * p.scale(pos.y))
		var pulse := 4.0 * floorf(fmod(_time * 6.0, 2.0))
		ci.draw_rect(Rect2(Shell.snap(c - Vector2(r + pulse, r + pulse)), Vector2.ONE * 2.0 * (r + pulse)), Color(1.0, 1.0, 1.0, 0.35))
	Look.draw_ball(ci, p, pos)


## True when a player has to hit the ball (not the machine): the ball glows (REQ-TN-5).
func _hits_pending() -> bool:
	return play.hitter >= 0


## The ring on the court where the next hit happens: `{show, green, left}`. It shows when a player has to hit and the contact is
## less than 1.2 s away (or at most HIT_W past). It is green when a swing now is a great one (REQ-TN-6), else yellow.
func ring_state() -> Dictionary:
	if play.hitter < 0 or play.contact.is_empty():
		return {"show": false, "green": false, "left": 0.0}
	var left := float(play.contact.t) - play.time
	var show := not (left > 1.2 or left < -Match.HIT_W)
	return {"show": show, "green": absf(left) <= float(play.level.green), "left": left}


func _draw_target(ci: CanvasItem, p: Look.Proj) -> void:
	var ring := ring_state()
	if not ring.show:
		return
	var cp: Vector3 = play.contact.pos
	var green: bool = ring.green
	var color := Color("5cf070") if green else Color("f4e04a")
	var pts := PackedVector2Array()
	for i in 17:
		var a := TAU * float(i) / 16.0
		pts.append(p.at(cp.x + cos(a) * 0.8, cp.y + sin(a) * 0.8))
	ci.draw_polyline(pts, color, 6.0 if green else 4.0)


func _game_draw() -> void:
	Shell.title(self, "registry.tennis")
	draw_leader_chip(self)
	var p := Look.Proj.new(size)
	if _clock.is_counting():
		_draw_countdown()
		return
	if not play.solo:
		_draw_panel()
	else:
		_draw_solo_panel()
	_draw_great(p)
	if is_over:
		return
	if _banner_left > 0.0 and _banner != "":
		Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.24), _banner, 64, _banner_color)
		if _banner_sub != "":
			Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.24 + 110.0), _banner_sub, 32, UiTheme.TEXT)
	elif play.phase == Match.Phase.SERVE and not play.solo:
		var server := play.server_slot()
		if participants.has(server):
			Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.24), Lang.f("tennis.serves", [player(server).player_name]), 48,
					player(server).color if Shell.contrast(player(server).color, UiTheme.BG) >= 4.5 else UiTheme.TEXT)
	var hint := _hint()
	if hint != "":
		Shell.hint(self, size, hint)


func _hint() -> String:
	if _playing > HINT_TIME or play.is_over():
		return ""
	if play.solo:
		return "tennis.hint_solo"
	if play.phase == Match.Phase.SERVE or play.phase == Match.Phase.TOSS:
		return "tennis.hint_serve"
	if play.phase == Match.Phase.RALLY:
		return "tennis.hint_hit"
	return ""


func _draw_countdown() -> void:
	var n := _clock.count_number()
	var label := str(n)
	draw_set_transform(Vector2(8.0, 8.0), 0.0, Vector2.ONE)
	Shell.countdown(self, size, label, _clock.count_elapsed(), UiTheme.BG)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Shell.countdown(self, size, label, _clock.count_elapsed())


## Over the player after a great hit.
func _draw_great(p: Look.Proj) -> void:
	for s in _great:
		if not play.chars.has(s):
			continue
		var c = play.chars[s]
		var at := Look.head_pos(_foot(p, c), p.scale(c.pos.y)) - Vector2(0.0, 40.0)
		Shell.label_plate(self, Shell.snap(at), "tennis.great", 32, Color("5cf070"))


## The score of the teams, top left: the colors of the players, the names, the games and the points of the game (REQ-TN-10).
func _draw_panel() -> void:
	var rules := play.rules
	var x := Shell.mx(self, 60.0, PANEL_W)
	var y := Look.HUD_H + 16.0
	var f := UiTheme.font()
	for team in 2:
		var row := Rect2(x, y + team * PANEL_ROW, PANEL_W, PANEL_ROW - 6.0)
		draw_style_box(UiTheme.line_box(UiTheme.FRAME, UiTheme.BG, 4), row)
		var cx := row.position.x + 14.0
		for s in rules.teams[team]:
			if participants.has(s):
				draw_rect(Rect2(cx, row.position.y + 17.0, 22.0, 22.0), player(s).color)
				cx += 30.0
		var names := Shell.fit_text(_team_names(team).to_upper(), PANEL_W - 250.0 - (cx - row.position.x), 28)
		draw_string(f, Vector2(cx + 4.0, row.position.y + 38.0), names, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.TEXT)
		if play.phase != Match.Phase.END and not rules.teams[team].is_empty() and rules.team_of(play.server_slot()) == team:
			draw_circle(Vector2(row.end.x - 190.0, row.position.y + 28.0), 8.0, Look.BALL)
		var games := 0
		for s in rules.teams[team]:
			games = maxi(games, int(rules.tally.get(s, 0)))
		draw_string(f, Vector2(row.end.x - 150.0, row.position.y + 38.0), str(games), HORIZONTAL_ALIGNMENT_RIGHT, 60.0, 32,
				UiTheme.ACCENT)
		if not rules.quick:
			draw_string(f, Vector2(row.end.x - 80.0, row.position.y + 38.0), rules.point_text(team), HORIZONTAL_ALIGNMENT_RIGHT, 64.0,
					32, UiTheme.TEXT)


## With 1 player: the running rally, the best one and the time left (REQ-TN-15).
func _draw_solo_panel() -> void:
	var f := UiTheme.font()
	var rally := Lang.f("tennis.rally", [play.rally]).to_upper()
	var best := Lang.f("tennis.best", [maxi(play.best_rally, play.rally)]).to_upper()
	var x := Shell.mx(self, 60.0, 360.0)
	var y := Look.HUD_H + 16.0
	for i in 2:
		var row := Rect2(x, y + i * PANEL_ROW, 360.0, PANEL_ROW - 6.0)
		draw_style_box(UiTheme.line_box(UiTheme.FRAME, UiTheme.BG, 4), row)
		draw_string(f, Vector2(row.position.x + 16.0, row.position.y + 38.0), rally if i == 0 else best,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.ACCENT if i == 0 else UiTheme.TEXT)
	Shell.timer(self, Vector2(Shell.TIMER_X, Shell.TIMER_Y), maxf(0.0, play.solo_left))
