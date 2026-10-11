extends "res://scripts/ui/tv_modal.gd"
## Players modal (REQ-FL-32 to 36). Opens from the players badge on the Games screen.
## It lists the slots with Remove, and shows the QR code and the room code for late phones.

const Protocol = preload("res://scripts/core/protocol.gd")
const Lang = preload("res://scripts/core/lang.gd")
const SlotList = preload("res://scripts/ui/slot_list.gd")
const QrView = preload("res://scripts/ui/qr_view.gd")

var _close_button: Button


func _init() -> void:
	card_width = 1400


func _build() -> void:
	body.add_theme_constant_override("separation", 18)
	body.add_child(UiKit.title("players_modal.players", 48))
	body.add_child(UiKit.label("players_modal.only_phones_room_wi", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	body.add_child(cols)

	var list: VBoxContainer = SlotList.new()
	list.removable = true
	list.row_height = 64
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.remove_requested.connect(func(slot): App.server.kick(slot))
	cols.add_child(list)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side.alignment = BoxContainer.ALIGNMENT_BEGIN
	cols.add_child(side)
	var qr: Control = QrView.new()
	qr.custom_minimum_size = Vector2(300, 300)
	var ip: String = App.discovery.ip if App.discovery != null else ""
	qr.text = Protocol.pair_url(ip if ip != "" else "?", App.server.room_code, App.server.pin)
	side.add_child(qr)
	var room := UiKit.title(App.server.room_code, 48)
	room.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(room)
	var pin := UiKit.title(Lang.f("pin.shown", [App.server.pin]), 32, UiTheme.TEXT)
	pin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(pin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(row)
	_close_button = UiKit.item("players_modal.close", close)
	row.add_child(_close_button)
	UiKit.focus_later(_close_button)
