extends SceneTree
## Button states and the Leave button of the phone wait screen (REQ-FL-41, 41a, 52, 53).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/ui_states.gd -- --role=controller

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

var _checks := 0
var _fails := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _run() -> void:
	_button_styles()
	await _wait_screen_leave()


func _button_styles() -> void:
	print("button states")
	# Three button colors with a shadow, a black focus border, a sinking pressed state, a gray disabled state
	# (REQ-FL-41, 41a, 50).
	var theme := UiTheme.make()
	var fills := {"Button": UiTheme.ACCENT, "PrimaryButton": UiTheme.OK, "DangerButton": UiTheme.DANGER,
			"RowButton": UiTheme.BUTTON, "LightButton": UiTheme.CARD}
	var btn_ok := true
	for type in fills:
		var n := theme.get_stylebox("normal", type) as StyleBoxFlat
		var f := theme.get_stylebox("focus", type) as StyleBoxFlat
		var pr := theme.get_stylebox("pressed", type) as StyleBoxFlat
		var d := theme.get_stylebox("disabled", type) as StyleBoxFlat
		btn_ok = btn_ok and n.bg_color.is_equal_approx(fills[type]) and n.shadow_offset == UiTheme.SHADOW
		btn_ok = btn_ok and f.border_color == UiTheme.FOCUS_BORDER and f.border_width_left >= 10
		btn_ok = btn_ok and f.shadow_offset.x > n.shadow_offset.x
		btn_ok = btn_ok and f.bg_color.is_equal_approx(n.bg_color)
		# Pressed: no shadow, and the box moved onto where the shadow was, with the same size.
		btn_ok = btn_ok and pr.shadow_size == 0 and pr.expand_margin_left == -UiTheme.SHADOW.x \
				and pr.expand_margin_right == UiTheme.SHADOW.x and pr.expand_margin_bottom == UiTheme.SHADOW.y
		# Disabled: opaque, gray, no shadow.
		btn_ok = btn_ok and d.bg_color.a == 1.0 and d.bg_color.s < 0.15 and d.shadow_size == 0
		btn_ok = btn_ok and UiTheme.contrast(theme.get_color("font_color", type), fills[type]) >= 4.5
		btn_ok = btn_ok and UiTheme.contrast(theme.get_color("font_disabled_color", type), UiTheme.DISABLED) >= 4.5
		if not btn_ok:
			print("    button style problem: ", type)
			break
	_check(btn_ok, "buttons: 3 colors, black focus border and lift, sunk pressed state, opaque gray disabled state")
	_check(fills.Button != fills.PrimaryButton and fills.Button != fills.DangerButton, "yellow, green and red are three colors")


## The first tap on Leave arms it (red, "Tap again to leave"), a tap after the time is over arms it again, and
## a second tap inside the time leaves (REQ-FL-52).
func _wait_screen_leave() -> void:
	print("wait screen Leave")
	var app: Node = root.get_node("App")
	var wait: Control = load("res://scripts/ui/controller_wait.gd").new()
	root.add_child(wait)
	await process_frame
	_check(wait._leave.text == "Leave" and wait._leave.theme_type_variation == "" and wait._leave_timer.is_stopped(),
			"Leave starts as a plain button")
	app.client._set_state(ControllerClient.State.CONNECTED)
	wait._leave.pressed.emit()
	_check(app.client.state == ControllerClient.State.CONNECTED and not wait._leave_timer.is_stopped()
			and wait._leave.theme_type_variation == "DangerButton" and wait._leave.text.contains("Tap again"),
			"the first tap arms Leave and does not leave")
	wait._leave_timer.timeout.emit() # The 3 s are over.
	_check(wait._leave.text == "Leave" and wait._leave.theme_type_variation == "",
			"Leave goes back to a plain button when the time is over")
	wait._leave.pressed.emit()
	wait._leave.pressed.emit()
	_check(app.client.state == ControllerClient.State.IDLE, "the second tap inside the time leaves the TV")
	wait.queue_free()
