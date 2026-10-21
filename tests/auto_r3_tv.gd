extends SceneTree
## TV screens: what used to be looked at by hand in manual tests 16, 17 and 18 and a machine can check (docs/MANUAL_TESTS.md):
## the reason on a tile that needs more phones and the denied sound (16.3e), the blinking prompt over 10 s (16.5a), the logo that
## drops in steps of 16 px and the square confetti (16.5b), the 4 sizes of the countdown number (16.5c), the slot squares in the
## Connect screen of Hebrew and English (17.2b), the Hebrew GO word (17.6c) and the silent Effects row (18.3d). Run:
##   godot --headless --path . --script tests/auto_r3_tv.gd -- --role=tv

const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Registry = preload("res://scripts/game/registry.gd")

var _checks := 0
var _fails := 0
var _app: Node
var _sound: Node
var _countdown_log: Array = []   # Every countdown box that the shell drew in a test of this file.


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	await _run()
	Shell.recorder = Callable()
	_app.set_language("en", false)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## A key of the remote as an input action (the same call as tests/focus_walk.gd). A button acts when the key is let go.
func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	_sound = root.get_node("Sound")
	_app.settings.language = "en"
	_app.set_language("en", false)
	_blinking_prompt()
	_countdown_steps()
	await _go_word()
	await _logo_drop()
	await _tile_reason()
	await _slot_squares()
	await _effects_zero()


## 16.5a: a blinking prompt shows 9 or 10 times in 10 s, 0.55 s on and 0.55 s off (REQ-FL-42). The real label is stepped by
## hand with 200 steps of 0.05 s; the state of its alpha is read after every step.
func _blinking_prompt() -> void:
	print("the blinking prompt")
	var blink: Label = UiKit.blinking("logo.press_ok_skip")
	var states: Array[bool] = []
	for i in 200:
		blink._process(0.05)
		states.append(blink.modulate.a == 1.0)
	var starts := 1 if states[0] else 0   # A run that is on at the first step counts as a start.
	for i in range(1, states.size()):
		if states[i] and not states[i - 1]:
			starts += 1
	_check(starts == 9 or starts == 10, "the prompt is on %d times in 10 s (9 or 10)" % starts)
	# The runs of the same state, in steps. The first and the last run may be cut by the start and the end of the 10 s.
	var runs: Array[Dictionary] = []
	for i in states.size():
		if runs.is_empty() or runs[runs.size() - 1].on != states[i]:
			runs.append({"on": states[i], "steps": 1})
		else:
			runs[runs.size() - 1].steps += 1
	var whole := runs.slice(1, runs.size() - 1)
	var worst := 0.0
	for r in whole:
		worst = maxf(worst, absf(float(r.steps) * 0.05 - 0.55))
	_check(whole.size() >= 14 and worst <= 0.06,
			"every whole on run and off run lasts 0.55 s (+-0.06): %d runs, the worst is %.2f s off" % [whole.size(), worst])
	_check(blink.modulate.a == 0.0 or blink.modulate.a == 1.0, "the alpha is 0 or 1 and never in between (a hard step, not a fade)")
	blink.free()


## 16.5c: the countdown number settles in exactly 4 sizes, from the largest to the smallest, and each size stays for several
## frames of 60 fps (REQ-FL-42). `Shell.countdown_size()` is stepped through one second.
func _countdown_steps() -> void:
	print("the countdown sizes")
	var sizes: Array[int] = []
	var frames_of := {}
	for i in 61:
		var s := Shell.countdown_size(float(i) / 60.0)
		sizes.append(s)
		frames_of[s] = int(frames_of.get(s, 0)) + 1
	var distinct: Array = frames_of.keys()
	var order: Array[int] = []
	for s in sizes:
		if order.is_empty() or order.back() != s:
			order.append(s)
	var shortest := 99
	for s in distinct:
		shortest = mini(shortest, int(frames_of[s]))
	_check(distinct.size() == 4 and order == [352, 320, 288, 256],
			"one second of the countdown has 4 sizes, largest first: %s" % str(order))
	_check(shortest >= 5, "each size stays for 5 frames or more at 60 fps (the shortest: %d frames)" % shortest)
	var in_grid := true
	for s in distinct:
		in_grid = in_grid and int(s) % 32 == 0
	_check(in_grid, "every size is a multiple of 32 px (the font grid)")


