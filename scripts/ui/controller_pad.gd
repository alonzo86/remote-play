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
const Registry = preload("res://scripts/game/registry.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")
const QuitDialog = preload("res://scripts/ui/controller_quit_dialog.gd")

var _sampler: Node
var _fingers: Dictionary = {}   # finger index -> zone name
var _touch_finger := -1
var _quit_dialog: Control
var _flash := {"recenter": 0.0}
var _aim_trail: Array[float] = []   # The last places of the knob, oldest first, for the trail.
var _leave_hold := 0.0   # Seconds that a finger has stayed on Disconnect (issue #239).
var _aim_frac := 0.5   # Where the finger left the aim strip (0 left, 1 right) in Bowling.

const HEADER_Y := 110.0   # The vertical middle of the header row.
const SCORE_Y := 210.0    # The vertical middle of the row under it: the place and the score of this player (REQ-FL-67).
# A long score text goes on a second line below the first, so it never reaches the name above it (issue #408).
const SCORE_GROWS_DOWN := true
const INFO_Y := 50.0      # How far the Recenter box and the turn and best rows move down for the score row.
const AIM_KNOB := 88.0       # The radius of the aim knob (it was 56 px; a finger covers a small one, issue #236, REQ-BW-4a).
const AIM_TRAIL := 8         # How many places of the knob the trail keeps.
const AIM_TICK_MS := 20      # The tick when the knob crosses the middle of the strip.
const LOST_FRAME := 20.0   # The width of the frame that shows a lost link (REQ-FL-52b).
const LOST_BUZZ_MS := 700  # The buzz when the link is lost (REQ-FL-52b).
const LEAVE_H := 110.0   # The height of the HOLD TO LEAVE box at the bottom.
const LEAVE_SIDE := 60.0    # Its gap to the left and right edge: the rounded corners of a phone must not cut it (REQ-FL-52a).
const LEAVE_BOTTOM := 40.0  # Its gap to the bottom edge.
const RECENTER_W := 480.0   # The RECENTER button: about as wide as its text, right above the HOLD TO LEAVE box (REQ-FL-52).
const RECENTER_H := 80.0
const RECENTER_SIZE := 48   # Its text.
const RECENTER_GAP := 24.0  # The gap between RECENTER and HOLD TO LEAVE, and between the A and B buttons and RECENTER.
const BEST_GAME_SIZE := 40  # The game name above it.
const BEST_SIZE := 56       # NEW BEST!: large and centered in the upper half of the play area (at least 48 px).
const LEAVE_SIZE := 40    # Its text: it fills the box, so the longest text (Hebrew) fits without cutting.
const LEAVE_HOLD := 0.8   # A game needs a long press to leave: a swinging child must not leave by accident (REQ-FL-52a).
const BUTTON_LIFT := 12.0        # How far the face of an arcade button stands above its lower edge.
const BUTTON_LIFT_DOWN := 4.0    # The same while it is pressed: the button looks pressed in.


func _ready() -> void:
	_sampler = SensorSampler.new()
	_sampler.client = App.client
	add_child(_sampler)
	# Connect methods, not lambdas: App.client outlives this screen.
	App.client.haptic_requested.connect(_on_haptic)
	App.client.phase_changed.connect(_on_phase)
	App.client.state_changed.connect(_on_state)


func _on_haptic(ms: int) -> void:
	Haptics.on_message(ms)   # It vibrates when the HAPTICS switch of the phone Settings screen is on (REQ-FL-66).


## The link is lost while the pad shows: one strong buzz, so a player who looks at the TV feels it (REQ-FL-52b).
## The HAPTICS switch of the phone decides, as for every buzz (REQ-FL-66).
func _on_state(state: int) -> void:
	if state == ControllerClient.State.RECONNECTING:
		Haptics.on_message(LOST_BUZZ_MS)
	queue_redraw()


