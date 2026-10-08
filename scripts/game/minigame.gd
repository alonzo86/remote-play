extends Control
## Base class for minigames. A minigame reads PlayerInput objects and draws.
## It does not use any networking script. To add a minigame:
##   1. Make a folder under scripts/game/.
##   2. Extend this script. Override _game_ready(), _game_tick(), _game_draw().
##   3. Add one entry for it in scripts/game/registry.gd.
## This base class handles: player list, pause while a phone is lost,
## the D-pad pause menu (Resume / Restart / Menu), and the back key.
## It is the game shell (REQ-GM-45): the menus here and the helpers in shell.gd have the Party Pop style.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Shell = preload("res://scripts/game/shell.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Protocol = preload("res://scripts/core/protocol.gd")

## Values the game was started with (App.go props). restart() uses them again.
var start_props := {}

## Slots that joined when the game started.
var participants: Array[int] = []

var _menu_box: Control
var _menu_open := false
var _paused_lost := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	participants = App.server.connected_slots()
	App.server.set_phase("playing", participants)
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


## True when every participant is lost: nobody is left to continue with.
func nobody_connected() -> bool:
	if participants.is_empty():
		return false
	for s in participants:
		if player(s).state == PlayerInput.State.CONNECTED:
			return false
	return true


func _process(delta: float) -> void:
	if nobody_connected():
		# Every participant is lost, so nobody is left. Do not ask to continue without them: end the game
		# at once (REQ-GM-30a).
		for s in lost_participants():
			App.server.drop_player(s)
	_prune_participants()
	var was_lost := _paused_lost
	_paused_lost = not lost_participants().is_empty()
	if _paused_lost != was_lost:
		App.server.set_phase("paused" if _paused_lost else "playing", participants)
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
	App.go(get_script(), start_props)


func open_menu(title: String, entries: Array) -> void:
	close_menu()
	_menu_open = true
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_box = center
	var card := UiKit.card_panel(UiTheme.CARD, 40)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	var l := UiKit.title(title, 64, UiTheme.CARD_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(l)
	var first: Button = null
	for e in entries:
		var b := UiKit.button(String(e[0]), e[1], first == null, 40)
		b.custom_minimum_size = Vector2(440, 82)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(b)
		if first == null:
			first = b
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	first.grab_focus()


## The buttons of the open menu (tests use it).
func menu_buttons() -> Array[Button]:
	var r: Array[Button] = []
	if _menu_box != null:
		for b in _menu_box.find_children("*", "Button", true, false):
			r.append(b)
	return r


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
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(UiTheme.OUTLINE, 0.72))
		var names := ""
		for s in lost_participants():
			names += "P%d " % (s + 1)
		var r := Rect2(size.x * 0.5 - 520.0, size.y * 0.5 - 130.0, 1040.0, 260.0)
		ci.draw_style_box(UiTheme.card(UiTheme.CARD), r)
		var tf := UiTheme.title_font()
		ci.draw_string(tf, Vector2(r.position.x, r.position.y + 112.0), "Waiting for %sto reconnect" % names,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 58, UiTheme.CARD_TEXT)
		if not nobody_connected(): # With nobody connected there is nobody to continue with.
			ci.draw_string(UiTheme.body_bold(), Vector2(r.position.x, r.position.y + 185.0),
					"Press OK to continue without them", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, UiTheme.CARD_DIM)
	elif _menu_open:
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(UiTheme.OUTLINE, 0.72))


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
