extends Control
## Games screen (REQ-FL-11 to 19): a grid of tiles (16:9 screenshot, title, player range), the
## players badge, the ABOUT and OPTIONS icon buttons, and an info bar under the grid with the description of the focused game.

const Lang = preload("res://scripts/core/lang.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Registry = preload("res://scripts/game/registry.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const GameTile = preload("res://scripts/ui/game_tile.gd")
const PlayersBadge = preload("res://scripts/ui/players_badge.gd")
const PhoneIcon = preload("res://scripts/ui/phone_icon.gd")
const PlayersModal = preload("res://scripts/ui/players_modal.gd")
const ScrollArrow = preload("res://scripts/ui/scroll_arrow.gd")

const CONTENT_W := 1720
const ROW_LEN := 3   # Tiles in a row (REQ-FL-12).
const SWIPE_PX := 30.0   # A finger that moves more than this is a swipe and not a tap (REQ-FL-12b).

var _root: VBoxContainer
var _grid_view: Control
var _scroll: ScrollContainer
var _tiles: Array[Button] = []
var _arrow_up: Control   # Blinks when rows are hidden above the grid (REQ-FL-12a).
var _arrow_down: Control   # Blinks when rows are hidden below the grid.
var _badge: Button
var _room: Label   # The room code in the header (REQ-FL-15a). It follows the address of the TV.
var _about: Button   # The ABOUT icon button (owner, 2026-11-12), before OPTIONS as on the phone.
var _gear: Button    # The OPTIONS icon button.
var _info: Label   # The description of the focused game.
var _reason: Label   # Under it, in yellow: why the focused game cannot start with the players now (REQ-FL-14).
var _shown: Dictionary = {}   # The game that the info bar shows.
var _modal: Control
var _players := -1
var _swipe_from := false   # The finger went down on the grid (`_input`).
var _swiped := false   # The finger has moved far enough to be a swipe, not a tap.
var _swipe_px := 0.0   # How far the finger has moved since it went down.
var _swipe_finger := 0   # The finger of the swipe (a second finger is ignored).
var _tap_tile: Button   # The tile under the finger when it went down: a tap opens it, a swipe opens nothing.


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
	var title := UiKit.title("games.select_game")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_room_tag())
	_badge = PlayersBadge.new()
	_badge.pressed.connect(_open_players)
	head.add_child(_badge)
	# ABOUT and OPTIONS are icon buttons with no word, as on the phone (owner, 2026-11-12); the focus is the thick yellow border.
	_about = PhoneIcon.button(PhoneIcon.ABOUT, "AboutButton", func():
		App.last_game = "@about"   # Back from About puts the focus on this button (REQ-FL-24).
		App.go(App.AboutScreen))
	head.add_child(_about)
	_gear = PhoneIcon.button(PhoneIcon.SETTINGS, "OptionsButton", func():
		App.last_game = "@gear" # Back from Settings puts the focus on the gear (REQ-FL-24).
		App.go_settings(), "gear_button.options")
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
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE   # `_input` reads a finger or a click (REQ-FL-12b); the remote uses the focus.
		t.pressed.connect(_on_tile.bind(g))
		t.focus_entered.connect(_show_description.bind(g))
		row.add_child(t)
		_tiles.append(t)

	# The scroll cue (REQ-FL-12a): a row of fixed height, so the layout does not jump when an arrow goes on or off.
	var cue := HBoxContainer.new()
	cue.alignment = BoxContainer.ALIGNMENT_CENTER
	cue.add_theme_constant_override("separation", 48)
	view.add_child(cue)
	_arrow_up = ScrollArrow.new()
	_arrow_up.up = true
	cue.add_child(_arrow_up)
	_arrow_down = ScrollArrow.new()
	cue.add_child(_arrow_down)

	# The info bar: three lines of 32 px, so that the bar does not change its height from game to game.
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme.line_box(UiTheme.TEXT_DIM))
	view.add_child(bar)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	bar.add_child(texts)
	_info = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_DESC)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size = Vector2(0, 2.0 * 44.0)
	texts.add_child(_info)
	_reason = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.ACCENT)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD
	_reason.custom_minimum_size = Vector2(0, 44.0)
	texts.add_child(_reason)

	_wire_focus()
	_players = -1
	_update_fit()
	var first: Button = _tiles[0] if not _tiles.is_empty() else _badge
	for t in _tiles:
		if String(t.game.id) == focus_id:
			first = t
	if focus_id == "@gear":
		first = _gear
	if focus_id == "@about":
		first = _about
	UiKit.focus_later(first)


