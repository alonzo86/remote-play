extends SceneTree

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
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
	# One simulated phone: Start needs a player (REQ-GM-20).
	var phone := ControllerClient.new()
	phone.player_name = "Sim0"
	root.add_child(phone)
	phone.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
	var joined := Time.get_ticks_msec()
	while app.server.connected_slots().size() < 1 and Time.get_ticks_msec() - joined < 4000:
		await process_frame
	app.go_game_settings("maze")
	await _frames(4)
	var sv: Control = app.current_screen()
	_check(is_instance_of(sv, TvGameSettings) and sv.rows.size() == 2 and sv.rows[0].value == "medium"
			and sv.rows[1].value == "garden",
			"the settings view of the maze has the rows Difficulty on Medium and Theme on Garden (REQ-MZ-12)")
	_check(sv.start_button.has_focus() and sv.rows[0]._value.text == "MEDIUM",
			"Start has the focus when the view opens, and the row shows Medium (issue #226)")
	var row_left: float = sv.rows[0].global_position.x
	var row_right: float = row_left + sv.rows[0].size.x
	_check(is_equal_approx(sv.rows[0].size.x, sv.rows[0].MIN_W) and is_equal_approx(sv.back_button.global_position.x, row_left)
			and is_equal_approx(sv.start_button.global_position.x + sv.start_button.size.x, row_right),
			"the maze view is as narrow as its widest row, and Back and Start are at its two edges (REQ-GM-90): %.0f px"
			% sv.rows[0].size.x)
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	var left := InputEventAction.new()
	left.action = "ui_left"
	left.pressed = true
	sv.rows[0]._gui_input(right)
	_check(sv.rows[0].value == "hard" and sv.rows[0]._value.text == "HARD", "Right gives Hard")
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
	_check(is_equal_approx(sv.back_button.global_position.y + sv.back_button.size.y * 0.5,
			sv.start_button.global_position.y + sv.start_button.size.y * 0.5)
			and sv.back_button.global_position.x < sv.start_button.global_position.x
			and sv.start_button.global_position.y > sv.rows[-1].global_position.y,
			"Back and Start are on one line below the rows, Back on the left (REQ-GM-90)")
	sv.on_back()
	await _frames(3)
	_check(is_instance_of(app.current_screen(), TvGames) and app.last_game == "maze", "Back returns to the Games screen")
	app.go_game_settings("maze")
	await _frames(4)
	sv = app.current_screen()
	_check(sv.rows[0].value == "hard", "the view opens with the last choice (REQ-GM-94)")
	_check(sv.rows[1]._value.text == "GARDEN", "the Theme row starts on Garden")
	sv.rows[1]._gui_input(right)
	_check(sv.rows[1].value == "castle" and sv.rows[1]._value.text == "CASTLE", "Right on the Theme row gives Castle")
	sv.rows[1]._gui_input(right)
	_check(sv.rows[1].value == "ice" and sv.rows[1]._value.text == "ICE", "Right again gives Ice")
	sv.start()
	await _frames(4)
	var game: Control = app.current_screen()
	_check(is_instance_of(game, MazeGame) and game.difficulty == "hard" and game.cols == 18 and game.rows == 9,
			"Start begins a Hard maze (18 x 9)")
	_check(game.start_props.difficulty == "hard", "Restart keeps the difficulty (REQ-GM-93)")
	_check(game.maze_theme == "ice" and game.start_props.maze_theme == "ice", "Start and Restart keep the theme (REQ-MZ-12)")
	# Banana Party has the same view, and Hard reaches the game and its field (REQ-SS-20).
	var Snow = load("res://scripts/game/snowball_splat/snowball_splat_game.gd")
	app.go_game_settings("snowball_splat")
	await _frames(4)
	sv = app.current_screen()
	_check(is_instance_of(sv, TvGameSettings) and sv.rows.size() == 1 and sv.rows[0].value == "medium",
			"Banana Party opens the settings view with Difficulty on Medium")
	sv.rows[0]._gui_input(right)
	sv.start()
	await _frames(4)
	var snow: Control = app.current_screen()
	_check(is_instance_of(snow, Snow) and snow.difficulty == "hard" and snow._field._speed == 1.5
			and snow.start_props.difficulty == "hard",
			"Start begins a Hard Banana Party, and Restart keeps it")
	# Car Race: the track list under Difficulty (REQ-MR-53, 54).
	var Race = load("res://scripts/game/marble_race/marble_race.gd")
	var MarbleTrack = load("res://scripts/game/marble_race/marble_track.gd")
	app.go_game_settings("marble_race")
	await _frames(4)
	sv = app.current_screen()
	var picker: Control = sv.rows[2]
	_check(sv.rows.size() == 3 and sv.rows[0].row.key == "difficulty" and sv.rows[1].row.key == "race_theme"
			and sv.rows[1].value == "candy"
			and sv.rows[1].row.titles == ["registry.candy", "registry.space", "registry.jungle"]
			and picker.tiles.size() == 11
			and picker.tiles[10].sketch.is_empty() and picker.tiles[0].sketch.size() >= 3,
			"the race view has Difficulty, Theme and 11 tracks under them, the last one without a sketch (the random track)")
	_check(picker.index == 0 and picker.value == "1", "Track 1 is in the middle at first")
	_check(sv.rows[0].global_position.y < sv.rows[1].global_position.y and sv.rows[1].global_position.y < picker.global_position.y
			and picker.global_position.y < sv.start_button.global_position.y,
			"the carousel is under Difficulty and Theme and above Start")
	_check(picker.size.x >= sv.rows[0].MIN_W and is_equal_approx(sv.rows[0].size.x, picker.size.x)
			and is_equal_approx(sv.rows[1].size.x, picker.size.x)
			and is_equal_approx(sv.rows[0].global_position.x, picker.global_position.x)
			and is_equal_approx(sv.back_button.global_position.x, picker.global_position.x)
			and is_equal_approx(sv.start_button.global_position.x + sv.start_button.size.x, picker.global_position.x + picker.size.x),
			"Difficulty, the carousel and the line of Back and Start all have the same width (REQ-GM-90): %.0f px" % picker.size.x)
	_check(picker._sb_selected.border_color == UiTheme.SELECTED and picker._sb_selected.bg_color == Color.WHITE
			and picker._sb_tile.border_color != UiTheme.SELECTED, "the selected track has a yellow border, not a color fill (REQ-GM-97)")
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
	sv.rows[1]._gui_input(right)
	sv.start()
	await _frames(4)
	var race: Control = app.current_screen()
	_check(is_instance_of(race, Race) and race.difficulty == "easy" and race.track_seed == MarbleTrack.FIXED_SEEDS[3]
			and race.track.bumpers.size() == MarbleTrack.make(race.track_seed, "easy").bumpers.size()
			and race.race_theme == "space" and race.start_props.race_theme == "space",
			"Start begins an Easy race on Track 4 in the Space theme, and Restart keeps the theme")
	var space_ok: bool = race._bumper_kinds.size() == race.track.bumpers.size() and not race._bumper_kinds.is_empty()
	for kind in race._bumper_kinds:
		space_ok = space_ok and ["asteroid", "satellite", "crater"].has(kind)
	_check(space_ok, "the obstacles of the Space theme are asteroids, satellites and craters (REQ-MR-46)")
	app.go_game_settings("marble_race")
	await _frames(4)
	sv = app.current_screen()
	_check(sv.rows[0].value == "easy" and sv.rows[1].value == "space" and sv.rows[2].value == "4" and sv.rows[2].index == 3,
			"the view opens with the last choices (REQ-GM-94)")
	sv.rows[2].set_value("random", true)
	sv.start()
	await _frames(4)
	race = app.current_screen()
	var random_seed: int = race.track_seed
	_check(not MarbleTrack.FIXED_SEEDS.has(random_seed) and race.track.title == "RANDOM TRACK",
			"the random track has a seed that is not fixed (REQ-MR-53)")
	race.restart()
	await _frames(4)
	_check(app.current_screen().track_seed == random_seed, "Restart plays the same random track (REQ-MR-54)")
	GameSettings.clear()
	# Focus wiring (REQ-GM-90): Down from the last row goes to Start, Up from Start and Back goes to that row.
	app.go_game_settings("maze")
	await _frames(4)
	sv = app.current_screen()
	var last_row: Control = sv.rows[-1]
	_check(last_row.get_node(last_row.focus_neighbor_bottom) == sv.start_button
			and sv.start_button.get_node(sv.start_button.focus_neighbor_top) == last_row
			and sv.back_button.get_node(sv.back_button.focus_neighbor_top) == last_row,
			"Down from the last row goes to Start; Up from Start and from Back goes to the row")
	# Start needs phones that fit the game (REQ-GM-20): a phone can leave while the view is open.
	_check(not sv.start_button.disabled and sv.reason_label.text == "", "with a phone the view has no reason line and Start works")
	await _back_focus(app, TvGames)
	app.go_game_settings("maze")   # The check left the view.
	await _frames(4)
	sv = app.current_screen()
	app.server.kick(0)
	await _frames(4)
	_check(sv.start_button.disabled and sv.reason_label.text == "NO PLAYERS CONNECTED",
			"with no phone Start is disabled and the line says why: %s" % sv.reason_label.text)
	sv.start()
	await _frames(3)
	_check(app.current_screen() == sv, "Start does nothing when the phones do not fit the game")
	await _hebrew_rows(app)
	await _slot_list(app)
	await _how_to(app)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The slot rows: a state word for each slot, a Remove item for a joined or lost slot, and the focus stays on a Remove item when
