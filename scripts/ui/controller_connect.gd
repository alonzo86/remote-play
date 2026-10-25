extends Control
## Phone screen before a TV is joined. Two ways to join: type the room code that the TV shows, or scan the QR code on the TV
## (on a phone with a scanner; no paste button, issue #115). There is no search for TVs: the TV sends nothing by itself.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const QrScanner = preload("res://scripts/net/qr_scanner.gd")
const Lang = preload("res://scripts/core/lang.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const ProfileDropdown = preload("res://scripts/ui/profile_dropdown.gd")

var _status: Label
var _qr: Node
var _code: LineEdit
var _typed_room := ""                 # The room code of a join by a typed code, while its guesses of the address run.
var _candidates: Array[String] = []   # The addresses of that join that are not tried yet.
var os_name := OS.get_name() # A test sets it to "iOS".
var local_ips_lookup: Callable = Protocol.private_ipv4s   # The addresses of this phone for a typed code. A test gives its own.


## The scan button is not shown on an iPhone or iPad (OS name "iOS"): there is no scanner plugin, so only the
## room code is used. A phone whose build has no scanner has no button either (issue #115).
static func shows_scan_button(os_name: String) -> bool:
	return os_name != "iOS"


func _ready() -> void:
	var margin := UiKit.margin(self, 40, 60, 40, 60)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)

	# The title and About share the top row. The row mirrors in Hebrew: About is at the right in English, at the left in Hebrew.
	var top := HBoxContainer.new()
	box.add_child(top)
	var title := UiKit.title("SABABI", 56)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var about := UiKit.box_button("common.about", func():
		App.go(App.AboutScreen, {"back_screen": App.ControllerConnect, "scanner_note": os_name == "Android"}),
			UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	about.custom_minimum_size = Vector2(0, 80)
	top.add_child(about)
	box.add_child(ProfileDropdown.new())

	_status = UiKit.label("", UiTheme.SIZE_BODY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)

	box.add_child(UiKit.label("connect.type_code", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_code = LineEdit.new()
	_code.max_length = Protocol.ROOM_LENGTH + 4   # Room for spaces; Protocol.clean_room_code removes them.
	_code.add_theme_font_size_override("font_size", 64)
	_code.custom_minimum_size = Vector2(0, 130)
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_code.text_changed.connect(_on_code_changed)
	_code.text_submitted.connect(func(_t): join_typed())
	row.add_child(_code)
	var join := UiKit.box_button("connect.join", join_typed, UiTheme.SIZE_ITEM)
	join.custom_minimum_size = Vector2(260, 130)
	row.add_child(join)

	_qr = QrScanner.new()
	add_child(_qr)
	_qr.scanned.connect(_on_qr_text)
	_qr.failed.connect(_on_qr_failed)
	if shows_scan_button(os_name) and _qr.is_available():
		var scan := UiKit.box_button("connect.scan_qr_code", _on_scan_pressed, 40)
		scan.custom_minimum_size = Vector2(0, 150)
		box.add_child(scan)

	App.client.state_changed.connect(_on_state)
	App.client.rejected.connect(_on_rejected)
	_on_state(App.client.state)


func _on_state(state: int) -> void:
	match state:
		ControllerClient.State.CONNECTING, ControllerClient.State.JOINING:
			_status.text = "connect.connecting"
			_status.add_theme_color_override("font_color", UiTheme.ACCENT)
		ControllerClient.State.RECONNECTING:
			_status.text = "connect.reconnecting"
			_status.add_theme_color_override("font_color", UiTheme.ACCENT)
		_:
			if App.last_error != "":
				_status.text = App.last_error.to_upper()
				_status.add_theme_color_override("font_color", UiTheme.BAD)
			else:
				_status.text = ""


## The field shows capital letters.
func _on_code_changed(text: String) -> void:
	var up := text.to_upper()
	if up != text:
		var caret := _code.caret_column
		_code.text = up
		_code.caret_column = caret


## Joins by the typed code. The phone takes the first two numbers of the TV address from its own Wi-Fi address and the last two
## from the code (docs/PROTOCOL.md, "Room code"). It tries each private address of the phone (a fast try each).
func join_typed() -> void:
	var room := Protocol.clean_room_code(_code.text)
	if Protocol.decode_room_code(room) < 0:
		_fail("connect.bad_code")
		return
	_candidates = Protocol.hosts_for_code(room, local_ips_lookup.call())
	if _candidates.is_empty():
		_fail("connect.room_not_found")   # The phone has no Wi-Fi address.
		return
	_typed_room = room
	_try_next_host()


func _try_next_host() -> void:
	var host: String = _candidates.pop_front()
	App.last_error = ""
	App.client.use_saved_token("")
	App.client.connect_to(host, Protocol.WS_PORT, _typed_room, true)


func _fail(key: String) -> void:
	_typed_room = ""
	_candidates.clear()
	App.last_error = Lang.t(key)
	_on_state(ControllerClient.State.IDLE)


func _on_scan_pressed() -> void:
	_qr.scan()


func _on_qr_text(text: String) -> void:
	if text.strip_edges().begins_with(ProfileCode.PREFIX):   # A player code, not a TV link (FD-22).
		App.go(App.ControllerProfiles, {"note": App.import_profile_text(text)})
		return
	var pair := Protocol.parse_pair_url(text)
	if pair.is_empty():
		App.last_error = Lang.t("connect.not_sababi_code")
		_on_state(ControllerClient.State.IDLE)
		return
	_typed_room = ""
	_join(pair.host, pair.port, pair.room)


func _on_qr_failed(reason: String) -> void:
	if reason == "cancelled":
		return
	App.last_error = Lang.f("connect.qr_failed", [reason])
	_on_state(ControllerClient.State.IDLE)


## A typed code that no address answers, or that another TV turns away (`bad_room`), tries the next address of the phone; when
## none is left, the room is not found (unreachable) or the code is wrong (bad_room, the text App set).
func _on_rejected(reason: String) -> void:
	if _typed_room != "" and reason in ["unreachable", "bad_room"]:
		if not _candidates.is_empty():
			_try_next_host()
			return
		if reason == "unreachable":
			App.last_error = Lang.t("connect.room_not_found")
	_typed_room = ""
	_candidates.clear()
	_on_state(App.client.state)   # The state went IDLE before the reason was known: show the reason now.


func on_back() -> void:
	App._quit()


func _join(host: String, port: int, room: String) -> void:
	App.last_error = ""
	App.client.use_saved_token("")
	App.client.connect_to(host, port, room)
