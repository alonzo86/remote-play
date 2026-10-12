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
const PinPad = preload("res://scripts/ui/pin_pad.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const TvProber = preload("res://scripts/net/tv_prober.gd")
const ProfileDropdown = preload("res://scripts/ui/profile_dropdown.gd")

const SEARCH_MS := 1500   # After Refresh the list says "Searching" this long (the beacon comes each second).

var _list: VBoxContainer
var _status: Label
var _qr: Node
var _search_until_ms := 0
var _pad: Control   # The PIN pad over the screen, while the player joins from the list.
var _prober: TvProber
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

	# The title and About share the top row. The row mirrors in Hebrew: About is at the right in English, at the left in Hebrew.
	var top := HBoxContainer.new()
	box.add_child(top)
	var title := UiKit.title("WOBBLE", 56)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var about := UiKit.box_button("About", func():
		App.go(App.AboutScreen, {"back_screen": App.ControllerConnect, "scanner_note": os_name == "Android"}),
			UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	about.custom_minimum_size = Vector2(0, 80)
	top.add_child(about)
	box.add_child(ProfileDropdown.new())

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
	var tv_title := UiKit.label("Discovered TVs", UiTheme.SIZE_BODY)
	tv_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(tv_title)
	var refresh := UiKit.box_button("Refresh", refresh_list, UiTheme.SIZE_BODY)
	refresh.custom_minimum_size = Vector2(0, 96)
	head.add_child(refresh)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	box.add_child(_list)

	_prober = TvProber.new()
	add_child(_prober)
	_prober.found.connect(App.controller_discovery.add_probed)

	App.controller_discovery.list_changed.connect(_rebuild_list)
	App.client.state_changed.connect(_on_state)
	App.client.rejected.connect(_on_rejected)
	_rebuild_list()
	_on_state(App.client.state)


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
	_prober.stop()
	_prober.start(Protocol.private_ipv4s())
	_search_until_ms = Time.get_ticks_msec() + SEARCH_MS
	_rebuild_list()


func _rebuild_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var tvs: Array = App.controller_discovery.sorted_list()
	if tvs.is_empty():
		var searching := Time.get_ticks_msec() < _search_until_ms or _prober.running
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
				func(): _ask_pin(tv.ip, tv.port, tv.room), UiTheme.SIZE_ITEM)
		b.custom_minimum_size = Vector2(0, 130)
		_list.add_child(b)


func _on_scan_pressed() -> void:
	if _qr.is_available():
		_qr.scan()
	else:
		_on_qr_text(DisplayServer.clipboard_get())


func _on_qr_text(text: String) -> void:
	if text.strip_edges().begins_with(ProfileCode.PREFIX):   # A player code, not a TV link (FD-22).
		App.go(App.ControllerProfiles, {"note": App.import_profile_text(text)})
		return
	var pair := Protocol.parse_pair_url(text)
	if pair.is_empty():
		App.last_error = Lang.t("This is not a Wobble code.")
		_on_state(ControllerClient.State.IDLE)
		return
	if pair.pin == "":
		_ask_pin(pair.host, pair.port, pair.room)   # An old link has no PIN.
	else:
		_join(pair.host, pair.port, pair.room, pair.pin)


func _on_qr_failed(reason: String) -> void:
	if reason == "cancelled":
		return
	App.last_error = Lang.f("QR scan failed: %s", [reason])
	_on_state(ControllerClient.State.IDLE)


## A TV that does not know the saved token needs the PIN: the pad opens (a phone that sent a PIN and was refused shows the text).
func _on_rejected(reason: String) -> void:
	if reason == "bad_pin" and App.client.pin == "":
		_ask_pin(App.client.host, App.client.port, App.client.room)


## Shows the PIN pad over the screen. The player reads the PIN on the TV (FD-25).
func _ask_pin(host: String, port: int, room: String) -> void:
	if _pad != null:
		return
	var cover := ColorRect.new()
	cover.color = UiTheme.BG
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var m := UiKit.margin(cover, 40, 120, 40, 60)
	var pad: Control = PinPad.new()
	m.add_child(pad)
	_pad = cover
	pad.entered.connect(func(pin: String):
		_close_pad()
		_join(host, port, room, pin))
	pad.cancelled.connect(_close_pad)


func _close_pad() -> void:
	if _pad != null:
		_pad.queue_free()
		_pad = null


## Back closes the PIN pad. Without a pad it leaves the app, as before.
func on_back() -> void:
	if _pad != null:
		_close_pad()
	else:
		App._quit()


func _join(host: String, port: int, room: String, pin := "") -> void:
	_prober.stop()   # A scan and a join must not run together.
	App.last_error = ""
	App.client.use_saved_token("")
	App.client.connect_to(host, port, room, pin)
