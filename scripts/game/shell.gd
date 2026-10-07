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


## A score or name chip in a player color (REQ-GM-46). `pos` is the top-left corner.
static func chip(ci: CanvasItem, pos: Vector2, msg: String, color: Color, width := 240.0, height := 58.0) -> Rect2:
	var r := Rect2(pos, Vector2(width, height))
	ci.draw_style_box(UiTheme.card(color, UiTheme.OUTLINE, 5, int(height * 0.5), true), r)
	var f := UiTheme.body_bold()
	var fs := 32
	var base := pos + Vector2(0, height * 0.5 + fs * 0.34)
	ci.draw_string_outline(f, base, msg, HORIZONTAL_ALIGNMENT_CENTER, width, fs, 5, UiTheme.OUTLINE)
	ci.draw_string(f, base, msg, HORIZONTAL_ALIGNMENT_CENTER, width, fs, Color.WHITE)
	return r


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


## A hint line at the bottom of the screen.
static func hint(ci: CanvasItem, area: Vector2, msg: String) -> void:
	text(ci, Vector2(0, area.y - 56), msg, 30, UiTheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, area.x)
