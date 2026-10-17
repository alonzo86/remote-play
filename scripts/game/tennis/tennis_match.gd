extends RefCounted
## One tennis match without a screen (REQ-TN-1 to 20): the players on the court, the serve, the rally, the points and the end.
## Pure logic. The game passes in what the phones do (`press_a()`, `swing()`) and the time (`tick()`), reads the positions
## and `sim` to draw, and takes the `events` for the sound, the buzz and the banners.
## The near team (team 0) stands at negative `y`. A player runs by itself to the place where the ball will be hit; a swing
## whose hit time is inside the hit window (HIT_W) of the contact time returns the ball (REQ-TN-4 to 7).
## With 1 player the other side is a friendly ball machine that returns every ball; the score is the longest rally (REQ-TN-15).

const Sim = preload("res://scripts/game/tennis/tennis_sim.gd")
const Rules = preload("res://scripts/game/tennis/tennis_rules.gd")

enum Phase { SERVE, TOSS, RALLY, POINT, END }

const HIT_W := 0.55             # A swing counts when its hit is this close (s) to the contact time.
const SERVE_W := 0.45           # The same for a serve, around the top of the toss.
const TOSS_UP := 4.6            # The speed (m/s) of the toss.
const TOSS_FROM := 1.0          # The height (m) of the hand at the toss.
const POINT_PAUSE := 1.8        # The banner after a point, a fault and a game.
const FAULT_PAUSE := 1.4
const GAME_PAUSE := 2.6
const FEED_DELAY := 1.6         # With 1 player the machine sends the next ball after this time.
const SOLO_ROUND := 90.0
const RUN_SPEED := 6.5
const BEHIND := 0.6             # A player hits the ball from this far behind it.
const FAULTS_FOR_POINT := 2

var rules := Rules.new()
var sim := Sim.new()
var rng := RandomNumberGenerator.new()
var difficulty := "medium"
var level := Rules.level("medium")
var solo := false
var phase := Phase.SERVE
var time := 0.0
var phase_time := 0.0
var chars := {}                 # slot -> {pos: Vector2, target: Vector2, team: int, anim: float (s since the last hit)}
var machine_pos := Vector2(0.0, Sim.HALF_L + 1.2)
var machine_anim := 99.0
var hit_team := 0               # The team that hit the ball last.
var expect_team := 1            # The team that has to return it.
var hitter := -1                # The slot that has to hit now (-1: the machine, or nobody).
var contact := {}               # {t: absolute time, pos: Vector3} of the next hit, or empty.
var serve_ball := false         # The ball in the air is a serve that has not landed yet.
var faults := 0
var rally := 0                  # With 1 player: balls of the player that landed in, in the running rally.
var best_rally := 0
var solo_left := SOLO_ROUND
var last_point := {}
var events: Array = []

var _toss_apex := 0.0
var _wait := 0.0
var _winners: Array[int] = []


## `slots`: the players. `quick`: the scoring Quick. `seed_value` makes the random aim of a lob or of the machine repeatable.
func setup(slots: Array, quick: bool, p_difficulty: String, seed_value := 1) -> void:
	difficulty = p_difficulty
	level = Rules.level(difficulty)
	rng.seed = seed_value
	solo = slots.size() == 1
	rules.setup(slots, quick)
	chars.clear()
	for s in slots:
		chars[s] = {"pos": Vector2.ZERO, "target": Vector2.ZERO, "team": 0, "anim": 99.0}
	time = 0.0
	solo_left = SOLO_ROUND
	rally = 0
	best_rally = 0
	faults = 0
	machine_anim = 99.0
	_begin_serve()
	for s in chars:
		chars[s].pos = chars[s].target


## The side of the court of a team: -1 for the near team (negative `y`), +1 for the far team.
static func side(team: int) -> float:
	return -1.0 if team == 0 else 1.0


## +1 when the right hand of the team is world `x` positive (the near team), -1 for the far team.
static func mirror(team: int) -> float:
	return 1.0 if team == 0 else -1.0


func take_events() -> Array:
	var e := events
	events = []
	return e


func team_of(slot: int) -> int:
	return int(chars[slot].team) if chars.has(slot) else 0


func is_over() -> bool:
	return phase == Phase.END


func winners() -> Array[int]:
	return _winners


## The half width of the court that counts: the singles lines for 1 against 1 and for a rally, the doubles lines otherwise.
func half_width() -> float:
	if solo:
		return Sim.HALF_W_SINGLES
	for t in rules.teams:
		if t.size() > 1:
			return Sim.HALF_W_DOUBLES
	return Sim.HALF_W_SINGLES