func _on_phase(_phase: String) -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_flash.recenter = maxf(_flash.recenter - delta * 3.0, 0.0)
	if _fingers.values().has("leave"):
		_leave_hold += delta
		if _leave_hold >= LEAVE_HOLD:
			_leave_hold = 0.0
			_fingers.erase(_fingers.find_key("leave"))
			App.client.leave()
			return
	else:
		_leave_hold = 0.0
	if not _aim_mode():
		_aim_frac = 0.5   # Each turn starts in the middle of the lane.
		_aim_trail.clear()
	queue_redraw()


# ---- Layout (all in viewport coordinates) ----

## The HOLD TO LEAVE box: at the bottom of the pad, inset from the sides and the bottom so that the rounded corners of a phone
## do not cut it (REQ-FL-52a). The header row has the badge and the name.
func _rect_leave() -> Rect2:
	return Rect2(LEAVE_SIDE, size.y - LEAVE_BOTTOM - LEAVE_H, size.x - 2.0 * LEAVE_SIDE, LEAVE_H)


## Where the player name (or RECONNECTING...) is written in the header: between the badge (and the avatar) and the right margin.
func _rect_name(has_avatar: bool) -> Rect2:
	var name_x := 270.0 if has_avatar else 190.0
	return Rect2(name_x, HEADER_Y - 45.0, size.x - name_x - 60.0, 90)


const LINE_SIZE := 64   # The place and the score under the header (REQ-FL-67): never smaller, two lines when long (#288).
const NAME_SIZE := 48   # The name in the header: never smaller, a wide name goes on two lines (#246).
const LOST_SIZE := 56   # RECONNECTING... on the dimmed pad.
const HINT_SIZE := 32   # The help line of the Recenter box.


## The lines of a name in the header at 48 px: one line, or more when the name is wider than `width` (issues #238, #246).
static func name_lines(text: String, width: float) -> Array[String]:
	return UiTheme.wrap_lines(UiTheme.font(), text, width, NAME_SIZE)


## Draws `lines` one under the other, the block centered on the middle of `rect` (the box grows around the middle). With
## `from_top` the first line stays on the middle of `rect` and the block grows downward (the score row, issue #408).
func _draw_lines_centered(f: Font, lines: Array[String], rect: Rect2, fs: int, align: HorizontalAlignment, x: float,
		color: Color, from_top := false) -> void:
	# The gap keeps the lines apart, also the Hebrew final letters (issue #403).
	var step := UiTheme.line_step(f, fs)
	var mid := rect.get_center()
	for i in lines.size():
		var line_rect := Rect2(rect.position.x, UiTheme.line_center(mid.y, lines.size(), step, i, from_top) - step * 0.5,
				rect.size.x, step)
		draw_string(f, Vector2(x, UiTheme.centered_baseline(f, line_rect, fs)), lines[i], align, rect.size.x, fs, color)


## The turn line of the pad (REQ-BW-14, REQ-MG-20): `kind` is "" for Bowling and "golf" for Mini Golf, `state` 1 is this phone on
## turn and 2 another player (`who`). Mini Golf says what to do with the phone to the phone on turn.
static func turn_text(kind: String, state: int, who: String) -> String:
	var golf := kind == "golf"
	if state == 1:
		return Lang.t("mini_golf.phone_turn" if golf else "bowling.phone_turn").to_upper()
	return Lang.f("mini_golf.phone_wait" if golf else "bowling.phone_wait", [who]).to_upper()


## The square in the slot color with the slot number, at the top left of the pad on the header row (REQ-FL-52).
func _rect_slot_square() -> Rect2:
	return Rect2(Vector2(60, HEADER_Y - 45.0), Vector2(90, 90))


## The color of that square: the slot color, and red when the link to the TV is lost.
func _slot_square_color() -> Color:
	var c: Node = App.client
	return c.color if c.state == ControllerClient.State.CONNECTED else UiTheme.BAD


## The fill of the Recenter box: black like every enabled button (REQ-FL-38a); white for a moment after a tap (REQ-FL-52).
func _recenter_fill() -> Color:
	return UiTheme.BUTTON_TEXT if _flash.recenter > 0.0 else UiTheme.BUTTON_FACE