## 17.6c: the GO word in Hebrew is the Hebrew text, whole and inside the screen and the 60 px margin, at every size of the
## countdown. Road Rally is the only game that shows the word GO; here it is drawn by `Shell.countdown()` that all games use.
func _go_word() -> void:
	print("the GO word")
	var holder := Control.new()
	holder.size = Vector2(1920, 1080)
	root.add_child(holder)
	Shell.recorder = func(kind: String, ci: CanvasItem, rect: Rect2, info: Dictionary) -> void:
		if kind == "countdown" and ci == holder:
			_countdown_log.append({"rect": rect, "text": info.text, "size": info.size, "lang": Lang.current()})
	holder.draw.connect(func() -> void:
		for e in [0.0, 0.1, 0.2, 0.9]:
			Shell.countdown(holder, holder.size, "shell.go", e))
	for code in ["en", "he"]:
		_app.set_language(code, false)
		_countdown_log.clear()
		holder.queue_redraw()
		await _frames(3)
		var want := Lang.t("shell.go").to_upper()
		var inside := true
		var texts_ok := true
		for e in _countdown_log:
			inside = inside and Rect2(60, 60, 1800, 960).encloses(e.rect)
			texts_ok = texts_ok and e.text == want
		_check(_countdown_log.size() >= 4 and texts_ok and inside,
				"[%s] GO is '%s' at 4 sizes, whole and inside the 60 px margin (%d boxes)" % [code, want, _countdown_log.size()])
	_app.set_language("he", false)
	_check(Lang.t("shell.go") == "קדימה", "the Hebrew GO word is the text 'קדימה'")
	_app.set_language("en", false)
	Shell.recorder = Callable()
	holder.queue_free()


## 16.5b: the logo falls from the top in hard steps of 16 px (every height is a multiple of 16, it only goes down, it ends in its
## place), and the confetti pieces are squares of one size with sharp edges (REQ-FL-42).
func _logo_drop() -> void:
	print("the logo drop")
	_app.settings.language = "en"
	_app.go_logo()
	var logo: Control = _app.current_screen()
	var ys: Array[float] = [logo._center.offset_top]
	var start := Time.get_ticks_msec()
	var confetti: Array = []
	while Time.get_ticks_msec() - start < 900:
		await process_frame
		ys.append(logo._center.offset_top)
		if confetti.is_empty():
			confetti = logo.find_children("*", "CPUParticles2D", true, false)
	var step := 16.0   # REQ-FL-42: steps of 16 px (the number comes from the requirement, not from logo.STEP).
	var on_grid := true
	var down_only := true
	var distinct := {}
	for i in ys.size():
		on_grid = on_grid and is_zero_approx(fposmod(ys[i], step))
		distinct[ys[i]] = true
		if i > 0:
			down_only = down_only and ys[i] >= ys[i - 1]
	_check(ys[0] == logo.DROP_FROM and ys.back() == 0.0, "the logo starts %.0f px above its place and ends in it" % -logo.DROP_FROM)
	_check(on_grid, "every height of the logo is a multiple of %.0f px: no in-between position (%d heights seen)" % [step,
			distinct.size()])
	_check(down_only and distinct.size() >= 4, "the logo only moves down, in %d separate steps" % distinct.size())
	var squares := not confetti.is_empty()
	for c in confetti:
		var tex: Texture2D = c.texture
		squares = squares and tex != null and tex.get_width() == tex.get_height() and tex.get_width() == c.PIXEL \
				and c.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	_check(squares and confetti.size() == 1, "the confetti burst is made of squares (%d x %d px) with the nearest filter" % [
			confetti[0].PIXEL if not confetti.is_empty() else 0, confetti[0].PIXEL if not confetti.is_empty() else 0])
	_app.go_connect()
	await _frames(3)


