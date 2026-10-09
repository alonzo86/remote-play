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
	ci.draw_string(UiTheme.body_bold(), pos + Vector2(x0, height * 0.5 + fs * 0.34),
			fit_text(msg, width - x0 - height * 0.3, fs), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.CARD_TEXT)
	return r


## A chip with a name and a score (REQ-GM-46). Nothing is cut: `width` comes from `score_chip_width()`. `pos` is the top-left corner.
static func score_chip(ci: CanvasItem, pos: Vector2, player_name: String, score: String, color: Color, width := 250.0,
		height := 58.0) -> Rect2:
	var r := chip(ci, pos, "", color, width, height)
	var parts := score_chip_parts(player_name, score, width, height)
	var base := height * 0.5 + 30 * 0.34
	ci.draw_string(UiTheme.body_bold(), pos + Vector2(parts.name_x, base), parts.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
			UiTheme.CARD_TEXT)
	ci.draw_string(UiTheme.body_bold(), pos + Vector2(parts.score_x, base), score, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
			UiTheme.CARD_TEXT)
	return r


## The width of a score chip for this name and score: the whole content, at least `min_w`. The name is never cut.
static func score_chip_width(player_name: String, score: String, height := 58.0, min_w := 200.0, font_size := 30) -> float:
	var f := UiTheme.body_bold()
	var content := height * 0.95 + f.get_string_size(player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 14.0 \
			+ f.get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + height * 0.3
	return maxf(content, min_w)


## The top-left corners of chips of the widths `widths`, in order, from the left to the right. The last chip of a row ends at the
## 60 px safe margin (REQ-GM-40). `area_w` is the width of the screen. A row is at most `max_row` px wide (`area_w` minus the
## 60 px margin when 0): the chips that do not fit go to a new row below, so no name is cut.
static func chip_row_positions(area_w: float, widths: Array, y := 36.0, gap := 10.0, max_row := 0.0,
		row_h := 68.0) -> Array[Vector2]:
	var limit := max_row if max_row > 0.0 else area_w - 120.0
	var rows: Array = [[]]
	var used := 0.0
	for i in widths.size():
		var w := float(widths[i])
		if not rows[-1].is_empty() and used + gap + w > limit:
			rows.append([])
			used = 0.0
		used += w + (gap if not rows[-1].is_empty() else 0.0)
		rows[-1].append(i)
	var out: Array[Vector2] = []
	out.resize(widths.size())
	for r in rows.size():
		var total := gap * maxf(rows[r].size() - 1, 0)
		for i in rows[r]:
			total += float(widths[i])
		var x := area_w - 60.0 - total
		for i in rows[r]:
			out[i] = Vector2(x, y + r * row_h)
			x += float(widths[i]) + gap
	return out


## Where the parts of a score chip go (a test checks it): the name (whole), the x of the name and the x of the score.
## The score ends at the right edge of the chip, inside the rounded end.
static func score_chip_parts(player_name: String, score: String, width: float, height: float, font_size := 30) -> Dictionary:
	var name_x := height * 0.95
	var right := width - height * 0.3
	var score_w := UiTheme.body_bold().get_string_size(score, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return {"name": player_name, "name_x": name_x,
			"score_x": right - score_w, "score_w": score_w}


## `text` shortened with "..." (one character) so that it is at most `max_w` px wide. A short text stays as it is.
static func fit_text(text: String, max_w: float, font_size := 30) -> String:
	var f := UiTheme.body_bold()
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
		return text
	var cut := text
	while not cut.is_empty() and f.get_string_size(cut + "\u2026", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w:
		cut = cut.substr(0, cut.length() - 1)
	if cut.is_empty() and f.get_string_size("\u2026", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w:
		return ""
	return cut + "\u2026"


## A player ball (REQ-GM-46, 47a, 47b): a hard shadow, a dark outline, the player color, a small shine and the
## slot number in white, so that players do not depend on the color alone. `pos` is the center.
## The outline is 6 px for a ball of 40 px or more and 4 px for a smaller one.
static func ball(ci: CanvasItem, pos: Vector2, radius: float, color: Color, slot: int) -> void:
	var m := ball_metrics(radius)
	ci.draw_circle(pos + UiTheme.SHADOW * 0.6, radius + m.outline, UiTheme.OUTLINE)
	ci.draw_circle(pos, radius + m.outline, UiTheme.OUTLINE)
	ci.draw_circle(pos, radius, color)
	ci.draw_circle(pos + m.shine_offset, m.shine_radius, Color(1, 1, 1, 0.55))
	var f := UiTheme.title_font()
	var base: Vector2 = pos + Vector2(-radius, m.baseline)
	ci.draw_string_outline(f, base, str(slot + 1), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, m.font_size, 8, UiTheme.OUTLINE)
	ci.draw_string(f, base, str(slot + 1), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, m.font_size, Color.WHITE)


## The sizes `ball()` draws with, for a ball of `radius` (a test checks them): the outline width (REQ-GM-47b), the shine,
## the size of the slot number and the baseline of the number under the center.
static func ball_metrics(radius: float) -> Dictionary:
	return {"outline": 6.0 if radius * 2.0 >= 40.0 else 4.0, "shine_offset": Vector2(-0.333, -0.375) * radius,
			"shine_radius": radius * 0.25, "font_size": roundi(radius * 1.08), "baseline": radius * 0.375}


## The players (PlayerInput objects) in slot order, P1 first (REQ-GM-46).
static func in_slot_order(players: Array) -> Array:
	var ordered := players.duplicate()
	ordered.sort_custom(func(a, b) -> bool: return a.slot < b.slot)
	return ordered


## One chip for each player in a row at the right edge of the screen, P1 first (REQ-GM-46).
## `area_w` is the width of the screen. `y` is the top of the chips.
static func player_chips(ci: CanvasItem, area_w: float, players: Array, y := 36.0, width := 250.0, step := 270.0) -> void:
	var ordered := in_slot_order(players)
	var spots := chip_positions(area_w, ordered.size(), y, width, step)
	for i in ordered.size():
		chip(ci, spots[i], ordered[i].player_name, ordered[i].color, width)


## The top-left corner of each of `count` chips in a row. The last chip ends at the 60 px safe margin (REQ-GM-40).
static func chip_positions(area_w: float, count: int, y := 36.0, width := 250.0, step := 270.0) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var x := area_w - 60.0 - width - step * (count - 1)
	for i in count:
		out.append(Vector2(x + step * i, y))
	return out


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