## The middle of the face of the arcade button `bit` at `center`: it sits lower while the button is down.
func _button_face(center: Vector2, bit: int) -> Vector2:
	return center - Vector2(0, BUTTON_LIFT_DOWN if (_sampler.buttons & bit) != 0 else BUTTON_LIFT)


## The RECENTER button: small, in the middle, right above the HOLD TO LEAVE box (REQ-FL-52).
func _rect_recenter() -> Rect2:
	var leave := _rect_leave()
	return Rect2((size.x - RECENTER_W) * 0.5, leave.position.y - RECENTER_GAP - RECENTER_H, RECENTER_W, RECENTER_H)


## The aim strip of Bowling (REQ-BW-4): the big box in the upper half of the play area.
func _rect_aim() -> Rect2:
	var top := 360.0 + INFO_Y
	var h := minf(size.y * 0.30, 620.0)
	return Rect2(60, top, size.x - 120, h)


## The help line of RECENTER ("POINT AT THE CENTER OF THE TV, THEN TAP"): under the turn row, in the upper half of the play area.
func _rect_hint() -> Rect2:
	return Rect2(60, 430.0 + INFO_Y - 50.0, size.x - 120, 120)


## The row of the place and the score of this player (REQ-FL-67): its first line is centered on `SCORE_Y`.
func _rect_score() -> Rect2:
	return Rect2(60, SCORE_Y - 30.0, size.x - 120, 60)


## The row of whose turn it is (REQ-BW-14), on the row of NEW BEST!.
func _rect_turn() -> Rect2:
	return Rect2(60, 376.0 + INFO_Y - 50.0, size.x - 120, 40)


## Where NEW BEST! is written: centered, in the upper half of the play area under the help line.
func _rect_best() -> Rect2:
	return Rect2(60, 655.0, size.x - 120, 160)


## The name of the game that NEW BEST! belongs to, on the line above it.
func _rect_best_game() -> Rect2:
	return Rect2(60, 580.0, size.x - 120, 56)


## True while this phone is on turn in Bowling: the Recenter box becomes the aim strip (REQ-BW-4).
func _aim_mode() -> bool:
	var c: Node = App.client
	return c.state == ControllerClient.State.CONNECTED and c.turn_state == 1 and c.turn_kind == ""


## True while the pad has the Recenter box: in a game where the phone is a pointer (REQ-GM-37) and outside a game.
func _recenter_shown() -> bool:
	return App.client.recenter_button


## True while the pad shows the button `key` ("a" or "b"): the game says which buttons it uses (REQ-GM-37a, issue #80).
func _button_shown(key: String) -> bool:
	return App.client.pad_buttons.contains(key)


## A button that is alone stands in the middle of the row; two buttons stand left and right.
func _center_a() -> Vector2:
	return Vector2(size.x * (0.28 if _button_shown("b") else 0.5), _buttons_y())


func _center_b() -> Vector2:
	return Vector2(size.x * (0.72 if _button_shown("a") else 0.5), _buttons_y())


## The A and B buttons stand right above the RECENTER button.
func _buttons_y() -> float:
	return _rect_recenter().position.y - RECENTER_GAP - _radius()


func _radius() -> float:
	return minf(size.x * 0.19, 200.0)


