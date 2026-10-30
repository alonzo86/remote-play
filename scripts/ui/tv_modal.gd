extends Control
## A modal on top of a TV screen: dim layer plus a centered panel with the double frame. The screen sends Back to `on_back()`.
## With `entries` it is a confirmation, a text menu: [[label, callable, role], ...] (role is "danger" or left out).
## A subclass can override `_build()`.
## The focus goes back to the control that had it when the modal closes.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal closed

var title_text := ""
var message := ""
var entries: Array = []
var default_index := 0
var card_width := 1200

var card: PanelContainer   # The panel.
var body: VBoxContainer

var _prev_focus: Control
var _suspended := {}   # Control -> its focus mode, for the controls under the dim layer while the modal is open.
var _buttons: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prev_focus = get_viewport().gui_get_focus_owner()
	_suspend_focus_below()
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = UiKit.panel(36)
	card.custom_minimum_size = Vector2(card_width, 0)
	center.add_child(card)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	card.add_child(body)
	_build()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiTheme.BG, 0.8))


## Default content: a title, a message and a text menu.
func _build() -> void:
	if title_text != "":
		var t := UiKit.title(title_text, 48, UiTheme.TEXT)   # A message is white: yellow is the color of the focused item.
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.add_child(t)
	if message != "":
		var m := UiKit.label(message, UiTheme.SIZE_BODY, UiTheme.TEXT_INFO)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.autowrap_mode = TextServer.AUTOWRAP_WORD
		body.add_child(m)
	var menu := UiKit.menu(entries)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(menu)
	for b in menu.get_children():
		_buttons.append(b)
	if not _buttons.is_empty():
		UiKit.focus_later(_buttons[clampi(default_index, 0, _buttons.size() - 1)])


const MOVES := {"ui_up": SIDE_TOP, "ui_down": SIDE_BOTTOM, "ui_left": SIDE_LEFT, "ui_right": SIDE_RIGHT}


## The focus stays inside the modal: an arrow key that would go to a control under the dim layer does nothing, and a focus that
## is already outside comes back to the first control of the modal.
func _input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	for action in MOVES:
		if event.is_action_pressed(action, true):
			if blocks_move(action):
				get_viewport().set_input_as_handled()
			return


## True when the arrow key `action` must not reach the controls under the modal. A focus that is outside the modal is brought back
## to its first control first.
func blocks_move(action: String) -> bool:
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or not is_ancestor_of(owner):
		var first := first_focusable()
		if first != null:
			first.grab_focus()
		return true
	var next := owner.find_valid_focus_neighbor(MOVES[action])
	return next == null or not is_ancestor_of(next)   # Inside the modal the move goes on.


## The first control of the modal that can take the focus, or null.
func first_focusable() -> Control:
	for c in find_children("*", "Control", true, false):
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree():
			return c
	return null


func on_back() -> void:
	close()


## The controls under the dim layer cannot take the focus while the modal is open, so an arrow key never reaches them.
func _suspend_focus_below() -> void:
	for c in get_tree().root.find_children("*", "Control", true, false):
		if c.focus_mode != Control.FOCUS_NONE and not is_ancestor_of(c) and c != self:
			_suspended[c] = c.focus_mode
			c.focus_mode = Control.FOCUS_NONE


func _restore_focus_below() -> void:
	for c in _suspended:
		if is_instance_valid(c):
			c.focus_mode = _suspended[c]
	_suspended.clear()


func _exit_tree() -> void:
	_restore_focus_below()


func close() -> void:
	if is_queued_for_deletion():
		return
	_restore_focus_below()
	if _prev_focus != null and is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree():
		UiKit.focus_later(_prev_focus)
	closed.emit()
	queue_free()
