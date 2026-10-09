extends RefCounted
## Party Pop theme (docs/TV_FLOW.md, FD-13): chunky, saturated, sticker-like.
## Thick dark outlines, hard shadows, rounded shapes. Fonts are in assets/fonts.
## The old names (BG, PANEL, PANEL_LIGHT, TEXT, TEXT_DIM, ACCENT, OK, BAD) keep their roles
## for games that draw on the dark background. The CARD colors are for white cards.

const BG := Color("3d1a9e")          # Purple background.
const BG_DARK := Color("2c1180")     # Info bars and dark panels.
const PANEL := Color("2c1180")
const PANEL_LIGHT := Color("4c2bbd")
const TEXT := Color("ffffff")
const TEXT_DIM := Color("d9c9ff")
const ACCENT := Color("ffd23f")      # Yellow: titles, numbers, focus.
const OK := Color("57cc99")
const BAD := Color("ff4d6d")
const OUTLINE := Color("1a0b45")     # Outline and hard shadow.
const BUTTON := Color("7152e8")      # Button fill: lighter purple than the background, so a button stands out.
const DISABLED := Color("c4c0cf")    # A disabled button: flat gray, no shadow (not see-through).
const DISABLED_EDGE := Color("7d7890") # Outline of a disabled button.
const DISABLED_TEXT := Color("4d4863") # Label of a disabled button.
const FOCUS_BORDER := Color("000000")  # The border of the focused button (REQ-FL-41).
const SELECTED := ACCENT               # The chosen value in the settings view: a yellow border or yellow text (REQ-GM-97).
const CARD := Color("ffffff")
const CARD_TEXT := Color("24104f")
const CARD_DIM := Color("6b5a9e")
const CHIP_OK := Color("b9f0d3")      # State chips on a card: light fill, dark text (4.5:1 or more).
const CHIP_OK_TEXT := Color("0d5538")
const CHIP_BAD := Color("ffd0d9")
const CHIP_BAD_TEXT := Color("a1163a")
const DANGER := Color("b3122f")       # Fill of a destructive button. White text: 6.9:1.
const BAD_TEXT := Color("ff8296")     # Error and offline text on the purple background (4.5:1 or more). BAD is for shapes.
const CARD_EMPTY := Color(1, 1, 1, 0.82)  # Fill of an empty player slot: its dark text stays readable on the purple.
const CARD_MUTED := Color("463678")   # Text on an empty slot or an OFF switch: 4.5:1 or more on the dimmed card.
const ROOM := Color("ff3d8b")        # Room code.
const CARD_READY := Color("1f9d6b")  # The "Ready!" word on a card.
const SLOT_EMPTY := Color("b9b0d6")  # Dot of an empty slot on a card.
const BADGE_EMPTY := Color("d8d2ea") # Dot of an empty slot on the players badge.
const CONFETTI: Array[Color] = [Color("ff5ea8"), Color("3ddcff"), Color("ffd23f")]

const OUTLINE_W := 6                 # Outline width in pixels at 1920x1080 (REQ-FL-38).
const SHADOW := Vector2(6, 6)
const SHADOW_COLOR := Color(0.10, 0.04, 0.27, 0.45)   # Lighter than the outline, so the shadow is not a second border.
const RADIUS := 26

const FONT_TITLE := "res://assets/fonts/LilitaOne-Regular.ttf"
const FONT_BODY := "res://assets/fonts/Fredoka.ttf"

static var _title_font: Font
static var _body_font: Font
static var _body_bold: Font


## Display font for titles (Lilita One). Falls back to the default font.
static func title_font() -> Font:
	if _title_font == null:
		_title_font = _load_font(FONT_TITLE, 0)
	return _title_font


## Body font (Fredoka medium).
static func body_font() -> Font:
	if _body_font == null:
		_body_font = _load_font(FONT_BODY, 500)
	return _body_font


## Body font, semibold. For names and labels.
static func body_bold() -> Font:
	if _body_bold == null:
		_body_bold = _load_font(FONT_BODY, 600)
	return _body_bold


static func _load_font(path: String, weight: int) -> Font:
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var base: Font = load(path)
	if base == null:
		return ThemeDB.fallback_font
	if weight == 0:
		return base
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"weight": weight} # "wght" is ignored by Godot. The name is "weight".
	return v