# ---- The serve ----

func server_slot() -> int:
	return chars.keys()[0] if solo else rules.server_slot()


func _begin_serve() -> void:
	phase = Phase.SERVE
	phase_time = 0.0
	sim.clear()
	serve_ball = false
	hitter = -1
	contact = {}
	for s in chars:
		chars[s].team = 0 if solo else rules.team_of(s)
	if solo:
		var slot: int = chars.keys()[0]
		chars[slot].target = Vector2(0.0, -(Sim.HALF_L - 1.2))
		return
	var server := server_slot()
	var st := team_of(server)
	var sx := _serve_x(st)
	var spos := Vector2(sx, side(st) * (Sim.HALF_L + BEHIND))
	var rt := rules.other(st)
	var box := -signf(sx)
	_set_formation(st, server, spos, Vector2(-sx * 0.6, side(st) * 3.5))
	var receivers: Array = rules.teams[rt]
	if not receivers.is_empty():
		_set_formation(rt, receivers[0], Vector2(box * 2.3, side(rt) * (Sim.HALF_L - 0.5)),
				Vector2(-box * 2.0, side(rt) * 3.0))
	events.append({"t": "serve_ready", "slot": server})


## Where the server of team `st` stands in x: the right or the left half of the baseline, from the view of the server.
func _serve_x(st: int) -> float:
	return (1.0 if rules.serve_side() == 0 else -1.0) * 2.0 * mirror(st)


## `lead` goes to `lead_pos`, the other member of the team (if any) goes to `partner_pos`.
func _set_formation(team: int, lead: int, lead_pos: Vector2, partner_pos: Vector2) -> void:
	for s in rules.teams[team]:
		chars[s].target = lead_pos if s == lead else partner_pos


func press_a(slot: int) -> void:
	if solo:
		if phase == Phase.SERVE and chars.has(slot):
			_wait = FEED_DELAY   # A skips the wait of the machine.
		return
	if phase != Phase.SERVE or slot != server_slot():
		return
	var c = chars[slot]
	sim.toss(Vector3(c.pos.x, c.pos.y, TOSS_FROM), TOSS_UP)
	_toss_apex = time + TOSS_UP / Sim.G
	phase = Phase.TOSS
	phase_time = 0.0
	events.append({"t": "toss", "slot": slot})


# ---- Swings ----

## A swing of `slot`: `power` 0 to 1, `down` (from top to bottom), `tilt_x` (-1 left to 1 right, of the phone) and the age of the
## hit in seconds. Returns "serve", "hit" or "none" (the swing did nothing: no cost, REQ-TN-5).
func swing(slot: int, power: float, down: bool, tilt_x: float, hit_age: float) -> String:
	if not chars.has(slot):
		return "none"
	var t := time - hit_age
	match phase:
		Phase.TOSS:
			if slot != server_slot() or not down or absf(t - _toss_apex) > SERVE_W:
				return "none"
			_serve_hit(slot, power, tilt_x, absf(t - _toss_apex) <= level.green)
			return "serve"
		Phase.RALLY:
			if slot != hitter or contact.is_empty() or absf(t - float(contact.t)) > HIT_W:
				return "none"
			_rally_hit(slot, power, tilt_x, absf(t - float(contact.t)) <= level.green)
			return "hit"
	return "none"


func _serve_hit(slot: int, power: float, tilt_x: float, green: bool) -> void:
	var team := team_of(slot)
	var from := sim.pos
	var box := -signf(chars[slot].pos.x)
	var hw := Sim.HALF_W_SINGLES
	var aim := tilt_x * mirror(team)
	var tx := box * hw * 0.5 + aim * hw * 0.65
	var depth := lerpf(2.6, 6.9, power) if green else lerpf(3.0, 5.0, power)
	if not green:
		tx += rng.randf_range(-1.0, 1.0) * 0.8
	if level.inside:
		tx = clampf(tx, minf(box * 0.3, box * (hw - 0.3)), maxf(box * 0.3, box * (hw - 0.3)))
		depth = minf(depth, Sim.SERVICE - 0.5)
	var flight: float = (lerpf(1.0, 0.75, power) if green else 1.35) * float(level.flight)
	sim.launch(from, Vector2(tx, -side(team) * depth), flight)
	serve_ball = true
	_after_hit(slot, team, green, power)


