extends Control
## Base class for minigames. A minigame reads PlayerInput objects and draws.
## It does not use any networking script. To add a minigame:
##   1. Make a folder under scripts/game/.
##   2. Extend this script. Override _game_ready(), _game_tick(), _game_draw().
##   3. Add one entry for it in scripts/game/registry.gd.
## This base class handles: player list, pause while a phone is lost,
## the D-pad pause menu (Resume / Try again / Menu), and the back key.
## It is the game shell (REQ-GM-45): the menus here and the helpers in shell.gd have the arcade style.
## A 2D game may draw its world at a low resolution (REQ-GM-47a): it returns true from `_pixel_world()` and draws the world in
## `_world_draw()`. The HUD stays in `_game_draw()`, at full resolution.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Shell = preload("res://scripts/game/shell.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")
const MedalView = preload("res://scripts/ui/medal_view.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")
const Medals = preload("res://scripts/game/medals.gd")
const Registry = preload("res://scripts/game/registry.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const Lang = preload("res://scripts/core/lang.gd")

## The size of the low-resolution world view and of the screen it stands for (REQ-GM-47a).
const PIXEL_VIEW := Vector2i(480, 270)
const DESIGN_SIZE := Vector2i(1920, 1080)

## Values the game was started with (App.go props). restart() uses them again.
var start_props := {}

## Slots that joined when the game started.
var participants: Array[int] = []

## How many players the round started with (REQ-GM-73): a round that started with one player gives no medal. 0 until the game
## is ready.
var players_at_start := 0

## True when the game has ended: a winner, or nobody is left. A game sets it when it opens its result menu.
## The pause menu cannot open and leaving does not ask (REQ-GM-31a) while it is true.
var is_over := false

var _menu_box: Control
var _menu_open := false
var _menu_kind := ""             # "hold" for the card of a lost phone, "menu" for the other menus.
var _hold := false               # A participant lost its connection: the game waits for a decision (REQ-GM-30).
## A game sets this before `open_results()` when the round gives no medal even with more than one player (a team game, or a
## match that ended by a leave).
var no_medals := false
var _hold_info := {}             # slot -> {name, color} of the players lost in this hold.
var _hold_sig := ""
var _pixel_viewport: SubViewport
## True only for the picture of a game tile (tools/make_tiles.gd, REQ-GM-49): the game draws its world and no HUD.
var tile_mode := false
var _pixel_layer: Control        # Draws the world of a pixel game, inside the low-resolution view.


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	participants = App.server.players_in()   # The phones that chose OUT in the settings view do not play (REQ-GM-104).
	players_at_start = participants.size()
	var entry := Registry.find(Registry.id_of_script(get_script()))
	App.server.recenter_button = Registry.has_control(entry, "recenter")   # REQ-GM-37
	App.server.pad_buttons = Registry.buttons_of(entry)   # REQ-GM-37a
	App.server.set_phase("playing", participants)
	Sound.duck(false)
	if _has_countdown():
		Sound.music_at_go(Registry.id_of_script(get_script()))   # The song starts at GO (REQ-FL-65a).
	else:
		Sound.music(Registry.id_of_script(get_script()))   # No countdown: the song starts with the play (REQ-GM-35).
	if _pixel_world():
		_build_pixel_view()
	_game_ready()
	if participants.is_empty():
		end_no_players()


## True when the game starts with the 3 s countdown (REQ-GM-35). Only a game with a visible timer has one; the others
## start at once and their song starts with the play. A game answers this in `_ready()` time: `participants` is set.
func _has_countdown() -> bool:
	return true


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
	open_menu("minigame.no_players_connected", [["minigame.back_to_menu", App.go_menu]])


func is_paused() -> bool:
	return _menu_open


func _process(delta: float) -> void:
	_prune_participants()
	_update_hold()
	if not is_paused():
		_game_tick(delta)
	_publish_scores()
	_request_redraw()


## The place and the score of every player, for the leader chip and the phones (REQ-GM-46, REQ-FL-67). A game with a score or a
## ranking returns its `Scoreboard` here. The default is null: no chip, and the phones show no score.
func _scoreboard() -> Scoreboard:
	return null


## The score of `slot` as text, for the chip and the phone. The default is the number of the `Scoreboard`; a ranking without
## a score yet (a race before the finish) gives an empty text.
func _score_label(entry: Dictionary) -> String:
	return Scoreboard.format(entry.score) if entry.finished else ""


## Sends each player its place and score (the server sends a changed message only).
func _publish_scores() -> void:
	var board := _scoreboard()
	if board == null:
		return
	var ranking := board.ranking()
	var lead := board.has_lead()   # Nobody has a place while everybody is level at 0 (REQ-FL-67).
	for e in ranking:
		App.server.send_score(e.slot, e.rank if lead else 0, ranking.size() if lead else 0, _score_label(e))


## The score text on the leader chip: the score of the first leader, empty when there is no board or no player.
func leader_text() -> String:
	var board := _scoreboard()
	if board == null or board.leaders().is_empty():
		return ""
	return _score_label(board.leaders()[0])


## The leader chip (REQ-GM-46): the leader of the round, or TIE, with the score. A game without `_scoreboard()` has none, and
## nobody shows while the best score is 0.
func draw_leader_chip(ci: CanvasItem) -> void:
	var board := _scoreboard()
	if board == null or not board.has_lead():
		return
	var leaders := board.leaders()
	Shell.leader_chip(ci, Shell.area_width(ci), leaders.map(func(e: Dictionary) -> Object: return player(e.slot)), leader_text())


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
			_hold_info[s] = {"name": player(s).player_name, "color": player(s).color, "label": slot_label(s),
					"avatar": player(s).avatar}
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


## How the cards name a player: the profile name, or "2P" for a phone without a profile (FD-22, REQ-GM-30).
func slot_label(slot: int) -> String:
	var p := player(slot)
	return p.player_name if p.has_profile() else "%dP" % (slot + 1)


func _slot_labels(slots: Array) -> String:
	var parts: Array[String] = []
	for s in slots:
		parts.append(String(_hold_info[s].label) if _hold_info.has(s) and _hold_info[s].has("label") else slot_label(int(s)))
	return Lang.t("pause.and").join(parts)


func _show_hold_card(lost: Array[int]) -> void:
	var rows: Array = []
	var gone: Array[int] = []
	for s in _hold_info:
		var info: Dictionary = _hold_info[s]
		var state := Lang.t("pause.left_game")
		if lost.has(s):
			state = Lang.t("pause.waiting_reconnect")
		elif participants.has(s):
			state = Lang.t("pause.is_back")
		else:
			gone.append(s)
		rows.append({"text": "%s   %s" % [info.name, state], "color": info.color, "avatar": info.get("avatar", -1)})
	var title: String
	var entries: Array = []
	if not lost.is_empty():
		title = Lang.f("pause.lost_connection", [_slot_labels(lost)])
		if participants.size() == 1:
			title = Lang.t("minigame.no_players_connected")   # The only phone is gone (REQ-GM-30a, issue #46).
		if not connected_participants().is_empty() and _allow_resume_without():
			entries.append([Lang.f("pause.resume_without", [_slot_labels(lost)]), _resume_without_lost])
	else:
		title = Lang.f("pause.left", [_slot_labels(gone)]) if not gone.is_empty() and gone.size() == _hold_info.size() \
				else Lang.f("pause.reconnected", [_slot_labels(_hold_info.keys())])
		entries.append(["minigame.resume", _resume_game])
	entries.append(["minigame.end_game", request_leave, "danger"])
	open_menu(title, entries, rows)
	_menu_kind = "hold"


## True when the card of a lost phone may offer "Resume without ...". A game that cannot go on without a player (Air Hockey
## after the players enrolled) returns false: the card has Resume (when the phone is back) and End game only.
func _allow_resume_without() -> bool:
	return true


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


## The items of the pause menu. End game leaves at once, no question (REQ-GM-31).
func pause_entries() -> Array:
	return [["minigame.resume", close_menu], ["minigame.restart", restart], ["minigame.end_game", App.go_menu, "danger"]]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _menu_open and _can_open_menu():
		open_menu("minigame.paused", pause_entries())
		get_viewport().set_input_as_handled()


func on_back() -> void:
	if is_over:
		App.go_menu() # The result menu and "No players connected" leave at once (REQ-GM-31a).
	elif _menu_open and _menu_kind != "hold":
		close_menu() # Also the "End the game?" question: Back is "Keep playing".
	else:
		request_leave() # On the card of a lost phone, Back asks to end the game.


## Leaves the game for the Games screen (REQ-GM-31a). While the game is in progress it asks first: a round
## must not end by a slip of the thumb. A game that is over (result menu, no players) leaves at once.
func request_leave() -> void:
	if _in_progress():
		open_menu("minigame.end_game_ask", [["minigame.resume_play", close_menu], ["minigame.end_game", App.go_menu, "danger"]])
	else:
		App.go_menu()


func restart() -> void:
	App.go(get_script(), start_props)


const MENU_CARD_W := 1200


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
	var card := UiKit.panel(32)
	card.custom_minimum_size = Vector2(MENU_CARD_W, 0)   # Wide enough that a Hebrew message is not one word to a line.
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	var l := UiKit.title(title, 48, UiTheme.TEXT)   # A message is white: yellow is the color of the focused item.
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(l)
	for r in rows:
		box.add_child(_menu_row(String(r.text), r.color, int(r.get("avatar", -1)), String(r.get("medal", ""))))
	var items := UiKit.menu(entries)
	items.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(items)
	var first: Button = items.get_child(0)
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	first.grab_focus()


## One line of the result list: a square in the player color, the avatar of the player when there is one (REQ-GM-46b), the medal
## of the place (REQ-GM-73), and the text.
func _menu_row(text: String, color: Color, avatar := -1, medal_tier := "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var square := ColorRect.new()
	square.color = color
	square.custom_minimum_size = Vector2(24, 24)
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(square)
	if Shell.has_chip_avatar(avatar):
		var av := AvatarView.new(avatar, 48.0)
		av.tappable = false
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(av)
	if medal_tier != "":
		row.add_child(MedalView.new(medal_tier))
	row.add_child(UiKit.label(text, UiTheme.SIZE_BODY))
	return row


## Ends a round with scores (REQ-GM-34, 72, 73): sets `is_over` and opens the result menu. It lists the ranking, and its
## buttons are Try again, then `extra_entries` (for example Choose track), then Back to menu.
## - The title names the single winner, or says "Tie!", or says "Round over" when nobody has a score.
##   `title` replaces it (a game puts the difficulty there).
## - With more than one player every row has the medal of its place: 1st gold, 2nd silver, 3rd bronze (`Medals.for_place()`).
##   A round that started with one player has no medal and no medal title (REQ-GM-73, issue #119).
## - `score_text` turns a score into text for the list (default `Scoreboard.format`). A player without a score shows
##   "not finished".
## A game with teams sets this before `open_results()` when a team won: two winners of the board are not a tie then.
var team_won := false


func open_results(board: Scoreboard, title := "", extra_entries: Array = [], score_text := Callable()) -> void:
	is_over = true
	var ranking := board.ranking()
	var rows: Array = []
	for e in ranking:
		var p := player(e.slot)
		var text := Lang.t("result.not_finished")
		if e.finished:
			text = String(score_text.call(e.score)) if score_text.is_valid() else Scoreboard.format(e.score)
		rows.append({"text": "%s   %s   %s" % [Scoreboard.ordinal(e.rank), p.player_name, text], "color": p.color,
				"avatar": p.avatar})
	_send_best_results(ranking)
	var winners := board.winners()
	var heading := title
	var solo := players_at_start == 1 or ranking.size() == 1   # One player in the round or left in the result: no medal.
	for i in ranking.size():   # More than one player: the medal of the place, 1st gold, 2nd silver, 3rd bronze.
		if ranking[i].finished and not no_medals and not solo:
			rows[i]["medal"] = Medals.for_place(ranking[i].rank)
	if heading == "":
		heading = Lang.t("minigame.round_over")
		if winners.size() == 1:
			heading = Lang.f("result.winner", [player(winners[0]).player_name])
		elif winners.size() > 1:
			heading = Lang.t("minigame.tie")
	# `win` for a winner; `tie` for a tie and for "Round over" (REQ-FL-65).
	var won := winners.size() == 1 or team_won
	open_result_menu(heading, rows, extra_entries, won)


## The result menu itself: the rows, then Try again, `extra_entries`, New game (a game with a settings view) and Back to menu.
## `open_results()` builds the rows from a `Scoreboard`; a game whose result has a player that is not a phone (the bot of Air
## Hockey, REQ-GM-105) builds its own rows and calls this. It sets `is_over`.
func open_result_menu(heading: String, rows: Array, extra_entries: Array = [], won := false) -> void:
	is_over = true
	var entries: Array = [["minigame.restart", restart]]
	entries.append_array(extra_entries)
	var id := Registry.id_of_script(get_script())
	if GameSettings.has_view(Registry.find(id)):
		entries.append(["minigame.new_game", App.go_game_settings.bind(id)])   # REQ-GM-95: back to the settings of the game
	entries.append(["minigame.back_to_menu", App.go_menu])
	open_menu(heading, entries, rows)
	Sound.stop_music()
	Sound.sfx("win" if won else "tie")


## The key of the personal best of this game and its settings (REQ-GM-98), for example `snowball_splat|medium`; a key of
## `ProfileKeys`. An empty text means the game has no personal best (Treasure Maze, Sumo Bumpers, a random track of the race).
func best_key() -> String:
	return ""


## A score of the `Scoreboard` as the whole number that is saved in a profile: a score as it is, a time in milliseconds.
func best_value(score: float) -> int:
	return roundi(score)


## Sends each finished player with a profile its result for the personal best (REQ-GM-99). A player without a score (not
## finished), a score of 0 and a game without a key send nothing. A restart is a new round and sends again.
func _send_best_results(ranking: Array) -> void:
	var key := best_key()
	if key == "":
		return
	for e in ranking:
		var v := best_value(e.score)
		if e.finished and v > 0:
			App.server.send_result(e.slot, key, v)


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
	if _pixel_layer == null:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	if tile_mode:
		return
	_game_draw()
	_draw_overlays(self)


## Draws the dim layer of a menu on `ci`.
## 2D games draw it on the game itself. 3D games draw it on the HUD layer above the 3D view.
func _draw_overlays(ci: CanvasItem) -> void:
	if _menu_open:
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(UiTheme.BG, 0.8))


## Called every frame. Subclasses with more canvas layers redraw them here.
func _request_redraw() -> void:
	queue_redraw()
	if _pixel_layer != null:
		_pixel_layer.queue_redraw()


## The world of a pixel game is drawn into a 480x270 view that stands for the 1920x1080 screen (the drawing code keeps its
## 1920x1080 units), and the view is scaled up with nearest filtering, so that one world pixel is 4x4 screen pixels. It is
## drawn behind the game node, so the HUD, the menus and the dim layer stay at full resolution on top (REQ-GM-47a).
func _build_pixel_view() -> void:
	_pixel_viewport = SubViewport.new()
	_pixel_viewport.size = PIXEL_VIEW
	_pixel_viewport.size_2d_override = DESIGN_SIZE
	_pixel_viewport.size_2d_override_stretch = true
	_pixel_viewport.disable_3d = true
	_pixel_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_pixel_viewport)
	_pixel_layer = Control.new()
	_pixel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pixel_layer.size = Vector2(DESIGN_SIZE)
	_pixel_layer.draw.connect(func(): _world_draw(_pixel_layer))
	_pixel_viewport.add_child(_pixel_layer)
	resized.connect(_fit_pixel_view)   # The view stands for the whole screen, whatever its size.
	var view := TextureRect.new()
	view.texture = _pixel_viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.z_index = -1
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_pixel_view()


# ---- Override in subclasses ----

func _game_ready() -> void:
	pass


func _game_tick(_delta: float) -> void:
	pass


func _game_draw() -> void:
	pass


func _fit_pixel_view() -> void:
	if size.x > 0.0 and size.y > 0.0:
		_pixel_viewport.size_2d_override = Vector2i(size)
		_pixel_layer.size = size


## True when the world of the game is drawn in the low-resolution view (REQ-GM-47a).
func _pixel_world() -> bool:
	return false


## Draws the world of a pixel game on `ci`, in 1920x1080 units. It fills the whole view itself.
func _world_draw(_ci: CanvasItem) -> void:
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
