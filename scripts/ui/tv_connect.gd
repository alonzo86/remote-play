extends Control
## Connect controllers screen (REQ-FL-5 to 10). QR code, room code and the 4 slots, and the QR code of the phone app
## until a phone joins.
## OK opens the Games screen once at least one phone has joined ("Press OK to continue"). Back asks to quit.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const QrView = preload("res://scripts/ui/qr_view.gd")
const SlotList = preload("res://scripts/ui/slot_list.gd")
const TvModal = preload("res://scripts/ui/tv_modal.gd")
const Lang = preload("res://scripts/core/lang.gd")
const About = preload("res://scripts/core/about.gd")

const APP_QR_SIDE := 340.0   # The QR code of the app: smaller than the room code, so the two are told apart (REQ-FL-5).

var _qr: Control
var _hint: Label
var _room: Label   # The room code. It follows the address of the TV, so it is read again each frame.
var _app_card: Control   # "GET THE APP": the QR code of the phone app. Only while no phone is joined.
var _modal: Control


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

	# At the other end of the row from the room code: the QR code of the phone app, for a first-time user (owner, 2026-11-06).
	# It goes away when the first phone has joined, so that a player who scans the room code never sees two codes.
	_app_card = UiKit.panel(24)
	_app_card.name = "AppCard"
	_app_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # The same top edge as the room card, its own height.
	cols.add_child(_app_card)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 14)
	_app_card.add_child(av)
	var app_title := UiKit.label("connect.get_app", UiTheme.SIZE_BODY, UiTheme.TEXT_INFO)
	app_title.autowrap_mode = TextServer.AUTOWRAP_WORD   # The card is as wide as its code, in Hebrew too: a long title wraps.
	app_title.custom_minimum_size = Vector2(APP_QR_SIDE, 0)
	av.add_child(app_title)
	var app_qr := QrView.new()
	app_qr.name = "AppQr"
	app_qr.quiet = 4   # A code that a phone camera reads: a quiet zone of 4 modules and whole pixels.
	app_qr.custom_minimum_size = Vector2(APP_QR_SIDE, APP_QR_SIDE)
	app_qr.text = About.APP_URL
	av.add_child(app_qr)

	# Footer: one line. "Press OK to continue" blinks once a phone has joined (REQ-FL-6). There is no button: OK is the only action.
	_hint = UiKit.blinking("", UiTheme.SIZE_ITEM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(0, 72)   # The line keeps its place, so that the layout does not jump.
	root.add_child(_hint)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


## OK opens the Games screen once a phone has joined (REQ-FL-7). The quit question has its own buttons.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and can_continue():
		get_viewport().set_input_as_handled()
		App.go_games()


func can_continue() -> bool:
	return _modal == null and App.server.connected_slots().size() >= 1


func _refresh() -> void:
	var ip: String = App.server.ip
	_room.text = App.server.room_code
	_app_card.visible = App.server.connected_slots().is_empty()
	_qr.text = Protocol.pair_url(ip, App.server.room_code) if ip != "" else ""
	if App.server.connected_slots().size() >= 1:
		_hint.add_theme_color_override("font_color", UiTheme.ACCENT)
		_hint.text = "connect.press_ok_continue"
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
