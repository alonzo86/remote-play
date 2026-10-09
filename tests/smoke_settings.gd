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
	root.size = Vector2i(1920, 1080)   # The TV is 16:9. The headless window can have another shape.
	await _frames(3)
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
	_check(is_equal_approx(sv.start_button.size.x, sv.rows[0].size.x) and is_equal_approx(sv.rows[0].size.x, sv.rows[0].MIN_W),
			"the maze view is as narrow as its widest row (REQ-GM-90): %.0f px" % sv.rows[0].size.x)
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
	# Marble Race: the track list under Difficulty (REQ-MR-53, 54).
	var Race = load("res://scripts/game/marble_race/marble_race.gd")
	var MarbleTrack = load("res://scripts/game/marble_race/marble_track.gd")
	app.go_game_settings("marble_race")
	await _frames(4)
	sv = app.current_screen()
	var picker: Control = sv.rows[1]
	_check(sv.rows.size() == 2 and sv.rows[0].row.key == "difficulty" and picker.tiles.size() == 11
			and picker.tiles[10].sketch.is_empty() and picker.tiles[0].sketch.size() >= 3,
			"the race view has Difficulty and 11 tracks under it, the last one without a sketch (the random track)")
	_check(picker.index == 0 and picker.value == "1", "Track 1 is in the middle at first")
	_check(sv.rows[0].global_position.y < picker.global_position.y and picker.global_position.y < sv.start_button.global_position.y,
			"the carousel is under Difficulty and above Start")
	var mid_x: float = picker.global_position.x + picker.size.x * 0.5
	_check(picker.size.x == picker.VIEW.x and is_equal_approx(sv.start_button.size.x, picker.size.x)
			and sv.rows[0].size.x < picker.size.x and absf(sv.rows[0].global_position.x + sv.rows[0].size.x * 0.5 - mid_x) < 1.0,
			"the view is as wide as the carousel, and Difficulty is narrower and in the middle (%.0f, %.0f px)"
			% [picker.size.x, sv.rows[0].size.x])
	sv.rows[0].grab_focus()
	await _frames(2)
	picker.grab_focus()
	var moved: Array = []
	picker.changed.connect(func(v: String): moved.append(v))
	picker._gui_input(right)
	picker._gui_input(right)
	_check(picker.value == "3" and picker.index == 2 and moved == ["2", "3"],
			"Right moves the line one track at a time: %s" % str(moved))
	picker._gui_input(left)
	_check(picker.value == "2", "Left moves it back")
	picker.set_value("random")
	picker._gui_input(right)
	_check(picker.value == "random" and picker.index == 10 and moved.size() == 3,
			"the line stops at the last track (the random one)")
	picker.set_value("1")
	picker._gui_input(left)
	_check(picker.value == "1" and moved.size() == 3, "and at the first track, and choosing by code is no user change")
	await _frames(20)
	_check(is_equal_approx(picker._pos, 0.0), "the line slides to the track in the middle")
	var TrackPicker = load("res://scripts/ui/track_picker.gd")
	var fitted: Array = TrackPicker.fit(picker.tiles[0].sketch, Rect2(0, 0, 100, 100))
	var inside := true
	for fp in fitted:
		inside = inside and fp.x >= -0.01 and fp.x <= 100.01 and fp.y >= -0.01 and fp.y <= 100.01
	_check(fitted.size() == picker.tiles[0].sketch.size() and inside and TrackPicker.fit([], Rect2(0, 0, 100, 100)).is_empty(),
			"a sketch is scaled to fit its tile")
	_check(TrackPicker.scale_at(0.0) == 1.0 and TrackPicker.scale_at(1.0) < 1.0
			and TrackPicker.scale_at(2.0) < TrackPicker.scale_at(1.0)
			and TrackPicker.x_at(0.0) == 0.0 and TrackPicker.x_at(-1.0) < 0.0 and TrackPicker.x_at(2.0) > TrackPicker.x_at(1.0),
			"tiles get smaller and go to the sides with the distance from the middle")
	var small_race: Array = _small_text(sv)
	_check(small_race.is_empty(), "no text below 28 px in the race view " + str(small_race))
	var bottom: float = sv.back_button.global_position.y + sv.back_button.size.y
	_check(bottom <= 1080.0 - 20.0 and sv.get_viewport().get_visible_rect().size.y >= bottom,
			"the race view fits the screen with Back at the bottom (%.0f)" % bottom)
	for i in 3:
		picker._gui_input(right)
	sv.rows[0]._gui_input(right)
	sv.rows[0]._gui_input(left)
	sv.rows[0]._gui_input(left)
	sv.start()
	await _frames(4)
	var race: Control = app.current_screen()
	_check(is_instance_of(race, Race) and race.difficulty == "easy" and race.track_seed == MarbleTrack.FIXED_SEEDS[3]
			and race.track.bumpers.size() == MarbleTrack.make(race.track_seed, "easy").bumpers.size(),
			"Start begins an Easy race on Track 4")
	app.go_game_settings("marble_race")
	await _frames(4)
	sv = app.current_screen()
	_check(sv.rows[0].value == "easy" and sv.rows[1].value == "4" and sv.rows[1].index == 3,
			"the view opens with the last choices (REQ-GM-94)")
	sv.rows[1].set_value("random", true)
	sv.start()
	await _frames(4)
	race = app.current_screen()
	var random_seed: int = race.track_seed
	_check(not MarbleTrack.FIXED_SEEDS.has(random_seed) and race.track.title == "Random track",
			"the random track has a seed that is not fixed (REQ-MR-53)")
	race.restart()
	await _frames(4)
	_check(app.current_screen().track_seed == random_seed, "Restart plays the same random track (REQ-MR-54)")
	GameSettings.clear()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
