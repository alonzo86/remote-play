extends Button
## One tile of the Games screen: a 16:9 screenshot, the title and the player range under it.
## Every tile has the same layout. Focus is a yellow outline, the tile does not change size (REQ-FL-13).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Registry = preload("res://scripts/game/registry.gd")

const SHOT_SIZE := Vector2(520, 293)
const TEXT_H := 84.0

var game := {}
var fits := true:
	set(v):
		fits = v
		_refresh()

var _frame: Panel
var _name: Label
var _meta: Label


func _ready() -> void:
	custom_minimum_size = Vector2(SHOT_SIZE.x, SHOT_SIZE.y + TEXT_H)
	focus_mode = Control.FOCUS_ALL
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())

	var shadow := Panel.new()
	shadow.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.SHADOW_COLOR, UiTheme.SHADOW_COLOR, 0, 20, false))
	shadow.position = UiTheme.SHADOW
	shadow.size = SHOT_SIZE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shadow)

	var shot := Panel.new()
	shot.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.BG_DARK, UiTheme.OUTLINE, 0, 20, false))
	shot.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	shot.size = SHOT_SIZE
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shot)
	var path := String(game.get("tile", ""))
	if path != "" and ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = SHOT_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot.add_child(tr)
	else:
		# Placeholder: a color from the id, and the title (REQ-FL-11).
		var bg := ColorRect.new()
		bg.color = Color.from_hsv(float(String(game.id).hash() % 360) / 360.0, 0.6, 0.65)
		bg.size = SHOT_SIZE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot.add_child(bg)

	_frame = Panel.new()
	_frame.size = SHOT_SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_name = UiKit.label(String(game.title), 38, UiTheme.TEXT, UiTheme.body_bold())
	_name.position = Vector2(0, SHOT_SIZE.y + 14)
	_name.size = Vector2(SHOT_SIZE.x, 44)
	_name.clip_text = true
	add_child(_name)
	_meta = UiKit.label("", 26, UiTheme.TEXT_DIM, UiTheme.body_font())
	_meta.position = Vector2(0, SHOT_SIZE.y + 54)
	_meta.size = Vector2(SHOT_SIZE.x, 32)
	add_child(_meta)

	focus_entered.connect(_refresh)
	focus_entered.connect(func(): UiTheme.bounce(self, 1.04)) # One short bounce (REQ-FL-42).
	focus_exited.connect(_refresh)
	_refresh()


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
	var s := UiTheme.card(Color.TRANSPARENT, UiTheme.ACCENT if f else UiTheme.OUTLINE,
			10 if f else UiTheme.OUTLINE_W, 20, false)
	_frame.add_theme_stylebox_override("panel", s)
	_name.add_theme_color_override("font_color", UiTheme.ACCENT if f else UiTheme.TEXT)
	if fits:
		_meta.text = players_text()
		_meta.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	else:
		_meta.text = reason()
		_meta.add_theme_color_override("font_color", UiTheme.ACCENT)
	modulate = Color(1, 1, 1, 1.0 if fits else 0.5)