## the list is rebuilt (REQ-FL-8, 33).
func _slot_list(app: Node) -> void:
	print("slot list")
	var players: Array = app.server.players
	players[0].state = PlayerInput.State.CONNECTED
	players[0].player_name = "Ann"
	players[1].state = PlayerInput.State.LOST
	players[1].player_name = "Bo"
	players[1].lost_since_ms = Time.get_ticks_msec()   # Else the server frees the slot at its next tick.
	players[2].state = PlayerInput.State.EMPTY
	var list: VBoxContainer = load("res://scripts/ui/slot_list.gd").new()
	list.removable = true
	var removed: Array[int] = []
	list.remove_requested.connect(func(slot: int): removed.append(slot))
	root.add_child(list)
	await process_frame
	var words: Array[String] = []
	for row in list.get_children():
		var labels := row.get_children().filter(func(n: Node) -> bool: return n is Label)
		words.append((labels[-1] as Label).text)
	_check(words == ["slot_list.ready", "slot_list.lost", "slot_list.wait", "slot_list.wait"],
			"each slot shows a state word: %s" % str(words))
	_check(list.remove_button(0) != null and list.remove_button(1) != null and list.remove_button(2) == null,
			"a joined or lost slot has a Remove item, an empty slot has none")
	list.remove_button(1).pressed.emit()
	_check(removed == [1], "Remove reports the slot")
	list.remove_button(1).grab_focus()
	players[1].state = PlayerInput.State.EMPTY   # The phone is removed: the list rebuilds and the focus moves to the first Remove.
	await process_frame
	await process_frame
	await process_frame
	_check(list.remove_button(1) == null and list.first_remove_button() == list.remove_button(0)
			and list.remove_button(0).has_focus(), "after a rebuild the focus stays on a Remove item")
	# A player with a profile has the avatar in the place of the number; a guest keeps the number (REQ-FL-69).
	players[0].set_profile("cd".repeat(16), 4, "Ann")
	await process_frame
	await process_frame
	var avatars := list.find_children("*", "Control", true, false).filter(
			func(n: Node) -> bool: return n.get_script() == load("res://scripts/ui/avatar_view.gd"))
	var numbers := 0
	for l in list.find_children("*", "Label", true, false):
		if (l as Label).text in ["1P", "2P", "3P", "4P"]:
			numbers += 1
	_check(avatars.size() == 1 and numbers == 3,
			"a profile shows its avatar in place of 1P; the other rows keep their numbers: %d %d" % [avatars.size(), numbers])
	for p in players:
		p.reset()
	list.queue_free()


