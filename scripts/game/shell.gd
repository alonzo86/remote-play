extends RefCounted
## The game shell (docs/GAME_REQUIREMENTS.md, REQ-GM-45): shared drawing for titles, score chips,
## the countdown and hints, in the arcade style (docs/TV_FLOW.md, FD-18). Games call these instead of drawing their own.
## The pause menu, the result screen and the "waiting for players" card are in minigame.gd.
## All positions are for a 1920x1080 screen. `ci` is the CanvasItem to draw on. All text is upper case, in the arcade font,
## in sizes of the 8 px grid. Texts go through `Lang.t()`; in Hebrew (right to left) the HUD is mirrored: the title is at the
## top right, the chips start at the left, the timer is at the left of the title (REQ-GM-47o). The game worlds are not mirrored.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")

const CHIP_FONT := 32          # The size of the text on a chip.
const CHIP_PAD := 16.0         # The space between the chip edge and its content.
const CHIP_SQUARE := 24.0      # The slot color square of a chip.
const CHIP_LINE := 4           # The frame of a chip.
const TAG_H := 56.0            # The height of a name tag in the countdown.
const TAG_GAP := 8.0           # The space between two name tags.


## The width of the screen a canvas item draws on (1920 for an item that has no size).
static func area_width(ci: CanvasItem) -> float:
	return (ci as Control).size.x if ci is Control else 1920.0


## The left edge of a box that is `w` wide and sits at `x` on a left to right screen, for the current language: the same `x`
## in English, the mirror image in Hebrew.
static func mx(ci: CanvasItem, x: float, w: float) -> float:
	return area_width(ci) - x - w if Lang.is_rtl() else x


