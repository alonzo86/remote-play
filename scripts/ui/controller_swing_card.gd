extends Control
## The safety card of a swing game on the phone (issue #79, REQ-GM-102): "hold on tight". It covers the waiting screen while the
## settings view of Pin Pals, Tennis or Mini Golf is open on the TV, until the player taps OK. It shows every time that
## the settings view of a swing game opens. The look is the one of the quit question (`controller_quit_dialog.gd`).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Lang = preload("res://scripts/core/lang.gd")

var ok_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # The screen below does not get the touches while the card is open.
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
	var t := UiKit.title("swing.card_title", 48, UiTheme.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(t)
	var text := UiKit.label("swing.card_text", UiTheme.SIZE_BODY, UiTheme.TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(text)
	ok_button = UiKit.box_button("common.ok", _ok, UiTheme.SIZE_ITEM)
	ok_button.custom_minimum_size = Vector2(0, 96)
	body.add_child(ok_button)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UiTheme.BG, 0.92))


func _ok() -> void:
	App.client.send_swing_ok()
	queue_free()
