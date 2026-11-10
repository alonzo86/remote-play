extends SceneTree
## The pause button and Back on the phone pad (issue #435, REQ-FL-52c): the button shows only while a game plays, it keeps the
## name and the leave box free, and a tap on it or Back during play ask the TV to end the game (`leave_ask`); in every other
## state Back opens the quit question (REQ-FL-55). A real TV server and the phone client of the App on the local machine. Run:
##   godot --headless --path . --script tests/pad_pause.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

# Not the game port: it depends on the process (as in net_leave_ask.gd).
var PORT := 47000 + OS.get_process_id() % 900
var _checks := 0
var _fails := 0
var _server: TvServer
var _asked: Array[int] = []
var _client: ControllerClient
var _pad: Control


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _wait_until(cond: Callable, max_ms := 3000) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _touch(pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 3
	e.pressed = pressed
	e.position = pos
	return e


func _on_asked(slot: int) -> void:
	_asked.append(slot)


func _set_phase(phase: String) -> void:
	_server.set_phase(phase)
	await _wait_until(func(): return _client.phase == phase)
	await process_frame


func _run() -> void:
	await process_frame
	var app: Node = root.get_node("App")
	_client = app.client
	_server = TvServer.new()
	_server.port = PORT
	root.add_child(_server)
	_server.start({})
	_server.set_phase("menu")
	_server.leave_asked.connect(_on_asked)
	_client.connect_to("127.0.0.1", PORT, _server.room_code)
	await _wait_until(func(): return _client.state == ControllerClient.State.CONNECTED)
	var holder := Control.new()
	holder.size = Vector2(1080, 1920)
	root.add_child(holder)
	_pad = load("res://scripts/ui/controller_pad.gd").new()
	_pad.theme = app.theme_res
	holder.add_child(_pad)
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	_pad._sampler.set_process(false)
	await _menu_phase()
	await _playing_phase()
	await _paused_phase()
	_client.leave()
	_server.stop()


func _menu_phase() -> void:
	print("not in a game")
	await _set_phase("menu")
	_check(not _pad._pause_shown(), "menu phase: the pad has no pause button")
	_check(_pad._zone_at(_pad._rect_pause().get_center()) != "pause", "menu phase: a touch at its place is not the pause zone")
	var wide: Rect2 = _pad._rect_name(true)
	_pad.on_back()
	await process_frame
	_check(is_instance_valid(_pad._quit_dialog) and _asked.is_empty(), "menu phase: Back opens the quit question and asks nothing")
	_pad.on_back()   # Back again answers "stay".
	await process_frame
	_check(not is_instance_valid(_pad._quit_dialog) or _pad._quit_dialog.is_queued_for_deletion(), "Back again closes the question")
	_check(wide.size.x == _pad.size.x - 270.0 - 60.0, "the name has the whole row while there is no button")


func _playing_phase() -> void:
	print("a game plays")
	await _set_phase("playing")
	var r: Rect2 = _pad._rect_pause()
	_check(_pad._pause_shown() and r.size == Vector2(96, 96), "playing: the pad shows the pause button, a 96 px square")
	_check(is_equal_approx(_pad.size.x - r.end.x, 60.0) and r.get_center().y == _pad.HEADER_Y,
			"it is at the top right, 60 px from the edge, on the row of the header: %s" % str(r))
	for has_avatar in [false, true]:
		var name_rect: Rect2 = _pad._rect_name(has_avatar)
		_check(name_rect.end.x <= r.position.x - 20.0 and not name_rect.intersects(r),
				"the room of the name ends before the button (avatar %s): %s against %s" % [has_avatar, str(name_rect), str(r)])
		# The name is never made smaller (issue #246): the widest name goes on more lines, and no letter is lost.
		var lines: Array[String] = _pad.name_lines("WWWWWWWWWW", name_rect.size.x)
		_check("".join(lines) == "WWWWWWWWWW",
				"a name of 10 wide letters keeps every letter in %.0f px: %s" % [name_rect.size.x, str(lines)])
	_check(not r.intersects(_pad._rect_leave()) and not r.intersects(_pad._rect_slot_square())
			and not r.intersects(_pad._rect_score()),
			"the button does not touch the leave box, the slot square or the score row")
	_check(_pad._zone_at(r.get_center()) == "pause" and _pad._zone_at(r.position - Vector2(30, 0)) != "pause",
			"a finger on the button is in the zone pause, one beside it is not")
	_pad._input(_touch(true, r.get_center()))
	_pad._input(_touch(false, r.get_center()))
	await _wait_until(func(): return _asked.size() == 1)
	_check(_asked == [_client.slot], "a tap on the button reaches the TV as a request of this phone: %s" % str(_asked))
	await create_timer(1.1).timeout
	_pad.on_back()
	await _wait_until(func(): return _asked.size() == 2)
	_check(_asked.size() == 2 and not is_instance_valid(_pad._quit_dialog),
			"Back during play asks the TV and opens no quit question")
	_pad._input(_touch(true, r.get_center()))
	_pad._input(_touch(false, r.get_center()))
	await create_timer(0.4).timeout
	_check(_asked.size() == 2, "a second tap 0.4 s later is dropped by the TV (one request each second)")


func _paused_phase() -> void:
	print("the game is paused")
	var r: Rect2 = _pad._rect_pause()
	await _set_phase("paused")
	_check(not _pad._pause_shown() and _pad._zone_at(r.get_center()) != "pause", "paused: no pause button and no zone")
	_check(_pad._rect_name(false).end.x > r.position.x, "paused: the name has the whole row")
	await create_timer(1.1).timeout
	var before := _asked.size()
	_pad.on_back()
	await process_frame
	_check(is_instance_valid(_pad._quit_dialog) and _asked.size() == before, "paused: Back opens the quit question and asks nothing")
	_pad.on_back()
	await process_frame
