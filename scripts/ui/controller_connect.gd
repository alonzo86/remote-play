extends Control
## Phone screen before a TV is joined. Two ways to join: scan the QR code on the TV, or pick a TV
## from the list of TVs found by UDP beacon (with a Refresh button). On an iPhone or iPad (no scanner
## plugin) only the list is shown. Nothing else: when neither works there is no TV to connect to.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const QrScanner = preload("res://scripts/net/qr_scanner.gd")
const Lang = preload("res://scripts/core/lang.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")

const SEARCH_MS := 1500   # After Refresh the list says "Searching" this long (the beacon comes each second).

var _list: VBoxContainer
var _status: Label
var _qr: Node
var _search_until_ms := 0
var os_name := OS.get_name() # A test sets it to "iOS".


## The scan / paste button is not shown on an iPhone or iPad (OS name "iOS"): there is no scanner plugin, so only the
## TV list is used. A Mac keeps "Paste TV link" for development runs.
static func shows_scan_button(os_name: String) -> bool:
	return os_name != "iOS"


## A line under "No TVs found" on an iPhone or iPad: the beacon needs the Local Network permission (REQ-FL-59).
static func empty_list_hint(os_name: String) -> String:
	if os_name == "iOS":
		return Lang.t("No TV? In Settings, allow Local Network for this app, and use the same Wi-Fi as the TV.")
	return ""


func _ready() -> void:
	var margin := UiKit.margin(self, 40, 60, 40, 60)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)

	box.add_child(UiKit.title("WOBBLE", 56))
	box.add_child(_profile_row())

	_status = UiKit.label("", UiTheme.SIZE_BODY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)

	_qr = QrScanner.new()
	add_child(_qr)
	_qr.scanned.connect(_on_qr_text)
	_qr.failed.connect(_on_qr_failed)
	if shows_scan_button(os_name):
		# No plugin (desktop, or a build without it): the button reads the TV link from the clipboard.
		var scan_text := "Scan QR code" if _qr.is_available() else "Paste TV link"
		var scan := UiKit.box_button(scan_text, _on_scan_pressed, 40)
		scan.custom_minimum_size = Vector2(0, 150)
		box.add_child(scan)

	var head := HBoxContainer.new()
	box.add_child(head)
	var tv_title := UiKit.label("Discovered TVs", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	tv_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(tv_title)
	var refresh := UiKit.box_button("Refresh", refresh_list, UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	refresh.custom_minimum_size = Vector2(0, 96)
	head.add_child(refresh)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	box.add_child(_list)

	App.controller_discovery.list_changed.connect(_rebuild_list)
	App.client.state_changed.connect(_on_state)
	_rebuild_list()
	_on_state(App.client.state)


## The row for the player of this phone (REQ-FL-71): the avatar and the name of the active profile, GUEST, or MAKE A PLAYER while
## the phone has no profile. A tap opens the list, or the new player screen when there is no profile yet.
func _profile_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var store = App.profiles
	var active = store.active()
	var av := AvatarView.new(active.avatar if active != null else -1, 110.0)
	av.tappable = false
	row.add_child(av)
	var text: String = active.player_name if active != null else ("Guest" if not store.profiles.is_empty() else "Make a player")
	var b := UiKit.box_button(text, _on_profile_pressed, UiTheme.SIZE_ITEM)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED if active != null else Node.AUTO_TRANSLATE_MODE_INHERIT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 110)
	row.add_child(b)
	return row


func _on_profile_pressed() -> void:
	if App.profiles.profiles.is_empty():
		App.go(App.ControllerProfileEdit, {"profile_id": ""})
	else:
		App.go(App.ControllerProfiles)


func _process(_delta: float) -> void:
	# Beacons refresh the player count. Rebuild is cheap, so do it about each second.
	if Engine.get_process_frames() % 60 == 0:
		_rebuild_list()


func _on_state(state: int) -> void:
	match state:
		ControllerClient.State.CONNECTING, ControllerClient.State.JOINING:
			_status.text = "CONNECTING..."
			_status.add_theme_color_override("font_color", UiTheme.ACCENT)
		ControllerClient.State.RECONNECTING:
			_status.text = "RECONNECTING..."
			_status.add_theme_color_override("font_color", UiTheme.ACCENT)
		_:
			if App.last_error != "":
				_status.text = App.last_error.to_upper()
				_status.add_theme_color_override("font_color", UiTheme.BAD)
			else:
				_status.text = "LOOKING FOR A TV..."
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
		_list.add_child(UiKit.label("Searching..." if searching else "No TVs found", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM))
		var hint := empty_list_hint(os_name)
		if not searching and hint != "":
			var hint_label := UiKit.label(hint, UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
			hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			_list.add_child(hint_label)
		return
	for tv in tvs:
		# Only "<code> x/y".
		var b := UiKit.box_button("%s %d/%d" % [tv.room, tv.players, tv.max],
				func(): _join(tv.ip, tv.port, tv.room), UiTheme.SIZE_ITEM)
		b.custom_minimum_size = Vector2(0, 130)
		_list.add_child(b)


func _on_scan_pressed() -> void:
	if _qr.is_available():
		_qr.scan()
	else:
		_on_qr_text(DisplayServer.clipboard_get())


func _on_qr_text(text: String) -> void:
	if text.strip_edges().begins_with("WP1."):   # A player code, not a TV link (FD-22).
		App.go(App.ControllerProfiles, {"note": App.import_profile_text(text)})
		return
	var pair := Protocol.parse_pair_url(text)
	if pair.is_empty():
		App.last_error = Lang.t("This is not a Wobble code.")
		_on_state(ControllerClient.State.IDLE)
		return
	_join(pair.host, pair.port, pair.room)


func _on_qr_failed(reason: String) -> void:
	if reason == "cancelled":
		return
	App.last_error = Lang.f("QR scan failed: %s", [reason])
	_on_state(ControllerClient.State.IDLE)


func _join(host: String, port: int, room: String) -> void:
	App.last_error = ""
	App.client.use_saved_token("")
	App.client.connect_to(host, port, room)
