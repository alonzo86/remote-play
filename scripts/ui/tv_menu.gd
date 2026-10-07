extends Control
## TV main menu. Shows the pairing QR code, the room code, and the player slots.
## All items work with the D-pad (focus navigation) and OK.

const Protocol = preload("res://scripts/core/protocol.gd")
const QrEncoder = preload("res://scripts/core/qr_encoder.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Registry = preload("res://scripts/game/registry.gd")

var _box: VBoxContainer
var _variants_of := ""   # Game id while its variant list is shown.
var _buttons: Array[Button] = []
var _qr: Array = []
var _qr_text := ""
var _toggle_overlay: Button
var _toggle_tilt: Button
var _toggle_yaw: Button


func _ready() -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.position = Vector2(110, 250)
	_box.custom_minimum_size = Vector2(760, 0)
	add_child(_box)
	_show_main()


func _clear() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()


func _show_main() -> void:
	_clear()
	_variants_of = ""
	for g in Registry.all():
		_add(_box, String(g.title), _start_game.bind(String(g.id)))
	_toggle_overlay = _add(_box, "", _on_toggle_overlay)
	_toggle_tilt = _add(_box, "", _on_toggle_tilt)
	_toggle_yaw = _add(_box, "", _on_toggle_yaw)
	_add(_box, "Quit", func(): App._quit())
	_refresh_labels()
	_buttons[0].grab_focus()


## Second step for games with variants (for example the tracks of the marble race).
func _show_variants(game: Dictionary) -> void:
	_clear()
	_variants_of = String(game.id)
	for v in game.variants:
		_add(_box, String(v.title), _start_game.bind(String(game.id), v.props))
	_add(_box, "Back", _show_main)
	_buttons[0].grab_focus()


func on_back() -> void:
	if _variants_of != "":
		_show_main()
	else:
		App._quit()


func _add(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(cb)
	parent.add_child(b)
	_buttons.append(b)
	return b


func _start_game(id: String, props := {}) -> void:
	var game := Registry.find(id)
	if game.has("variants") and props.is_empty():
		_show_variants(game)
		return
	var script := Registry.load_script(id)
	if script != null:
		App.go(script, props if not props.is_empty() else game.get("props", {}))


func _refresh_labels() -> void:
	_toggle_overlay.text = "Debug overlay: %s   (Menu key)" % ("ON" if App.settings.overlay else "OFF")
	_toggle_tilt.text = "Invert tilt axes: %s" % ("ON" if App.settings.invert_tilt else "OFF")
	_toggle_yaw.text = "Invert pointer yaw: %s" % ("ON" if App.settings.invert_yaw else "OFF")


func _on_toggle_overlay() -> void:
	App.toggle_overlay()
	_refresh_labels()


func _on_toggle_tilt() -> void:
	App.settings.invert_tilt = not App.settings.invert_tilt
	App.save_settings()
	_refresh_labels()


func _on_toggle_yaw() -> void:
	App.settings.invert_yaw = not App.settings.invert_yaw
	App.save_settings()
	_refresh_labels()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(110, 130), "REMOTE PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, UiTheme.ACCENT)
	draw_string(font, Vector2(114, 190), "Phone motion controller prototype",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiTheme.TEXT_DIM)

	if _variants_of != "":
		draw_string(font, Vector2(114, 236), "Choose a track", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiTheme.ACCENT)

	# Right panel
	var px := size.x - 860.0
	draw_rect(Rect2(px, 80, 760, size.y - 160), UiTheme.PANEL)
	var ip: String = App.discovery.ip if App.discovery != null else ""
	var room: String = App.server.room_code
	draw_string(font, Vector2(px + 40, 150), "Join with your phone", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UiTheme.TEXT)
	draw_string(font, Vector2(px + 40, 240), "ROOM " + room, HORIZONTAL_ALIGNMENT_LEFT, -1, 80, UiTheme.ACCENT)
	var url := Protocol.pair_url(ip if ip != "" else "?", room)
	draw_string(font, Vector2(px + 40, 290), url, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiTheme.TEXT_DIM)
	if ip == "":
		draw_string(font, Vector2(px + 40, 330), "No Wi-Fi address found.", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiTheme.BAD)
	if url != _qr_text:
		_qr_text = url
		_qr = QrEncoder.encode(url)
	_draw_qr(Vector2(px + 40, 330), 300.0)
	draw_string(font, Vector2(px + 370, 380), "Open the controller app.", HORIZONTAL_ALIGNMENT_LEFT, 340, 28, UiTheme.TEXT)
	draw_string(font, Vector2(px + 370, 420), "It finds this TV by itself.", HORIZONTAL_ALIGNMENT_LEFT, 340, 28, UiTheme.TEXT)
	draw_string(font, Vector2(px + 370, 460), "Or type the room code.", HORIZONTAL_ALIGNMENT_LEFT, 340, 28, UiTheme.TEXT)

	# Player slots
	var y := 690.0
	for p in App.server.players:
		draw_rect(Rect2(px + 40, y, 680, 64), UiTheme.PANEL_LIGHT)
		draw_rect(Rect2(px + 40, y, 16, 64), p.color)
		var label := "Player %d   -" % (p.slot + 1)
		var col: Color = UiTheme.TEXT_DIM
		match p.state:
			PlayerInput.State.CONNECTED:
				label = "Player %d   %s" % [p.slot + 1, p.player_name]
				col = UiTheme.TEXT
			PlayerInput.State.LOST:
				label = "Player %d   %s   (lost)" % [p.slot + 1, p.player_name]
				col = UiTheme.BAD
		draw_string(font, Vector2(px + 76, y + 44), label, HORIZONTAL_ALIGNMENT_LEFT, 480, 32, col)
		if p.state == PlayerInput.State.CONNECTED and p.rtt_ms >= 0.0:
			draw_string(font, Vector2(px + 580, y + 44), "%d ms" % roundi(p.rtt_ms),
					HORIZONTAL_ALIGNMENT_RIGHT, 120, 30, UiTheme.OK)
		y += 76.0


func _draw_qr(origin: Vector2, side: float) -> void:
	draw_rect(Rect2(origin, Vector2(side, side)), Color.WHITE)
	if _qr.is_empty():
		return
	var n := _qr.size()
	var quiet := 2
	var cell := side / float(n + quiet * 2)
	for y in n:
		for x in n:
			if _qr[y][x]:
				draw_rect(Rect2(origin + Vector2(x + quiet, y + quiet) * cell, Vector2(cell, cell)).grow(0.4), Color.BLACK)
