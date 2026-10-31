extends SceneTree
## Every game at 1280x720 (REQ-2D-2: a 2D game builds its layout from `size`, not from fixed pixels; the picture must work at
## 1280x720 and 1920x1080). With 2 simulated phones on the loopback, every game of the registry is started in a 1280x720 window
## and checked: the game fills the window, its pixel view stands for the window, every box the HUD draws (title, timer, chips,
## hint, countdown, plates: read with `Shell.recorder`) is inside the window, in English and in Hebrew, and every control of the
## game is inside the window. The same games at 1080p: tests/hud_layout.gd.
##   godot --headless --path . --script tests/small_screen.gd -- --role=tv

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Shell = preload("res://scripts/game/shell.gd")

const SCREEN := Vector2i(1280, 720)

var _checks := 0
var _fails := 0
var _clients: Array = []
var _seq := [0, 0]
var _game: Control
var _boxes: Array = []


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
	Shell.recorder = Callable()
	Lang.set_language("en", root)
	root.size = Vector2i(1920, 1080)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _stream(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in 2:
			_clients[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), Vector3.ZERO,
					Vector3(2.0 * (1 - 2 * i), 1.0, 9.5), 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


func _on_box(kind: String, ci: CanvasItem, rect: Rect2, _info: Dictionary) -> void:
	if ci == _game:
		_boxes.append({"kind": kind, "rect": rect})


func _run() -> void:
	await _frames(5)
	var app: Node = root.get_node("App")
	root.size = SCREEN
	await _frames(3)
	load("res://scripts/game/game_settings.gd").clear()
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		_clients.append(c)
		var joined := Time.get_ticks_msec()
		while app.server.connected_slots().size() < i + 1 and Time.get_ticks_msec() - joined < 4000:
			await process_frame
	_check(app.server.connected_slots().size() == 2, "2 simulated phones joined")
	Shell.recorder = _on_box
	var screen := Rect2(Vector2.ZERO, Vector2(SCREEN))
	for spec in Registry.all():
		for code in ["en", "he"]:
			Lang.set_language(code, root)
			var props: Dictionary = spec.get("props", {}).duplicate()
			props["difficulty"] = "medium"
			app.go(Registry.load_script(String(spec.id)), props)
			_game = app.current_screen()
			if spec.get("enroll", false):
				_game._on_button(Protocol.BTN_A, 0)
				_game._on_button(Protocol.BTN_A, 1)
			_boxes.clear()
			await _stream(1.2)
			var state := "%s in %s" % [spec.id, code]
			_check(_game.size == Vector2(SCREEN), "REQ-2D-2: %s: the game fills the 1280x720 window (%s)" % [state, str(_game.size)])
			if _game._pixel_viewport != null:
				_check(Vector2(_game._pixel_viewport.size_2d_override) == _game.size,
						"REQ-2D-2: %s: the pixel view stands for the whole window" % state)
			var outside: Array[String] = []
			for b in _boxes:
				if not screen.encloses(b.rect):
					outside.append("%s %s" % [b.kind, str(b.rect)])
			_check(not _boxes.is_empty() and outside.is_empty(),
					"REQ-2D-2: %s: all %d boxes of the HUD are inside the window (outside: %s)" % [state, _boxes.size(), str(outside)])
			var off: Array[String] = []
			for n in _game.find_children("*", "Control", true, false):
				var c := n as Control
				if c.is_visible_in_tree() and c.size.x > 0.0 and not screen.grow(1.0).encloses(c.get_global_rect()):
					off.append("%s %s" % [c.name, str(c.get_global_rect())])
			_check(off.is_empty(), "REQ-2D-2: %s: every control of the game is inside the window (outside: %s)" % [state, str(off)])
			app.go_menu()
			await _frames(2)
	Lang.set_language("en", root)
	for c in _clients:
		c.leave()
