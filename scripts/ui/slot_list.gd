extends VBoxContainer
## The 4 player slots as cards (Connect screen and Players modal). It follows the server by itself.
## With `removable`, a joined or lost slot has a "Remove" button (REQ-FL-33).

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

signal remove_requested(slot: int)

var removable := false
var row_height := 84

var _sig := ""
var _prev: Array[int] = []
var _remove_buttons: Dictionary = {}   # slot -> Button


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	for i in Protocol.MAX_PLAYERS:
		_prev.append(PlayerInput.State.EMPTY)
	_rebuild(false)


func _process(_delta: float) -> void:
	if _signature() != _sig:
		_rebuild(true)


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


func _rebuild(animate: bool) -> void:
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
		var row := _make_row(p)
		add_child(row)
		if animate and p.state == PlayerInput.State.CONNECTED and _prev[p.slot] != PlayerInput.State.CONNECTED:
			_pop.call_deferred(row)
		_prev[p.slot] = p.state
	if focused_slot >= 0:
		var b: Button = _remove_buttons.get(focused_slot)
		if b == null:
			b = first_remove_button()
		if b != null:
			UiKit.focus_later(b)


func _pop(row: Control) -> void:
	if not is_instance_valid(row):
		return
	UiTheme.bounce(row, 1.05)


func _make_row(p: PlayerInput) -> Control:
	var present := p.is_present()
	var fill := UiTheme.CARD if present else UiTheme.CARD_EMPTY
	var border := UiTheme.BAD if p.state == PlayerInput.State.LOST else UiTheme.OUTLINE
	var panel := PanelContainer.new()
	var style := UiTheme.card(fill, border, UiTheme.OUTLINE_W, 22, present)
	style.set_content_margin_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, row_height)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	panel.add_child(h)

	var dot := Control.new()
	dot.custom_minimum_size = Vector2(54, 54)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num := p.slot + 1
	var col: Color = p.color if present else UiTheme.SLOT_EMPTY
	dot.draw.connect(func():
		dot.draw_circle(dot.size * 0.5, 27.0, UiTheme.OUTLINE)
		dot.draw_circle(dot.size * 0.5, 22.0, col)
		UiTheme.draw_centered(dot, UiTheme.title_font(), str(num), Rect2(Vector2.ZERO, dot.size), 30, UiTheme.text_on(col)))
	h.add_child(dot)

	var name_text := p.player_name if present and p.player_name != "" else "Player %d" % num
	var name_l := UiKit.label(name_text, 34, UiTheme.CARD_TEXT if present else UiTheme.CARD_MUTED, UiTheme.body_bold())
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(name_l)

	var state_text := "waiting"
	var state_col := UiTheme.CARD_MUTED
	var chip_fill := Color(0, 0, 0, 0)
	match p.state:
		PlayerInput.State.CONNECTED:
			state_text = "Ready!"
			state_col = UiTheme.CHIP_OK_TEXT
			chip_fill = UiTheme.CHIP_OK
		PlayerInput.State.LOST:
			state_text = "Lost"
			state_col = UiTheme.CHIP_BAD_TEXT
			chip_fill = UiTheme.CHIP_BAD
	var st := UiKit.label(state_text, 30, state_col, UiTheme.body_bold())
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if chip_fill.a > 0.0:
		# A state chip (pill with a dark outline): readable from the sofa (REQ-FL-8).
		var chip := PanelContainer.new()
		var cs := UiTheme.card(chip_fill, UiTheme.OUTLINE, 4, 26, false)
		cs.content_margin_left = 22
		cs.content_margin_right = 22
		cs.content_margin_top = 6
		cs.content_margin_bottom = 6
		chip.add_theme_stylebox_override("panel", cs)
		chip.add_child(st)
		h.add_child(chip)
	else:
		h.add_child(st)

	if removable and present:
		var rb := UiKit.button("\u2715  Remove", func(): remove_requested.emit(p.slot), false, 28)
		rb.theme_type_variation = "DangerButton" # Red, white text, the \u2715 (REQ-FL-50).
		rb.custom_minimum_size = Vector2(190, 0)
		h.add_child(rb)
		_remove_buttons[p.slot] = rb
	return panel
