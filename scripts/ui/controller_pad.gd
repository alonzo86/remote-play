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
const Medal = preload("res://scripts/ui/medal.gd")
const QuitDialog = preload("res://scripts/ui/controller_quit_dialog.gd")

var _sampler: Node
var _fingers: Dictionary = {}   # finger index -> zone name
var _touch_finger := -1
var _quit_dialog: Control
var _flash := {"recenter": 0.0}
var _aim_trail: Array[float] = []   # The last places of the knob, oldest first, for the trail.
var leave_drawn := false   # True when the last _draw painted the HOLD TO DISCONNECT box (read by tests/phone_result_line.gd).
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
const LOST_FRAME := 8.0    # The width of the yellow frame that shows a lost link (REQ-FL-52b; it was 20 px red and white dashes).
const LOST_BUZZ_MS := 700  # The buzz when the link is lost (REQ-FL-52b).
const LEAVE_H := 110.0   # The height of the HOLD TO DISCONNECT box at the bottom.
const LEAVE_SIDE := 60.0    # Its gap to the left and right edge: the rounded corners of a phone must not cut it (REQ-FL-52a).
const LEAVE_BOTTOM := 40.0  # Its gap to the bottom edge.
const RECENTER_W := 480.0   # The RECENTER button: about as wide as its text, right above the HOLD TO DISCONNECT box (REQ-FL-52).
const RECENTER_H := 80.0
const RECENTER_SIZE := 48   # Its text.
const RECENTER_GAP := 24.0  # The gap between RECENTER and HOLD TO DISCONNECT, and between the A and B buttons and RECENTER.
const GAME_SIZE := 40       # The name of the game, line 1 of the result (REQ-FL-67a).
const RESULT_GAP_GAME := 48.0   # The gap between the game name and the place row of the result.
const RESULT_GAP_ROW := 32.0    # The gap between the place row and line 3 (the score).
const RESULT_ROW_H := 128.0     # The place row: the medal is 128 px (the 16 px sheet at scale 8); the row is as high without it.
const RESULT_MEDAL_GAP := 32.0  # The gap between the medal and the place text.
const LEAVE_SIZE := 40    # Its text: it fills the box, so the longest text (Hebrew) fits without cutting.
const LEAVE_HOLD := 0.8   # A game needs a long press to leave: a swinging child must not leave by accident (REQ-FL-52a).
const PAUSE_SIZE := 96.0   # The pause button at the top right: a square like the icon buttons of the waiting screen (REQ-FL-52c).
const PAUSE_GAP := 24.0    # Its gap to the name in the header.
const PAUSE_BAR_W := 18.0  # The two bars of its symbol.
const PAUSE_BAR_H := 44.0
const PAUSE_BAR_GAP := 18.0
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
	if _fingers.values().has("leave") and _leave_shown():
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

## The HOLD TO DISCONNECT box: at the bottom of the pad, inset from the sides and the bottom so that the rounded corners of a
## phone do not cut it (REQ-FL-52a). The header row has the badge and the name.
func _rect_leave() -> Rect2:
	return Rect2(LEAVE_SIDE, size.y - LEAVE_BOTTOM - LEAVE_H, size.x - 2.0 * LEAVE_SIDE, LEAVE_H)


## Where the player name (or RECONNECTING...) is written in the header: between the badge (and the avatar) and the right margin.
func _rect_name(has_avatar: bool) -> Rect2:
	var name_x := 270.0 if has_avatar else 190.0
	var room := PAUSE_SIZE + PAUSE_GAP if _pause_shown() else 0.0   # The pause button takes the right end of the row.
	return Rect2(name_x, HEADER_Y - 45.0, size.x - name_x - 60.0 - room, 90)


## True while the pad shows the pause button: only while the game plays and the phone is connected (REQ-FL-52c). Not while it is
## paused, and never in a menu (the pad is not shown there).
func _pause_shown() -> bool:
	var c: Node = App.client
	return c.phase == "playing" and c.state == ControllerClient.State.CONNECTED and not _result_shown()


