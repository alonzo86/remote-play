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
const Scoreboard = preload("res://scripts/game/scoreboard.gd")
const Medals = preload("res://scripts/game/medals.gd")

## Values the game was started with (App.go props). restart() uses them again.
var start_props := {}

## Slots that joined when the game started.
var participants: Array[int] = []

## True when the game has ended: a winner, or nobody is left. A game sets it when it opens its result menu.
## The pause menu cannot open and leaving does not ask (REQ-GM-31a) while it is true.
var is_over := false

var _menu_box: Control
var _menu_open := false
var _paused_lost := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	participants = App.server.connected_slots()
	App.server.set_phase("playing", participants)
	_game_ready()
	if participants.is_empty():
		end_no_players()


func player(slot: int) -> PlayerInput:
	return App.server.players[slot]


## Slots of participants that lost their connection.
func lost_participants() -> Array[int]:
	var r: Array[int] = []
	for s in participants:
		if player(s).state == PlayerInput.State.LOST:
			r.append(s)
	return r


## Remove participants that left for good. The game removes the objects of each one in `_on_player_left()`
## (REQ-GM-21). When nobody is left, the game ends at once (REQ-GM-22).
func _prune_participants() -> void:
	var keep: Array[int] = []
	var gone: Array[int] = []
	for s in participants:
		if player(s).is_present():
			keep.append(s)
		else:
			gone.append(s)
	if gone.is_empty():
		return
	participants = keep
	for s in gone:
		_on_player_left(s)
	if participants.is_empty():
		end_no_players()
	_on_participants_changed()


## Ends the game with the "No players connected" menu (REQ-GM-22). It does nothing when the game is over already.
func end_no_players() -> void:
	if is_over:
		return
	is_over = true
	open_menu("No players connected", [["Back to menu", App.go_menu]])


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
			open_menu("Paused", [["Resume", close_menu], ["Restart", restart], ["Back to menu", request_leave]])
			get_viewport().set_input_as_handled()


func on_back() -> void:
	if _menu_open:
		close_menu() # Also the "End the game?" question: Back is "Keep playing".
	else:
		request_leave()


## Leaves the game for the Games screen (REQ-GM-31a). While the game is in progress it asks first: a round
## must not end by a slip of the thumb. A game that is over (result menu, no players) leaves at once.
func request_leave() -> void:
	if _in_progress():
		open_menu("End the game?", [["Keep playing", close_menu], ["\u2715  End game", App.go_menu, "danger"]])
	else:
		App.go_menu()


func restart() -> void:
	App.go(get_script(), start_props)


## `rows` are optional lines under the title: `{text, color}` for each, with a dot in the color (the result ranking).
func open_menu(title: String, entries: Array, rows: Array = []) -> void:
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
	for r in rows:
		box.add_child(_menu_row(String(r.text), r.color))
	var first: Button = null
	for e in entries:
		var b := UiKit.button(String(e[0]), e[1], first == null, 40)
		if e.size() > 2 and e[2] == "danger":
			b.theme_type_variation = "DangerButton"
		b.custom_minimum_size = Vector2(440, 82)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(b)
		if first == null:
			first = b
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	first.grab_focus()


## One line of the result list: a dot in the player color, and the text.
func _menu_row(text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(40, 40)
	dot.add_theme_stylebox_override("panel", UiTheme.card(color, UiTheme.OUTLINE, 5, 20, false))
	row.add_child(dot)
	row.add_child(UiKit.label(text, 40, UiTheme.CARD_TEXT))
	return row


## Ends a round with scores (REQ-GM-34, 72, 73): sets `is_over` and opens the result menu with the ranking, Restart and
## Back to menu. The title names the winner, or says "Tie". With one player and `tiers` (see `Medals`) it shows the medal.
func open_results(board: Scoreboard, tiers: Array = []) -> void:
	is_over = true
	var ranking := board.ranking()
	var rows: Array = []
	for e in ranking:
		var p := player(e.slot)
		rows.append({"text": "%s   %s   %s" % [Scoreboard.ordinal(e.rank), p.player_name, Scoreboard.format(e.score)],
				"color": p.color})
	var title := "Round over"
	var winners := board.winners()
	if ranking.size() == 1 and not tiers.is_empty():
		title = Medals.label(Medals.medal(ranking[0].score, tiers, board.lower_is_better))
	elif winners.size() == 1 and ranking.size() > 1:
		title = "%s wins!" % player(winners[0]).player_name
	elif winners.size() > 1:
		title = "Tie!"
	open_menu(title, [["Restart", restart], ["Back to menu", App.go_menu]], rows)


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


## True when the pause menu may open. By default it may while the game is not over and a player is left.
## A game adds its own limits (for example no pause menu in a countdown).
func _can_open_menu() -> bool:
	return not is_over and not participants.is_empty()


## True while the game is in progress, so that leaving it asks first (REQ-GM-31a). It is not the same as
## `_can_open_menu()`: a game may block the pause menu (for example in a countdown) and still be in progress.
## By default it is the same.
func _in_progress() -> bool:
	return _can_open_menu()


## A participant left for good. Remove the object of that slot (REQ-GM-21). `participants` has no `slot` any more.
func _on_player_left(_slot: int) -> void:
	pass


## The list of participants changed (after `_on_player_left()` for each slot and the end check).
func _on_participants_changed() -> void:
	pass
