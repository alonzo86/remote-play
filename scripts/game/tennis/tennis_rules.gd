extends RefCounted
## The score and the teams of Tennis (REQ-TN-1, 10, 11, 20). Pure logic: no drawing, no ball.
## Scoring `Real`: the points of a game count 0, 15, 30, 40, and at 40 to 40 a team needs two points more than the other (deuce,
## advantage); a match goes to GAMES_TO_WIN games. Scoring `Quick`: the first to QUICK_POINTS points wins and there are no games.
## `tally` is the number of games (Real) or points (Quick) that each player has won. A team gives its tally to every player.
## 2 players: 1 against 1. 3 players: 2 against 1, and the single player changes after every game (Real) or 2 points (Quick).
## 4 players: 2 against 2. Team 0 is the team of the first player: it stands at the near end of the court (the camera).

const GAMES_TO_WIN := 3
const QUICK_POINTS := 5
const QUICK_SERVE_POINTS := 2     # In Quick the server changes after this many points.
const POINT_NAMES := ["0", "15", "30", "40"]

var quick := false
var slots: Array[int] = []
var teams: Array = [[], []]       # Two arrays of slots. Team 0 holds slots[0].
var tally := {}                   # slot -> games (Real) or points (Quick).
var points := [0, 0]              # The points of the running game, for each team (Real), or of the whole match (Quick).
var chunks := 0                   # Games (Real) or blocks of 2 points (Quick) that are over: it moves the server and the single.
var forfeit := false              # A team has no player left (REQ-TN-20).

var _order: Array[int] = []       # Indexes in `slots` in the order of the servers.


func setup(p_slots: Array, p_quick: bool) -> void:
	quick = p_quick
	slots.assign(p_slots)
	tally.clear()
	for s in slots:
		tally[s] = 0
	points = [0, 0]
	chunks = 0
	forfeit = false
	_rebuild()


## The teams and the order of the servers for the players that are left.
func _rebuild() -> void:
	var n := slots.size()
	if n <= 1:
		teams = [slots.duplicate(), []]
		_order.assign([0] if n == 1 else [])
		return
	if n == 2:
		teams = [[slots[0]], [slots[1]]]
		_order = [0, 1]
	elif n == 3:
		var single := chunks % 3
		var pair: Array = []
		for i in 3:
			if i != single:
				pair.append(slots[i])
		teams = [pair, [slots[single]]]
		if slots[0] == slots[single]:
			teams = [[slots[single]], pair]
		_order = [0, 1, 2]
	else:
		teams = [[slots[0], slots[1]], [slots[2], slots[3]]]
		_order = [0, 2, 1, 3]


func team_of(slot: int) -> int:
	return 0 if teams[0].has(slot) else 1


func other(team: int) -> int:
	return 1 - team


## The slot that serves the next point.
func server_slot() -> int:
	if _order.is_empty():
		return -1
	return slots[_order[chunks % _order.size()]]


## 0: the server stands on the right half of the baseline (from the view of the server), 1: on the left. It changes with every
## point of a game.
func serve_side() -> int:
	return (points[0] + points[1]) % 2


## A point for `team`. Returns `{team, game, match, text}`: `game` when it ends a game (Real), `match` when it ends the match.
func score_point(team: int) -> Dictionary:
	var out := {"team": team, "game": false, "match": false, "chunk": false}
	points[team] += 1
	if quick:
		for s in teams[team]:
			tally[s] += 1
		if (points[0] + points[1]) % QUICK_SERVE_POINTS == 0:
			_next_chunk()
			out.chunk = true
		out.match = match_over()
		return out
	if points[team] >= 4 and points[team] - points[other(team)] >= 2:
		for s in teams[team]:
			tally[s] += 1
		points = [0, 0]
		out.game = true
		out.match = match_over()
		_next_chunk()
		out.chunk = true
	return out


func _next_chunk() -> void:
	chunks += 1
	if slots.size() == 3:
		_rebuild()


func target() -> int:
	return QUICK_POINTS if quick else GAMES_TO_WIN


func match_over() -> bool:
	if forfeit:
		return true
	for s in slots:
		if tally[s] >= target():
			return true
	return false


## The players that won the match: the ones at the target (or the last team left after a forfeit).
func winners() -> Array[int]:
	var out: Array[int] = []
	if forfeit:
		out.assign(slots)
		return out
	for s in slots:
		if tally[s] >= target():
			out.append(s)
	return out


## A player left. Returns true when the match is over because of it (a team has no player left, REQ-TN-20). The teams and the
## servers are made again from the players that are left.
func remove_player(slot: int) -> bool:
	if not slots.has(slot):
		return match_over()
	slots.erase(slot)
	tally.erase(slot)
	if slots.size() < 2:
		forfeit = true
		_rebuild()
		return true
	points = [0, 0] if not quick else points
	_rebuild()
	return match_over()


## "deuce" at 40 to 40, "advantage" while a team leads after 40 to 40, else "". Only in Real.
func status() -> String:
	if quick or points[0] < 3 or points[1] < 3:
		return ""
	return "deuce" if points[0] == points[1] else "advantage"


## The advantage team, or -1.
func advantage_team() -> int:
	return -1 if status() != "advantage" else (0 if points[0] > points[1] else 1)


## The number of a team for the score: "0", "15", "30", "40" in Real, the points in Quick. A team with the advantage shows "AD".
func point_text(team: int) -> String:
	if quick:
		return str(points[team])
	if status() != "":
		return "AD" if advantage_team() == team else "40"
	return POINT_NAMES[mini(points[team], 3)]


## The level of a difficulty: the half width of the green part of the hit window in seconds (REQ-TN-6), the factor on the flight
## time (a slower ball on Easy), whether the ball is kept inside the lines (Easy) and the medal tiers of 1 player (REQ-TN-16).
static func level(difficulty: String) -> Dictionary:
	match difficulty:
		"easy":
			return {"green": 0.30, "flight": 1.2, "inside": true, "tiers": [4, 8, 14], "machine_error": 0.8}
		"hard":
			return {"green": 0.15, "flight": 0.9, "inside": false, "tiers": [6, 14, 28], "machine_error": 2.2}
	return {"green": 0.21, "flight": 1.0, "inside": false, "tiers": [5, 10, 20], "machine_error": 1.4}
