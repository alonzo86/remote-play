extends Control
## Phone screen while the TV is not playing a game (REQ-FL-28): the logo and Connect screens
## ("Waiting for the host"), the Games and Settings screens ("Choose a game on the TV"), and a round
## that this phone joined too late for ("waiting"). The pad screen is for `playing` and `paused`.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")
const Lang = preload("res://scripts/core/lang.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")

var _title: Label
var _sub: Label
var _best: Label
var _best_detail: Label
var _dot: Control
var _name: Label
var _leave: Button
var _leave_timer: Timer
var _profile_button: Button

const LEAVE_ARM_SECONDS := 3.0


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
	_name = UiKit.label("", UiTheme.SIZE_ITEM)
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # A player name is never translated (REQ-FL-63).
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name)
	_title = UiKit.title("", 56)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_title)
	_sub = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_sub)
	_best = UiKit.title("", 56, UiTheme.OK)   # NEW BEST! after a round that set a personal best (REQ-GM-100).
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_best)
	_best_detail = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	_best_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_best_detail)
	box.add_child(UiKit.spacer(60))
	# Leave is a framed text box. The first tap arms it, the second tap leaves (REQ-FL-52).
	_leave = UiKit.box_button("Leave", _on_leave_pressed, UiTheme.SIZE_ITEM)
	_leave.custom_minimum_size = Vector2(0, 96)
	_leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_leave)
	_profile_button = UiKit.box_button("Player", func(): App.go(App.ControllerProfiles), UiTheme.SIZE_ITEM)
	_profile_button.custom_minimum_size = Vector2(440, 96)
	_profile_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_profile_button)
	var settings := UiKit.box_button("Settings", func(): App.go(App.ControllerSettings), UiTheme.SIZE_ITEM)
	settings.custom_minimum_size = Vector2(440, 96)
	settings.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(settings)
	_leave_timer = Timer.new()
	_leave_timer.one_shot = true
	_leave_timer.wait_time = LEAVE_ARM_SECONDS
	_leave_timer.timeout.connect(_disarm_leave)
	add_child(_leave_timer)

	# Connect methods, not lambdas: App.client outlives this screen, and Godot disconnects a method
	# when its node is freed.
	App.client.phase_changed.connect(_on_phase)
	App.client.state_changed.connect(_on_state)
	App.client.profile_answered.connect(_refresh)
	_refresh()


func _on_leave_pressed() -> void:
	if _leave_timer.is_stopped():
		_leave.text = "TAP AGAIN TO LEAVE"
		_set_leave_color(UiTheme.BAD)
		_leave_timer.start()
	else:
		App.client.leave()


func _disarm_leave() -> void:
	_leave.text = "LEAVE"
	_set_leave_color(UiTheme.TEXT)


## The color of the Leave box: white, or red while it is armed. The frame and the text have the same color.
func _set_leave_color(color: Color) -> void:
	_leave.add_theme_stylebox_override("normal", UiTheme.line_box(color))
	_leave.add_theme_stylebox_override("hover", UiTheme.line_box(color))
	_leave.add_theme_color_override("font_color", color)
	_leave.add_theme_color_override("font_hover_color", color)


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
	_title.text = String(t[0]).to_upper()
	_sub.text = String(t[1]).to_upper()
	if c.state != ControllerClient.State.CONNECTED:
		_sub.text = "RECONNECTING..."
	_name.text = c.tv_player_name.to_upper() if c.tv_pid != "" else "%dP" % (c.slot + 1)
	_profile_button.visible = c.can_change_profile()   # A round has started: the player cannot be changed now (REQ-FL-71).
	var best: Dictionary = App.last_best
	_best.text = Lang.t("New best!").to_upper() if not best.is_empty() else ""
	_best_detail.text = ""
	if not best.is_empty():
		_best_detail.text = ProfileKeys.format(best.key, best.value)
		if best.old > 0:
			_best_detail.text += "   " + Lang.f("Before: %s", [ProfileKeys.format(best.key, best.old)]).to_upper()
	_dot.queue_redraw()


func _draw_dot() -> void:
	var c: Node = App.client
	var side := 280.0
	var box := Rect2(_dot.size * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side))
	_dot.draw_rect(box, c.color)
	if c.tv_pid != "" and Avatar.draw(_dot, box.grow(-20.0), c.tv_avatar):
		return   # The avatar takes the place of the number (REQ-FL-69).
	UiTheme.draw_centered(_dot, UiTheme.font(), str(c.slot + 1), box, 160, UiTheme.text_on(c.color))
