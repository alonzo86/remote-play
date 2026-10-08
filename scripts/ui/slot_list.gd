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
	var fill := UiTheme.CARD if present else Color(UiTheme.CARD, 0.5)
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
	var col: Color = p.color if present else Color("b9b0d6")
	dot.draw.connect(func():
		dot.draw_circle(dot.size * 0.5, 27.0, UiTheme.OUTLINE)
		dot.draw_circle(dot.size * 0.5, 22.0, col)
		UiTheme.draw_centered(dot, UiTheme.title_font(), str(num), Rect2(Vector2.ZERO, dot.size), 30, Color.WHITE))
	h.add_child(dot)

	var name_text := p.player_name if present and p.player_name != "" else "Player %d" % num
	var name_l := UiKit.label(name_text, 34, UiTheme.CARD_TEXT if present else UiTheme.CARD_DIM, UiTheme.body_bold())
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(name_l)

	var state_text := "waiting"
	var state_col := UiTheme.CARD_DIM
	match p.state:
		PlayerInput.State.CONNECTED:
			state_text = "Ready!"
			state_col = Color("1f9d6b")
		PlayerInput.State.LOST:
			state_text = "lost"
			state_col = UiTheme.BAD
	var st := UiKit.label(state_text, 28, state_col, UiTheme.body_bold())
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(st)

	if removable and present:
		var rb := UiKit.button("Remove", func(): remove_requested.emit(p.slot), false, 28)
		rb.custom_minimum_size = Vector2(170, 0)
		var s2 := UiTheme.card(UiTheme.BAD.darkened(0.25), UiTheme.OUTLINE, 4, 16, false)
		s2.set_content_margin_all(8)
		rb.add_theme_stylebox_override("normal", s2)
		var s3 := UiTheme.card(UiTheme.BAD.darkened(0.25), UiTheme.ACCENT, 8, 16, false)
		s3.set_content_margin_all(8)
		rb.add_theme_stylebox_override("focus", s3)
		rb.add_theme_stylebox_override("hover", s3)
		h.add_child(rb)
		_remove_buttons[p.slot] = rb
	return panel
