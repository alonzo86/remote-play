extends RefCounted
## The game shell (docs/GAME_REQUIREMENTS.md, REQ-GM-45): shared drawing for titles, score chips,
## the countdown and hints, in the Party Pop style. Games call these instead of drawing their own.
## The pause menu, the result screen and the "waiting for players" card are in minigame.gd.
## All positions are for a 1920x1080 screen. `ci` is the CanvasItem to draw on.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")


## Game title in the display font. Yellow with a dark outline.
static func title(ci: CanvasItem, text: String, pos := Vector2(60, 96), font_size := 60) -> void:
	var f := UiTheme.title_font()
	ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 12, UiTheme.OUTLINE)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.ACCENT)


## Text with a dark outline. It stays readable on any background.
static func text(ci: CanvasItem, pos: Vector2, msg: String, font_size := 32, color: Color = UiTheme.TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := UiTheme.body_bold()
	ci.draw_string_outline(f, pos, msg, align, width, font_size, _outline_for(font_size), UiTheme.OUTLINE)
	ci.draw_string(f, pos, msg, align, width, font_size, color)


## A score or name chip (REQ-GM-46): a white pill with a dark outline, a dot in the player color,
## and dark text. White text on the light player colors (orange, teal) is hard to read (contrast
## below 4.5:1), so the text never sits on the player color. `pos` is the top-left corner.
static func chip(ci: CanvasItem, pos: Vector2, msg: String, color: Color, width := 240.0, height := 58.0) -> Rect2:
	var r := Rect2(pos, Vector2(width, height))
	ci.draw_style_box(UiTheme.card(UiTheme.CARD, UiTheme.OUTLINE, 5, int(height * 0.5), true), r)
	var c := pos + Vector2(height * 0.5, height * 0.5)
	ci.draw_circle(c, height * 0.33, UiTheme.OUTLINE)
	ci.draw_circle(c, height * 0.26, color)
	var fs := 30
	var x0 := height * 0.95
	ci.draw_string(UiTheme.body_bold(), pos + Vector2(x0, height * 0.5 + fs * 0.34), msg,
			HORIZONTAL_ALIGNMENT_LEFT, width - x0 - height * 0.3, fs, UiTheme.CARD_TEXT)
	return r


## A player ball (REQ-GM-46, 47a, 47b): a hard shadow, a dark outline, the player color, a small shine and the
## slot number in white, so that players do not depend on the color alone. `pos` is the center.
## The outline is 6 px for a ball of 40 px or more and 4 px for a smaller one.
static func ball(ci: CanvasItem, pos: Vector2, radius: float, color: Color, slot: int) -> void:
	var outline := 6.0 if radius * 2.0 >= 40.0 else 4.0
	ci.draw_circle(pos + UiTheme.SHADOW * 0.6, radius + outline, UiTheme.OUTLINE)
	ci.draw_circle(pos, radius + outline, UiTheme.OUTLINE)
	ci.draw_circle(pos, radius, color)
	ci.draw_circle(pos + Vector2(-0.333, -0.375) * radius, radius * 0.25, Color(1, 1, 1, 0.55))
	var f := UiTheme.title_font()
	var font_size := roundi(radius * 1.08)
	var base := pos + Vector2(-radius, radius * 0.375)
	ci.draw_string_outline(f, base, str(slot + 1), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, 8, UiTheme.OUTLINE)
	ci.draw_string(f, base, str(slot + 1), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color.WHITE)


## The players (PlayerInput objects) in slot order, P1 first (REQ-GM-46).
static func in_slot_order(players: Array) -> Array:
	var ordered := players.duplicate()
	ordered.sort_custom(func(a, b) -> bool: return a.slot < b.slot)
	return ordered


## One chip for each player in a row at the right edge of the screen, P1 first (REQ-GM-46).
## `area_w` is the width of the screen. `y` is the top of the chips.
static func player_chips(ci: CanvasItem, area_w: float, players: Array, y := 36.0, width := 250.0, step := 270.0) -> void:
	var ordered := in_slot_order(players)
	var x := area_w - 60.0 - step * ordered.size() + 20.0
	for p in ordered:
		chip(ci, Vector2(x, y), p.player_name, p.color, width)
		x += step


## The race timer: a pill with a dark outline, in a fixed place. `pos` is the top-left corner.
static func timer(ci: CanvasItem, pos: Vector2, seconds: float, width := 200.0) -> Rect2:
	var r := Rect2(pos, Vector2(width, 64.0))
	ci.draw_style_box(UiTheme.card(UiTheme.BG_DARK, UiTheme.OUTLINE, 5, 32, true), r)
	ci.draw_string(UiTheme.title_font(), pos + Vector2(0, 46.0), "%.1f s" % seconds, HORIZONTAL_ALIGNMENT_CENTER, width, 40,
			UiTheme.TEXT)
	return r


## Contrast ratio of two colors (WCAG). Tests use it to check the text on the chips.
static func contrast(a: Color, b: Color) -> float:
	return UiTheme.contrast(a, b)


## The countdown. `label` is "3", "2", "1" or "GO". `elapsed` is 0 to 1 inside the current number:
## the number pops in big and settles (REQ-FL-42).
static func countdown(ci: CanvasItem, area: Vector2, label: String, elapsed := 1.0, color: Color = UiTheme.ACCENT) -> void:
	var f := UiTheme.title_font()
	var fs := 240
	var s := 1.0 + 0.45 * pow(1.0 - clampf(elapsed * 2.5, 0.0, 1.0), 2.0)
	var c := Vector2(area.x * 0.5, area.y * 0.5)
	ci.draw_set_transform(c, 0.0, Vector2(s, s))
	var base := Vector2(-area.x * 0.5, fs * 0.35) # The transform is at the center of the area.
	ci.draw_string_outline(f, base, label, HORIZONTAL_ALIGNMENT_CENTER, area.x, fs, 28, UiTheme.OUTLINE)
	ci.draw_string(f, base, label, HORIZONTAL_ALIGNMENT_CENTER, area.x, fs, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _outline_for(font_size: int) -> int:
	return clampi(int(font_size * 0.18), 4, 10)


## A hint line at the bottom of the screen, on a dark plate so that game graphics behind it
## (for example a wall) never make it hard to read.
static func hint(ci: CanvasItem, area: Vector2, msg: String) -> void:
	var w := UiTheme.body_bold().get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 64.0
	var plate := Rect2((area.x - w) * 0.5, area.y - 100.0, w, 64.0)
	ci.draw_style_box(UiTheme.card(UiTheme.BG_DARK, UiTheme.OUTLINE, 4, 32, false), plate)
	ci.draw_string(UiTheme.body_bold(), Vector2(plate.position.x, plate.position.y + 43.0), msg,
			HORIZONTAL_ALIGNMENT_CENTER, w, 30, UiTheme.TEXT)