## 16.3e: with 1 phone, a game that needs more phones shows its reason in yellow, and OK on its tile plays the sound of a dim
## item and does not start the game (REQ-FL-14).
func _tile_reason() -> void:
	print("the reason on a tile")
	for i in 4:
		_app.server.players[i].state = 1 if i == 0 else 0
	_app.go_games()
	await _frames(20)
	var screen: Control = _app.current_screen()
	var sumo: Button = null
	var paint: Button = null
	for t in screen._tiles:
		if String(t.game.id) == "sumo_bumpers":
			sumo = t
		if String(t.game.id) == "paint_grab":
			paint = t
	_check(sumo != null and paint != null, "the Games screen has the tiles of Sumo Bumpers and Paint Grab")
	if sumo == null or paint == null:
		return
	sumo.grab_focus()
	await _frames(10)
	var want := Registry.reason(sumo.game, 1).to_upper()
	_check(want != "" and sumo._meta.text == want and sumo._meta.get_theme_color("font_color") == UiTheme.ACCENT,
			"Sumo Bumpers with 1 phone shows the reason '%s' in yellow" % want)
	_check(paint._meta.text != want and paint._meta.get_theme_color("font_color") == UiTheme.TEXT_DIM,
			"Paint Grab, which fits 1 phone, shows its player range in the dim color, not in yellow")
	_check(sumo.modulate.a < 1.0 and paint.modulate.a == 1.0, "the tile that does not fit is dim")
	var heard: Array[String] = []
	var cb := func(id: String) -> void: heard.append(id)
	_sound.sfx_played.connect(cb)
	_sound._last_ms.clear()
	await _press("ui_accept")
	await _frames(5)
	_sound.sfx_played.disconnect(cb)
	var still_games: bool = _app.current_screen() == screen
	_check(heard == ["denied"] and still_games,
			"OK on that tile plays only `denied` (%s) and stays on the Games screen" % str(heard))
	for i in 4:
		_app.server.players[i].state = 0


## 17.2b: on the Connect screen each slot row has the color square at the side where the row starts: at the right of the name in
## Hebrew, at the left of it in English, and the 4 squares are in one column (REQ-FL-54).
func _slot_squares() -> void:
	print("the slot squares")
	for code in ["he", "en"]:
		_app.set_language(code, false)
		_app.go_connect()
		await _frames(6)
		var list: Control = null
		for n in _app.current_screen().find_children("*", "VBoxContainer", true, false):
			if n.get_script() != null and String(n.get_script().resource_path).ends_with("slot_list.gd"):
				list = n
		_check(list != null and list.get_child_count() == 4, "[%s] the Connect screen has a list of 4 slot rows" % code)
		if list == null:
			continue
		var side_ok := true
		var xs: Array[float] = []
		for row in list.get_children():
			var square: Control = row.get_child(0)
			var name_label: Control = row.get_child(2)
			var sx := square.get_global_rect().get_center().x
			var nx := name_label.get_global_rect().get_center().x
			xs.append(snappedf(sx, 1.0))
			side_ok = side_ok and (sx > nx if code == "he" else sx < nx)
		_check(side_ok, "[%s] each color square is at the %s of its name" % [code, "right" if code == "he" else "left"])
		_check(xs.all(func(x: float) -> bool: return x == xs[0]), "[%s] the 4 squares are in one column (x %s)" % [code, str(xs)])
	_app.set_language("en", false)


## 18.3d: with Effects at 0 every effect still goes through the SFX bus, and that bus is at -80 dB or lower, so nothing can be
## heard; with Effects at 6 the same bus is at the level of step 6, not muted, and the Music bus did not move (REQ-FL-64).
func _effects_zero() -> void:
	print("Effects at 0")
	var old: Dictionary = _app.settings.duplicate()
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var music_bus := AudioServer.get_bus_index("Music")
	_app.settings.mute = false
	_app.settings.music_volume = 7
	for level in [0, 6]:
		_app.settings.sfx_volume = level
		_sound.apply_settings()
		_sound._last_ms.clear()
		var played: bool = _sound.sfx("select")
		var routed: bool = _sound._pool.all(func(p: AudioStreamPlayer) -> bool: return p.bus == "SFX")
		var db := AudioServer.get_bus_volume_db(sfx_bus)
		if level == 0:
			_check(played and routed and db <= -80.0, "Effects 0: the effect goes through the SFX bus, which is at %.0f dB" % db)
		else:
			_check(played and routed and is_equal_approx(db, _sound.step_db(6)) and not AudioServer.is_bus_mute(sfx_bus),
					"Effects 6: the same bus is at %.1f dB and not muted" % db)
		_check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), _sound.step_db(7) + _sound.MUSIC_TRIM_DB),
				"Effects %d: the Music bus is not changed" % level)
		await _wait(0.06)
	_app.settings.merge(old, true)
	_sound.apply_settings()
