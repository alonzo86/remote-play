extends "res://scripts/ui/menu_item.gd"
## A choice row of the settings view (REQ-GM-92): `Difficulty  <  Easy  >`. With the focus, Left and Right on the remote
## change the value. The row stops at the first and last value. The arrow at an end is dim. OK does nothing. In Hebrew the row is
## mirrored: the arrow of the previous value is at the right, so Right goes to the previous value.
## The focus shows as the pixel cursor in front of the row (REQ-FL-41).

const Lang = preload("res://scripts/core/lang.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")

signal changed(value: String)

## The least width of the row. The view is as wide as its widest row, and every row gets that width.
const MIN_W := 880.0

var row := {}
var value := ""

var _name: Label
var _left: Label
var _value: Label
var _right: Label


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(MIN_W, 88)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 20)
	add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = UiTheme.CURSOR_UNIT * 4.0 + 24.0
	h.offset_right = -(UiTheme.CURSOR_UNIT * 4.0 + 24.0)   # The same room at both sides: the cursor is at the right in Hebrew.
	_name = UiKit.label(String(row.label), UiTheme.SIZE_ITEM)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_name)
	_left = _arrow("<")
	h.add_child(_left)
	_value = UiKit.label("", UiTheme.SIZE_ITEM, UiTheme.SELECTED)   # REQ-GM-97: the chosen value is yellow.
	_value.custom_minimum_size = Vector2(240, 0)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_value)
	_right = _arrow(">")
	h.add_child(_right)
	_refresh()


func _arrow(text: String) -> Label:
	var l := UiKit.label(text, UiTheme.SIZE_ITEM)
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
	_value.text = Lang.t(GameSettings.title_of(row, value)).to_upper()
	var i: int = row.values.find(value)
	_left.modulate.a = 1.0 if i > 0 else 0.3
	_right.modulate.a = 1.0 if i < row.values.size() - 1 else 0.3


func _gui_input(event: InputEvent) -> void:
	var forward := -1 if is_layout_rtl() else 1   # The step of a press of Right.
	if event.is_action_pressed("ui_left"):
		move(-forward)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		move(forward)
		accept_event()
