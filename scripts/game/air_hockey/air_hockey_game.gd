extends "res://scripts/game/minigame.gd"
## Air Hockey (REQ-AH-1 to 22). Two seats on a table, each tilts a phone to slide a mallet and hit a black puck at the other goal;
## the first to the goals of the setting (3 to 10) wins. With one phone the other seat is ROBO, the bot (`hockey_bot.gd`,
## REQ-GM-105). The players enroll at every start with A (REQ-GM-106): the first two phones that press A play, the others watch.
## The rink and the puck are in air_hockey_sim.gd, the pictures in air_hockey_look.gd. The game is for children too
## (REQ-GM-80 to 84): a goal takes nothing away, and nobody is out.

const Sim = preload("res://scripts/game/air_hockey/air_hockey_sim.gd")
const Look = preload("res://scripts/game/air_hockey/air_hockey_look.gd")
const HockeyBot = preload("res://scripts/game/air_hockey/hockey_bot.gd")
const Haptics = preload("res://scripts/game/haptics.gd")

const GOAL_BANNER := 2.0        # REQ-AH-9: how long the banner of a goal shows.
const HINT_TIME := 6.0
const BUZZ_GAP_MS := 150
const HIT_BUZZ_SPEED := 450.0   # A hit that sends the puck away faster than this buzzes the phone (REQ-AH-12).
const WALL_SOUND_SPEED := 450.0
const CHIP_Y := 940.0
const CHIP_H := 64.0
const BANNER_FONT := 72
const FIRST_TO_X := 560.0
const FIRST_TO_W := 360.0

enum Phase { ENROLL, PLAY, GOAL }

## Set before the game starts (REQ-GM-93). `start_props` keeps them for Try again.
var difficulty := "medium"
var goals := "5"

var sim := Sim.new()
var phase := Phase.ENROLL
var bot: HockeyBot = null        # ROBO, when one phone plays.
var seats: Array[Dictionary] = []   # Seat 0 (left) and 1 (right): {slot (-1 for the bot), name, color, avatar}.
var scores: Array[int] = [0, 0]
var banner_text := ""

var _enrolled: Array[int] = []
var _board: Scoreboard
var _banner_left := 0.0
var _serve_seat := -1            # The seat that conceded the last goal: the puck is served on its side.
var _haptics := Haptics.new()
var _time := 0.0


func _has_countdown() -> bool:
	return false   # No visible timer, so no countdown (REQ-GM-35).


func goals_to_win() -> int:
	return clampi(int(goals), 3, 10)


func _game_ready() -> void:
	for s in participants:
		player(s).button_pressed.connect(_on_button.bind(s))
	if participants.size() == 1:
		_enroll(participants[0])


func _exit_tree() -> void:
	for s in participants:
		var cb := _on_button.bind(s)
		if player(s).button_pressed.is_connected(cb):
			player(s).button_pressed.disconnect(cb)


## REQ-GM-106: a press on A of a phone enrolls it. The second phone starts the match.
func _on_button(bit: int, slot: int) -> void:
	if bit != Protocol.BTN_A or phase != Phase.ENROLL or is_paused() or is_over:
		return
	_enroll(slot)


func _enroll(slot: int) -> void:
	if phase != Phase.ENROLL or _enrolled.has(slot):
		return
	_enrolled.append(slot)
	Sound.sfx("join")
	game_host.haptic(slot, 40)
	if _enrolled.size() >= 2 or participants.size() == 1:
		_start_match()


## The TV remote starts the match with the one phone that enrolled, against ROBO (REQ-GM-106).
func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.ENROLL and not _menu_open and not is_over and _enrolled.size() == 1 and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_start_match()


func _start_match() -> void:
	participants = _enrolled.duplicate()
	seats.clear()
	for s in participants:
		seats.append({"slot": s, "name": player(s).player_name, "color": player(s).color, "avatar": player(s).shown_avatar()})
	if participants.size() == 1:
		bot = HockeyBot.new(difficulty, 1, int(Time.get_ticks_usec()))
		seats.append({"slot": -1, "name": Lang.t("air_hockey.bot_name"), "color": Look.BOT_COLOR, "avatar": -1})
	_board = Scoreboard.new(participants)
	game_host.set_phase("playing", participants)   # The other phones watch: their pad says "waiting".
	for s in participants:
		player(s).recenter()   # The pose held when the match starts is the center.
	scores = [0, 0]
	_serve_seat = -1
	sim.reset(-1)
	phase = Phase.PLAY


