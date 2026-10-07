extends Control
## A modal on top of a TV screen: dim layer plus a centered card. The screen sends Back to `on_back()`.
## With `entries` it is a confirmation: [[label, callable], ...]. A subclass can override `_build()`.
## The focus goes back to the control that had it when the modal closes.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal closed

var title_text := ""
var message := ""
var entries: Array = []
var default_index := 0
var card_width := 760

var card: PanelContainer
var body: VBoxContainer

var _prev_focus: Control
var _buttons: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prev_focus = get_viewport().gui_get_focus_owner()
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = UiKit.card_panel(UiTheme.CARD, 44)
	card.custom_minimum_size = Vector2(card_width, 0)
	center.add_child(card)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	card.add_child(body)
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiTheme.OUTLINE, 0.72))


## Default content: a title, a message and a row of buttons.
func _build() -> void:
	if title_text != "":
		var t := UiKit.title(title_text, 54, UiTheme.CARD_TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(t)
	if message != "":
		var m := UiKit.label(message, 32, UiTheme.CARD_DIM, UiTheme.body_font())
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.add_child(m)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	body.add_child(row)
	for e in entries:
		var b := UiKit.button(String(e[0]), e[1])
		b.custom_minimum_size = Vector2(260, 0)
		row.add_child(b)
		_buttons.append(b)
	if not _buttons.is_empty():
		UiKit.focus_later(_buttons[clampi(default_index, 0, _buttons.size() - 1)])


func on_back() -> void:
	close()


func close() -> void:
	if is_queued_for_deletion():
		return
	if _prev_focus != null and is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree():
		UiKit.focus_later(_prev_focus)
	closed.emit()
	queue_free()