## The choice row in Hebrew (REQ-FL-54): Right goes to the previous value and Left to the next, as the arrows are mirrored; the
## Up and Down keys visit the same items in the same order as in English, one item for each press.
func _hebrew_rows(app: Node) -> void:
	print("settings view in Hebrew")
	var Lang = load("res://scripts/core/lang.gd")
	var chains := {}
	for code in ["en", "he"]:
		app.set_language(code, false)
		app.go_game_settings("maze")
		await _frames(6)
		var sv: Control = app.current_screen()
		var row: Control = sv.rows[0]
		row.set_value("medium")
		row.grab_focus()
		var order: Array = row.row.values
		var right := InputEventAction.new()
		right.action = "ui_right"
		right.pressed = true
		var left := InputEventAction.new()
		left.action = "ui_left"
		left.pressed = true
		row._gui_input(right)
		var after_right: String = row.value
		row._gui_input(left)
		row._gui_input(left)
		var after_left: String = row.value
		if code == "he":
			_check(after_right == order[0] and after_left == order[2],
					"in Hebrew Right goes to the previous value (%s) and Left to the next (%s)" % [after_right, after_left])
		else:
			_check(after_right == order[2] and after_left == order[0],
					"in English Right goes to the next value (%s) and Left to the previous (%s)" % [after_right, after_left])
		_check((row._left.get_global_rect().get_center().x < row._right.get_global_rect().get_center().x) == (code == "en"),
				"%s: the arrow of the previous value is at the %s of the next" % [code, "left" if code == "en" else "right"])
		# Issue #229: the arrow glyph that is DRAWN (Hebrew mirrors "<" and ">") points the way of the key that uses it: the arrow
		# at the left of the value is "<" and the one at the right is ">" in both languages, and the dim arrow at the end of the
		# row is the one whose key would go past the end.
		var at_left: Label = row._left if row._left.get_global_rect().get_center().x < row._right.get_global_rect().get_center().x \
				else row._right
		var at_right: Label = row._right if at_left == row._left else row._left
		var lt := _glyph("<", TextServer.DIRECTION_LTR)
		_check(_drawn_glyph(at_left) == lt and _drawn_glyph(at_right) == _glyph(">", TextServer.DIRECTION_LTR),
				"%s: the arrow at the left of the value is drawn as '<' and the one at the right as '>'" % code)
		row.set_value(order[order.size() - 1])
		var end_dim: Label = row._right   # The arrow of the "next" step: the key that cannot go on at the last value.
		_check(end_dim.modulate.a < 1.0 and row._left.modulate.a == 1.0,
				"%s: at the last value the arrow of the key that cannot go on is dim" % code)
		_check((at_right == end_dim) == (code == "en"),
				"%s: the dim arrow at the last value is at the %s" % [code, "right" if code == "en" else "left"])
		row.set_value("medium")
		var chain: Array = []
		var cur: Control = row
		for i in 6:
			var below := cur.find_valid_focus_neighbor(SIDE_BOTTOM)
			if below == null or below == cur:
				break
			_check(below.get_global_rect().position.y > cur.get_global_rect().position.y,
					"%s: Down from item %d goes to an item below it" % [code, i])
			chain.append(below.get_script().resource_path.get_file() + ":" + str(below.name))
			cur = below
		chains[code] = chain.map(func(x: String) -> String: return x.split(":")[0])
	_check(chains.en == chains.he and not chains.en.is_empty(),
			"Down visits the same kinds of items in English and in Hebrew: %s" % str(chains.en))
	app.set_language("en", false)
	Lang.set_language("en", root)


