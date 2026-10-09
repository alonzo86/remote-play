extends Button
## A choice row of the settings view (REQ-GM-92): `Difficulty  <  Easy  >`. With the focus, Left and Right on the remote
## change the value. The row stops at the first and last value. The arrow at an end is dim. OK does nothing.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")

signal changed(value: String)

## The least width of the row. The view is as wide as its widest row, and every row gets that width.
const MIN_W := 560.0

var row := {}
var value := ""

var _name: Label
var _left: Label
var _value: Label
var _right: Label


func _ready() -> void:
	theme_type_variation = "RowButton"
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(MIN_W, 104)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 20)
	add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 36
	h.offset_right = -36
	_name = UiKit.label(String(row.label), 40, UiTheme.TEXT, UiTheme.body_bold())
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_name)
	_left = _arrow("<")
	h.add_child(_left)
	_value = UiKit.label("", 40, UiTheme.SELECTED, UiTheme.title_font())   # REQ-GM-97: the chosen value is yellow.
	_value.custom_minimum_size = Vector2(190, 0)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_value)
	_right = _arrow(">")
	h.add_child(_right)
	_refresh()


func _arrow(text: String) -> Label:
	var l := UiKit.label(text, 44, UiTheme.TEXT, UiTheme.title_font())
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func set_value(v: String) -> void:
	value = v
	if _value != null:
		_refresh()


## Changes the value by `delta` steps (Left is -1, Right is +1).
func move(delta: int) -> void:
	var v := GameSettings.step(row, value, delta)
	if v == value:
		return
	value = v
	_refresh()
	changed.emit(value)


func _refresh() -> void:
	_value.text = GameSettings.title_of(row, value)
	var i: int = row.values.find(value)
	_left.modulate.a = 1.0 if i > 0 else 0.3
	_right.modulate.a = 1.0 if i < row.values.size() - 1 else 0.3


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		move(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		move(1)
		accept_event()
