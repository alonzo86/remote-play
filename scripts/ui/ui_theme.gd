extends RefCounted
## Arcade theme (docs/TV_FLOW.md, FD-18): "8-bit cabinet". A black screen, a small fixed palette from the NES palette,
## one blocky pixel font, double frames, square corners, text menus with a pixel cursor. Sizes are for 1920x1080.
## The font files are in assets/fonts. Game colors that are not in this file belong to the game (REQ-GM-48).

const BG := Color("000000")          # Every screen background.
const TEXT := Color("fcfcfc")        # Text and the outer frame line.
const TEXT_INFO := Color("b0b0b0")   # Active info text: hints, ranges, WAIT, help (#221).
const TEXT_DIM := Color("7c7c7c")    # A disabled item only; never enabled text (#221).
const ACCENT := Color("f8b800")      # Titles, the room code, the focused item, PRESS OK.
const FRAME := Color("0058f8")       # The inner frame line (not text).
const OK := Color("00b800")          # READY, good.
const BAD := Color("f83800")         # LOST, errors, danger.
const DISABLED := TEXT_DIM           # A disabled item: dim text, no cursor.
const SLOT_EMPTY := Color("3c3c3c")  # A square of an empty slot (not text).
const CONFETTI: Array[Color] = [ACCENT, OK, FRAME]

# Names the games use until their own restyle (phases 2 to 4). They point to the arcade colors.
const BG_DARK := BG
const OUTLINE := BG                  # The dark outline of a game object.
const CARD := BG
const CARD_TEXT := TEXT
const CARD_DIM := TEXT_INFO
const CARD_MUTED := TEXT_INFO
const SELECTED := ACCENT             # The chosen value in the settings view (REQ-GM-97).
const FOCUS_BORDER := ACCENT
const BAD_TEXT := BAD
const DANGER := BAD

# A button that is not disabled is white (issue #173, REQ-FL-38a): a white face, black text, a white edge.
const BUTTON_FACE := TEXT            # The face of every enabled button (phone and TV).
const BUTTON_TEXT := BG              # The text on that face: 20:1 on white.
const BUTTON_EDGE := Color("a4a4a4") # The darker lower edge of the round A and B buttons.
const MARK_W := 12                   # The border of a marked button (the focus, the chosen one): twice the normal line.

const LINE := 6                      # The width of a frame line in pixels at 1920x1080 (REQ-FL-38).
const OUTLINE_W := LINE
# There are no shadows and no round corners (REQ-FL-38).

const FONT_FILE := "res://assets/fonts/PressStart2P-Regular.ttf"
const FONT_HEBREW := "res://assets/fonts/SababiPixelHebrew.ttf"

# Text sizes on the TV (REQ-FL-40): the font is an 8 px grid, so every size is a multiple of 8.
const SIZE_BODY := 32
const SIZE_ITEM := 40
const SIZE_TITLE := 64
const SIZE_LOGO := 96
const SIZE_COUNTDOWN := 256

const BLINK_S := 0.55                # A prompt is on for 0.55 s and off for 0.55 s (a hard step, REQ-FL-42).
const CURSOR_UNIT := 5.0             # One pixel of the cursor on the TV. The cursor is 4 pixels wide and 7 high.

static var _font: Font


## The one font: Press Start 2P, with the project Hebrew pixel font as its fallback for Hebrew names.
static func font() -> Font:
	if _font == null:
		_font = _load_font()
	return _font


static func _load_font() -> Font:
	if not ResourceLoader.exists(FONT_FILE):
		return ThemeDB.fallback_font
	var base := load(FONT_FILE) as Font
	if base == null:
		return ThemeDB.fallback_font
	if ResourceLoader.exists(FONT_HEBREW):
		var hebrew := load(FONT_HEBREW) as Font
		if hebrew != null:
			var chain: Array[Font] = [hebrew]
			base.fallbacks = chain
	return base


## A panel: the double frame (REQ-FL-38). `padding` is the space inside the frame.
static func frame(padding := 24, fill: Color = BG) -> StyleBox:
	return (load("res://scripts/ui/arcade_frame.gd") as GDScript).new().setup(LINE, padding, fill, TEXT, FRAME)


## A single frame line around a box (a game tile, a header box, a phone box). Square corners.
static func line_box(color: Color, fill: Color = BG, width := LINE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_border_width_all(width)
	s.border_color = color
	s.set_content_margin_all(float(width + 8))
	return s


## The box of a button in one state ("normal", "hover", "focus", "pressed" or "disabled"). Enabled: a white face with black
## text (`BUTTON_FACE`, `BUTTON_TEXT`). `marked` (the chosen IN or OUT, the active player) is a yellow border twice as thick,
## so the mark is a shape and a color and the face stays white. The focus (the TV remote, a keyboard) is different: a yellow
## face with black text (11.8:1) and the same thick border, so a focused button is never taken for a marked one.
## Pressed is the reverse (black face, white text). Disabled keeps its dim look (a dim line on black).
static func button_box(state: String, marked := false) -> StyleBoxFlat:
	match state:
		"disabled":
			return _same_margins(line_box(TEXT_DIM))
		"pressed":
			return _same_margins(line_box(TEXT, BG))
		"focus":
			return _same_margins(line_box(ACCENT, ACCENT, MARK_W))
		_:
			var edge := ACCENT if marked else BUTTON_FACE
			return _same_margins(line_box(edge, BUTTON_FACE, MARK_W if marked else LINE))


## A button keeps one size in every state: the content margin does not follow the border width, so a focus or a mark never
## moves its neighbors.
static func _same_margins(s: StyleBoxFlat) -> StyleBoxFlat:
	s.set_content_margin_all(float(LINE + 8))
	return s


## The text color of a button in a state (see `button_box`).
static func button_text(state: String) -> Color:
	match state:
		"disabled":
			return DISABLED
		"pressed":
			return TEXT
		_:   # Normal, hover and focus (the yellow face) have black text.
			return BUTTON_TEXT


## Gives a Button the white look in every state. `marked`: see `button_box`.
static func style_button(b: Button, marked := false) -> void:
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, button_box(st, marked))
	var colors := {"font_color": "normal", "font_hover_color": "hover", "font_focus_color": "focus",
			"font_pressed_color": "pressed", "font_disabled_color": "disabled"}
	for c in colors:
		b.add_theme_color_override(c, button_text(colors[c]))


