extends Button
## One tile of the Games screen: a 16:9 screenshot in a 6 px frame, and the title and the player range under it.
## Every tile has the same size and layout. The focused tile has a yellow frame and a cursor before its title (REQ-FL-13).
## The description of the focused game is in the bar under the grid (docs/ARCADE_STYLE_PLAN.md, question 1).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Lang = preload("res://scripts/core/lang.gd")

const SHOT := Vector2(480, 270)       # The screenshot (16:9). Every tile has this size.
const TEXT_H := 150.0                 # The room under the screenshot: the title and the player range.

var game := {}
var fits := true:
	set(v):
		fits = v
		_refresh()

var _frame: Panel
var _name: Label
var _meta: Label


func _ready() -> void:
	custom_minimum_size = Vector2(SHOT.x, SHOT.y + TEXT_H)
	focus_mode = Control.FOCUS_ALL
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())

	var shot := Control.new()
	shot.size = SHOT
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shot)
	var tile_tex := load_tile(String(game.get("tile", "")))
	if tile_tex != null:
		var tr := TextureRect.new()
		tr.texture = tile_tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.size = SHOT
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot.add_child(tr)
	else:
		# Placeholder: a color from the id (REQ-FL-11).
		var bg := ColorRect.new()
		bg.color = Color.from_hsv(float(String(game.id).hash() % 360) / 360.0, 0.6, 0.65)
		bg.size = SHOT
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shot.add_child(bg)

	_frame = Panel.new()
	_frame.size = SHOT
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_name = UiKit.label(String(game.title), UiTheme.SIZE_BODY)
	var cursor_room := UiTheme.CURSOR_UNIT * 4.0 + 16.0
	_name.position = Vector2(0.0 if is_layout_rtl() else cursor_room, SHOT.y + 16)   # The cursor is at the right in Hebrew.
	_name.size = Vector2(SHOT.x - cursor_room, 40)
	add_child(_name)
	_meta = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	_meta.position = Vector2(0, SHOT.y + 64)
	_meta.size = Vector2(SHOT.x, 80)
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_meta)

	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	_refresh()


## The screenshot of a game as a texture, or null (then the tile shows a placeholder).
## A tile that fails to load writes a warning to the log (`adb logcat -s godot`).
static func load_tile(path: String) -> Texture2D:
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		push_warning("Tile image not found: %s" % path)
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("Tile image could not be loaded: %s" % path)
		return null
	return tex


func players_text() -> String:
	var lo := int(game.min_players)
	var hi := int(game.max_players)
	if lo == hi:
		return Lang.t("games.one_player") if lo == 1 else Lang.f("games.n_players", [lo])
	return Lang.f("games.range_players", [lo, hi])


## Why the game cannot start with the players now (REQ-FL-14).
func reason() -> String:
	return Registry.reason(game, App.server.connected_slots().size())


func _draw() -> void:
	if has_focus():
		var rtl := is_layout_rtl()
		UiTheme.draw_cursor(self, Vector2(size.x - UiTheme.CURSOR_UNIT * 4.0 if rtl else 0.0, SHOT.y + 36.0), UiTheme.ACCENT,
				UiTheme.CURSOR_UNIT, rtl)


func _refresh() -> void:
	if _frame == null:
		return
	var f := has_focus()
	_frame.add_theme_stylebox_override("panel", UiTheme.line_box(UiTheme.ACCENT if f else UiTheme.TEXT_DIM, Color.TRANSPARENT))
	_name.add_theme_color_override("font_color", UiTheme.ACCENT if f else UiTheme.TEXT)
	if fits:
		_meta.text = players_text().to_upper()
		_meta.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	else:
		_meta.text = reason().to_upper()
		_meta.add_theme_color_override("font_color", UiTheme.ACCENT)
	modulate = Color(1, 1, 1, 1.0 if fits else 0.5)
	queue_redraw()
