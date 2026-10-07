extends Control
## Base class for minigames. A minigame reads PlayerInput objects and draws.
## It does not use any networking script. To add a minigame:
##   1. Make a folder under scripts/game/.
##   2. Extend this script. Override _game_ready(), _game_tick(), _game_draw().
##   3. Add one button for it in scripts/ui/tv_menu.gd.
## This base class handles: player list, pause while a phone is lost,
## the D-pad pause menu (Resume / Restart / Menu), and the back key.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")

## Slots that joined when the game started.
var participants: Array[int] = []

var _menu_box: VBoxContainer
var _menu_open := false
var _paused_lost := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	participants = App.server.connected_slots()
	App.server.set_phase("playing")
	_game_ready()


func player(slot: int) -> PlayerInput:
	return App.server.players[slot]


## Slots of participants that lost their connection.
func lost_participants() -> Array[int]:
	var r: Array[int] = []
	for s in participants:
		if player(s).state == PlayerInput.State.LOST:
			r.append(s)
	return r


## Remove participants that left for good.
func _prune_participants() -> void:
	var keep: Array[int] = []
	for s in participants:
		if player(s).is_present():
			keep.append(s)
	if keep.size() != participants.size():
		participants = keep
		_on_participants_changed()


func is_paused() -> bool:
	return _menu_open or _paused_lost


func _process(delta: float) -> void:
	_prune_participants()
	var was_lost := _paused_lost
	_paused_lost = not lost_participants().is_empty()
	if _paused_lost != was_lost:
		App.server.set_phase("paused" if _paused_lost else "playing")
	if not is_paused():
		_game_tick(delta)
	_request_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _menu_open:
		if _paused_lost:
			# Continue without the lost players.
			for s in lost_participants():
				App.server.drop_player(s)
			get_viewport().set_input_as_handled()
		elif _can_open_menu():
			open_menu("Paused", [["Resume", close_menu], ["Restart", restart], ["Back to menu", App.go_menu]])
			get_viewport().set_input_as_handled()


func on_back() -> void:
	if _menu_open:
		close_menu()
	else:
		App.go_menu()


func restart() -> void:
	App.go(get_script())


func open_menu(title: String, entries: Array) -> void:
	close_menu()
	_menu_open = true
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 14)
	_menu_box.custom_minimum_size = Vector2(560, 0)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 54)
	l.add_theme_color_override("font_color", UiTheme.ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_box.add_child(l)
	var first: Button = null
	for e in entries:
		var b := Button.new()
		b.text = e[0]
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(e[1])
		_menu_box.add_child(b)
		if first == null:
			first = b
	add_child(_menu_box)
	_menu_box.position = (size - Vector2(560, 120 + entries.size() * 80)) * 0.5
	first.grab_focus()


func close_menu() -> void:
	_menu_open = false
	if _menu_box != null:
		_menu_box.queue_free()
		_menu_box = null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	_game_draw()
	_draw_overlays(self)


## Draws the "waiting for players" text and the dim layer of the pause menu on `ci`.
## 2D games draw it on the game itself. 3D games draw it on the HUD layer above the 3D view.
func _draw_overlays(ci: CanvasItem) -> void:
	if _paused_lost:
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
		var lost := lost_participants()
		var names := ""
		for s in lost:
			names += "P%d " % (s + 1)
		var font := ThemeDB.fallback_font
		ci.draw_string(font, Vector2(0, size.y * 0.45), "Waiting for %sto reconnect" % names,
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 60, UiTheme.ACCENT)
		ci.draw_string(font, Vector2(0, size.y * 0.45 + 70), "Press OK to continue without them",
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, UiTheme.TEXT_DIM)
	elif _menu_open:
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))


## Called every frame. Subclasses with more canvas layers redraw them here.
func _request_redraw() -> void:
	queue_redraw()


# ---- Override in subclasses ----

func _game_ready() -> void:
	pass


func _game_tick(_delta: float) -> void:
	pass


func _game_draw() -> void:
	pass


func _can_open_menu() -> bool:
	return true


func _on_participants_changed() -> void:
	pass