## Game title: yellow, in the arcade font. At the top left, and at the top right in Hebrew.
static func title(ci: CanvasItem, text: String, pos := Vector2(60, 96), font_size := 32) -> void:
	var shown := Lang.t(text).to_upper()
	var w := UiTheme.font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ci.draw_string(UiTheme.font(), Vector2(mx(ci, pos.x, w), pos.y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			UiTheme.ACCENT)


## Text in the arcade font (upper case).
static func text(ci: CanvasItem, pos: Vector2, msg: String, font_size := 32, color: Color = UiTheme.TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	ci.draw_string(UiTheme.font(), pos, Lang.t(msg).to_upper(), align, width, font_size, color)


## `msg` in upper case, centered on `pos` (the start of the baseline is moved left by half the width of the text). Nothing is cut.
static func text_centered(ci: CanvasItem, pos: Vector2, msg: String, font_size := 32, color: Color = UiTheme.TEXT) -> void:
	var upper := Lang.t(msg).to_upper()
	var w := UiTheme.font().get_string_size(upper, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ci.draw_string(UiTheme.font(), pos - Vector2(w * 0.5, 0.0), upper, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## A name or score chip (REQ-GM-46): a black box with a 4 px frame, a square in the player color, and the text in the text
## color. The text never sits on the player color. `pos` is the top-left corner.
static func chip(ci: CanvasItem, pos: Vector2, msg: String, color: Color, width := 240.0, height := 64.0) -> Rect2:
	var r := Rect2(pos, Vector2(width, height))
	ci.draw_style_box(UiTheme.line_box(UiTheme.TEXT, UiTheme.BG, CHIP_LINE), r)
	var rtl := Lang.is_rtl()
	var square_x := width - CHIP_PAD - CHIP_SQUARE if rtl else CHIP_PAD
	ci.draw_rect(Rect2(pos + Vector2(square_x, (height - CHIP_SQUARE) * 0.5), Vector2(CHIP_SQUARE, CHIP_SQUARE)), color)
	var x0 := name_x()
	var base := UiTheme.centered_baseline(UiTheme.font(), Rect2(0, 0, 0, height), CHIP_FONT)
	var shown := fit_text(msg.to_upper(), width - x0 - CHIP_PAD, CHIP_FONT)
	var text_w := UiTheme.font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT).x
	var text_x := pos.x + (width - x0 - text_w if rtl else x0)
	ci.draw_string(UiTheme.font(), Vector2(text_x, pos.y + base), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT, UiTheme.TEXT)
	return r


## A chip with a name and a score (REQ-GM-46). Nothing is cut: `width` comes from `score_chip_width()`.
static func score_chip(ci: CanvasItem, pos: Vector2, player_name: String, score: String, color: Color, width := 250.0,
		height := 64.0) -> Rect2:
	var r := chip(ci, pos, "", color, width, height)
	var parts := score_chip_parts(player_name, score, width, height)
	var base := UiTheme.centered_baseline(UiTheme.font(), Rect2(0, 0, 0, height), CHIP_FONT)
	var name_w := UiTheme.font().get_string_size(String(parts.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT).x
	var name_x_now: float = width - parts.name_x - name_w if Lang.is_rtl() else parts.name_x   # The score sits at the other end.
	var score_x_now: float = width - parts.score_x - parts.score_w if Lang.is_rtl() else parts.score_x
	ci.draw_string(UiTheme.font(), pos + Vector2(name_x_now, base), String(parts.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1,
			CHIP_FONT, UiTheme.TEXT)
	ci.draw_string(UiTheme.font(), pos + Vector2(score_x_now, base), score.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT,
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


## The left edge of the leader chip: it ends at the 60 px safe margin (REQ-GM-40). In a right to left language it starts there.
static func leader_chip_x(area_w: float, width: float) -> float:
	return 60.0 if Lang.is_rtl() else area_w - 60.0 - width


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
static func ball(ci: CanvasItem, pos: Vector2, radius: float, color: Color, slot: int, avatar := -1) -> void:
	var m := ball_metrics(radius)
	ci.draw_circle(pos, radius + m.outline, UiTheme.OUTLINE)
	ci.draw_circle(pos, radius, color)
	mark(ci, pos, radius, color, slot, avatar)


## The sign of a player on its ball: the avatar when the player has one and the ball is large enough, else the slot number in the
## text color of most contrast (REQ-GM-46). `drop` moves it down by that share of the radius. Returns true for the avatar.
static func mark(ci: CanvasItem, pos: Vector2, radius: float, color: Color, slot: int, avatar := -1,
		drop := 0.0) -> bool:
	var center := pos + Vector2(0.0, radius * drop)
	if avatar >= 0 and radius >= AVATAR_MIN_RADIUS:
		var side := radius * 1.45
		if Avatar.draw(ci, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), avatar):
			return true
	UiTheme.draw_centered(ci, UiTheme.font(), str(slot + 1), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			ball_metrics(radius).font_size, UiTheme.text_on(color))
	return false


## The smallest ball that shows an avatar: a 16 px picture fits in a square of 1.45 radius from a radius of 11.
const AVATAR_MIN_RADIUS := 11.0


## The sizes `ball()` draws with, for a ball of `radius` (a test checks them): the outline width (REQ-GM-47b) and the size of
## the slot number, a multiple of 8 (the font grid).
static func ball_metrics(radius: float) -> Dictionary:
	return {"outline": 6.0 if radius * 2.0 >= 40.0 else 4.0, "font_size": maxi(8, roundi(radius / 8.0) * 8)}


## One world pixel in 1920x1080 units: the world view is 480x270 (REQ-GM-47a, `Minigame.PIXEL_VIEW`).
const WORLD_PIXEL := 4.0


## `v` moved to the grid of world pixels, so that a shape does not shimmer between two pixels while it moves.
static func snap(v: Vector2) -> Vector2:
	return (v / WORLD_PIXEL).round() * WORLD_PIXEL


## `count` star pixels on the world pixel grid of a screen of `area` units, always in the same places for the same `seed_value`.
## Every third star is blue, the others dark gray (`draw_stars()`).
static func star_field(count: int, seed_value: int, area := Vector2(1920.0, 1080.0)) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stars := PackedVector2Array()
	for i in count:
		stars.append(Vector2(rng.randi_range(0, int(area.x / WORLD_PIXEL) - 1), rng.randi_range(0, int(area.y / WORLD_PIXEL) - 1))
				* WORLD_PIXEL)
	return stars


## The star pixels of `star_field()` on a pixel layer: a black sky with dark gray and blue stars.
static func draw_stars(ci: CanvasItem, stars: PackedVector2Array) -> void:
	for i in stars.size():
		ci.draw_rect(Rect2(stars[i], Vector2.ONE * WORLD_PIXEL), UiTheme.FRAME if i % 3 == 0 else UiTheme.SLOT_EMPTY)


## A player ball in a pixel world (REQ-GM-47b): a black outline of one world pixel and a flat fill. It draws on the low-resolution
## layer, so it has no number: `ball_number()` draws that on the HUD at full resolution (REQ-GM-46).
static func pixel_ball(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	var c := snap(pos)
	ci.draw_circle(c, radius + WORLD_PIXEL, UiTheme.OUTLINE)
	ci.draw_circle(c, radius, color)


## The slot number of a ball, at full resolution, for a ball that is drawn in a pixel world. `drop` moves the number down by that
## share of the radius (`NUMBER_DROP` for a creature with eyes).
static func ball_number(ci: CanvasItem, pos: Vector2, radius: float, color: Color, slot: int, drop := 0.0,
		avatar := -1) -> void:
	mark(ci, pos, radius, color, slot, avatar, drop)


## The number of a creature sits lower than the middle, under the eyes of `pixel_eyes()`.
const NUMBER_DROP := 0.25


## Two square eyes for a creature in a pixel world: a black frame of 16 px, a white eye of 8 px and a pupil of 4 px that steps
## to the side the creature moves (`look` is its speed as a share of the speed limit).
static func pixel_eyes(ci: CanvasItem, center: Vector2, radius: float, look: Vector2) -> void:
	var step := look.limit_length(1.0).round()
	for sign_x in [-1.0, 1.0]:
		var e := snap(center + Vector2(sign_x * radius * 0.33, -radius * 0.55))
		ci.draw_rect(Rect2(e - Vector2(8, 8), Vector2(16, 16)), UiTheme.OUTLINE)
		ci.draw_rect(Rect2(e - Vector2(4, 4), Vector2(8, 8)), Color.WHITE)
		ci.draw_rect(Rect2(e - Vector2(2, 2) + step * 2.0, Vector2(4, 4)), UiTheme.OUTLINE)


## The one score chip of the HUD (REQ-GM-46): the leader of the round with the score. `leaders` are the PlayerInput objects with
## the best place: one player shows its name in its color, more than one shows "TIE" with a gray square. `score` is the text
## (it can be empty). The chip is as wide as its content, so no name is cut, and a 16 letter name still fits next to the
## timer. `area_w` is the width of the screen; the chip ends at the right 60 px margin (at the left margin in Hebrew).
static func leader_chip(ci: CanvasItem, area_w: float, leaders: Array, score: String, y := 36.0) -> void:
	if leaders.is_empty():
		return
	var tie := leaders.size() > 1
	var label := Lang.t("shell.tie") if tie else String(leaders[0].player_name)
	var w := score_chip_width(label, score)
	score_chip(ci, Vector2(leader_chip_x(area_w, w), y), label, score, UiTheme.TEXT_DIM if tie else leaders[0].color, w)


## The rectangles of the name tags that stand above the game objects in the countdown (REQ-GM-46a). `entries` are
## `{pos, name}` with `pos` the middle of the object on the screen; `radius` is how far the tag stands above it. A tag is as wide
## as its name, inside the 60 px margin, and a tag that would cover an earlier one moves down until it does not.
static func name_tag_rects(area: Vector2, entries: Array, radius := 48.0) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for e in entries:
		var w := name_x() + UiTheme.font().get_string_size(String(e.name).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1,
				CHIP_FONT).x + CHIP_PAD
		var r := Rect2(Vector2(clampf(e.pos.x - w * 0.5, 60.0, maxf(area.x - 60.0 - w, 60.0)),
				clampf(e.pos.y - radius - TAG_H, 60.0, area.y - 60.0 - TAG_H)), Vector2(w, TAG_H))
		for _try in 8:
			var free := true
			for o in out:
				if o.intersects(r.grow(TAG_GAP)):
					free = false
					r.position.y += TAG_H + TAG_GAP
					break
			if free:
				break
		out.append(r)
	return out


## Name tags (REQ-GM-46a): each player's name next to its object, in the countdown only, so that nobody has to read a list.
## `entries` are `{pos, name, color}` (see `name_tag_rects()`).
static func name_tags(ci: CanvasItem, area: Vector2, entries: Array, radius := 48.0) -> void:
	var rects := name_tag_rects(area, entries, radius)
	for i in entries.size():
		chip(ci, rects[i].position, String(entries[i].name), entries[i].color, rects[i].size.x, TAG_H)


## The race timer: a black box with a frame, in a fixed place. `pos` is the top-left corner.
static func timer(ci: CanvasItem, pos: Vector2, seconds: float, width := 240.0) -> Rect2:
	var r := Rect2(Vector2(mx(ci, pos.x, width), pos.y), Vector2(width, 64.0))
	ci.draw_style_box(UiTheme.line_box(UiTheme.TEXT, UiTheme.BG, CHIP_LINE), r)
	UiTheme.draw_centered(ci, UiTheme.font(), Lang.f("shell.seconds", [seconds]).to_upper(), r, CHIP_FONT, UiTheme.TEXT)
	return r


## Contrast ratio of two colors (WCAG). Tests use it to check the text on the chips.
static func contrast(a: Color, b: Color) -> float:
	return UiTheme.contrast(a, b)


## The countdown. `label` is "3", "2", "1" or "GO". `elapsed` is 0 to 1 inside the current number:
## the number is big and settles in 4 steps (REQ-FL-42), in sizes of the 8 px grid.
static func countdown(ci: CanvasItem, area: Vector2, label: String, elapsed := 1.0, color: Color = UiTheme.ACCENT) -> void:
	var fs := countdown_size(elapsed)
	var rect := Rect2(Vector2.ZERO, area)
	ci.draw_string(UiTheme.font(), Vector2(0.0, UiTheme.centered_baseline(UiTheme.font(), rect, fs)), Lang.t(label).to_upper(),
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
	var upper := Lang.t(msg).to_upper()
	var box := f.get_multiline_string_size(upper, HORIZONTAL_ALIGNMENT_LEFT, max_w, UiTheme.SIZE_BODY)
	var w := box.x + 64.0
	var h := box.y + 40.0
	var plate := Rect2((area.x - w) * 0.5, area.y - 36.0 - h, w, h)
	ci.draw_style_box(UiTheme.line_box(UiTheme.TEXT_DIM, UiTheme.BG, CHIP_LINE), plate)
	ci.draw_multiline_string(f, Vector2(plate.position.x, plate.position.y + 20.0 + f.get_ascent(UiTheme.SIZE_BODY)), upper,
			HORIZONTAL_ALIGNMENT_CENTER, w, UiTheme.SIZE_BODY, -1, UiTheme.TEXT)
