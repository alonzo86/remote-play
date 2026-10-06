extends Control
## Phone screen before a TV is joined. Lists the TVs found by UDP beacon.
## The player can also type a room code or the TV IP address.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _list: VBoxContainer
var _status: Label
var _input: LineEdit


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)

	var title := Label.new()
	title.text = "REMOTE PLAY"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.add_theme_font_size_override("font_size", 38)
	box.add_child(_status)

	var tv_title := Label.new()
	tv_title.text = "TVs on this Wi-Fi"
	tv_title.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	box.add_child(tv_title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	box.add_child(_list)

	var manual := Label.new()
	manual.text = "Or type the room code or the TV IP"
	manual.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	box.add_child(manual)

	_input = LineEdit.new()
	_input.placeholder_text = "KQZM  or  192.168.1.20"
	_input.max_length = 21
	_input.custom_minimum_size = Vector2(0, 110)
	_input.add_theme_font_size_override("font_size", 46)
	_input.text_submitted.connect(func(_t): _join_typed())
	box.add_child(_input)

	var join := Button.new()
	join.text = "Join"
	join.custom_minimum_size = Vector2(0, 120)
	join.pressed.connect(_join_typed)
	box.add_child(join)

	App.controller_discovery.list_changed.connect(_rebuild_list)
	App.client.state_changed.connect(_on_state)
	_rebuild_list()
	_on_state(App.client.state)


func _process(_delta: float) -> void:
	# Beacons refresh the player count. Rebuild is cheap, so do it about each second.
	if Engine.get_process_frames() % 60 == 0:
		_rebuild_list()


func _on_state(state: int) -> void:
	match state:
		ControllerClient.State.CONNECTING, ControllerClient.State.JOINING:
			_status.text = "Connecting..."
			_status.add_theme_color_override("font_color", UiTheme.ACCENT)
		ControllerClient.State.RECONNECTING:
			_status.text = "Reconnecting..."
			_status.add_theme_color_override("font_color", UiTheme.ACCENT)
		_:
			if App.last_error != "":
				_status.text = App.last_error
				_status.add_theme_color_override("font_color", UiTheme.BAD)
			else:
				_status.text = "Looking for a TV..."
				_status.add_theme_color_override("font_color", UiTheme.TEXT)


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var tvs: Array = App.controller_discovery.sorted_list()
	if tvs.is_empty():
		var l := Label.new()
		l.text = "(none found yet)"
		l.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		_list.add_child(l)
		return
	for tv in tvs:
		var b := Button.new()
		b.text = "%s   [%s]   %d/%d" % [tv.name, tv.room, tv.players, tv.max]
		b.custom_minimum_size = Vector2(0, 130)
		b.pressed.connect(func(): _join(tv.ip, tv.port, tv.room))
		_list.add_child(b)


func _join_typed() -> void:
	var text := _input.text.strip_edges()
	if text == "":
		return
	if Protocol.is_ipv4(text):
		_join(text, Protocol.WS_PORT, "")
		return
	var room := text.to_upper()
	var tv: Variant = App.controller_discovery.tvs.get(room)
	if tv == null:
		App.last_error = "Room %s not found. Is the TV on the same Wi-Fi?" % room
		_on_state(ControllerClient.State.IDLE)
		return
	_join(tv.ip, tv.port, tv.room)


func _join(host: String, port: int, room: String) -> void:
	App.last_error = ""
	App.client.use_saved_token("")
	App.client.connect_to(host, port, room)