## Issue #77, REQ-GM-103: the settings view of every game shows its how-to-play text under the name, in English and in Hebrew, and
## Back and Start stay inside the 60 px safe margin of the screen.
## The glyph index that the TextServer draws for `text` in the font of the UI when the direction is `dir`.
func _glyph(text: String, dir: int) -> int:
	var para := TextParagraph.new()
	para.direction = dir
	para.add_string(text, UiTheme.font(), 32)
	var glyphs: Array[Dictionary] = TextServerManager.get_primary_interface().shaped_text_get_glyphs(para.get_line_rid(0))
	return int(glyphs[0].index) if not glyphs.is_empty() else -1


## The glyph that a label with a single arrow character draws in its layout direction.
func _drawn_glyph(l: Label) -> int:
	return _glyph(l.text, TextServer.DIRECTION_RTL if l.is_layout_rtl() else TextServer.DIRECTION_LTR)


func _how_to(app: Node) -> void:
	print("how to play")
	var lang_script = app.Lang
	for code in ["en", "he"]:
		lang_script.set_language(code, root)
		for g in app.Registry.all():
			app.go_game_settings(String(g.id))
			await _frames(3)
			var view: Control = app.current_screen()
			var label: Label = view.how_to_label
			var text: String = lang_script.t(String(g.how_to))
			_check(text != String(g.how_to) and text.length() > 20 and label.text == String(g.how_to),
					"%s %s: the view shows the how-to-play text" % [code, g.id])
			var low: float = maxf(view.start_button.get_global_rect().end.y, view.back_button.get_global_rect().end.y)
			_check(low <= 1080.0 - 60.0 and label.get_global_rect().position.y >= 60.0,
					"%s %s: the text, Back and Start are inside the safe margin (the bottom is at %.0f px of 1020)" % [code, g.id, low])
			# Issue #120: how to play is the bottom band, wide, under Start; the names of the rows have one width.
			_check(label.get_global_rect().position.y >= view.start_button.get_global_rect().end.y and label.size.x >= 1400.0
					and label.get_global_rect().end.y <= 1080.0 - 60.0,
					"%s %s: how to play is wide, under Start and inside the margin" % [code, g.id])
			var name_w := -1.0
			var same := true
			for row in view.rows:
				if row.get_script().resource_path.get_file() != "choice_row.gd":
					continue
				name_w = row.name_width() if name_w < 0.0 else name_w
				same = same and is_equal_approx(row.name_width(), name_w)
			_check(same, "%s %s: the names of the rows have one width (%.0f)" % [code, g.id, name_w])
	lang_script.set_language("en", root)


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)


