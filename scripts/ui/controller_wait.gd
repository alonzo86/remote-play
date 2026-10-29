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
const QuitDialog = preload("res://scripts/ui/controller_quit_dialog.gd")
const SwingCard = preload("res://scripts/ui/controller_swing_card.gd")

var _title: Label
var _sub: Label
var _best: Label
var _best_detail: Label
var _dot: Control
var _name: Label
var _leave: Button
var _quit_dialog: Control
var _pick_box: Control      # "Play this game?" with IN and OUT, in the TV settings view with two or more phones (issue #76).
var _in_button: Button
var _out_button: Button
var _swing_card: Control   # The safety card of a swing game (issue #79). Null while it is not open.


func _ready() -> void:
	var m := UiKit.margin(self, 40, 60, 40, 60)
	var page := VBoxContainer.new()
	m.add_child(page)
	# Disconnect is at the top right, where the pad has it (REQ-FL-52). One tap leaves the TV.
	var top := HBoxContainer.new()
	top.layout_direction = Control.LAYOUT_DIRECTION_LTR   # The pad is not mirrored in Hebrew, so this is not either.
	top.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(top)
	_leave = UiKit.box_button("pad.disconnect", App.client.leave, 32)
	_leave.custom_minimum_size = Vector2(0, 90)
	top.add_child(_leave)
	# The content scrolls when the screen is too low for it (a phone held in landscape), and is centered when it fits.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 36)
	scroll.add_child(box)

	_dot = Control.new()
	var landscape := get_viewport_rect().size.x > get_viewport_rect().size.y
	_dot.custom_minimum_size = Vector2(0, 200 if landscape else 360)
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
	_pick_box = VBoxContainer.new()
	_pick_box.add_theme_constant_override("separation", 24)
	box.add_child(_pick_box)
	var question := UiKit.title("setup.question", 48, UiTheme.TEXT)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD
	_pick_box.add_child(question)
	var choice := HBoxContainer.new()
	choice.add_theme_constant_override("separation", 24)
	_pick_box.add_child(choice)
	_in_button = UiKit.box_button("setup.in", func(): App.client.send_play(true), UiTheme.SIZE_ITEM)
	_out_button = UiKit.box_button("setup.out", func(): App.client.send_play(false), UiTheme.SIZE_ITEM)
	for b in [_in_button, _out_button]:
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.add_child(b)
	_best = UiKit.title("", 56, UiTheme.OK)   # NEW BEST! after a round that set a personal best (REQ-GM-100).
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_best)
	_best_detail = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	_best_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_best_detail)
	var settings := UiKit.box_button("common.settings", func(): App.go(App.ControllerSettings), UiTheme.SIZE_ITEM)
	settings.custom_minimum_size = Vector2(440, 96)
	settings.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(settings)
	var about := UiKit.box_button("common.about", func():
		App.go(App.AboutScreen, {"back_screen": App.ControllerWait, "scanner_note": OS.get_name() == "Android"}),
			UiTheme.SIZE_ITEM)
	about.custom_minimum_size = Vector2(440, 96)
	about.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(about)

	# Connect methods, not lambdas: App.client outlives this screen, and Godot disconnects a method
	# when its node is freed.
	App.client.phase_changed.connect(_on_phase)
	App.client.state_changed.connect(_on_state)
	App.client.profile_answered.connect(_refresh)
	App.client.setup_changed.connect(_update_setup)
	_refresh()
	_update_setup()


## The question IN or OUT shows with two or more phones in the settings view. The chosen button is filled (issue #76).
func _update_pick() -> void:
	var c: Node = App.client
	_pick_box.visible = c.setup_pick
	_mark(_in_button, c.setup_in)
	_mark(_out_button, not c.setup_in)


## Both answers are white (issue #173). The chosen one has the thick yellow border (a shape and a color), so the choice never
## depends on the color alone (issue #76).
func _mark(b: Button, chosen: bool) -> void:
	UiTheme.style_button(b, chosen)


## The setup of the TV settings view: the question IN or OUT (issue #76), and the safety card while the setup is a swing game
## and this phone has not tapped OK for this view (issues #79 and #148).
func _update_setup() -> void:
	_update_pick()
	var want: bool = App.client.setup_swing and not App.client.swing_acked
	if want and not is_instance_valid(_swing_card):
		_swing_card = SwingCard.new()
		add_child(_swing_card)
	elif not want and is_instance_valid(_swing_card):
		_swing_card.queue_free()


func _on_phase(_phase: String) -> void:
	_refresh()


func _on_state(_state: int) -> void:
	_refresh()


## The text for each TV phase.
static func texts_for(phase: String) -> Array:
	match phase:
		"menu":
			return ["wait.choose_game_tv", "wait.use_tv_remote_phone"]
		"waiting":
			return ["wait.round_running", "wait.join_next_round"]
		_:
			return ["wait.waiting_host", ""]


func _refresh() -> void:
	var c: Node = App.client
	var t := texts_for(c.phase)
	_title.text = Lang.t(String(t[0])).to_upper()
	_sub.text = Lang.t(String(t[1])).to_upper()
	if c.state != ControllerClient.State.CONNECTED:
		_sub.text = "connect.reconnecting"
	_name.text = c.tv_player_name.to_upper() if c.tv_pid != "" else "%dP" % (c.slot + 1)
	var best: Dictionary = App.current_best()
	_best.text = Lang.t("pad.new_best").to_upper() if not best.is_empty() else ""
	_best_detail.text = ""
	if not best.is_empty():
		_best_detail.text = ProfileKeys.format(best.key, best.value)
		if best.old > 0:
			_best_detail.text += "   " + Lang.f("pad.before", [ProfileKeys.format(best.key, best.old)]).to_upper()
	_dot.queue_redraw()


func _draw_dot() -> void:
	var c: Node = App.client
	var side := minf(280.0, _dot.size.y - 20.0)
	var has_avatar: bool = c.tv_pid != "" and Avatar.is_known(c.tv_avatar)
	# The color square with its number, and the avatar next to it (REQ-FL-70); the pair is centered.
	var width := side * 2.0 + 20.0 if has_avatar else side
	var box := Rect2(Vector2((_dot.size.x - width) * 0.5, (_dot.size.y - side) * 0.5), Vector2(side, side))
	_dot.draw_rect(box, c.color)
	UiTheme.draw_centered(_dot, UiTheme.font(), str(c.slot + 1), box, 160, UiTheme.text_on(c.color))
	if has_avatar:
		var av := Rect2(box.position + Vector2(side + 20.0, 0.0), box.size)
		_dot.draw_style_box(UiTheme.line_box(UiTheme.TEXT_DIM, UiTheme.BG, 6), av)
		Avatar.draw(_dot, av.grow(-20.0), c.tv_avatar)


## Back asks whether to quit the app (REQ-FL-55); Back again answers "stay".
func on_back() -> void:
	if is_instance_valid(_quit_dialog):
		_quit_dialog.close()
		return
	_quit_dialog = QuitDialog.new()
	add_child(_quit_dialog)