## True while the result of the game shows on the phone (REQ-FL-67a): the line of the player in the middle and only the
## HOLD TO DISCONNECT box.
func _result_shown() -> bool:
	return App.client.final_text != "" and App.client.state == ControllerClient.State.CONNECTED


## True while the pad shows the HOLD TO DISCONNECT box: in a game and in the result (REQ-FL-52a, REQ-FL-67a). The drawing, the
## hold and the touch zone all use it.
func _leave_shown() -> bool:
	return true


## Where the one line of an older TV is written (no place and no score in its `final` message): the middle of the screen.
func _rect_final() -> Rect2:
	return Rect2(60, size.y * 0.5 - 60.0, size.x - 120, 120)


## The line of the result on lines of at most `width`: 64 px like the score line, never smaller, never cut (REQ-FL-67a).
static func final_lines(text: String, width: float) -> Array[String]:
	return UiTheme.wrap_lines(UiTheme.font(), text.to_upper(), width, LINE_SIZE)


## True when the TV sent the parts of the result (the place and the score): the block of three lines shows. An older TV sends only
## the one line `v`, and the phone shows it as before, with no game name and no medal (REQ-FL-67a).
func _final_structured() -> bool:
	var c: Node = App.client
	return c.final_place != "" and c.final_score != ""


## The name of the game with registry id `id` in the language of the phone, in capitals. Empty for an unknown id.
static func game_name(id: String) -> String:
	var game := Registry.find(id)
	return Lang.t(String(game.title)).to_upper() if not game.is_empty() else ""


## Line 3 of the result on lines of at most `width`: the score, the time or NOT FINISHED in white; when this player set a personal
## best (`best` is true: `App.current_best()` is set), NEW BEST! and the value in yellow in its place. They are on one line when they fit, else
## the title is one line and the value the next: the wrap never takes the unit away from the number, and the text is never smaller.
static func line3_lines(score: String, best: bool, width: float) -> Array[String]:
	var f := UiTheme.font()
	var value := score.to_upper()
	if not best:
		return UiTheme.wrap_lines(f, value, width, LINE_SIZE)
	var title := Lang.t("pad.new_best").to_upper()
	if UiTheme.text_width(f, title + " " + value, LINE_SIZE) <= width:
		return [title + " " + value] as Array[String]
	var lines: Array[String] = [title]
	lines.append_array(UiTheme.wrap_lines(f, value, width, LINE_SIZE))
	return lines


## The block of the result (REQ-FL-67a), centered as a whole on the middle of the screen: the game name (40 px), 48 px, the place
## row (128 px), 32 px, line 3 (64 px, one line or two). `block_top = floor(size.y / 2 - h / 2)`. The rectangles are in the
## coordinates of the pad; `game_lines` and `line3` are the texts; a game that is not known has no name line and no gap above the row.
func _final_block() -> Dictionary:
	var c: Node = App.client
	var f := UiTheme.font()
	var width := size.x - 120.0
	var title := game_name(c.final_game)
	var game_lines: Array[String] = []
	if title != "":
		game_lines = UiTheme.wrap_lines(f, title, width, GAME_SIZE)
	var best := not App.current_best().is_empty()
	var line3 := line3_lines(c.final_score, best, width)
	var h_game := 0.0
	if not game_lines.is_empty():
		h_game = _lines_height(game_lines.size(), GAME_SIZE) + RESULT_GAP_GAME
	var h_line3 := _lines_height(line3.size(), LINE_SIZE)
	var h := h_game + RESULT_ROW_H + RESULT_GAP_ROW + h_line3
	var top := floorf(size.y * 0.5 - h * 0.5)
	var row_top := top + h_game
	return {"top": top, "h": h, "game_lines": game_lines, "game": Rect2(60, top, width, maxf(h_game - RESULT_GAP_GAME, 0.0)),
			"row": Rect2(60, row_top, width, RESULT_ROW_H), "line3_lines": line3, "best": best,
			"line3": Rect2(60, row_top + RESULT_ROW_H + RESULT_GAP_ROW, width, h_line3)}


## The height of `count` lines of `font_size` that are a line gap apart: the size of a line is the size of the font.
static func _lines_height(count: int, font_size: int) -> float:
	return float(count * font_size + (count - 1) * UiTheme.line_gap(font_size))