## Issues #134 and #135, REQ-GM-90 and REQ-FL-55: in the settings view of every game, in English and in Hebrew, the D-pad reaches
## Back (from Start with Left in English, with Right in Hebrew, and back again), and the Back key goes to the Games screen.
func _back_focus(app: Node, games_script: GDScript) -> void:
	print("back and the D-pad")
	var lang_script = app.Lang
	for code in ["en", "he"]:
		lang_script.set_language(code, root)
		var toward_back := "ui_right" if code == "he" else "ui_left"
		var toward_start := "ui_left" if code == "he" else "ui_right"
		for g in app.Registry.all():
			app.go_game_settings(String(g.id))
			await _frames(4)
			var view: Control = app.current_screen()
			# Issue #226: the view opens on Start. While Start cannot work (too few phones, or a swing game waits for the safety taps)
			# the focus is on an item that can be used: the first row, or Back where it was parked.
			var owner := root.gui_get_focus_owner()
			var ok: bool = owner == view.start_button if not view.start_button.disabled else (
					owner == view.rows[0] or owner == view.back_button)
			_check(ok, "%s %s: the view opens with the focus on %s" % [
					code, g.id, "Start" if not view.start_button.disabled else "the first row or Back (Start waits)"])
			if not view.start_button.disabled:
				view.start_button.grab_focus()
				await _press(toward_back)
				_check(root.gui_get_focus_owner() == view.back_button,
						"%s %s: %s from Start goes to Back" % [code, g.id, toward_back])
				await _press(toward_start)
				_check(root.gui_get_focus_owner() == view.start_button,
						"%s %s: %s from Back goes to Start" % [code, g.id, toward_start])
			else:
				view.back_button.grab_focus()
			app._last_back_ms = 0   # Two Back presses inside 250 ms count once.
			await _press("ui_cancel")
			await _frames(3)
			_check(is_instance_of(app.current_screen(), games_script) and app.last_game == String(g.id),
					"%s %s: the Back key goes to the Games screen with the tile of the game" % [code, g.id])
	lang_script.set_language("en", root)
	# Issue #134: a screen that takes 300 ms to build must not get the second event of the same press (a key and a notification).
	var slow := GDScript.new()
	slow.source_code = "extends Control\nvar backs := 0\nfunc on_back() -> void:\n\tbacks += 1\n\tOS.delay_msec(300)\n"
	slow.reload()
	var stub: Control = slow.new()
	var real_screen: Control = app._screen
	app._screen = stub
	app._last_back_ms = 0
	app._back()
	app._back()   # Arrives after the slow screen is built.
	_check(stub.backs == 1, "a Back press that arrives after a slow screen change counts once (%d)" % stub.backs)
	app._screen = real_screen
	stub.free()
