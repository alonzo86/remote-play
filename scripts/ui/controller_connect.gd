extends Control
## Phone screen before a TV is joined. Two ways to join: type the room code that the TV shows, or scan the QR code on the TV
## (on a phone with a scanner; no paste button, issue #115). There is no search for TVs: the TV sends nothing by itself.

const Protocol = preload("res://scripts/core/protocol.gd")
const QuitDialog = preload("res://scripts/ui/controller_quit_dialog.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const QrScanner = preload("res://scripts/net/qr_scanner.gd")
const Haptics = preload("res://scripts/game/haptics.gd")
const Lang = preload("res://scripts/core/lang.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const ProfileDropdown = preload("res://scripts/ui/profile_dropdown.gd")

var _status: Label
var _quit_dialog: Control
var _qr: Node
var _code: LineEdit
var _typed_room := ""                 # The room code of a join by a typed code, while its guesses of the address run.
var _candidates: Array[String] = []   # The addresses of that join that are not tried yet.
var os_name := OS.get_name() # A test sets it to "iOS".
var local_ips_lookup: Callable = Protocol.private_ipv4s   # The addresses of this phone for a typed code. A test gives its own.


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
			UiTheme.SIZE_BODY)
	about.custom_minimum_size = Vector2(0, 80)
	top.add_child(about)
	box.add_child(ProfileDropdown.new())

	_status = UiKit.label("", UiTheme.SIZE_BODY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)

	# The QR scan is the main way to join (issue #241): the biggest button, first, with the thick yellow frame. Typing 4 letters
	# is the second way, under it.
	_qr = QrScanner.new()
	_qr.os_name = os_name
	add_child(_qr)
	_qr.scanned.connect(_on_qr_text)
	_qr.failed.connect(_on_qr_failed)
	if _qr.is_available():   # An iPhone shows it too when its build has the scanner plugin (REQ-FL-58, issue #299).
		var scan := UiKit.box_button("connect.scan_qr_code", _on_scan_pressed, 56, true)
		scan.custom_minimum_size = Vector2(0, 260)
		box.add_child(scan)

	box.add_child(UiKit.label("connect.type_code", UiTheme.SIZE_BODY, UiTheme.TEXT_INFO))
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


## The field shows capital letters. The 4th letter joins at once (issue #241): a young child does not need to find JOIN. A
## text that is not a code shows the error at once. JOIN and Enter stay for a keyboard that sends the letters later.
func _on_code_changed(text: String) -> void:
	var up := text.to_upper()
	if up != text:
		var caret := _code.caret_column
		_code.text = up
		_code.caret_column = caret
	if Protocol.clean_room_code(up).length() == Protocol.ROOM_LENGTH:
		join_typed()


## Joins by the typed code. The phone takes the first two numbers of the TV address from its own Wi-Fi address and the last two
## from the code (docs/PROTOCOL.md, "Room code"). It tries each private address of the phone (a fast try each).
func join_typed() -> void:
	var room := Protocol.clean_room_code(_code.text)
	if _typed_room == room and App.client.state in [ControllerClient.State.CONNECTING, ControllerClient.State.JOINING]:
		return   # The 4th letter joined already: JOIN or Enter right after it does not start a second try.
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
	if _qr.buzzes_on_scan():
		Haptics.on_message(QrScanner.BUZZ_MS)   # Once, when the code is read; follows the HAPTICS switch (REQ-FL-89).
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
	var text := QrScanner.failure_text(reason)
	if text == "":
		return   # A cancel shows nothing (REQ-FL-90).
	App.last_error = text
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


## Back asks whether to quit the app (REQ-FL-55, issue #110); Back again answers "stay".
func on_back() -> void:
	if is_instance_valid(_quit_dialog):
		_quit_dialog.close()
		return
	_quit_dialog = QuitDialog.new()
	add_child(_quit_dialog)


func _join(host: String, port: int, room: String) -> void:
	App.last_error = ""
	App.client.use_saved_token("")
	App.client.connect_to(host, port, room)