func _zone_at(pos: Vector2) -> String:
	if _rect_leave().has_point(pos):
		return "leave"
	if _aim_mode() and _rect_aim().has_point(pos):
		return "aim"
	if _recenter_shown() and not _aim_mode() and _rect_recenter().has_point(pos):
		return "recenter"
	if _button_shown("a") and pos.distance_to(_center_a()) <= _radius() * 1.25:
		return "a"
	if _button_shown("b") and pos.distance_to(_center_b()) <= _radius() * 1.25:
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
			_leave_hold = 0.0   # The leave happens in _process after LEAVE_HOLD seconds.
		"recenter":
			App.client.send_recenter()
			_flash.recenter = 1.0
		"a":
			_sampler.buttons |= Protocol.BTN_A
		"b":
			_sampler.buttons |= Protocol.BTN_B
	# On the aim strip only the finger on the strip is the touch that the TV reads (REQ-BW-4).
	if _touch_finger < 0 and (zone == "aim" or not _aim_mode()):
		_aim_trail.clear()   # Each slide has its own trail.
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
		var strip := _rect_aim()
		var before := _aim_frac
		_aim_frac = clampf((pos.x - strip.position.x) / strip.size.x, 0.0, 1.0)
		if crossed_middle(before, _aim_frac):
			Haptics.on_message(AIM_TICK_MS)   # A tick under the finger at the middle of the lane (follows the HAPTICS switch).
		if not is_equal_approx(before, _aim_frac):
			_aim_trail.append(before)
			if _aim_trail.size() > AIM_TRAIL:
				_aim_trail.pop_front()
		_sampler.touch.x = _aim_frac


# ---- Drawing ----

## The text of a new best on the pad: "NEW BEST! 340", with the old best when there was one.
static func best_line(best: Dictionary) -> String:
	var text := Lang.t("pad.new_best").to_upper() + " " + ProfileKeys.format(best.key, best.value)
	if best.old > 0:
		text += "  " + Lang.f("pad.before", [ProfileKeys.format(best.key, best.old)]).to_upper()
	return text


## The name of the game that a NEW BEST! belongs to ("PAINT GRAB"), from the key of the best. Empty for an unknown game.
static func best_game_name(best: Dictionary) -> String:
	var game := Registry.find(ProfileKeys.game_of(String(best.get("key", ""))))
	return Lang.t(String(game.title)).to_upper() if not game.is_empty() else ""


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
	var name_rect := _rect_name(has_avatar)
	_draw_lines_centered(f, name_lines(status.to_upper(), name_rect.size.x), name_rect, NAME_SIZE, HORIZONTAL_ALIGNMENT_LEFT,
			name_rect.position.x, UiTheme.ACCENT if online else UiTheme.BAD)

	# The place and the score of this player, on a row of their own under the header (REQ-FL-67).
	var line := score_line(c.score_rank, c.score_of, c.score_text) if online else ""
	if line != "":
		var line_rect := _rect_score()
		_draw_lines_centered(f, score_lines(line, line_rect.size.x), line_rect, LINE_SIZE, HORIZONTAL_ALIGNMENT_LEFT,
				line_rect.position.x, UiTheme.TEXT, SCORE_GROWS_DOWN)

	# Whose turn it is, in a game with turns, on the row of NEW BEST! (the two never show together, REQ-BW-14).
	if online and c.turn_state != 0:
		var turn_rect := _rect_turn()
		var turn_color: Color = UiTheme.ACCENT if c.turn_state == 1 else UiTheme.TEXT_INFO
		if c.turn_kind == "golf" and c.turn_state == 1:
			# Mini Golf tells the player on turn what to do with the phone (the TV shows no instructions during the game). The
			# Recenter help line is not drawn in this game, so the two lines have the room.
			var hint_rect := Rect2(turn_rect.position, Vector2(turn_rect.size.x, 80))
			_draw_lines_centered(f, UiTheme.wrap_lines(f, turn_text(c.turn_kind, c.turn_state, c.turn_who), hint_rect.size.x, 32),
					hint_rect, 32, HORIZONTAL_ALIGNMENT_LEFT, hint_rect.position.x, turn_color)
		else:
			draw_string(f, Vector2(turn_rect.position.x, UiTheme.centered_baseline(f, turn_rect, 32)),
					turn_text(c.turn_kind, c.turn_state, c.turn_who), HORIZONTAL_ALIGNMENT_LEFT, turn_rect.size.x, 32, turn_color)

	# NEW BEST! with the game name, only while the result of the game is open (REQ-GM-100; App.current_best() decides).
	var best: Dictionary = App.current_best()
	if not best.is_empty() and c.state == ControllerClient.State.CONNECTED:
		var game_rect := _rect_best_game()
		var game_name := best_game_name(best)
		_draw_lines_centered(f, UiTheme.wrap_lines(f, game_name, game_rect.size.x, BEST_GAME_SIZE), game_rect, BEST_GAME_SIZE,
				HORIZONTAL_ALIGNMENT_CENTER, game_rect.position.x, UiTheme.TEXT)
		var best_rect := _rect_best()
		_draw_lines_centered(f, UiTheme.wrap_lines(f, best_line(best), best_rect.size.x, BEST_SIZE), best_rect, BEST_SIZE,
				HORIZONTAL_ALIGNMENT_CENTER, best_rect.position.x, UiTheme.ACCENT)

	if not online:
		_draw_lost_link(f)

	# Disconnect: a framed text box. A game needs a press of LEAVE_HOLD seconds; the box fills while the finger stays (REQ-FL-52a).
	var lr := _rect_leave()
	_draw_box(lr, UiTheme.TEXT, UiTheme.BUTTON_FACE, Lang.t("pad.disconnect_hold"), LEAVE_SIZE, UiTheme.BUTTON_TEXT)
	if _leave_hold > 0.0:
		var fill := Rect2(lr.position, Vector2(lr.size.x * minf(_leave_hold / LEAVE_HOLD, 1.0), lr.size.y))
		draw_rect(fill, UiTheme.BAD)
		draw_string(UiTheme.font(), Vector2(lr.position.x, UiTheme.centered_baseline(UiTheme.font(), lr, LEAVE_SIZE)),
				Lang.t("pad.disconnect_hold").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, LEAVE_SIZE, UiTheme.BG)

	if _aim_mode():
		_draw_aim_strip(_rect_aim(), f)
	elif _recenter_shown():
		_draw_recenter(_rect_recenter(), f)

	# A and B are round arcade buttons: A green, B red (REQ-FL-52). The player color is only the square at the top.
	if _button_shown("a"):
		_draw_button(_center_a(), "A", Protocol.BTN_A, UiTheme.OK)
	if _button_shown("b"):
		_draw_button(_center_b(), "B", Protocol.BTN_B, UiTheme.BAD)