func _rally_hit(slot: int, power: float, tilt_x: float, green: bool) -> void:
	var team := team_of(slot)
	var other := rules.other(team) if not solo else 1
	var hw := half_width()
	var tx := tilt_x * mirror(team) * hw * 1.12
	var frac := lerpf(0.40, 0.97, power) if green else 0.82
	if not green:
		tx += rng.randf_range(-1.0, 1.0) * 1.2
	var ty := side(other) * frac * Sim.HALF_L
	if level.inside:
		tx = clampf(tx, -(hw - 0.4), hw - 0.4)
		ty = clampf(ty, -(Sim.HALF_L - 0.6), Sim.HALF_L - 0.6)
	var flight: float = (lerpf(1.1, 0.72, power) if green else 1.7) * float(level.flight)
	var from := Vector3(sim.pos.x, sim.pos.y, maxf(sim.pos.z, 0.5))
	var c = chars[slot]
	c.pos = Vector2(sim.pos.x, sim.pos.y + side(team) * BEHIND)
	c.target = c.pos
	sim.launch(from, Vector2(tx, ty), flight)
	_after_hit(slot, team, green, power)


## The ball was hit by `team` (`slot`, or -1 for the machine): the other team has to return it.
func _after_hit(slot: int, team: int, green: bool, power: float) -> void:
	hit_team = team
	expect_team = rules.other(team) if not solo else 1 - team
	phase = Phase.RALLY
	phase_time = 0.0
	if slot >= 0:
		chars[slot].anim = 0.0
	else:
		machine_anim = 0.0
	events.append({"t": "hit", "slot": slot, "team": team, "green": green, "power": power})
	var pred := sim.predict()
	contact = {}
	hitter = -1
	if not pred.is_empty():
		contact = {"t": time + float(pred.contact_t), "pos": pred.contact_pos}
	_choose_hitter()


## The player of the team that has to return the ball who is nearest to the contact point runs there (REQ-TN-5).
func _choose_hitter() -> void:
	hitter = -1
	var members: Array = []
	if solo:
		members = chars.keys() if expect_team == 0 else []
	else:
		members = rules.teams[expect_team]
	if members.is_empty() or contact.is_empty():
		return
	var cp := Vector2(contact.pos.x, contact.pos.y)
	var best := INF
	for s in members:
		var d: float = chars[s].pos.distance_to(cp)
		if d < best:
			best = d
			hitter = s
	var t_c := side(expect_team)
	chars[hitter].target = Vector2(cp.x, cp.y + t_c * BEHIND)
	for s in members:
		if s != hitter:
			chars[s].target = Vector2(-cp.x * 0.5, t_c * 3.0)


# ---- The time ----

func tick(delta: float) -> void:
	time += delta
	phase_time += delta
	_move(delta)
	if solo and phase != Phase.END:
		solo_left -= delta
		if solo_left <= 0.0:
			_end_solo()
			return
	match phase:
		Phase.SERVE:
			_tick_serve(delta)
		Phase.TOSS:
			_tick_toss(delta)
		Phase.RALLY:
			_tick_rally(delta)
		Phase.POINT:
			_wait -= delta
			if _wait <= 0.0:
				if not solo and rules.match_over():
					_end_match()
				else:
					_begin_serve()
	machine_anim += delta


func _move(delta: float) -> void:
	for s in chars:
		var c = chars[s]
		c.pos = c.pos.move_toward(c.target, RUN_SPEED * delta)
		c.anim += delta


func _tick_serve(delta: float) -> void:
	if not solo:
		return
	_wait += delta
	if _wait >= FEED_DELAY and phase_time >= FEED_DELAY * 0.5:
		_wait = 0.0
		_feed()


## With 1 player: the machine sends a ball to the player.
func _feed() -> void:
	var hw := Sim.HALF_W_SINGLES
	var to := Vector2(rng.randf_range(-0.4, 0.4) * hw, -rng.randf_range(0.5, 0.8) * Sim.HALF_L)
	sim.launch(Vector3(machine_pos.x, machine_pos.y, 1.0), to, 1.3 * float(level.flight))
	rally = 0
	faults = 0
	serve_ball = false
	_after_hit(-1, 1, true, 0.5)


func _tick_toss(delta: float) -> void:
	sim.tick(delta)
	if sim.pos.z < 0.6 and sim.vel.z < 0.0:
		sim.clear()
		phase = Phase.SERVE   # The ball was not hit: the server tosses again (REQ-TN-9).
		phase_time = 0.0
		events.append({"t": "toss_lost", "slot": server_slot()})