## A card: fill, thick dark outline, rounded corners and a hard shadow (no blur).
static func card(fill: Color = CARD, border: Color = OUTLINE, border_w := OUTLINE_W,
		radius := RADIUS, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = 32
	s.content_margin_right = 32
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	if shadow:
		s.shadow_color = SHADOW_COLOR
		s.shadow_size = 1
		s.shadow_offset = SHADOW
	return s


## Old helper. Flat box without a shadow.
static func box(fill: Color, border: Color = Color.TRANSPARENT, border_w := 0, radius := 8) -> StyleBoxFlat:
	var s := card(fill, border, border_w, radius, false)
	return s


## Contrast ratio of two colors (WCAG).
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var f := func(x: float) -> float: return x / 12.92 if x <= 0.03928 else pow((x + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


## The text color for a label on a fill (a slot number on a slot color): white or the dark card text,
## whichever has more contrast. White on orange is 2.1:1, dark on orange is 8.1:1.
static func text_on(fill: Color) -> Color:
	return Color.WHITE if contrast(Color.WHITE, fill) >= contrast(CARD_TEXT, fill) else CARD_TEXT


## The style of one state of a button (`state`: normal, focus, pressed or disabled).
## Focus: a thick black border and a longer shadow (the button lifts, its size stays). Pressed: the box moves onto
## its shadow and the shadow goes (the button sinks). Disabled: flat gray.
static func button_style(fill: Color, state := "normal", radius := RADIUS) -> StyleBoxFlat:
	match state:
		"focus":
			var f := card(fill, FOCUS_BORDER, 10, radius, true)
			f.shadow_offset = SHADOW * 1.8
			return f
		"pressed":
			var p := card(fill.darkened(0.12), FOCUS_BORDER, 10, radius, false)
			p.expand_margin_left = -SHADOW.x
			p.expand_margin_top = -SHADOW.y
			p.expand_margin_right = SHADOW.x
			p.expand_margin_bottom = SHADOW.y
			return p
		"disabled":
			return card(DISABLED, DISABLED_EDGE, 4, radius, false)
	return card(fill, OUTLINE, OUTLINE_W, radius, true)


static func _button_type(t: Theme, type: String, fill: Color, text: Color) -> void:
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(c, type, text)
	t.set_color("font_disabled_color", type, DISABLED_TEXT)
	t.set_stylebox("normal", type, button_style(fill))
	t.set_stylebox("hover", type, button_style(fill, "focus"))
	t.set_stylebox("focus", type, button_style(fill, "focus"))
	t.set_stylebox("pressed", type, button_style(fill, "pressed"))
	t.set_stylebox("disabled", type, button_style(fill, "disabled"))


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 34
	t.set_font("font", "Label", body_font())
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", body_bold())
	t.set_font_size("font_size", "Button", 36)
	# Three button colors, all with a hard shadow: yellow (default), green (the main action), red (destroys
	# something). A focused button gets a thick black border and lifts (a longer shadow). A pressed button sinks
	# onto its shadow. A disabled button is flat gray (REQ-FL-41, 41a, 50).
	_button_type(t, "Button", ACCENT, CARD_TEXT)
	t.set_type_variation("PrimaryButton", "Button")
	_button_type(t, "PrimaryButton", OK, CARD_TEXT)
	t.set_type_variation("DangerButton", "Button")
	_button_type(t, "DangerButton", DANGER, Color.WHITE)
	# A white button: the one action that must stand out among the colored buttons (Scan QR code).
	t.set_type_variation("LightButton", "Button")
	_button_type(t, "LightButton", CARD, CARD_TEXT)
	# A purple row (a settings row, the players badge): white text on the button purple.
	t.set_type_variation("RowButton", "Button")
	_button_type(t, "RowButton", BUTTON, TEXT)
	# A quiet button for "Back" on a choice screen: dark and flat. Focused, it turns light, so the black border shows.
	t.set_type_variation("SecondaryButton", "Button")
	_button_type(t, "SecondaryButton", Color("d8d2ea"), CARD_TEXT)
	t.set_color("font_color", "SecondaryButton", TEXT_DIM)
	t.set_stylebox("normal", "SecondaryButton", card(BG_DARK, Color(TEXT_DIM, 0.55), 4, RADIUS, false))
	t.set_color("font_color", "LineEdit", CARD_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", CARD_DIM)
	t.set_color("caret_color", "LineEdit", CARD_TEXT)
	t.set_stylebox("normal", "LineEdit", card(CARD))
	t.set_stylebox("focus", "LineEdit", card(CARD, ACCENT, 10))
	return t


## Draws `text` centered in `rect` on `ci`, horizontally and vertically (by the font's ascent and
## descent, so a digit sits in the middle of a circle).
static func draw_centered(ci: CanvasItem, font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	ci.draw_string(font, Vector2(rect.position.x, centered_baseline(font, rect, font_size)), text,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, color)


## The baseline y that puts the middle of a line of text (ascent to descent) at the middle of `rect`.
static func centered_baseline(font: Font, rect: Rect2, font_size: int) -> float:
	return rect.position.y + rect.size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5


## Scale pop for a node (a slot that fills, a button that is chosen). About 150 ms.
static func bounce(node: Control, amount := 1.08) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * amount, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_IN)
