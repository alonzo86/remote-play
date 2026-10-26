extends SceneTree
## The medals in the result menu (REQ-GM-73): each row has the medal of its place, 1st gold, 2nd silver, 3rd bronze; players that
## tie have the same medal, nobody after the 3rd has one, and a player who did not finish has none. One player has no medal.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/results_medals.gd -- --role=tv

const Scoreboard = preload("res://scripts/game/scoreboard.gd")
const MedalView = preload("res://scripts/ui/medal_view.gd")

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
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	var app: Node = root.get_node("App")
	for i in 4:
		app.server.players[i].state = 1
	var maze: GDScript = load("res://scripts/game/maze/maze_game.gd")
	app.go(maze)
	await _frames(5)
	var game: Control = app.current_screen()
	# Times: lower is better. Four players with distinct times.
	var board := Scoreboard.new([], true)
	for s in 4:
		board.set_score(s, 10.0 + s)
	game.open_results(board)
	await _frames(2)
	_check(MedalView.tiers_in(game._menu_box) == ["gold", "silver", "bronze"],
			"1st gold, 2nd silver, 3rd bronze, nothing for the 4th")
	# A tie for the first place: both gold; the next place is the 3rd.
	board = Scoreboard.new([], true)
	board.set_score(0, 10.0)
	board.set_score(1, 10.0)
	board.set_score(2, 12.0)
	board.set_score(3, 13.0)
	game.open_results(board)
	await _frames(2)
	var tiers := MedalView.tiers_in(game._menu_box)
	_check(tiers == ["gold", "gold", "bronze"],
			"a tie for the first place gives both gold, and the next place is the 3rd: %s" % str(tiers))
	# A tie for the second place: both silver.
	board = Scoreboard.new([], true)
	board.set_score(0, 10.0)
	board.set_score(1, 11.0)
	board.set_score(2, 11.0)
	game.open_results(board)
	await _frames(2)
	_check(MedalView.tiers_in(game._menu_box) == ["gold", "silver", "silver"], "a tie for the second place gives both silver")
	# A player who did not finish has no medal.
	board = Scoreboard.new([], true)
	board.set_score(0, 10.0)
	board.set_unfinished(1, 3.0)
	game.open_results(board)
	await _frames(2)
	_check(MedalView.tiers_in(game._menu_box) == ["gold"], "a player who did not finish has no medal")
	# One player (a round that started with one phone): no medal at all, and no medal title (REQ-GM-73, issue #119).
	for i in range(1, 4):
		app.server.players[i].state = 0
	app.go(maze)
	await _frames(5)
	game = app.current_screen()
	var solo := Scoreboard.new([0], true)
	solo.set_score(0, 25.0)
	game.open_results(solo)
	await _frames(2)
	_check(MedalView.tiers_in(game._menu_box).is_empty(), "one player gets no medal, not even gold for the 1st place")
	var texts: Array = game._menu_box.find_children("*", "Label", true, false).map(func(l): return String(l.text))
	_check(texts.filter(func(t): return t.to_upper().contains("MEDAL")).is_empty(), "and no title about a medal: %s" % str(texts))
	# The sound of the result menu: a single player with a score wins; a player without a score gets the neutral sound (REQ-FL-65).
	var played: Array[String] = []
	var cb := func(id: String) -> void: played.append(id)
	var sound: Node = root.get_node("Sound")
	sound.sfx_played.connect(cb)
	await _frames(3)   # The same effect twice in 40 ms is one sound.
	played.clear()
	game.open_results(solo)
	_check(played.has("win") and not played.has("tie"), "a solo round with a score plays the win fanfare: %s" % str(played))
	await _frames(5)
	played.clear()
	var nobody := Scoreboard.new([0], true)
	nobody.set_unfinished(0, 3.0)
	game.open_results(nobody)
	_check(played.has("tie") and not played.has("win"), "a solo round with no score plays the neutral sound: %s" % str(played))
	sound.sfx_played.disconnect(cb)
	for i in 4:
		app.server.players[i].state = 0
