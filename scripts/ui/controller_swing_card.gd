extends Control
## The safety card of a swing game on the phone (issue #79, REQ-GM-102): "hold on tight". It covers the waiting screen while the
## settings view of Bowling, Tennis or Mini Golf is open on the TV, until the player taps OK. It shows every time that
## the settings view of a swing game opens. The look is the one of the quit question (`controller_quit_dialog.gd`).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Lang = preload("res://scripts/core/lang.gd")

var ok_button: Button


## The picture of the card (issue #235): a phone held with a wrist strap and two arcs of a swing. A child who does not read
## the line sees "hold it tight". Drawn in code (REQ-P6: no image file).
class Icon extends Control:
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var u := minf(size.y, 200.0) / 200.0
		var body := Rect2(c + Vector2(-35, -80) * u, Vector2(70, 130) * u)
		draw_style_box(UiTheme.line_box(UiTheme.TEXT, UiTheme.BG, int(6.0 * u)), body)
		draw_circle(body.get_center() + Vector2(0, 48) * u, 6.0 * u, UiTheme.TEXT)
		# The wrist strap: a loop under the phone.
		draw_arc(c + Vector2(0, 62) * u, 38.0 * u, 0.0, PI, 24, UiTheme.ACCENT, 8.0 * u)
		# The swing: an arc at each side.
		draw_arc(c + Vector2(0, -10) * u, 100.0 * u, deg_to_rad(-35), deg_to_rad(35), 16, UiTheme.TEXT_DIM, 6.0 * u)
		draw_arc(c + Vector2(0, -10) * u, 100.0 * u, deg_to_rad(145), deg_to_rad(215), 16, UiTheme.TEXT_DIM, 6.0 * u)


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
	var icon := Icon.new()
	icon.custom_minimum_size = Vector2(0, 200)
	body.add_child(icon)
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
