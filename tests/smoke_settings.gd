extends SceneTree
## Smoke test of the settings view (REQ-GM-90 to 95) with the maze. Run:
##   godot --headless --path . --script tests/smoke_settings.gd -- --role=tv
## No phone is needed: the view is opened with App.go_game_settings(). The rest of the flow is in smoke_tv.gd.

var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Texts in the tree of `n` with a font size below 28 px (REQ-GM-41).
func _small_text(n: Node) -> Array:
	var out := []
	if n is Label or n is Button:
		var fs: int = n.get_theme_font_size("font_size")
		if n.text != "" and fs < 28:
			out.append("%s:%d" % [n.text.left(20), fs])
	for c in n.get_children():
		out.append_array(_small_text(c))
	return out


func _run() -> void:
	await _frames(5)
	var MazeGame = load("res://scripts/game/maze/maze_game.gd")
	var TvGames = load("res://scripts/ui/tv_games.gd")
	var TvGameSettings = load("res://scripts/ui/tv_game_settings.gd")
	var GameSettings = load("res://scripts/game/game_settings.gd")
	var app: Node = root.get_node("App")
	GameSettings.clear()
	app.go_game_settings("maze")
	await _frames(4)
	var sv: Control = app.current_screen()
	_check(is_instance_of(sv, TvGameSettings) and sv.rows.size() == 1 and sv.rows[0].value == "medium",
			"the settings view of the maze has the row Difficulty on Medium")
	_check(sv.rows[0].has_focus() and sv.rows[0]._value.text == "Medium", "the row has the focus and shows Medium")
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	var left := InputEventAction.new()
	left.action = "ui_left"
	left.pressed = true
	sv.rows[0]._gui_input(right)
	_check(sv.rows[0].value == "hard" and sv.rows[0]._value.text == "Hard", "Right gives Hard")
	sv.rows[0]._gui_input(right)
	_check(sv.rows[0].value == "hard", "Right at the last value stops")
	sv.rows[0]._gui_input(left)
	sv.rows[0]._gui_input(left)
	sv.rows[0]._gui_input(left)
	_check(sv.rows[0].value == "easy", "Left goes down to Easy and stops there")
	sv.rows[0]._gui_input(right)
	sv.rows[0]._gui_input(right)
	var small: Array = _small_text(sv)
	_check(small.is_empty(), "the settings view has no text below 28 px (REQ-GM-41) " + str(small))
	_check(sv.back_button.global_position.y > sv.start_button.global_position.y, "Back is at the bottom, below Start (REQ-GM-90)")
	sv.on_back()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvGames) and app.last_game == "maze", "Back returns to the Games screen")
	app.go_game_settings("maze")
	await _frames(4)
	sv = app.current_screen()
	_check(sv.rows[0].value == "hard", "the view opens with the last choice (REQ-GM-94)")
	sv.start()
	await _frames(4)
	var game: Control = app.current_screen()
	_check(is_instance_of(game, MazeGame) and game.difficulty == "hard" and game.cols == 21 and game.rows == 11,
			"Start begins a Hard maze (21 x 11)")
	_check(game.start_props.difficulty == "hard", "Restart keeps the difficulty (REQ-GM-93)")
	# Snowball Splat has the same view, and Hard reaches the game and its field (REQ-SS-20).
	var Snow = load("res://scripts/game/snowball_splat/snowball_splat_game.gd")
	app.go_game_settings("snowball_splat")
	await _frames(4)
	sv = app.current_screen()
	_check(is_instance_of(sv, TvGameSettings) and sv.rows.size() == 1 and sv.rows[0].value == "medium",
			"Snowball Splat opens the settings view with Difficulty on Medium")
	sv.rows[0]._gui_input(right)
	sv.start()
	await _frames(4)
	var snow: Control = app.current_screen()
	_check(is_instance_of(snow, Snow) and snow.difficulty == "hard" and snow._field._speed == 1.5
			and snow.start_props.difficulty == "hard",
			"Start begins a Hard Snowball Splat, and Restart keeps it")
	GameSettings.clear()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