func _allow_resume_without() -> bool:
	return phase == Phase.ENROLL   # A match cannot go on without a player (REQ-AH-19).


func _can_open_menu() -> bool:
	return super() and phase != Phase.ENROLL


func _in_progress() -> bool:
	return not is_over and not participants.is_empty() and phase != Phase.ENROLL


func _on_player_left(slot: int) -> void:
	_enrolled.erase(slot)
	if _board != null:
		_board.remove(slot)


## REQ-AH-19: a player that left for good ends the match. Before the match the one phone that is left plays ROBO.
func _on_participants_changed() -> void:
	if is_over:
		return
	if phase == Phase.ENROLL:
		if participants.size() == 1:
			_enroll(participants[0])
	elif participants.size() < seats.size() - (1 if bot != null else 0):
		_finish()


func _game_tick(delta: float) -> void:
	_time += delta
	if is_over:
		return
	match phase:
		Phase.PLAY:
			_tick_play(delta)
		Phase.GOAL:
			_banner_left -= delta
			if _banner_left <= 0.0:
				sim.reset(_serve_seat)
				if bot != null:
					bot.reset()
				phase = Phase.PLAY


## The tilt of a seat: a phone, or the bot.
func seat_tilt(seat: int, delta: float) -> Vector2:
	var slot := int(seats[seat].slot)
	if slot >= 0:
		return player(slot).tilt()
	var pad := sim.paddles[seat]
	return bot.tilt(delta, {"puck_pos": sim.puck_pos, "puck_vel": sim.puck_vel, "pad_pos": pad.pos, "pad_vel": pad.vel})


func _tick_play(delta: float) -> void:
	var ev := sim.step(delta, [seat_tilt(0, delta), seat_tilt(1, delta)])
	if int(ev.hit) >= 0 and float(ev.hit_speed) > 0.0:
		_on_hit(int(ev.hit), float(ev.hit_speed))
	elif float(ev.wall) > WALL_SOUND_SPEED:
		Sound.sfx("hockey_wall")
	if int(ev.goal) >= 0:
		_goal(int(ev.goal))


## REQ-AH-12: a hit that is hard enough buzzes the phone of the paddle and makes a sound.
func _on_hit(seat: int, speed: float) -> void:
	if speed < HIT_BUZZ_SPEED:
		return
	Sound.sfx("hockey_hit")
	var slot := int(seats[seat].slot)
	if slot >= 0:
		_haptics.pulse(slot, 25, BUZZ_GAP_MS)


## REQ-AH-9: a goal gives a point to the other seat, a banner shows, and the puck is served again. Nothing is taken away.
func _goal(scorer: int) -> void:
	scores[scorer] += 1
	_serve_seat = 1 - scorer
	var slot := int(seats[scorer].slot)
	if slot >= 0:
		_board.add(slot, 1.0)
		game_host.haptic(slot, 120)
	Sound.sfx("hockey_goal")
	if scores[scorer] >= goals_to_win():
		_finish()
		return
	banner_text = Lang.f("air_hockey.goal_for", [String(seats[scorer].name)])
	phase = Phase.GOAL
	_banner_left = GOAL_BANNER


## REQ-AH-10: the match is over. With ROBO the rows are made here (ROBO is not a phone, REQ-GM-105); with two phones the shared
## result menu ranks them (REQ-GM-72, 73). After a leave only the player that stays is on the board: a technical win (REQ-AH-19).
func _finish() -> void:
	if bot != null:
		if scores[0] > scores[1]:
			game_host.haptic(int(seats[0].slot), 400)
		_finish_with_bot()
		return
	for s in _board.winners():
		game_host.haptic(s, 400)
	open_results(_board)


func _finish_with_bot() -> void:
	var order: Array[int] = [0, 1]
	if scores[1] > scores[0]:
		order = [1, 0]
	var rows: Array = []
	for i in order.size():
		var seat := order[i]
		var spec := _result_spec(float(scores[seat]))
		var goals := ResultText.spec_text(spec)
		rows.append({"text": "%s   %s   %s" % [Scoreboard.ordinal(i + 1), seats[seat].name, goals],
				"color": seats[seat].color, "avatar": seats[seat].avatar,
				"slot": seats[seat].slot, "cells": [Scoreboard.ordinal(i + 1), seats[seat].name, goals],
				"rank": i + 1, "spec": spec})
	var heading := Lang.f("result.winner", [String(seats[order[0]].name)])
	open_result_menu(heading, rows, [], order[0] == 0)