## The link is lost (REQ-FL-52b): the play area is dimmed and a frame of white and red dashes runs around the pad. Dashes, not
## only red, so a color-blind player and a child who looks at the TV see a change; the buzz is in `_on_state`.
func _draw_lost_link(f: Font) -> void:
	var top := HEADER_Y + 60.0
	draw_rect(Rect2(0, top, size.x, size.y - top), Color(UiTheme.BG, 0.6))
	var dash := 60.0
	var fw := LOST_FRAME
	var i := 0
	var x := 0.0
	while x < size.x:
		var col: Color = UiTheme.BAD if i % 2 == 0 else UiTheme.TEXT
		var w := minf(dash, size.x - x)
		draw_rect(Rect2(x, 0, w, fw), col)
		draw_rect(Rect2(x, size.y - fw, w, fw), col)
		x += dash
		i += 1
	var y := 0.0
	i = 0
	while y < size.y:
		var col2: Color = UiTheme.BAD if i % 2 == 0 else UiTheme.TEXT
		var h := minf(dash, size.y - y)
		draw_rect(Rect2(0, y, fw, h), col2)
		draw_rect(Rect2(size.x - fw, y, fw, h), col2)
		y += dash
		i += 1
	var mid := Rect2(60, size.y * 0.5 - 40.0, size.x - 120, 80)
	var msg := Lang.t("connect.reconnecting").to_upper()
	_draw_lines_centered(f, UiTheme.wrap_lines(f, msg, mid.size.x, LOST_SIZE), mid, LOST_SIZE, HORIZONTAL_ALIGNMENT_CENTER,
			mid.position.x, UiTheme.TEXT)


