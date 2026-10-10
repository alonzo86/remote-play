extends Control
## Connect controllers screen (REQ-FL-5 to 10). QR code, room code and the 4 slots.
## OK opens the Games screen once at least one phone has joined ("Press OK to continue"). Back asks to quit.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const QrView = preload("res://scripts/ui/qr_view.gd")
const SlotList = preload("res://scripts/ui/slot_list.gd")
const TvModal = preload("res://scripts/ui/tv_modal.gd")

var _qr: Control
var _hint: Label
var _credit: Label   # CREDIT 02: the number of phones that have joined.
var _modal: Control


func _ready() -> void:
	var m := UiKit.margin(self, 64, 60, 64, 60) # The 60 px safe area (RISKS D5) is the smallest margin.
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 26)
	m.add_child(root)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 90)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# Left: the QR code in a double frame, with the room code.
	var left := CenterContainer.new()
	cols.add_child(left)
	var card := UiKit.panel(24)
	left.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	card.add_child(cv)
	_qr = QrView.new()
	_qr.custom_minimum_size = Vector2(420, 420)
	cv.add_child(_qr)
	cv.add_child(UiKit.label("Room code", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM))
	var room := UiKit.title(App.server.room_code, UiTheme.SIZE_TITLE)
	room.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(room)

	# Right: title, help text and the slots.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	var title := UiKit.title("Player select")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_credit = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	head.add_child(_credit)
	var help := UiKit.label("Be in the same room, on the same Wi-Fi. Open the Remote Play app on your phone and scan the code.",
			UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
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


## OK opens the Games screen once a phone has joined (REQ-FL-7). The quit question has its own buttons.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and can_continue():
		get_viewport().set_input_as_handled()
		App.go_games()


func can_continue() -> bool:
	return _modal == null and App.server.connected_slots().size() >= 1


func _refresh() -> void:
	var ip: String = App.discovery.ip if App.discovery != null else ""
	_qr.text = Protocol.pair_url(ip if ip != "" else "?", App.server.room_code) if ip != "" else ""
	_credit.text = "CREDIT %02d" % App.server.connected_slots().size()
	if App.server.connected_slots().size() >= 1:
		_hint.add_theme_color_override("font_color", UiTheme.ACCENT)
		_hint.text = "PRESS OK TO CONTINUE"
		_hint.set_process(true)
	elif ip == "":
		_hint.add_theme_color_override("font_color", UiTheme.BAD)
		_hint.text = "NO WI-FI ADDRESS FOUND. CONNECT THE TV TO YOUR NETWORK."
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
	d.title_text = "Quit Remote Play?"
	d.entries = [["Stay", Callable(self, "_close_dialog")], ["Quit", App._quit, "danger"]]
	d.default_index = 0
	d.closed.connect(func(): _modal = null)
	_modal = d
	add_child(d)


func _close_dialog() -> void:
	if _modal != null:
		_modal.close()
