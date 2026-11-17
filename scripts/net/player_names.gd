extends RefCounted
## The names that the TV shows for the players (docs/PROFILES_PLAN.md 4.3). It was part of `TvServer` and moved here so that
## the server file stays under the line limit of the linter (issue #455); the rules did not change.

const PlayerInput = preload("res://scripts/input/player_input.gd")


## The names that the TV shows (docs/PROFILES_PLAN.md 4.3): the profile name, or "Player N" for a phone without a name. A
## name that another player has already gets a number (`Sam`, `Sam 2`); case and spaces at the ends do not count. With `only`
## set, only that slot is made again (a phone that joins in a round), against the names of the others.
static func assign(players: Array, only := -1) -> void:
	var used: Array[String] = []
	if only >= 0:
		for p in players:
			if p.is_present() and p.slot != only:
				used.append(p.player_name.strip_edges().to_upper())
	for p in players:
		if not p.is_present() or (only >= 0 and p.slot != only):
			continue
		var base: String = p.raw_name if p.raw_name != "" else PlayerInput.default_name(p.slot)
		var shown := base
		var n := 2
		while used.has(shown.strip_edges().to_upper()):
			shown = "%s %d" % [base, n]
			n += 1
		p.player_name = shown
		used.append(shown.strip_edges().to_upper())