## Draws `lines` from the top of `rect`, centered, one line gap apart. The text of a line is centered in a box as high as its font.
func _draw_block_lines(f: Font, lines: Array[String], rect: Rect2, fs: int, color: Color) -> void:
	var pitch := float(fs + UiTheme.line_gap(fs))
	for i in lines.size():
		var line_rect := Rect2(rect.position.x, rect.position.y + float(i) * pitch, rect.size.x, float(fs))
		draw_string(f, Vector2(line_rect.position.x, UiTheme.centered_baseline(f, line_rect, fs)), lines[i],
				HORIZONTAL_ALIGNMENT_CENTER, line_rect.size.x, fs, color)


## Where the parts of the place row are (a test uses it): the place text (64 px) and, when this player has a medal, the medal
## (128 px) beside it: on the left of the text, and on the right of it in Hebrew. The row is centered as a whole. `medal` has no
## size when the player has no medal; the text keeps its place and the row keeps its height.
func _place_row_layout(row: Rect2) -> Dictionary:
	var c: Node = App.client
	var tw := UiTheme.text_width(UiTheme.font(), c.final_place.to_upper(), LINE_SIZE)
	var has_medal := Medal.is_known(c.final_medal)
	var total := tw + (RESULT_ROW_H + RESULT_MEDAL_GAP if has_medal else 0.0)
	var x0 := row.position.x + (row.size.x - total) * 0.5
	var medal := Rect2()
	var text_x := x0
	if has_medal:
		if Lang.is_rtl():
			medal = Rect2(x0 + tw + RESULT_MEDAL_GAP, row.position.y, RESULT_ROW_H, RESULT_ROW_H)
		else:
			medal = Rect2(x0, row.position.y, RESULT_ROW_H, RESULT_ROW_H)
			text_x = x0 + RESULT_ROW_H + RESULT_MEDAL_GAP
	return {"medal": medal, "text": Rect2(text_x, row.position.y, tw, row.size.y)}


func _draw_place_row(f: Font, row: Rect2) -> void:
	var c: Node = App.client
	var parts := _place_row_layout(row)
	if parts.medal.size.x > 0.0:
		Medal.draw(self, parts.medal, c.final_medal)
	var text_rect: Rect2 = parts.text
	draw_string(f, Vector2(text_rect.position.x, UiTheme.centered_baseline(f, text_rect, LINE_SIZE)), c.final_place.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, text_rect.size.x + 8.0, LINE_SIZE, UiTheme.TEXT)


## The pause button: a 96 px square at the right end of the header row, 60 px from the right edge like the icon buttons of the
## waiting screen (REQ-FL-52c).
func _rect_pause() -> Rect2:
	return Rect2(size.x - 60.0 - PAUSE_SIZE, HEADER_Y - PAUSE_SIZE * 0.5, PAUSE_SIZE, PAUSE_SIZE)


const LINE_SIZE := 64   # The place and the score under the header (REQ-FL-67): never smaller, two lines when long (#288).
const NAME_SIZE := 48   # The name in the header: never smaller, a wide name goes on two lines (#246).
const LOST_SIZE := 56   # RECONNECTING... on the dimmed pad.
const LOST_DIM := 0.62  # How dark the play area (the buttons) gets when the link is lost.
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


## The color of that square: the slot color, also when the link to the TV is lost (owner, 2026-11-10: no red, issue #433).
func _slot_square_color() -> Color:
	return App.client.color


## The fill of the Recenter box: black like every enabled button (REQ-FL-38a); white for a moment after a tap (REQ-FL-52).
func _recenter_fill() -> Color:
	return UiTheme.BUTTON_TEXT if _flash.recenter > 0.0 else UiTheme.BUTTON_FACE


## The middle of the face of the arcade button `bit` at `center`: it sits lower while the button is down.
func _button_face(center: Vector2, bit: int) -> Vector2:
	return center - Vector2(0, BUTTON_LIFT_DOWN if (_sampler.buttons & bit) != 0 else BUTTON_LIFT)


