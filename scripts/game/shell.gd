extends RefCounted
## The game shell (docs/GAME_REQUIREMENTS.md, REQ-GM-45): shared drawing for titles, score chips,
## the countdown and hints, in the arcade style (docs/TV_FLOW.md, FD-18). Games call these instead of drawing their own.
## The pause menu, the result screen and the "waiting for players" card are in minigame.gd.
## All positions are for a 1920x1080 screen. `ci` is the CanvasItem to draw on. All text is upper case, in the arcade font,
## in sizes of the 8 px grid.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const CHIP_FONT := 32          # The size of the text on a chip.
const CHIP_PAD := 16.0         # The space between the chip edge and its content.
const CHIP_SQUARE := 24.0      # The slot color square of a chip.
const CHIP_LINE := 4           # The frame of a chip.


## Game title: yellow, in the arcade font.
static func title(ci: CanvasItem, text: String, pos := Vector2(60, 96), font_size := 32) -> void:
	ci.draw_string(UiTheme.font(), pos, text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.ACCENT)


## Text in the arcade font (upper case).
static func text(ci: CanvasItem, pos: Vector2, msg: String, font_size := 32, color: Color = UiTheme.TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	ci.draw_string(UiTheme.font(), pos, msg.to_upper(), align, width, font_size, color)


## A name or score chip (REQ-GM-46): a black box with a 4 px frame, a square in the player color, and the text in the text
## color. The text never sits on the player color. `pos` is the top-left corner.
static func chip(ci: CanvasItem, pos: Vector2, msg: String, color: Color, width := 240.0, height := 64.0) -> Rect2:
	var r := Rect2(pos, Vector2(width, height))
	ci.draw_style_box(UiTheme.line_box(UiTheme.TEXT, UiTheme.BG, CHIP_LINE), r)
	ci.draw_rect(Rect2(pos + Vector2(CHIP_PAD, (height - CHIP_SQUARE) * 0.5), Vector2(CHIP_SQUARE, CHIP_SQUARE)), color)
	var x0 := name_x()
	var base := UiTheme.centered_baseline(UiTheme.font(), Rect2(0, 0, 0, height), CHIP_FONT)
	ci.draw_string(UiTheme.font(), pos + Vector2(x0, base), fit_text(msg.to_upper(), width - x0 - CHIP_PAD, CHIP_FONT),
			HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT, UiTheme.TEXT)
	return r


## A chip with a name and a score (REQ-GM-46). Nothing is cut: `width` comes from `score_chip_width()`.
static func score_chip(ci: CanvasItem, pos: Vector2, player_name: String, score: String, color: Color, width := 250.0,
		height := 64.0) -> Rect2:
	var r := chip(ci, pos, "", color, width, height)
	var parts := score_chip_parts(player_name, score, width, height)
	var base := UiTheme.centered_baseline(UiTheme.font(), Rect2(0, 0, 0, height), CHIP_FONT)
	ci.draw_string(UiTheme.font(), pos + Vector2(parts.name_x, base), String(parts.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1,
			CHIP_FONT, UiTheme.TEXT)
	ci.draw_string(UiTheme.font(), pos + Vector2(parts.score_x, base), score.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT,
			UiTheme.TEXT)
	return r


## The x of the text on a chip: after the square.
static func name_x() -> float:
	return CHIP_PAD + CHIP_SQUARE + CHIP_PAD


## The width of a score chip for this name and score: the whole content, at least `min_w`. The name is never cut.
static func score_chip_width(player_name: String, score: String, _height := 64.0, min_w := 200.0,
		font_size := CHIP_FONT) -> float:
	var f := UiTheme.font()
	var content := name_x() + f.get_string_size(player_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0 \
			+ f.get_string_size(score.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + CHIP_PAD
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
## The score ends at the right edge of the chip, inside the padding.
static func score_chip_parts(player_name: String, score: String, width: float, _height: float,
		font_size := CHIP_FONT) -> Dictionary:
	var right := width - CHIP_PAD
	var score_w := UiTheme.font().get_string_size(score.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return {"name": player_name, "name_x": name_x(),
			"score_x": right - score_w, "score_w": score_w}


## `text` shortened with "..." (one character) so that it is at most `max_w` px wide. A short text stays as it is.
static func fit_text(text: String, max_w: float, font_size := CHIP_FONT) -> String:
	var f := UiTheme.font()
	if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_w:
		return text
	var cut := text
	while not cut.is_empty() and f.get_string_size(cut + "\u2026", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w:
		cut = cut.substr(0, cut.length() - 1)
	if cut.is_empty() and f.get_string_size("\u2026", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w:
		return ""
	return cut + "\u2026"


## A player ball: a dark outline, the player color, and the slot number in the text color of most contrast, so that players do
## not depend on the color alone. `pos` is the center. The outline is 6 px for a ball of 40 px or more and 4 px for a smaller one.
static func ball(ci: CanvasItem, pos: Vector2, radius: float, color: Color, slot: int) -> void:
	var m := ball_metrics(radius)
	ci.draw_circle(pos, radius + m.outline, UiTheme.OUTLINE)
	ci.draw_circle(pos, radius, color)
	UiTheme.draw_centered(ci, UiTheme.font(), str(slot + 1), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			m.font_size, UiTheme.text_on(color))


## The sizes `ball()` draws with, for a ball of `radius` (a test checks them): the outline width (REQ-GM-47b) and the size of
## the slot number, a multiple of 8 (the font grid).
static func ball_metrics(radius: float) -> Dictionary:
	return {"outline": 6.0 if radius * 2.0 >= 40.0 else 4.0, "font_size": maxi(8, roundi(radius / 8.0) * 8)}


## One world pixel in 1920x1080 units: the world view is 480x270 (REQ-GM-47a, `Minigame.PIXEL_VIEW`).
const WORLD_PIXEL := 4.0


## `v` moved to the grid of world pixels, so that a shape does not shimmer between two pixels while it moves.
static func snap(v: Vector2) -> Vector2:
	return (v / WORLD_PIXEL).round() * WORLD_PIXEL


## A player ball in a pixel world (REQ-GM-47b): a black outline of one world pixel and a flat fill. It draws on the low-resolution
## layer, so it has no number: `ball_number()` draws that on the HUD at full resolution (REQ-GM-46).
static func pixel_ball(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	var c := snap(pos)
	ci.draw_circle(c, radius + WORLD_PIXEL, UiTheme.OUTLINE)
	ci.draw_circle(c, radius, color)


## The slot number of a ball, at full resolution, for a ball that is drawn in a pixel world.
static func ball_number(ci: CanvasItem, pos: Vector2, radius: float, color: Color, slot: int) -> void:
	UiTheme.draw_centered(ci, UiTheme.font(), str(slot + 1), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			ball_metrics(radius).font_size, UiTheme.text_on(color))


## The players (PlayerInput objects) in slot order, P1 first (REQ-GM-46).
static func in_slot_order(players: Array) -> Array:
	var ordered := players.duplicate()
	ordered.sort_custom(func(a, b) -> bool: return a.slot < b.slot)
	return ordered


## One chip for each player, P1 first (REQ-GM-46). The one place that draws the name chips of the games: a game only gives the
## score of each slot in `scores` (slot -> text; a slot without a text has a name chip only) and calls this every frame.
## `area_w` is the width of the screen. The chips end at the right 60 px margin. Each chip is as wide as its content, so no name
## or score is cut. A row is at most `max_row` px wide (0 means the screen inside the margins), and the rest goes to a second row.
static func player_chips(ci: CanvasItem, area_w: float, players: Array, scores := {}, max_row := 0.0, y := 36.0) -> void:
	var ordered := in_slot_order(players)
	var texts: Array[String] = []
	var widths: Array = []
	for p in ordered:
		texts.append(String(scores.get(p.slot, "")))
		widths.append(score_chip_width(p.player_name, texts[-1]))
	var spots := chip_row_positions(area_w, widths, y, 10.0, max_row)
	for i in ordered.size():
		score_chip(ci, spots[i], ordered[i].player_name, texts[i], ordered[i].color, widths[i])


## The race timer: a black box with a frame, in a fixed place. `pos` is the top-left corner.
static func timer(ci: CanvasItem, pos: Vector2, seconds: float, width := 240.0) -> Rect2:
	var r := Rect2(pos, Vector2(width, 64.0))
	ci.draw_style_box(UiTheme.line_box(UiTheme.TEXT, UiTheme.BG, CHIP_LINE), r)
	UiTheme.draw_centered(ci, UiTheme.font(), "%.1f S" % seconds, r, CHIP_FONT, UiTheme.TEXT)
	return r


## Contrast ratio of two colors (WCAG). Tests use it to check the text on the chips.
static func contrast(a: Color, b: Color) -> float:
	return UiTheme.contrast(a, b)


## The countdown. `label` is "3", "2", "1" or "GO". `elapsed` is 0 to 1 inside the current number:
## the number is big and settles in 4 steps (REQ-FL-42), in sizes of the 8 px grid.
static func countdown(ci: CanvasItem, area: Vector2, label: String, elapsed := 1.0, color: Color = UiTheme.ACCENT) -> void:
	var fs := countdown_size(elapsed)
	var rect := Rect2(Vector2.ZERO, area)
	ci.draw_string(UiTheme.font(), Vector2(0.0, UiTheme.centered_baseline(UiTheme.font(), rect, fs)), label.to_upper(),
			HORIZONTAL_ALIGNMENT_CENTER, area.x, fs, color)


## The font size of the countdown number `elapsed` (0 to 1) into its second: 352, 320, 288, then 256 px.
static func countdown_size(elapsed: float) -> int:
	var step := clampi(floori(clampf(elapsed * 2.5, 0.0, 1.0) * 4.0), 0, 3)
	return UiTheme.SIZE_COUNTDOWN + (3 - step) * 32


## A hint line at the bottom of the screen, on a black plate with a frame so that game graphics behind it (for example a
## wall) never make it hard to read. A long hint wraps to more lines; none of it is cut.
static func hint(ci: CanvasItem, area: Vector2, msg: String) -> void:
	var f := UiTheme.font()
	var max_w := area.x - 240.0
	var upper := msg.to_upper()
	var box := f.get_multiline_string_size(upper, HORIZONTAL_ALIGNMENT_LEFT, max_w, UiTheme.SIZE_BODY)
	var w := box.x + 64.0
	var h := box.y + 40.0
	var plate := Rect2((area.x - w) * 0.5, area.y - 36.0 - h, w, h)
	ci.draw_style_box(UiTheme.line_box(UiTheme.TEXT_DIM, UiTheme.BG, CHIP_LINE), plate)
	ci.draw_multiline_string(f, Vector2(plate.position.x, plate.position.y + 20.0 + f.get_ascent(UiTheme.SIZE_BODY)), upper,
			HORIZONTAL_ALIGNMENT_CENTER, w, UiTheme.SIZE_BODY, -1, UiTheme.TEXT)