## A flat box with a border for the games (their boards and platforms). The corners stay square and there is no shadow:
## `radius` and `shadow` stay in the signature so the games keep working until they are restyled.
static func card(fill: Color = CARD, border: Color = OUTLINE, border_w := OUTLINE_W, _radius := 0,
		_shadow := false) -> StyleBoxFlat:
	var s := line_box(border, fill, border_w)
	s.content_margin_left = 32
	s.content_margin_right = 32
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


## Contrast ratio of two colors (WCAG).
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var f := func(x: float) -> float: return x / 12.92 if x <= 0.03928 else pow((x + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


## The text color for a label on a fill (a slot number on a slot color): the black screen color or the white text color,
## whichever has more contrast.
static func text_on(fill: Color) -> Color:
	return TEXT if contrast(TEXT, fill) >= contrast(BG, fill) else BG


## Settings of one kind of menu item: the colors of the label for each state, and the room for the cursor.
static func _item_type(t: Theme, type: String, normal: Color, focus: Color) -> void:
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		t.set_color(c, type, normal)
	t.set_color("font_focus_color", type, focus)
	t.set_color("font_hover_pressed_color", type, focus)
	t.set_color("font_disabled_color", type, DISABLED)
	var s := StyleBoxEmpty.new()
	s.content_margin_left = CURSOR_UNIT * 4.0 + 24.0
	s.content_margin_right = 16.0   # `MenuItem` swaps the two margins in a right to left layout.
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		t.set_stylebox(st, type, s)


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = SIZE_BODY
	t.set_font("font", "Label", font())
	t.set_font_size("font_size", "Label", SIZE_BODY)
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", font())
	t.set_font_size("font_size", "Button", SIZE_ITEM)
	# A menu item is text with a cursor. The focused item is yellow (REQ-FL-41). A destructive item is red when it has
	# the focus. A quiet item (Back) is dim until it has the focus.
	_item_type(t, "Button", TEXT, ACCENT)
	t.set_type_variation("DangerButton", "Button")
	_item_type(t, "DangerButton", TEXT, BAD)
	t.set_type_variation("QuietButton", "Button")
	_item_type(t, "QuietButton", TEXT, ACCENT)   # An enabled item is white (issue #173).
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_INFO)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_stylebox("normal", "LineEdit", line_box(TEXT_INFO))
	t.set_stylebox("focus", "LineEdit", line_box(ACCENT))
	return t


## Draws `text` centered in `rect` on `ci`, horizontally and vertically (by the font's ascent and
## descent, so a digit sits in the middle of a box).
static func draw_centered(ci: CanvasItem, f: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	# Left aligned from a computed x: the centered alignment of draw_string loses a right to left text (Hebrew).
	# No width is given to draw_string (a text wider than the box would be cut to its last letters); a text that does not fit is
	# drawn smaller, in steps of the 8 px grid, so it stays inside the box.
	var size := fit_size(f, text, rect.size.x, font_size)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, Vector2(rect.position.x + (rect.size.x - w) * 0.5, centered_baseline(f, rect, size)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## The largest size of `font_size`, `font_size - 8`, ... (at least 16) at which `text` is at most `max_w` wide.
static func fit_size(f: Font, text: String, max_w: float, font_size: int) -> int:
	var size := font_size
	while size > 16 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		size -= 8
	return size


## The baseline y that puts the middle of a line of text (ascent to descent) at the middle of `rect`.
static func centered_baseline(f: Font, rect: Rect2, font_size: int) -> float:
	return rect.position.y + rect.size.y * 0.5 + (f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5


## The menu cursor, drawn as pixels (REQ-FL-41), not as a font glyph: 4 columns of `unit` px, 7, 5, 3 and 1 pixels high.
## `at` is the middle of its left edge. With `flip` it points to the left (right to left layouts).
static func draw_cursor(ci: CanvasItem, at: Vector2, color: Color, unit := CURSOR_UNIT, flip := false) -> void:
	for r in cursor_rects(at, unit, flip):
		ci.draw_rect(r, color)


## The rectangles of the cursor (a test checks them).
static func cursor_rects(at: Vector2, unit := CURSOR_UNIT, flip := false) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for col in 4:
		var h := float(7 - 2 * col) * unit
		var x := float(col) * unit
		if flip:
			x = float(3 - col) * unit
		out.append(Rect2(at + Vector2(x, -h * 0.5), Vector2(unit, h)))
	return out


## Whether a blinking prompt shows at `seconds` (REQ-FL-42): on for BLINK_S, then off for BLINK_S, a hard step.
static func blink_on(seconds: float) -> bool:
	return fmod(maxf(seconds, 0.0), BLINK_S * 2.0) < BLINK_S
