extends VBoxContainer
## The 4 player slots as rows (Connect screen and Players modal). It follows the server by itself.
## With `removable`, a joined or lost slot has a "Remove" button (REQ-FL-33).

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

const SQUARE := 24.0   # The slot color square.

signal remove_requested(slot: int)

var removable := false
var row_height := 72

var _sig := ""
var _remove_buttons: Dictionary = {}   # slot -> Button


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_rebuild()


func _process(_delta: float) -> void:
	if _signature() != _sig:
		_rebuild()


func remove_button(slot: int) -> Button:
	return _remove_buttons.get(slot)


func first_remove_button() -> Button:
	for s in Protocol.MAX_PLAYERS:
		if _remove_buttons.has(s):
			return _remove_buttons[s]
	return null


func _signature() -> String:
	var s := ""
	for p in App.server.players:
		s += "%d:%d:%s;" % [p.slot, p.state, p.player_name]
	return s


func _rebuild() -> void:
	var focused_slot := -1
	for slot in _remove_buttons:
		if is_instance_valid(_remove_buttons[slot]) and _remove_buttons[slot].has_focus():
			focused_slot = slot
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_remove_buttons.clear()
	_sig = _signature()
	for p in App.server.players:
		add_child(_make_row(p))
	if focused_slot >= 0:
		var b: Button = _remove_buttons.get(focused_slot)
		if b == null:
			b = first_remove_button()
		if b != null:
			UiKit.focus_later(b)


## One row (REQ-FL-8): a square in the slot color, "1P" to "4P", the name, and the state word. The state is always a word,
## so it never depends on the color alone.
func _make_row(p: PlayerInput) -> Control:
	var present := p.is_present()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	h.custom_minimum_size = Vector2(0, row_height)

	var square := Control.new()
	square.custom_minimum_size = Vector2(SQUARE, SQUARE)
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = p.color if present else UiTheme.SLOT_EMPTY
	square.draw.connect(func(): square.draw_rect(Rect2(Vector2.ZERO, square.size), col))
	h.add_child(square)

	h.add_child(_cell("%dP" % (p.slot + 1), UiTheme.TEXT if present else UiTheme.TEXT_DIM))
	var name_l := _cell(p.player_name if present else "", UiTheme.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	h.add_child(name_l)

	var state_text := "wait"
	var state_col := UiTheme.TEXT_DIM
	match p.state:
		PlayerInput.State.CONNECTED:
			state_text = "ready"
			state_col = UiTheme.OK
		PlayerInput.State.LOST:
			state_text = "lost"
			state_col = UiTheme.BAD
	h.add_child(_cell(state_text, state_col))

	if removable and present:
		var rb := UiKit.item("Remove", func(): remove_requested.emit(p.slot), UiTheme.SIZE_BODY, "danger")
		h.add_child(rb)
		_remove_buttons[p.slot] = rb
	return h


func _cell(text: String, color: Color) -> Label:
	var l := UiKit.label(text, UiTheme.SIZE_ITEM, color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
