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
const Registry = preload("res://scripts/game/registry.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")

## Values the game was started with (App.go props). restart() uses them again.
var start_props := {}

## Slots that joined when the game started.
var participants: Array[int] = []

## True when the game has ended: a winner, or nobody is left. A game sets it when it opens its result menu.
## The pause menu cannot open and leaving does not ask (REQ-GM-31a) while it is true.
var is_over := false

var _menu_box: Control
var _menu_open := false
var _menu_kind := ""             # "hold" for the card of a lost phone, "menu" for the other menus.
var _hold := false               # A participant lost its connection: the game waits for a decision (REQ-GM-30).
var _hold_info := {}             # slot -> {name, color} of the players lost in this hold.
var _hold_sig := ""


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	participants = App.server.connected_slots()
	App.server.set_phase("playing", participants)
	Sound.duck(false)
	Sound.music_at_go(Registry.id_of_script(get_script()))   # The song starts at GO (REQ-FL-65a).
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
	return _menu_open


func _process(delta: float) -> void:
	_prune_participants()
	_update_hold()
	if not is_paused():
		_game_tick(delta)
	_request_redraw()


## While a participant is lost the game is paused and a card says so (REQ-GM-30). The game never goes on by itself:
## the TV user chooses. "Resume without ..." is there only while another participant is still connected. "Resume" is
## there when every participant is connected again. The card changes by itself when a phone comes back or leaves.
func _update_hold() -> void:
	if is_over:
		if _hold:
			_hold = false
			_hold_info.clear()
			App.server.set_phase("playing", participants)
		return
	var lost := lost_participants()
	if not lost.is_empty() and not _hold:
		_hold = true
		App.server.set_phase("paused", participants)   # The slot of the lost phone is kept longer (a phone call).
	for s in lost:
		if not _hold_info.has(s):
			_hold_info[s] = {"name": player(s).player_name, "color": player(s).color}
	if not _hold:
		return
	if _menu_open and _menu_kind != "hold":
		return   # Another menu is on top ("End the game?"). The card comes back when it closes.
	var sig := "%s|%d|%s" % [str(lost), connected_participants().size(), str(participants)]
	if _menu_kind != "hold" or sig != _hold_sig:
		_hold_sig = sig
		_show_hold_card(lost)


## Slots of the participants that are connected now.
func connected_participants() -> Array[int]:
	var r: Array[int] = []
	for s in participants:
		if player(s).state == PlayerInput.State.CONNECTED:
			r.append(s)
	return r


func _slot_labels(slots: Array) -> String:
	var parts: Array[String] = []
	for s in slots:
		parts.append("P%d" % (int(s) + 1))
	return " and ".join(parts)


func _show_hold_card(lost: Array[int]) -> void:
	var rows: Array = []
	var gone: Array[int] = []
	for s in _hold_info:
		var info: Dictionary = _hold_info[s]
		var state := "left the game"
		if lost.has(s):
			state = "waiting to reconnect"
		elif participants.has(s):
			state = "is back"
		else:
			gone.append(s)
		rows.append({"text": "%s   %s" % [info.name, state], "color": info.color})
	var title: String
	var entries: Array = []
	if not lost.is_empty():
		title = "%s lost connection" % _slot_labels(lost)
		if not connected_participants().is_empty():
			entries.append(["Resume without %s" % _slot_labels(lost), _resume_without_lost])
	else:
		title = "%s left the game" % _slot_labels(gone) if not gone.is_empty() and gone.size() == _hold_info.size() \
				else "%s reconnected" % _slot_labels(_hold_info.keys())
		entries.append(["Resume", _resume_game])
	entries.append(["\u2715  End game", request_leave, "danger"])
	open_menu(title, entries, rows)
	_menu_kind = "hold"


## Goes on without the lost players: their slots are freed (the TV user chose "Resume without ...").
func _resume_without_lost() -> void:
	for s in lost_participants():
		App.server.drop_player(s)
	_prune_participants()
	_resume_game()


func _resume_game() -> void:
	if is_over:
		return   # Nobody was left: the "No players connected" menu stays.
	_hold = false
	_hold_info.clear()
	close_menu()
	App.server.set_phase("playing", participants)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _menu_open and _can_open_menu():
		open_menu("Paused", [["Resume", close_menu], ["Restart", restart], ["Back to menu", request_leave]])
		get_viewport().set_input_as_handled()


func on_back() -> void:
	if _menu_open and _menu_kind != "hold":
		close_menu() # Also the "End the game?" question: Back is "Keep playing".
	else:
		request_leave() # On the card of a lost phone, Back asks to end the game.


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
	_menu_kind = "menu"
	Sound.duck(true)
	Sound.sfx("pause")
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


## Ends a round with scores (REQ-GM-34, 72, 73): sets `is_over` and opens the result menu. It lists the ranking, and its
## buttons are Restart, then `extra_entries` (for example Choose track), then Back to menu.
## - The title names the single winner, or says "Tie!", or says "Round over" when nobody has a score.
##   With one player and `tiers` (see `Medals`) it is the medal. `title` replaces it.
## - `score_text` turns a score into text for the list (default `Scoreboard.format`). A player without a score shows
##   "not finished".
func open_results(board: Scoreboard, tiers: Array = [], title := "", extra_entries: Array = [],
		score_text := Callable()) -> void:
	is_over = true
	var ranking := board.ranking()
	var rows: Array = []
	for e in ranking:
		var p := player(e.slot)
		var text := "not finished"
		if e.finished:
			text = String(score_text.call(e.score)) if score_text.is_valid() else Scoreboard.format(e.score)
		rows.append({"text": "%s   %s   %s" % [Scoreboard.ordinal(e.rank), p.player_name, text], "color": p.color})
	var winners := board.winners()
	var heading := title
	if heading == "":
		heading = "Round over"
		if ranking.size() == 1 and not tiers.is_empty():
			# A player without a score gets no medal: the score 0 would beat every limit of a time.
			var medal := Medals.medal(ranking[0].score, tiers, board.lower_is_better) if ranking[0].finished else Medals.NONE
			heading = Medals.label(medal)
		elif winners.size() == 1:
			heading = "%s wins!" % player(winners[0]).player_name
		elif winners.size() > 1:
			heading = "Tie!"
	var entries: Array = [["Restart", restart]]
	entries.append_array(extra_entries)
	var id := Registry.id_of_script(get_script())
	if GameSettings.has_view(Registry.find(id)):
		entries.append(["Settings", App.go_game_settings.bind(id)])   # REQ-GM-95
	entries.append(["Back to menu", App.go_menu])
	open_menu(heading, entries, rows)
	Sound.stop_music()
	Sound.sfx("tie" if heading in ["Tie!", "Round over"] else "win")


## The buttons of the open menu (tests use it).
func menu_buttons() -> Array[Button]:
	var r: Array[Button] = []
	if _menu_box != null:
		for b in _menu_box.find_children("*", "Button", true, false):
			r.append(b)
	return r


func close_menu() -> void:
	if _menu_open:
		Sound.duck(false)
		Sound.sfx("resume")
	_menu_open = false
	_menu_kind = ""
	if _menu_box != null:
		_menu_box.queue_free()
		_menu_box = null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	_game_draw()
	_draw_overlays(self)


## Draws the dim layer of a menu on `ci`.
## 2D games draw it on the game itself. 3D games draw it on the HUD layer above the 3D view.
func _draw_overlays(ci: CanvasItem) -> void:
	if _menu_open:
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
