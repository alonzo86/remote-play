extends Control
## Phone screen before a TV is joined. Two ways to join: scan the QR code on the TV, or pick a TV
## from the list of TVs found by UDP beacon (with a Refresh button). Nothing else: when neither
## works there is no TV to connect to.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const QrScanner = preload("res://scripts/net/qr_scanner.gd")

const SEARCH_MS := 1500   # After Refresh the list says "Searching" this long (the beacon comes each second).

var _list: VBoxContainer
var _status: Label
var _qr: Node
var _search_until_ms := 0


func _ready() -> void:
	var margin := UiKit.margin(self, 40, 60, 40, 60)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)

	box.add_child(UiKit.title("REMOTE PLAY", 92))

	_status = UiKit.label("", 38, UiTheme.TEXT, UiTheme.body_font())
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)

	_qr = QrScanner.new()
	add_child(_qr)
	_qr.scanned.connect(_on_qr_text)
	_qr.failed.connect(_on_qr_failed)
	# No plugin (desktop, or a build without it): the button reads the TV link from the clipboard.
	var scan_text := "Scan QR code" if _qr.is_available() else "Paste TV link"
	var scan := UiKit.button(scan_text, _on_scan_pressed, false, 48)
	scan.theme_type_variation = "LightButton" # White: it stands out from the green TV buttons and the yellow Refresh.
	scan.custom_minimum_size = Vector2(0, 150)
	box.add_child(scan)

	var head := HBoxContainer.new()
	box.add_child(head)
	var tv_title := UiKit.label("Discovered TVs", 40, UiTheme.TEXT_DIM, UiTheme.body_bold())
	tv_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(tv_title)
	var refresh := UiKit.button("Refresh", refresh_list, false, 36)
	refresh.custom_minimum_size = Vector2(240, 96)
	head.add_child(refresh)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	box.add_child(_list)

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
				_status.add_theme_color_override("font_color", UiTheme.BAD_TEXT)
			else:
				_status.text = "Looking for a TV..."
				_status.add_theme_color_override("font_color", UiTheme.TEXT)


## Forget the TVs seen so far and listen again. A TV that is on shows up with its next beacon.
func refresh_list() -> void:
	App.controller_discovery.forget_all()
	_search_until_ms = Time.get_ticks_msec() + SEARCH_MS
	_rebuild_list()


func _rebuild_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var tvs: Array = App.controller_discovery.sorted_list()
	if tvs.is_empty():
		var searching := Time.get_ticks_msec() < _search_until_ms
		_list.add_child(UiKit.label("Searching..." if searching else "No TVs found", 34, UiTheme.TEXT_DIM))
		return
	for tv in tvs:
		# Green, so that the Refresh button above (yellow) is not the same color. Only "<code> x/y".
		var b := UiKit.button("%s %d/%d" % [tv.room, tv.players, tv.max],
				func(): _join(tv.ip, tv.port, tv.room), true, 40)
		b.custom_minimum_size = Vector2(0, 130)
		_list.add_child(b)


func _on_scan_pressed() -> void:
	if _qr.is_available():
		_qr.scan()
	else:
		_on_qr_text(DisplayServer.clipboard_get())


func _on_qr_text(text: String) -> void:
	var pair := Protocol.parse_pair_url(text)
	if pair.is_empty():
		App.last_error = "This is not a Remote Play code."
		_on_state(ControllerClient.State.IDLE)
		return
	_join(pair.host, pair.port, pair.room)


func _on_qr_failed(reason: String) -> void:
	if reason == "cancelled":
		return
	App.last_error = "QR scan failed: " + reason
	_on_state(ControllerClient.State.IDLE)


func _join(host: String, port: int, room: String) -> void:
	App.last_error = ""
	App.client.use_saved_token("")
	App.client.connect_to(host, port, room)