## Recenter: a black box with white text that turns white with black text for a moment when it is tapped.
func _draw_recenter(rr: Rect2, f: Font) -> void:
	var flashing: bool = _flash.recenter > 0.0
	_draw_box(rr, UiTheme.TEXT, _recenter_fill(), Lang.t("pad.recenter"), RECENTER_SIZE,
			UiTheme.BUTTON_FACE if flashing else UiTheme.BUTTON_TEXT)
	var hr := _rect_hint()
	_draw_lines_centered(f, hint_lines(f, hr), hr, HINT_SIZE, HORIZONTAL_ALIGNMENT_CENTER, hr.position.x, UiTheme.TEXT_DESC)


## The lines of the help line of RECENTER at 32 px: one line, or more when the line, as in Hebrew, would be wider than `rr`
## (issue #246: it is not made smaller). It keeps a gap of 16 px at each side.
func hint_lines(f: Font, rr: Rect2) -> Array[String]:
	return UiTheme.wrap_lines(f, Lang.t("pad.point_at_tv_then").to_upper(), rr.size.x - 2.0 * (UiTheme.LINE + 16.0), HINT_SIZE)


## True when the knob went from one side of the middle of the strip to the other, or onto the middle (REQ-BW-4a).
static func crossed_middle(before: float, now: float) -> bool:
	return (before - 0.5) * (now - 0.5) < 0.0 or (now == 0.5 and before != 0.5)


## The aim strip of Bowling (REQ-BW-4): a finger slides the ball left or right along the foul line. The mark stays where the
## finger left it. The word is the help line; the lane lines are drawn as a plain row of ticks.
func _draw_aim_strip(rr: Rect2, f: Font) -> void:
	var col: Color = App.client.color
	draw_style_box(UiTheme.line_box(UiTheme.ACCENT, UiTheme.BG), rr)
	var mid_y := rr.position.y + rr.size.y * 0.45
	for i in 9:
		var tx := rr.position.x + rr.size.x * float(i) / 8.0
		draw_rect(Rect2(tx - 3.0, mid_y - (40.0 if i == 4 else 20.0), 6.0, 80.0 if i == 4 else 40.0), UiTheme.TEXT_DIM)
	var bx := rr.position.x + rr.size.x * _aim_frac
	# The trail: the earlier places of the knob, smaller and fainter the older they are.
	for i in _aim_trail.size():
		var k := float(i + 1) / float(_aim_trail.size() + 1)
		draw_circle(Vector2(rr.position.x + rr.size.x * _aim_trail[i], mid_y), AIM_KNOB * (0.4 + 0.5 * k), Color(col, 0.15 + 0.3 * k))
	draw_circle(Vector2(bx, mid_y), AIM_KNOB + UiTheme.LINE, UiTheme.TEXT)
	draw_circle(Vector2(bx, mid_y), AIM_KNOB, col)
	draw_string(f, rr.position + Vector2(0, rr.size.y - 40), Lang.t("pad.slide_to_aim"), HORIZONTAL_ALIGNMENT_CENTER,
			rr.size.x, 32, UiTheme.TEXT)


func _draw_box(r: Rect2, frame: Color, fill: Color, text: String, fs: int, col: Color) -> void:
	draw_style_box(UiTheme.line_box(frame, fill), r)
	var ty := UiTheme.centered_baseline(UiTheme.font(), r, fs)
	draw_string(UiTheme.font(), Vector2(r.position.x, ty), text.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)


## An arcade button (REQ-FL-52): a 6 px white ring, a gray lower edge, a face in the color `col` (A green, B red; owner,
## 2026-11-03) with a letter in `UiTheme.text_on(col)`; the face sits in when the button is down.
func _draw_button(center: Vector2, label: String, bit: int, col: Color) -> void:
	var r := _radius()
	draw_circle(center, r + UiTheme.LINE, UiTheme.TEXT)
	draw_circle(center, r, UiTheme.BUTTON_EDGE)
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


## The score line on lines of at most `width`: always 64 px; a place and a long score that do not fit go on a second line, the
## row grows downward (issue #288, REQ-FL-40: the text is never made smaller). Nothing is cut.
static func score_lines(text: String, width: float) -> Array[String]:
	return UiTheme.wrap_lines(UiTheme.font(), text, width, LINE_SIZE)
