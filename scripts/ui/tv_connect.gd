extends Control
## Connect controllers screen (REQ-FL-5 to 10). QR code, room code and the 4 slots. (The QR code of the phone app is on the
## logo screen since 2026-11-10.)
## OK opens the Games screen once at least one phone has joined ("Press OK to continue"). Back asks to quit.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const QrView = preload("res://scripts/ui/qr_view.gd")
const SlotList = preload("res://scripts/ui/slot_list.gd")
const TvModal = preload("res://scripts/ui/tv_modal.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _qr: Control
var _hint: Label
var _room: Label   # The room code. It follows the address of the TV, so it is read again each frame.
var _modal: Control
var _tap_armed := false   # A press that may become a tap (`_tap`).


func _ready() -> void:
	var m := UiKit.margin(self, 64, 60, 64, 60) # The 60 px safe area (RISKS D5) is the smallest margin.
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 26)
	m.add_child(root)

	# The two columns start at the same top edge, and together they sit in the middle of the screen.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 90)
	cols.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	root.add_child(cols)

	# Left: the QR code in a double frame, with the room code.
	var left := VBoxContainer.new()
	cols.add_child(left)
	var card := UiKit.panel(24)
	left.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	card.add_child(cv)
	cv.add_child(UiKit.label("connect.scan_to_join", UiTheme.SIZE_BODY, UiTheme.TEXT_INFO))
	_qr = QrView.new()
	_qr.custom_minimum_size = Vector2(420, 420)
	cv.add_child(_qr)
	cv.add_child(UiKit.label("connect.room_code", UiTheme.SIZE_BODY, UiTheme.TEXT_INFO))
	_room = UiKit.title(App.server.room_code, UiTheme.SIZE_TITLE)
	_room.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_room)

	# Right: title, help text and the slots.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	cols.add_child(right)
	right.add_child(UiKit.title("common.players"))
	for help_key in ["connect.same_wi_fi", "connect.open_app_scan_code", "connect.or_type_code"]:
		var help := UiKit.label(help_key, UiTheme.SIZE_BODY, UiTheme.TEXT_DESC)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD
		right.add_child(help)
	right.add_child(UiKit.spacer(10))
	right.add_child(SlotList.new())

	# Footer: one line. "Press OK to continue" blinks once a phone has joined (REQ-FL-6). There is no button: OK is the only action.
	_hint = UiKit.blinking("", UiTheme.SIZE_ITEM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(0, 72)   # The line keeps its place, so that the layout does not jump.
	root.add_child(_hint)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


## OK opens the Games screen once a phone has joined (REQ-FL-7). On a phone or a tablet a tap does the same (REQ-FL-7a). The quit
## question has its own buttons.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and can_continue():
		get_viewport().set_input_as_handled()
		App.go_games()


## A tap (REQ-FL-7a). It is read in `_input`, before the GUI: the screen takes the click that the engine makes from a touch, and
## nothing is left for `_unhandled_input`. The press arms it when nothing else can take the tap at that moment: a phone
## has joined, and neither the quit question nor the card of a join request is open. A button of the card or of the question can
## close it before the finger is lifted, so the lifted finger only follows the press and does not look at the card again. The
## press does not go on: the click that the engine makes would land on a Games tile.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		Role.note_touch()
		_tap(event.pressed, event.canceled)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(event.pressed, false)


func _tap(pressed: bool, canceled: bool) -> void:
	if pressed:
		_tap_armed = can_continue() and not (App.join_requests != null and App.join_requests.is_open())
	elif canceled:
		_tap_armed = false
	elif _tap_armed:
		_tap_armed = false
		if can_continue():
			get_viewport().set_input_as_handled()
			App.go_games()


func can_continue() -> bool:
	return _modal == null and App.server.connected_slots().size() >= 1


func _refresh() -> void:
	var ip: String = App.server.ip
	_room.text = App.server.room_code
	_qr.text = Protocol.pair_url(ip, App.server.room_code) if ip != "" else ""
	if App.server.connected_slots().size() >= 1:
		_hint.add_theme_color_override("font_color", UiTheme.ACCENT)
		_hint.text = "connect.tap_continue" if Role.is_touch_ui() else "connect.press_ok_continue"
		_hint.set_process(true)
	elif ip == "":
		_hint.add_theme_color_override("font_color", UiTheme.BAD)
		_hint.text = "connect.no_wi_fi_address"
		_hint.set_process(false)
		_hint.modulate.a = 1.0
	else:
		_hint.text = ""
		_hint.set_process(true)


func on_back() -> void:
	if _modal != null:
		_modal.on_back()
		return
	var d: Control = TvModal.new()
	d.title_text = "connect.quit_sababi"
	d.entries = [["connect.stay", Callable(self, "_close_dialog")], ["connect.quit", App._quit, "danger"]]
	d.default_index = 0
	d.closed.connect(func(): _modal = null)
	_modal = d
	add_child(d)


func _close_dialog() -> void:
	if _modal != null:
		_modal.close()
