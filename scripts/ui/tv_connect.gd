extends Control
## Connect controllers screen (REQ-FL-5 to 10). QR code, room code and the 4 slots.
## Continue opens the Games screen once at least one phone has joined. Back asks to quit.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const QrView = preload("res://scripts/ui/qr_view.gd")
const SlotList = preload("res://scripts/ui/slot_list.gd")
const TvModal = preload("res://scripts/ui/tv_modal.gd")

var _qr: Control
var _status: Label
var _continue: Button
var _modal: Control
var _was_ready := false


func _ready() -> void:
	var m := UiKit.margin(self, 64, 60, 64, 60) # The 60 px safe area (RISKS D5) is the smallest margin.
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 26)
	m.add_child(root)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 90)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# Left: the QR card with the room code.
	var left := CenterContainer.new()
	cols.add_child(left)
	var card := UiKit.card_panel(UiTheme.CARD, 28)
	left.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	card.add_child(cv)
	_qr = QrView.new()
	_qr.custom_minimum_size = Vector2(420, 420)
	cv.add_child(_qr)
	var room := UiKit.title(App.server.room_code, 92, UiTheme.ROOM)
	room.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(room)

	# Right: title, help text and the slots.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(right)
	right.add_child(UiKit.title("Connect controllers", 80))
	var help := UiKit.label("Be in the same room, on the same Wi-Fi. Open the Remote Play app on your phone and scan the code.",
			32, UiTheme.TEXT_DIM, UiTheme.body_font())
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(help)
	right.add_child(UiKit.spacer(10))
	right.add_child(SlotList.new())

	# Footer: status on the left, Continue on the right.
	var foot := HBoxContainer.new()
	root.add_child(foot)
	_status = UiKit.label("", 30, UiTheme.TEXT_DIM, UiTheme.body_font())
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_status)
	_continue = UiKit.button("Continue", App.go_games, true, 44)
	_continue.custom_minimum_size = Vector2(380, 96)
	foot.add_child(_continue)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var ip: String = App.discovery.ip if App.discovery != null else ""
	_qr.text = Protocol.pair_url(ip if ip != "" else "?", App.server.room_code) if ip != "" else ""
	var n: int = App.server.connected_slots().size()
	var ready := n >= 1
	_continue.disabled = not ready
	if ip == "":
		_status.text = "No Wi-Fi address found. Connect the TV to your network."
		_status.add_theme_color_override("font_color", UiTheme.BAD)
	else:
		_status.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		_status.text = ("%d of %d players connected" % [n, Protocol.MAX_PLAYERS]) if ready \
				else "Waiting for the first player to join"
	if ready and not _was_ready and _modal == null:
		_continue.grab_focus() # Focus starts on Continue (REQ-FL-7).
	_was_ready = ready


func on_back() -> void:
	if _modal != null:
		_modal.on_back()
		return
	var d: Control = TvModal.new()
	d.title_text = "Quit Remote Play?"
	d.entries = [["Stay", Callable(self, "_close_dialog")], ["Quit", App._quit]]
	d.default_index = 0
	d.closed.connect(func(): _modal = null)
	_modal = d
	add_child(d)


func _close_dialog() -> void:
	if _modal != null:
		_modal.close()
