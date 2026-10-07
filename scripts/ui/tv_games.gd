extends Control
## Games screen (REQ-FL-11 to 19): a grid of tiles (16:9 screenshot, title, player range), the
## players badge, the Settings gear, and an info bar with the description of the focused game.
## A game with variants asks for the variant first (the marble race track).

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Registry = preload("res://scripts/game/registry.gd")
const GameTile = preload("res://scripts/ui/game_tile.gd")
const PlayersBadge = preload("res://scripts/ui/players_badge.gd")
const GearButton = preload("res://scripts/ui/gear_button.gd")
const PlayersModal = preload("res://scripts/ui/players_modal.gd")

const CONTENT_W := 1460

var _root: VBoxContainer
var _grid_view: Control
var _variant_view: Control
var _scroll: ScrollContainer
var _tiles: Array[Button] = []
var _badge: Button
var _gear: Button
var _info_name: Label
var _info_text: Label
var _modal: Control
var _variants_of := ""
var _players := -1
var _flash_reason := 0.0


func _ready() -> void:
	# The content is a column of CONTENT_W px, centered on any screen width (the stretch mode is
	# "expand"). Header, grid and info bar share its edges.
	var m := UiKit.margin(self, 0, 60, 0, 56)
	_root = VBoxContainer.new()
	_root.custom_minimum_size = Vector2(CONTENT_W, 0)
	_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 20)
	m.add_child(_root)
	_show_grid(App.last_game)


func _clear_views() -> void:
	for v in [_grid_view, _variant_view]:
		if v != null:
			_root.remove_child(v)
			v.queue_free()
	_grid_view = null
	_variant_view = null
	_tiles.clear()


func _show_grid(focus_id := "") -> void:
	_clear_views()
	_variants_of = ""
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 22)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(view)
	_grid_view = view

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	view.add_child(head)
	var title := UiKit.title("Choose a game", 80)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_badge = PlayersBadge.new()
	_badge.pressed.connect(_open_players)
	head.add_child(_badge)
	_gear = GearButton.new()
	_gear.pressed.connect(func():
		App.last_game = "@gear" # Back from Settings puts the focus on the gear (REQ-FL-24).
		App.go_settings())
	head.add_child(_gear)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.follow_focus = true
	view.add_child(_scroll)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	_scroll.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 26)
	pad.add_child(grid)
	for g in Registry.all():
		var t: Button = GameTile.new()
		t.game = g
		t.pressed.connect(_on_tile.bind(g))
		t.focus_entered.connect(_show_info.bind(String(g.title), String(g.description)))
		grid.add_child(t)
		_tiles.append(t)
	_badge.focus_entered.connect(_show_info.bind("Players", "See who is connected, remove a player, or add a phone."))
	_gear.focus_entered.connect(_show_info.bind("Settings", "Debug overlay and the invert switches for tilt and yaw."))

	var bar := UiKit.card_panel(UiTheme.BG_DARK, 20)
	view.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	bar.add_child(h)
	_info_name = UiKit.title("", 40)
	_info_name.custom_minimum_size = Vector2(260, 0)
	h.add_child(_info_name)
	_info_text = UiKit.label("", 30, UiTheme.TEXT, UiTheme.body_font())
	_info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	h.add_child(_info_text)

	_players = -1
	_update_fit()
	var first: Button = _tiles[0] if not _tiles.is_empty() else _badge
	for t in _tiles:
		if String(t.game.id) == focus_id:
			first = t
	if focus_id == "@gear":
		first = _gear
	UiKit.focus_later(first)


func _show_info(title: String, text: String) -> void:
	_info_name.text = title
	_info_text.text = text
	_info_text.add_theme_color_override("font_color", UiTheme.TEXT)


func _process(delta: float) -> void:
	if _variants_of == "":
		_update_fit()
	if _flash_reason > 0.0:
		_flash_reason -= delta
		if _flash_reason <= 0.0:
			var f := get_viewport().gui_get_focus_owner()
			if f != null and "game" in f:
				_show_info(String(f.game.title), String(f.game.description))


## Dims the tiles of games that do not accept the number of players now (REQ-FL-14, 27).
func _update_fit() -> void:
	var n: int = App.server.connected_slots().size()
	if n == _players:
		return
	_players = n
	for t in _tiles:
		t.fits = Registry.accepts(t.game, n)


func _on_tile(game: Dictionary) -> void:
	var n: int = App.server.connected_slots().size()
	if not Registry.accepts(game, n):
		_info_name.text = String(game.title)
		_info_text.text = "%s. Add or remove phones with the players badge." % Registry.reason(game, n)
		_info_text.add_theme_color_override("font_color", UiTheme.ACCENT)
		_flash_reason = 2.5
		return
	App.last_game = String(game.id)
	if game.has("variants"):
		_show_variants(game)
	else:
		_launch(String(game.id), game.get("props", {}))


func _launch(id: String, props: Dictionary) -> void:
	var script := Registry.load_script(id)
	if script != null:
		App.go(script, props)


## Second step for games with variants (REQ-FL-17).
func _show_variants(game: Dictionary) -> void:
	_clear_views()
	_variants_of = String(game.id)
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 18)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(view)
	_variant_view = view
	view.add_child(UiKit.title("%s: choose a track" % String(game.title), 72))
	view.add_child(UiKit.spacer(14))
	var first: Button = null
	for v in game.variants:
		var b := UiKit.button(String(v.title), _launch.bind(String(game.id), v.props), false, 44)
		b.custom_minimum_size = Vector2(0, 96)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		view.add_child(b)
		if first == null:
			first = b
	var back := UiKit.button("Back", func(): _show_grid(_variants_of), false, 36)
	view.add_child(back)
	UiKit.focus_later(first)


func _open_players() -> void:
	var d: Control = PlayersModal.new()
	d.closed.connect(func(): _modal = null)
	_modal = d
	add_child(d)


func on_back() -> void:
	if _modal != null:
		_modal.on_back()
	elif _variants_of != "":
		_show_grid(_variants_of)
	else:
		App.go_connect() # Back goes to the Connect screen. The players stay (REQ-FL-18).
