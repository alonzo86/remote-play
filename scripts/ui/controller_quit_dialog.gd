extends Control
## The question "Quit Sababi?" on the phone (REQ-FL-55): Back on the Connect screen, the waiting screen and the pad asks
## before it leaves the app.
## A dim layer and a framed card with STAY and QUIT. Back (`close()`) is the same as STAY. The texts are the ones of the TV quit
## question (`connect.quit_sababi`, `connect.stay`, `connect.quit`).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal closed

var stay_button: Button
var quit_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # The screen below does not get the touches while the question is open.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := UiKit.panel(36)
	card.custom_minimum_size = Vector2(maxf(size.x - 120.0, 400.0), 0)
	center.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	card.add_child(body)
	var t := UiKit.title("connect.quit_sababi", 48, UiTheme.TEXT)   # A message is white: yellow is the focus.
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(t)
	stay_button = UiKit.box_button("connect.stay", close, UiTheme.SIZE_ITEM)
	stay_button.custom_minimum_size = Vector2(0, 96)
	body.add_child(stay_button)
	quit_button = UiKit.box_button("connect.quit", App._quit, UiTheme.SIZE_ITEM)
	quit_button.custom_minimum_size = Vector2(0, 96)
	body.add_child(quit_button)
	UiKit.focus_later(stay_button)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiTheme.BG, 0.85))


func close() -> void:
	closed.emit()
	queue_free()