## The RECENTER button: small, in the middle, right above the HOLD TO DISCONNECT box (REQ-FL-52).
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


## The row of whose turn it is (REQ-BW-14).
func _rect_turn() -> Rect2:
	return Rect2(60, 376.0 + INFO_Y - 50.0, size.x - 120, 40)


## True while this phone is on turn in Bowling: the Recenter box becomes the aim strip (REQ-BW-4).
func _aim_mode() -> bool:
	var c: Node = App.client
	return not _result_shown() and c.state == ControllerClient.State.CONNECTED and c.turn_state == 1 and c.turn_kind == ""


## True while the pad has the Recenter box: in a game where the phone is a pointer (REQ-GM-37) and outside a game.
func _recenter_shown() -> bool:
	return App.client.recenter_button and not _result_shown()


## True while the pad shows the button `key` ("a" or "b"): the game says which buttons it uses (REQ-GM-37a, issue #80).
func _button_shown(key: String) -> bool:
	return not _result_shown() and App.client.pad_buttons.contains(key)


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
	if _result_shown():
		# Only the HOLD TO DISCONNECT box shows and works; the places of the other buttons are dead (REQ-FL-67a).
		return "leave" if _leave_shown() and _rect_leave().has_point(pos) else "pad"
	if _pause_shown() and _rect_pause().has_point(pos):
		return "pause"
	if _leave_shown() and _rect_leave().has_point(pos):
		return "leave"
	if _aim_mode() and _rect_aim().has_point(pos):
		return "aim"
	if _recenter_shown() and not _aim_mode() and _rect_recenter().has_point(pos):
		return "recenter"
	var button := _button_zone(pos)
	return button if button != "" else "pad"


## "a" or "b" when `pos` is on that round button, else "".
func _button_zone(pos: Vector2) -> String:
	if _button_shown("a") and pos.distance_to(_center_a()) <= _radius() * 1.25:
		return "a"
	if _button_shown("b") and pos.distance_to(_center_b()) <= _radius() * 1.25:
		return "b"
	return ""


# ---- Input ----

## Back during play asks the TV to pause and ask "End the game?", as the pause button does (REQ-FL-52c). In every other state it
## asks whether to quit the app (REQ-FL-55); Back again answers "stay". The pad ignores touches while the question shows.
func on_back() -> void:
	if is_instance_valid(_quit_dialog):
		_quit_dialog.close()
		return
	if _pause_shown():
		App.client.send_leave_ask()
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
		"pause":
			App.client.send_leave_ask()
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

