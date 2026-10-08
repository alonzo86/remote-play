extends Control
## Phone screen while the TV is not playing a game (REQ-FL-28): the logo and Connect screens
## ("Waiting for the host"), the Games and Settings screens ("Choose a game on the TV"), and a round
## that this phone joined too late for ("waiting"). The pad screen is for `playing` and `paused`.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _title: Label
var _sub: Label
var _dot: Control
var _name: Label


func _ready() -> void:
	var m := UiKit.margin(self, 40, 60, 40, 60)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 36)
	m.add_child(box)

	_dot = Control.new()
	_dot.custom_minimum_size = Vector2(0, 360)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(_draw_dot)
	box.add_child(_dot)
	_name = UiKit.label("", 46, UiTheme.TEXT, UiTheme.body_bold())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name)
	_title = UiKit.title("", 84)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_title)
	_sub = UiKit.label("", 40, UiTheme.TEXT_DIM, UiTheme.body_font())
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_sub)
	box.add_child(UiKit.spacer(60))
	var leave := UiKit.button("Leave", func(): App.client.leave(), false, 44)
	leave.custom_minimum_size = Vector2(0, 120)
	box.add_child(leave)

	# Connect methods, not lambdas: App.client outlives this screen, and Godot disconnects a method
	# when its node is freed.
	App.client.phase_changed.connect(_on_phase)
	App.client.state_changed.connect(_on_state)
	_refresh()


func _on_phase(_phase: String) -> void:
	_refresh()


func _on_state(_state: int) -> void:
	_refresh()


## The text for each TV phase.
static func texts_for(phase: String) -> Array:
	match phase:
		"menu":
			return ["Choose a game on the TV", "Use the TV remote. Your phone is ready."]
		"waiting":
			return ["A round is running", "You join the next round."]
		_:
			return ["Waiting for the host", ""]


func _refresh() -> void:
	var c: Node = App.client
	var t := texts_for(c.phase)
	_title.text = t[0]
	_sub.text = t[1]
	if c.state != ControllerClient.State.CONNECTED:
		_sub.text = "Reconnecting..."
	_name.text = "Player %d  -  %s" % [c.slot + 1, c.tv_name]
	_dot.queue_redraw()


func _draw_dot() -> void:
	var c: Node = App.client
	var center := _dot.size * 0.5
	var r := 150.0
	_dot.draw_circle(center + UiTheme.SHADOW, r + 10.0, UiTheme.OUTLINE)
	_dot.draw_circle(center, r + 10.0, UiTheme.OUTLINE)
	_dot.draw_circle(center, r, c.color)
	UiTheme.draw_centered(_dot, UiTheme.title_font(), str(c.slot + 1),
			Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), 170, Color.WHITE)