## "3 goals" for the result list.
func _goals_text(value: float) -> String:
	return ResultText.spec_text(_result_spec(value))


## The score as data for the result list and for the phone (issue #470).
func _result_spec(value: float) -> Array:
	return ResultText.spec("air_hockey.one_goal") if int(value) == 1 else ResultText.spec("air_hockey.n_goals", [int(value)])


func _scoreboard() -> Scoreboard:
	return _board if bot == null else null   # With ROBO a rank of one player would say nothing (REQ-GM-105).


# ---- Drawing ----

func _pixel_world() -> bool:
	return true


func _world_draw(ci: CanvasItem) -> void:
	_fit_design(CHIP_Y, CHIP_H)   # The simulation stays in design units; only the drawing is scaled (REQ-AH-23).
	ci.draw_set_transform(design_off, 0.0, Vector2(design_k, design_k))
	Look.draw_table(ci, size / design_k, -design_off / design_k)
	if phase == Phase.ENROLL:
		Look.draw_puck(ci, Shell.snap(Sim.RINK.get_center()))
		return
	for i in seats.size():
		Look.draw_paddle(ci, Shell.snap(sim.paddles[i].pos), seats[i].color)
	Look.draw_puck(ci, Shell.snap(sim.puck_pos))


func _game_draw() -> void:
	_fit_design(CHIP_Y, CHIP_H)
	Shell.title(self, "registry.air_hockey")
	if phase == Phase.ENROLL:
		_draw_enroll()
		return
	draw_leader_chip(self)
	if not is_over:
		Shell.status(self, FIRST_TO_X, FIRST_TO_W + 80.0, Lang.f("air_hockey.first_to", [goals_to_win()]))
	_draw_chips()
	if phase == Phase.GOAL and not is_over:
		Shell.label_plate(self, Vector2(size.x * 0.5, size.y * 0.5 + 24.0), banner_text, BANNER_FONT, UiTheme.ACCENT)
	if _time < HINT_TIME and phase == Phase.PLAY and not is_over:
		Shell.hint(self, size, "air_hockey.tilt_to_slide", _chip_y() - 16.0)   # Above the chips, not over them (issue #223).


## Under the table, each chip under its own goal. The chip keeps its size (text never shrinks, REQ-FL-40); only its place scales.
func _chip_y() -> float:
	return _to_screen(Vector2(0.0, CHIP_Y)).y


func _chip_pos(seat: int, w: float) -> Vector2:
	var x := _to_screen(Sim.RINK.position).x if seat == 0 else _to_screen(Sim.RINK.end).x - w
	return Vector2(x, _chip_y())


## The two score chips under the table, each under its own goal (the table is not mirrored in Hebrew, REQ-GM-47o).
func _draw_chips() -> void:
	for i in seats.size():
		var seat: Dictionary = seats[i]
		var score := str(scores[i])
		var w := Shell.score_chip_width(String(seat.name), score, 64.0, 250.0, Shell.CHIP_FONT, int(seat.avatar))
		Shell.score_chip(self, _chip_pos(i, w), String(seat.name), score, seat.color, w, 64.0, int(seat.avatar))


## Before the match: who is in, and how to start.
func _draw_enroll() -> void:
	var mid := size.y * 0.5
	Shell.label_plate(self, Vector2(size.x * 0.5, mid - 70.0), "air_hockey.press_a", 56, UiTheme.ACCENT)
	if _enrolled.size() == 1 and participants.size() >= 2:
		Shell.label_plate(self, Vector2(size.x * 0.5, mid + 50.0), Lang.f("air_hockey.or_ok_robo", [Lang.t("air_hockey.bot_name")]),
				32, UiTheme.TEXT)
	for i in _enrolled.size():
		var p := player(_enrolled[i])
		var w := Shell.score_chip_width(p.player_name, Lang.t("setup.in"), 64.0, 250.0, Shell.CHIP_FONT, p.shown_avatar())
		Shell.score_chip(self, _chip_pos(i, w), p.player_name, Lang.t("setup.in"), p.color, w, 64.0, p.shown_avatar())