## The arrow keys between the header (the players badge, ABOUT and OPTIONS) and the tiles are set here, not left to the
## position of the controls: when the grid has scrolled, the first row of tiles is under the header and the nearest control to
## the right of the badge was a tile, so OPTIONS could not be reached. The header order is the one on the screen (ABOUT and
## OPTIONS are at the left in Hebrew). Up and Down at the edges stay where they are, so the focus does not jump to the other end.
func _wire_focus() -> void:
	if _tiles.is_empty():
		return
	var rtl := Lang.is_rtl()
	var order: Array[Control] = [_badge, _about, _gear]
	if rtl:
		order = [_gear, _about, _badge]
	var over_a: Control = _tiles[0] if rtl else _tiles[mini(ROW_LEN, _tiles.size()) - 1]   # The tile under the badge.
	var over_b: Control = _tiles[mini(ROW_LEN, _tiles.size()) - 1] if rtl else over_a        # The tile under OPTIONS.
	for i in order.size():
		var c := order[i]
		_link(c, SIDE_LEFT, order[i - 1] if i > 0 else c)
		_link(c, SIDE_RIGHT, order[i + 1] if i < order.size() - 1 else c)
		_link(c, SIDE_TOP, c)
	_link(_badge, SIDE_BOTTOM, over_a)
	_link(_about, SIDE_BOTTOM, over_b)
	_link(_gear, SIDE_BOTTOM, over_b)
	for i in mini(ROW_LEN, _tiles.size()):
		_link(_tiles[i], SIDE_TOP, _badge)
	var last_row := (_tiles.size() - 1) / ROW_LEN * ROW_LEN   # The index of the first tile of the last row.
	for i in range(last_row, _tiles.size()):
		_link(_tiles[i], SIDE_BOTTOM, _tiles[i])


func _link(from: Control, side: Side, to: Control) -> void:
	from.set_focus_neighbor(side, from.get_path_to(to))


func _process(_delta: float) -> void:
	_update_fit()
	_update_cue()
	if _room != null:
		_room.text = _room_text()


## A finger or a mouse on the grid (REQ-FL-12b, issue #510). It is read here, before the GUI, and the tiles do not take the
## touch (they ignore the mouse): the click that the engine makes from a touch would open a tile at the end of a swipe, or give a
## tile the focus. A finger that goes down on the grid and moves more than `SWIPE_PX` (in any direction) is a swipe: the grid
## scrolls by the distance of the finger up or down, and no tile opens or takes the focus. A finger that is lifted without that
## move is a tap: it opens the tile that was under it when it went down (`_on_tile`). The remote uses the focus, as before.
func _input(event: InputEvent) -> void:
	if _scroll == null or _modal != null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _swipe_from:
				return   # A second finger does not start a new swipe.
			_swipe_from = _scroll.get_global_rect().has_point(event.position)
			_swipe_finger = event.index
			_swiped = false
			_swipe_px = 0.0
			_tap_tile = _tile_at(event.position) if _swipe_from else null
		elif event.index == _swipe_finger and _swipe_from:
			var tapped := _tap_tile if not (event.canceled or _swiped) else null
			_swipe_from = false
			_swiped = false
			_tap_tile = null
			if tapped != null:
				_on_tile(tapped.game)
	elif event is InputEventScreenDrag and _swipe_from and event.index == _swipe_finger:
		_swipe_px += event.relative.length()
		_swiped = _swiped or _swipe_px > SWIPE_PX
		if _swiped:
			_scroll.scroll_vertical -= roundi(event.relative.y)
			get_viewport().set_input_as_handled()   # The scroll box does not scroll a second time.


## The tile that has this point (a screen position), or null.
func _tile_at(pos: Vector2) -> Button:
	for t in _tiles:
		if t.is_visible_in_tree() and t.get_global_rect().has_point(pos):
			return t
	return null


## Turns the two arrows on when the grid has rows above or below the visible part (REQ-FL-12a).
func _update_cue() -> void:
	if _scroll == null or _arrow_up == null:
		return
	var bar := _scroll.get_v_scroll_bar()
	_arrow_up.active = ScrollArrow.more_above(bar.value)
	_arrow_down.active = ScrollArrow.more_below(bar.value, bar.page, bar.max_value)


## The room code, always in the header (REQ-FL-15a): a dim label and the code under it. It is not a focus target.
func _room_tag() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var cap := UiKit.label("connect.room_code", UiTheme.SIZE_BODY, UiTheme.TEXT_INFO)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	_room = UiKit.title(_room_text(), UiTheme.SIZE_ITEM)
	_room.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_room)
	return box


func _room_text() -> String:
	var code: String = App.server.room_code
	return code if code != "" else "----"   # A TV with no address has no code yet (REQ-FL-84).


## Dims the tiles of games that do not accept the number of players now (REQ-FL-14, 27).
func _update_fit() -> void:
	var n: int = App.server.connected_slots().size()
	if n == _players:
		return
	_players = n
	for t in _tiles:
		t.fits = Registry.accepts(t.game, n)
	if not _shown.is_empty():
		_show_description(_shown)   # The reason changes with the players.


func _show_description(game: Dictionary) -> void:
	_shown = game
	_info.text = Lang.t(String(game.get("description", ""))).to_upper()
	var n: int = App.server.connected_slots().size()
	_reason.text = "" if Registry.accepts(game, n) else Registry.reason(game, n).to_upper()


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