func _tick_rally(delta: float) -> void:
	sim.tick(delta)
	if solo and expect_team == 1 and not contact.is_empty() and time >= float(contact.t):
		_machine_hit()
		return
	for e in sim.events:
		if phase != Phase.RALLY:
			break
		if e.t == "net":
			_net_hit()
		elif e.t == "bounce":
			_bounce(e)
	if phase == Phase.RALLY and phase_time > 14.0:
		_award(hit_team, "timeout")


func _machine_hit() -> void:
	var hw := Sim.HALF_W_SINGLES
	var err := float(level.machine_error)
	var tx := clampf(rng.randf_range(-1.0, 1.0) * hw * 0.55 * (err / 1.4), -(hw - 0.5), hw - 0.5)
	var ty := side(0) * rng.randf_range(0.6, 0.85) * Sim.HALF_L
	var from := Vector3(sim.pos.x, sim.pos.y, maxf(sim.pos.z, 0.5))
	sim.launch(from, Vector2(tx, ty), 1.15 * float(level.flight))
	_after_hit(-1, 1, true, 0.5)


func _net_hit() -> void:
	events.append({"t": "net"})
	if serve_ball:
		_fault("net")
	else:
		_award(1 - hit_team, "net")


func _bounce(e: Dictionary) -> void:
	var bp: Vector3 = e.pos
	if int(e.n) >= 2:
		events.append({"t": "bounce", "pos": bp})
		_award(hit_team, "double_bounce")
		return
	var valid := _in_service_box(bp) if serve_ball else _in_court(bp)
	if not valid:
		events.append({"t": "out", "pos": bp})
		if serve_ball:
			_fault("out")
		else:
			_award(1 - hit_team, "out")
		return
	events.append({"t": "bounce", "pos": bp})
	serve_ball = false
	faults = 0
	if solo and hit_team == 0:
		rally += 1


## The ball landed inside the lines of the side of the team that has to return it.
func _in_court(p: Vector3) -> bool:
	return p.y * side(hit_team) < 0.0 and absf(p.y) <= Sim.HALF_L and absf(p.x) <= half_width()


## The service box across the net from the server: the half of the court with the sign `box` in x, up to the service line.
func _in_service_box(p: Vector3) -> bool:
	var server := server_slot()
	var st := team_of(server)
	var box := -signf(_serve_x(st))
	return p.y * side(st) < 0.0 and absf(p.y) <= Sim.SERVICE and p.x * box >= 0.0 and absf(p.x) <= Sim.HALF_W_SINGLES


# ---- Points ----

func _fault(reason: String) -> void:
	faults += 1
	if faults >= FAULTS_FOR_POINT:
		var st := team_of(server_slot())
		_award(rules.other(st), "double_fault")
		return
	events.append({"t": "fault", "reason": reason})
	phase = Phase.POINT
	phase_time = 0.0
	_wait = FAULT_PAUSE


## `team` won the point. With 1 player the point is the end of a rally (`team` 1: the player missed).
func _award(team: int, reason: String) -> void:
	faults = 0
	if solo:
		best_rally = maxi(best_rally, rally)
		events.append({"t": "rally_over", "rally": rally, "best": best_rally, "reason": reason})
		rally = 0
		phase = Phase.POINT
		phase_time = 0.0
		_wait = POINT_PAUSE
		return
	var r := rules.score_point(team)
	last_point = {"team": team, "reason": reason, "game": r.game, "match": r.match, "status": rules.status()}
	events.append({"t": "point", "team": team, "reason": reason, "game": r.game, "match": r.match,
			"status": rules.status()})
	phase = Phase.POINT
	phase_time = 0.0
	_wait = GAME_PAUSE if r.game else POINT_PAUSE


func _end_match() -> void:
	phase = Phase.END
	_winners = rules.winners()
	events.append({"t": "match_over", "winners": _winners})


func _end_solo() -> void:
	best_rally = maxi(best_rally, rally)
	phase = Phase.END
	events.append({"t": "time_up", "best": best_rally})


# ---- Players that leave ----

## A player left (REQ-TN-20). With 1 player the game ends (the base class shows the menu).
func remove_player(slot: int) -> void:
	if not chars.has(slot):
		return
	if solo:
		chars.erase(slot)
		phase = Phase.END
		return
	chars.erase(slot)
	var over := rules.remove_player(slot)
	if over:
		_end_match()
		return
	if phase == Phase.SERVE or phase == Phase.TOSS:
		_begin_serve()
	elif phase == Phase.RALLY:
		if hitter == slot or hitter < 0:
			_choose_hitter()
	elif phase == Phase.POINT:
		pass
