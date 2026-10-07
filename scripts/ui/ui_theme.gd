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
const CARD := Color("ffffff")
const CARD_TEXT := Color("24104f")
const CARD_DIM := Color("6b5a9e")
const ROOM := Color("ff3d8b")        # Room code.
const CONFETTI: Array[Color] = [Color("ff5ea8"), Color("3ddcff"), Color("ffd23f")]

const OUTLINE_W := 6                 # Outline width in pixels at 1920x1080 (REQ-FL-38).
const SHADOW := Vector2(8, 8)
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
	v.variation_opentype = {"wght": weight}
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
		s.shadow_color = OUTLINE
		s.shadow_size = 1
		s.shadow_offset = SHADOW
	return s


## Old helper. Flat box without a shadow.
static func box(fill: Color, border: Color = Color.TRANSPARENT, border_w := 0, radius := 8) -> StyleBoxFlat:
	var s := card(fill, border, border_w, radius, false)
	return s


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 34
	t.set_font("font", "Label", body_font())
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", body_bold())
	t.set_font_size("font_size", "Button", 36)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(c, "Button", CARD_TEXT)
	t.set_color("font_disabled_color", "Button", CARD_DIM)
	t.set_stylebox("normal", "Button", card())
	t.set_stylebox("hover", "Button", card(CARD, ACCENT, 10))
	t.set_stylebox("focus", "Button", card(CARD, ACCENT, 10))
	t.set_stylebox("pressed", "Button", card(ACCENT))
	t.set_stylebox("disabled", "Button", card(Color(CARD, 0.55), OUTLINE, OUTLINE_W, RADIUS, false))
	# A yellow button for the main action of a screen.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", card(ACCENT))
	t.set_stylebox("hover", "PrimaryButton", card(ACCENT, CARD, 10))
	t.set_stylebox("focus", "PrimaryButton", card(ACCENT, CARD, 10))
	t.set_stylebox("pressed", "PrimaryButton", card(ACCENT.darkened(0.15)))
	t.set_stylebox("disabled", "PrimaryButton", card(Color(ACCENT, 0.45), OUTLINE, OUTLINE_W, RADIUS, false))
	t.set_color("font_color", "LineEdit", CARD_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", CARD_DIM)
	t.set_color("caret_color", "LineEdit", CARD_TEXT)
	t.set_stylebox("normal", "LineEdit", card(CARD))
	t.set_stylebox("focus", "LineEdit", card(CARD, ACCENT, 10))
	return t


## Scale pop for a node (a slot that fills, a button that is chosen). About 150 ms.
static func bounce(node: Control, amount := 1.08) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * amount, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_IN)