func _draw() -> void:
	var f := UiTheme.font()
	var c: Node = App.client
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)

	# The slot color square with the slot number, and the state word (RECONNECTING... when the link is lost).
	var online: bool = c.state == ControllerClient.State.CONNECTED
	var square := _rect_slot_square()
	var square_color: Color = _slot_square_color()
	draw_rect(square, square_color)
	UiTheme.draw_centered(self, f, str(c.slot + 1), square, 56, UiTheme.text_on(square_color))
	# The avatar is next to the color square, not on it (REQ-FL-70).
	var shown: int = c.tv_avatar if c.tv_pid != "" else Avatar.GUEST   # A guest has its own picture (owner, 2026-11-11).
	var has_avatar: bool = Avatar.is_known(shown)
	if has_avatar:
		var av := Rect2(Vector2(square.end.x + 10.0, square.position.y), square.size)
		draw_style_box(UiTheme.line_box(UiTheme.TEXT_DIM, UiTheme.BG, 4), av)
		Avatar.draw(self, av.grow(-5.0), shown)
	var own: String = c.tv_player_name if c.tv_pid != "" else "%dP" % (c.slot + 1)
	var status := own if online else Lang.t("connect.reconnecting")
	var name_rect := _rect_name(has_avatar)
	_draw_lines_centered(f, name_lines(status.to_upper(), name_rect.size.x), name_rect, NAME_SIZE, HORIZONTAL_ALIGNMENT_LEFT,
			name_rect.position.x, UiTheme.ACCENT)

	# The place and the score of this player, on a row of their own under the header (REQ-FL-67).
	var line := score_line(c.score_rank, c.score_of, c.score_text) if online and not _result_shown() else ""
	if line != "":
		var line_rect := _rect_score()
		_draw_lines_centered(f, score_lines(line, line_rect.size.x), line_rect, LINE_SIZE, HORIZONTAL_ALIGNMENT_LEFT,
				line_rect.position.x, UiTheme.TEXT, SCORE_GROWS_DOWN)

	# Whose turn it is, in a game with turns, (it is not drawn while the result shows).
	if online and c.turn_state != 0 and not _result_shown():
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

	if _pause_shown():
		_draw_pause(_rect_pause())

	# The result of the game (REQ-FL-67a): the block of three lines in the middle, and only the HOLD TO DISCONNECT box below.
	# An older TV sends one line, shown as before.
	if _result_shown():
		if _final_structured():
			var block := _final_block()
			if not block.game_lines.is_empty():
				_draw_block_lines(f, block.game_lines, block.game, GAME_SIZE, UiTheme.TEXT_DESC)
			_draw_place_row(f, block.row)
			_draw_block_lines(f, block.line3_lines, block.line3, LINE_SIZE, UiTheme.ACCENT if block.best else UiTheme.TEXT)
		else:
			var final_rect := _rect_final()
			_draw_lines_centered(f, final_lines(c.final_text, final_rect.size.x), final_rect, LINE_SIZE,
					HORIZONTAL_ALIGNMENT_CENTER, final_rect.position.x, UiTheme.TEXT)

	# Disconnect: a framed text box. A game needs a press of LEAVE_HOLD seconds; the box fills while the finger stays (REQ-FL-52a).
	var lr := _rect_leave()
	leave_drawn = _leave_shown()
	if leave_drawn:
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

	# The link is lost: the buttons and the Recenter box are dimmed, a thin yellow frame and RECONNECTING... on top (REQ-FL-52b).
	if not online:
		_draw_lost_link(f)


## The link is lost (REQ-FL-52b; softer since 2026-11-10, owner, issue #433): the play area with the buttons is dimmed (the
## header and the HOLD TO DISCONNECT box are not), a thin yellow frame runs around the pad and RECONNECTING... is written in the
## middle in yellow. The cue is not only a color: the buttons go dark, and the frame and the words show; the buzz is in
## `_on_state`.
func _draw_lost_link(f: Font) -> void:
	var top := HEADER_Y + 60.0
	var bottom := _rect_leave().position.y
	draw_rect(Rect2(0, top, size.x, bottom - top), Color(UiTheme.BG, LOST_DIM))
	var fw := LOST_FRAME
	draw_rect(Rect2(0, 0, size.x, fw), UiTheme.ACCENT)
	draw_rect(Rect2(0, size.y - fw, size.x, fw), UiTheme.ACCENT)
	draw_rect(Rect2(0, 0, fw, size.y), UiTheme.ACCENT)
	draw_rect(Rect2(size.x - fw, 0, fw, size.y), UiTheme.ACCENT)
	var mid := Rect2(60, size.y * 0.5 - 40.0, size.x - 120, 80)
	var msg := Lang.t("connect.reconnecting").to_upper()
	_draw_lines_centered(f, UiTheme.wrap_lines(f, msg, mid.size.x, LOST_SIZE), mid, LOST_SIZE, HORIZONTAL_ALIGNMENT_CENTER,
			mid.position.x, UiTheme.ACCENT)


## The pause button: the frame and the black fill of the icon buttons, and the two white bars of a pause symbol (REQ-FL-52c).
func _draw_pause(r: Rect2) -> void:
	draw_style_box(UiTheme.line_box(UiTheme.TEXT, UiTheme.BUTTON_FACE), r)
	var mid := r.get_center()
	for dx in [-(PAUSE_BAR_GAP + PAUSE_BAR_W) * 0.5, (PAUSE_BAR_GAP + PAUSE_BAR_W) * 0.5]:
		draw_rect(Rect2(mid.x + dx - PAUSE_BAR_W * 0.5, mid.y - PAUSE_BAR_H * 0.5, PAUSE_BAR_W, PAUSE_BAR_H), UiTheme.BUTTON_TEXT)


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
