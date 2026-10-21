extends Control
## Phone screen while connected. Draws everything itself and tracks touches by finger,
## so Recenter, A and B can be used at the same time (multi-touch).

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const SensorSampler = preload("res://scripts/input/sensor_sampler.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Haptics = preload("res://scripts/game/haptics.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")
const QuitDialog = preload("res://scripts/ui/controller_quit_dialog.gd")

var _sampler: Node
var _fingers: Dictionary = {}   # finger index -> zone name
var _touch_finger := -1
var _quit_dialog: Control
var _flash := {"recenter": 0.0}
var _aim_frac := 0.5   # Where the finger left the aim strip (0 left, 1 right) in Pin Pals.

const HEADER_Y := 110.0   # The vertical middle of the header row.
const SCORE_Y := 205.0    # The vertical middle of the row under it: the place and the score of this player (REQ-FL-67).
const INFO_Y := 50.0      # How far the latency rows and the Recenter box move down for the score row.
const BUTTON_LIFT := 12.0        # How far the face of an arcade button stands above its lower edge.
const BUTTON_LIFT_DOWN := 4.0    # The same while it is pressed: the button looks pressed in.


func _ready() -> void:
	_sampler = SensorSampler.new()
	_sampler.client = App.client
	add_child(_sampler)
	# Connect methods, not lambdas: App.client outlives this screen.
	App.client.haptic_requested.connect(_on_haptic)
	App.client.phase_changed.connect(_on_phase)


func _on_haptic(ms: int) -> void:
	Haptics.on_message(ms)   # It vibrates when the HAPTICS switch of the phone Settings screen is on (REQ-FL-66).


func _on_phase(_phase: String) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_flash.recenter = maxf(_flash.recenter - delta * 3.0, 0.0)
	if not _aim_mode():
		_aim_frac = 0.5   # Each turn starts in the middle of the lane.
	queue_redraw()


# ---- Layout (all in viewport coordinates) ----

## The header (player badge, name and Disconnect) is one row: all three are centered on HEADER_Y.
func _rect_leave() -> Rect2:
	return Rect2(size.x - 300, HEADER_Y - 45.0, 270, 90)


## The square in the slot color with the slot number, at the top left of the pad on the header row (REQ-FL-52).
func _rect_slot_square() -> Rect2:
	return Rect2(Vector2(60, HEADER_Y - 45.0), Vector2(90, 90))


## The color of that square: the slot color, and red when the link to the TV is lost.
func _slot_square_color() -> Color:
	var c: Node = App.client
	return c.color if c.state == ControllerClient.State.CONNECTED else UiTheme.BAD


## The fill of the Recenter box: yellow for a moment after a tap (REQ-FL-52), else black.
func _recenter_fill() -> Color:
	return UiTheme.ACCENT if _flash.recenter > 0.0 else UiTheme.BG


## The middle of the face of the arcade button `bit` at `center`: it sits lower while the button is down.
func _button_face(center: Vector2, bit: int) -> Vector2:
	return center - Vector2(0, BUTTON_LIFT_DOWN if (_sampler.buttons & bit) != 0 else BUTTON_LIFT)


func _rect_recenter() -> Rect2:
	var top := 360.0 + INFO_Y
	var h := minf(size.y * 0.30, 620.0)
	return Rect2(60, top, size.x - 120, h)


## True while this phone is on turn in Pin Pals: the Recenter box becomes the aim strip (REQ-BW-4).
func _aim_mode() -> bool:
	var c: Node = App.client
	return c.state == ControllerClient.State.CONNECTED and c.turn_state == 1 and c.turn_kind == ""


func _center_a() -> Vector2:
	return Vector2(size.x * 0.28, size.y - 330)


func _center_b() -> Vector2:
	return Vector2(size.x * 0.72, size.y - 330)


func _radius() -> float:
	return minf(size.x * 0.19, 200.0)


func _zone_at(pos: Vector2) -> String:
	if _rect_leave().has_point(pos):
		return "leave"
	if _rect_recenter().has_point(pos):
		return "aim" if _aim_mode() else "recenter"
	if pos.distance_to(_center_a()) <= _radius() * 1.25:
		return "a"
	if pos.distance_to(_center_b()) <= _radius() * 1.25:
		return "b"
	return "pad"


# ---- Input ----

## Back asks whether to quit the app (REQ-FL-55); Back again answers "stay". The pad ignores touches while the question shows.
func on_back() -> void:
	if is_instance_valid(_quit_dialog):
		_quit_dialog.close()
		return
	for index in _fingers.keys():
		_on_zone_up(_fingers[index], index)
	_fingers.clear()
	_quit_dialog = QuitDialog.new()
	add_child(_quit_dialog)


func _input(event: InputEvent) -> void:
	if is_instance_valid(_quit_dialog):
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = get_global_transform().affine_inverse() * event.position
		if event.pressed:
			var zone := _zone_at(pos)
			_fingers[event.index] = zone
			_on_zone_down(zone, event.index, pos)
		else:
			var zone2: String = _fingers.get(event.index, "")
			_fingers.erase(event.index)
			_on_zone_up(zone2, event.index)
	elif event is InputEventScreenDrag:
		if event.index == _touch_finger:
			_update_touch(get_global_transform().affine_inverse() * event.position)


func _on_zone_down(zone: String, index: int, pos: Vector2) -> void:
	match zone:
		"leave":
			App.client.leave()
		"recenter":
			App.client.send_recenter()
			_flash.recenter = 1.0
		"a":
			_sampler.buttons |= Protocol.BTN_A
		"b":
			_sampler.buttons |= Protocol.BTN_B
	# On the aim strip only the finger on the strip is the touch that the TV reads (REQ-BW-4).
	if _touch_finger < 0 and (zone == "aim" or not _aim_mode()):
		_touch_finger = index
		_sampler.touching = true
		_update_touch(pos)


func _on_zone_up(zone: String, index: int) -> void:
	match zone:
		"a":
			_sampler.buttons &= ~Protocol.BTN_A
		"b":
			_sampler.buttons &= ~Protocol.BTN_B
	if index == _touch_finger:
		_touch_finger = -1
		_sampler.touching = false


func _update_touch(pos: Vector2) -> void:
	_sampler.touch = Vector2(clampf(pos.x / size.x, 0.0, 1.0), clampf(pos.y / size.y, 0.0, 1.0))
	if _aim_mode():
		# On the aim strip x is the place on the strip, not on the screen.
		var strip := _rect_recenter()
		_aim_frac = clampf((pos.x - strip.position.x) / strip.size.x, 0.0, 1.0)
		_sampler.touch.x = _aim_frac


# ---- Drawing ----

## The text of a new best on the pad: "NEW BEST! 340", with the old best when there was one.
static func best_line(best: Dictionary) -> String:
	var text := Lang.t("pad.new_best").to_upper() + " " + ProfileKeys.format(best.key, best.value)
	if best.old > 0:
		text += "  " + Lang.f("pad.before", [ProfileKeys.format(best.key, best.old)]).to_upper()
	return text


func _draw() -> void:
	var f := UiTheme.font()
	var c: Node = App.client
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)

	# The slot color square with the slot number, and the state word. The square is red when the link is lost.
	var online: bool = c.state == ControllerClient.State.CONNECTED
	var square := _rect_slot_square()
	var square_color: Color = _slot_square_color()
	draw_rect(square, square_color)
	UiTheme.draw_centered(self, f, str(c.slot + 1), square, 56, UiTheme.text_on(square_color))
	# The avatar is next to the color square, not on it (REQ-FL-70).
	var has_avatar: bool = c.tv_pid != "" and Avatar.is_known(c.tv_avatar)
	if has_avatar:
		var av := Rect2(Vector2(square.end.x + 10.0, square.position.y), square.size)
		draw_style_box(UiTheme.line_box(UiTheme.TEXT_DIM, UiTheme.BG, 4), av)
		Avatar.draw(self, av.grow(-5.0), c.tv_avatar)
	var own: String = c.tv_player_name if c.tv_pid != "" else "%dP" % (c.slot + 1)
	var status := own if online else Lang.t("connect.reconnecting")
	var name_x := 270.0 if has_avatar else 190.0
	var name_rect := Rect2(name_x, HEADER_Y - 45.0, size.x - name_x - 320.0, 90)
	draw_string(f, Vector2(name_rect.position.x, UiTheme.centered_baseline(f, name_rect, 48)), status.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, name_rect.size.x, 48, UiTheme.ACCENT if online else UiTheme.BAD)

	# The place and the score of this player, on a row of their own under the header (REQ-FL-67).
	var line := score_line(c.score_rank, c.score_of, c.score_text) if online else ""
	if line != "":
		var line_rect := Rect2(60, SCORE_Y - 30.0, size.x - 120, 60)
		var line_size := line_font_size(line, line_rect.size.x)
		draw_string(f, Vector2(line_rect.position.x, UiTheme.centered_baseline(f, line_rect, line_size)), line,
				HORIZONTAL_ALIGNMENT_LEFT, line_rect.size.x, line_size, UiTheme.TEXT)

	# Whose turn it is, in a game with turns, on the row of NEW BEST! (the two never show together, REQ-BW-14).
	if online and c.turn_state != 0:
		var turn_rect := Rect2(60, 376.0 + INFO_Y - 50.0, size.x - 120, 40)
		var golf: bool = c.turn_kind == "golf"
		var turn_text := Lang.t("bowling.phone_turn") if c.turn_state == 1 else Lang.f(
				"mini_golf.phone_wait" if golf else "bowling.phone_wait", [c.turn_who])
		draw_string(f, Vector2(turn_rect.position.x, UiTheme.centered_baseline(f, turn_rect, 32)), turn_text.to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, turn_rect.size.x, 32, UiTheme.ACCENT if c.turn_state == 1 else UiTheme.TEXT_DIM)

	# NEW BEST! while the result menu is open, until the next round starts (REQ-GM-100).
	var best: Dictionary = App.current_best()
	if not best.is_empty() and c.state == ControllerClient.State.CONNECTED:
		var best_rect := Rect2(60, 376.0 + INFO_Y - 50.0, size.x - 120, 40)
		draw_string(f, Vector2(best_rect.position.x, UiTheme.centered_baseline(f, best_rect, 32)), best_line(best),
				HORIZONTAL_ALIGNMENT_LEFT, best_rect.size.x, 32, UiTheme.OK)

	var lat := "RTT -- ms" if c.rtt_ms < 0 else "RTT %d ms" % roundi(c.rtt_ms)
	draw_string(f, Vector2(60, 262 + INFO_Y), lat.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, _lat_color(c.rtt_ms))
	draw_string(f, Vector2(60, 316 + INFO_Y), ("%d Hz  -  TV: %s" % [roundi(c.tx_rate), c.phase]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 120, 24, UiTheme.TEXT_DIM)

	# Disconnect: a framed text box. One tap leaves the TV (REQ-FL-52).
	_draw_box(_rect_leave(), UiTheme.TEXT, UiTheme.BG, Lang.t("pad.disconnect"), 24, UiTheme.TEXT)

	var rr := _rect_recenter()
	if _aim_mode():
		_draw_aim_strip(rr, f)
	else:
		_draw_recenter(rr, f)

	# A and B are round arcade buttons. A is green and B is red (REQ-FL-52). The player color is only the square at the top.
	_draw_button(_center_a(), "A", Protocol.BTN_A, UiTheme.OK)
	_draw_button(_center_b(), "B", Protocol.BTN_B, UiTheme.BAD)


## Recenter: a yellow framed box that fills with yellow for a moment when it is tapped.
func _draw_recenter(rr: Rect2, f: Font) -> void:
	var flashing: bool = _flash.recenter > 0.0
	_draw_box(rr, UiTheme.ACCENT, _recenter_fill(), Lang.t("pad.recenter"), 72,
			UiTheme.BG if flashing else UiTheme.ACCENT)
	draw_string(f, rr.position + Vector2(0, rr.size.y - 40), Lang.t("pad.point_at_tv_then"),
			HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 32, UiTheme.BG if flashing else UiTheme.TEXT)


## The aim strip of Pin Pals (REQ-BW-4): a finger slides the ball left or right along the foul line. The mark stays where the
## finger left it. The word is the help line; the lane lines are drawn as a plain row of ticks.
func _draw_aim_strip(rr: Rect2, f: Font) -> void:
	var col: Color = App.client.color
	draw_style_box(UiTheme.line_box(UiTheme.ACCENT, UiTheme.BG), rr)
	var mid_y := rr.position.y + rr.size.y * 0.45
	for i in 9:
		var tx := rr.position.x + rr.size.x * float(i) / 8.0
		draw_rect(Rect2(tx - 3.0, mid_y - (40.0 if i == 4 else 20.0), 6.0, 80.0 if i == 4 else 40.0), UiTheme.TEXT_DIM)
	var bx := rr.position.x + rr.size.x * _aim_frac
	draw_circle(Vector2(bx, mid_y), 56.0 + UiTheme.LINE, UiTheme.TEXT)
	draw_circle(Vector2(bx, mid_y), 56.0, col)
	draw_string(f, rr.position + Vector2(0, rr.size.y - 40), Lang.t("pad.slide_to_aim"), HORIZONTAL_ALIGNMENT_CENTER,
			rr.size.x, 32, UiTheme.TEXT)


func _draw_box(r: Rect2, frame: Color, fill: Color, text: String, fs: int, col: Color) -> void:
	draw_style_box(UiTheme.line_box(frame, fill), r)
	var ty := UiTheme.centered_baseline(UiTheme.font(), r, fs)
	draw_string(UiTheme.font(), Vector2(r.position.x, ty), text.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)


## An arcade button: a 6 px white ring, a dark lower edge, and a face that sits in when the button is down.
func _draw_button(center: Vector2, label: String, bit: int, col: Color) -> void:
	var r := _radius()
	draw_circle(center, r + UiTheme.LINE, UiTheme.TEXT)
	draw_circle(center, r, col.darkened(0.45))
	var face := _button_face(center, bit)
	draw_circle(face, r - BUTTON_LIFT, col)
	UiTheme.draw_centered(self, UiTheme.font(), label, Rect2(face - Vector2(r, r), Vector2(r, r) * 2.0), 96,
			UiTheme.text_on(col))


## The line under the header during a game (REQ-FL-67): the place and the score of this player, "2ND  12". The place shows
## only with two or more ranked players; the score only when the TV sent one. Empty when there is nothing to say.
static func score_line(rank: int, of: int, score: String) -> String:
	var parts: Array[String] = []
	if rank > 0 and of > 1:
		parts.append(Scoreboard.ordinal(rank))
	if score != "":
		parts.append(score)
	return "  ".join(parts).to_upper()


## The size of the score line: 64 px, and 48 or 32 px when a long score would not fit in `width`. Nothing is cut.
static func line_font_size(text: String, width: float) -> int:
	for fs in [64, 48, 32]:
		if UiTheme.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
			return fs
	return 32


func _lat_color(rtt: float) -> Color:
	if rtt < 0:
		return UiTheme.TEXT_DIM
	if rtt < 25:
		return UiTheme.OK
	if rtt < 60:
		return UiTheme.ACCENT
	return UiTheme.BAD
