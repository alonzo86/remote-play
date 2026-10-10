extends Control
## Games screen (REQ-FL-11 to 19): a grid of tiles (16:9 screenshot, title, player range), the
## players badge, the OPTIONS button, and an info bar under the grid with the description of the focused game.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Registry = preload("res://scripts/game/registry.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const GameTile = preload("res://scripts/ui/game_tile.gd")
const PlayersBadge = preload("res://scripts/ui/players_badge.gd")
const GearButton = preload("res://scripts/ui/gear_button.gd")
const PlayersModal = preload("res://scripts/ui/players_modal.gd")

const CONTENT_W := 1720
const ROW_LEN := 3   # Tiles in a row (REQ-FL-12).

var _root: VBoxContainer
var _grid_view: Control
var _scroll: ScrollContainer
var _tiles: Array[Button] = []
var _badge: Button
var _gear: Button
var _info: Label   # The description of the focused game.
var _modal: Control
var _players := -1


func _ready() -> void:
	# The content is a column of CONTENT_W px, centered on any screen width (the stretch mode is
	# "expand"). Header, grid and info bar share its edges.
	var m := UiKit.margin(self, 0, 60, 0, 60)
	_root = VBoxContainer.new()
	_root.custom_minimum_size = Vector2(CONTENT_W, 0)
	_root.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 20)
	m.add_child(_root)
	_show_grid(App.last_game)


func _clear_views() -> void:
	for v in [_grid_view]:
		if v != null:
			_root.remove_child(v)
			v.queue_free()
	_grid_view = null
	_tiles.clear()


func _show_grid(focus_id := "") -> void:
	_clear_views()
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", 22)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(view)
	_grid_view = view

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 32)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	view.add_child(head)
	var title := UiKit.title("Select game")
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
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL # The scroll box gives it the full width, so the grid can center.
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	_scroll.add_child(pad)
	# Rows of ROW_LEN tiles (REQ-FL-12).
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 30)
	pad.add_child(rows)
	var row: HBoxContainer = null
	for g in Registry.all():
		if row == null or row.get_child_count() >= ROW_LEN:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 30)
			rows.add_child(row)
		var t: Button = GameTile.new()
		t.game = g
		t.pressed.connect(_on_tile.bind(g))
		t.focus_entered.connect(_show_description.bind(g))
		row.add_child(t)
		_tiles.append(t)

	# The info bar: three lines of 32 px, so that the bar does not change its height from game to game.
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme.line_box(UiTheme.TEXT_DIM))
	view.add_child(bar)
	_info = UiKit.label("", UiTheme.SIZE_BODY)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size = Vector2(0, 3.0 * 44.0)
	bar.add_child(_info)

	_players = -1
	_update_fit()
	var first: Button = _tiles[0] if not _tiles.is_empty() else _badge
	for t in _tiles:
		if String(t.game.id) == focus_id:
			first = t
	if focus_id == "@gear":
		first = _gear
	UiKit.focus_later(first)


func _process(_delta: float) -> void:
	_update_fit()


## Dims the tiles of games that do not accept the number of players now (REQ-FL-14, 27).
func _update_fit() -> void:
	var n: int = App.server.connected_slots().size()
	if n == _players:
		return
	_players = n
	for t in _tiles:
		t.fits = Registry.accepts(t.game, n)


func _show_description(game: Dictionary) -> void:
	_info.text = String(game.get("description", "")).to_upper()


func _on_tile(game: Dictionary) -> void:
	var n: int = App.server.connected_slots().size()
	if not Registry.accepts(game, n):
		Sound.sfx("denied")
		return # The tile shows the reason in yellow under its title (REQ-FL-14).
	App.last_game = String(game.id)
	if GameSettings.has_view(game):
		App.go_game_settings(String(game.id))
	else:
		_launch(String(game.id), game.get("props", {}))


func _launch(id: String, props: Dictionary) -> void:
	var script := Registry.load_script(id)
	if script != null:
		App.go(script, props)


func _open_players() -> void:
	var d: Control = PlayersModal.new()
	d.closed.connect(func(): _modal = null)
	_modal = d
	add_child(d)


func on_back() -> void:
	if _modal != null:
		_modal.on_back()
	else:
		App.go_connect() # Back goes to the Connect screen. The players stay (REQ-FL-18).
