extends Button
## One tile of the Games screen: a 16:9 screenshot, the title and the player range under it.
## Every tile has the same layout. Focus is a yellow outline, the tile does not change size (REQ-FL-13).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Registry = preload("res://scripts/game/registry.gd")

const SHOT := Vector2(420, 236)       # The screenshot (16:9). Every tile has this size.
const INFO_W := 360.0                 # The extra width of the focused tile: the description of the game.
const GAP := 24.0
const TEXT_H := 84.0
const GROW_S := 0.18                  # Seconds to grow or shrink (REQ-FL-42).

var game := {}
var fits := true:
	set(v):
		fits = v
		_refresh()

var _frame: Panel
var _card: Panel
var _shadow: Panel
var _name: Label
var _meta: Label
var _desc: Label
var _tween: Tween
var _w := SHOT.x


func _ready() -> void:
	custom_minimum_size = Vector2(SHOT.x, SHOT.y + TEXT_H)
	focus_mode = Control.FOCUS_ALL
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())

	_shadow = Panel.new()
	_shadow.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.SHADOW_COLOR, UiTheme.SHADOW_COLOR, 0, 20, false))
	_shadow.position = UiTheme.SHADOW
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shadow)

	# The card is as wide as the tile. The screenshot is on its left, the description on its right.
	_card = Panel.new()
	_card.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.BG_DARK, UiTheme.OUTLINE, 0, 20, false))
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	var shot := Panel.new()
	shot.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.BG_DARK, UiTheme.OUTLINE, 0, 20, false))
	shot.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	shot.size = SHOT
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shot)
	var path := String(game.get("tile", ""))
	if path != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = SHOT
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot.add_child(tr)
	else:
		# Placeholder: a color from the id, and the title (REQ-FL-11).
		var bg := ColorRect.new()
		bg.color = Color.from_hsv(float(String(game.id).hash() % 360) / 360.0, 0.6, 0.65)
		bg.size = SHOT
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot.add_child(bg)

	_desc = UiKit.label(String(game.get("description", "")), 28, UiTheme.TEXT, UiTheme.body_font())
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc.clip_text = true
	_desc.modulate.a = 0.0
	add_child(_desc)
	_desc.position = Vector2(SHOT.x + GAP, 20)
	_desc.size = Vector2(INFO_W - GAP - 24.0, SHOT.y - 40) # After autowrap is on: the text wraps at this width.

	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_name = UiKit.label(String(game.title), 38, UiTheme.TEXT, UiTheme.body_bold())
	_name.position = Vector2(0, SHOT.y + 14)
	_name.size = Vector2(SHOT.x, 44)
	_name.clip_text = true
	add_child(_name)
	_meta = UiKit.label("", 28, UiTheme.TEXT_DIM, UiTheme.body_font())
	_meta.position = Vector2(0, SHOT.y + 54)
	_meta.size = Vector2(SHOT.x, 36)
	add_child(_meta)

	focus_entered.connect(_refresh)
	focus_entered.connect(_grow.bind(true))
	focus_exited.connect(_refresh)
	focus_exited.connect(_grow.bind(false))
	_set_width(SHOT.x)
	_refresh()


## The width of the tile when it has the focus (the screenshot, a gap and the description).
static func wide_width() -> float:
	return SHOT.x + INFO_W


## The width the tile is growing or shrinking to (the focus decides, REQ-FL-13).
func target_width() -> float:
	return wide_width() if has_focus() else SHOT.x


## Grows to show the description when focused, back to the screenshot width when not (a Netflix menu).
func _grow(wide: bool) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_width, _w, wide_width() if wide else SHOT.x, GROW_S)
	_tween.tween_property(_desc, "modulate:a", 1.0 if wide else 0.0, GROW_S)


func _set_width(w: float) -> void:
	_w = w
	custom_minimum_size.x = w
	var sz := Vector2(w, SHOT.y)
	_shadow.size = sz
	_card.size = sz
	_frame.size = sz


func players_text() -> String:
	var lo := int(game.min_players)
	var hi := int(game.max_players)
	return "%d player%s" % [lo, "" if lo == 1 else "s"] if lo == hi else "%d-%d players" % [lo, hi]


## Why the game cannot start with the players now (REQ-FL-14).
func reason() -> String:
	return Registry.reason(game, App.server.connected_slots().size())


func _refresh() -> void:
	if _frame == null:
		return
	var f := has_focus()
	# No yellow outline on the focused tile: it is wide and its title is yellow (REQ-FL-13).
	var s := UiTheme.card(Color.TRANSPARENT, UiTheme.OUTLINE, UiTheme.OUTLINE_W, 20, false)
	_frame.add_theme_stylebox_override("panel", s)
	_name.add_theme_color_override("font_color", UiTheme.ACCENT if f else UiTheme.TEXT)
	if fits:
		_meta.text = players_text()
		_meta.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	else:
		_meta.text = reason()
		_meta.add_theme_color_override("font_color", UiTheme.ACCENT)
	modulate = Color(1, 1, 1, 1.0 if fits else 0.5)
