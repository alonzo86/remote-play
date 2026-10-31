extends SceneTree
## Helpers shared by the minigames: RoundClock (REQ-GM-35, 71), Haptics (REQ-GM-43), the leader chip (REQ-GM-46),
## Scoreboard (REQ-GM-70, 72) and Medals (REQ-GM-73).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/game_helpers.gd -- --role=controller

const Lang = preload("res://scripts/core/lang.gd")
const Registry = preload("res://scripts/game/registry.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Scoreboard = preload("res://scripts/game/scoreboard.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const SumoArena = preload("res://scripts/game/sumo_bumpers/sumo_arena.gd")
const SumoLook = preload("res://scripts/game/sumo_bumpers/sumo_look.gd")

var SnowGame: GDScript   # Loaded at run time: a game script needs the App autoload.
var _checks := 0
var _fails := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	SnowGame = load("res://scripts/game/snowball_splat/snowball_splat_game.gd")
	_round_clock()
	_haptics()
	_shell_leader()
	_shell_layout()
	_label_plate()
	_score_chip()
	_chip_avatar()
	await _medal_icon()
	_fit_size()
	_pixel_world()
	_round_length()
	_scoreboard()
	_medals()
	_game_settings()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## A plain array copy, so that a typed Array[int] can be compared with a literal.
func _ints(a: Array) -> Array:
	return a.map(func(x): return x)


## The helpers of a pixel world (REQ-GM-47i to 47n).
func _pixel_world() -> void:
	print("pixel world")
	var Sumo = load("res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd")
	var Minigame = load("res://scripts/game/minigame.gd")
	_check(Minigame.PIXEL_VIEW * 4 == Minigame.DESIGN_SIZE and Shell.WORLD_PIXEL == 1920.0 / Minigame.PIXEL_VIEW.x,
			"the view is 480x270 and one world pixel is 4 screen pixels at 1920x1080")
	_check(Shell.snap(Vector2(9.0, 5.0)) == Vector2(8.0, 4.0) and Shell.snap(Vector2(10.0, 14.0)) == Vector2(12.0, 16.0)
			and Shell.snap(Vector2(-3.0, 2.0)) == Vector2(-4.0, 4.0), "a position moves to the nearest world pixel")
	_check(Sumo.fall_scale(0.0) == 1.0 and Sumo.fall_scale(0.15) == 1.0 and Sumo.fall_scale(0.25) == 0.75
			and Sumo.fall_scale(0.45) == 0.5 and Sumo.fall_scale(0.7) == 0.25 and Sumo.fall_scale(Sumo.FALL_TIME) == 0.0
			and Sumo.fall_scale(5.0) == 0.0, "a fallen bumper shrinks in 4 steps and then is gone (REQ-SB-9)")
	_check(Sumo.danger_ring(0.0).is_equal_approx(SumoLook.RIM) and Sumo.danger_ring(1.0).is_equal_approx(SumoLook.DANGER)
			and Sumo.danger_ring(0.6).r > SumoLook.RIM.r, "the island edge turns red as the island gets small (REQ-SB-15)")
	var life: float = SnowGame.POOF_LIFE
	var steps := []
	for share in [0.0, 0.4, 0.9, 5.0]:
		steps.append(SnowGame.poof_step(life * share))
	_check(steps == [0, 1, 2, 2], "the poof of a missed banana grows in 3 hard steps: %s" % str(steps))
	_check(SnowGame.CURSOR_R * 2.0 >= 12.0 * Shell.WORLD_PIXEL, "the cursor ring is 12 world pixels or more across (REQ-GM-47m)")
	var sky := Shell.star_field(48, 7)
	var on_grid := true
	for st in sky:
		on_grid = on_grid and fmod(st.x, Shell.WORLD_PIXEL) == 0.0 and fmod(st.y, Shell.WORLD_PIXEL) == 0.0 \
				and st.x >= 0.0 and st.x < 1920.0 and st.y >= 0.0 and st.y < 1080.0
	_check(sky.size() == 48 and on_grid and sky == Shell.star_field(48, 7) and sky != Shell.star_field(48, 8),
			"the star pixels are on the world pixel grid, inside the screen, and the same for the same seed")
	var min_ball: float = SumoArena.BUMPER_R * 2.0
	_check(min_ball >= 12.0 * Shell.WORLD_PIXEL, "a bumper is 12 world pixels or more across (REQ-GM-47m): %.0f px" % min_ball)
	var worst := 99.0
	for col in Protocol.PLAYER_COLORS:   # A penguin is cut out of the grass by its black outline (like REQ-MR-43).
		worst = minf(worst, Shell.contrast(col, SumoLook.OUTLINE))
	_check(worst >= 3.0,
			"every player color has a contrast of 3:1 or more on the black outline of a penguin (REQ-GM-47m): %.2f" % worst)
	_check(Shell.contrast(SumoLook.OUTLINE, SumoLook.GRASS_A) >= 3.0 and Shell.contrast(SumoLook.OUTLINE, SumoLook.GRASS_B) >= 3.0
			and Shell.contrast(SumoLook.OUTLINE, SumoLook.SKY_BOTTOM) >= 3.0,
			"the outline of a penguin differs from both grass tones and from the sky by 3:1 or more (REQ-SB-15)")
	_sumo_look()


func _sumo_look() -> void:
	var a: Image = SumoLook.penguin_image(Protocol.PLAYER_COLORS[0], 0)
	_check(a.get_width() == 18 and a.get_height() == 18, "a penguin is 16x16 world pixels plus a one pixel outline")
	_check(a.get_pixel(0, 0).a == 0.0 and a.get_pixel(9, 0).is_equal_approx(SumoLook.OUTLINE),
			"the corners are empty and the top of the head has the outline")
	var left: Image = SumoLook.penguin_image(Protocol.PLAYER_COLORS[0], -1)
	var right: Image = SumoLook.penguin_image(Protocol.PLAYER_COLORS[0], 1)
	_check(left.get_data() != right.get_data() and left.get_data() != a.get_data(),
			"the pupils look to the side the penguin rolls")
	var green: Image = SumoLook.penguin_image(Protocol.PLAYER_COLORS[1], 0)
	_check(green.get_pixel(2, 10).is_equal_approx(Protocol.PLAYER_COLORS[1])
			and a.get_pixel(2, 10).is_equal_approx(Protocol.PLAYER_COLORS[0]),
			"the body of a penguin has the player color")
	var wrapped := true
	for i in SumoLook.CLOUDS.size():
		for t in [0.0, 50.0, 400.0, 5000.0]:
			var x: float = SumoLook.cloud_x(i, t)
			wrapped = wrapped and x >= -float(SumoLook.CLOUDS[i][2]) and x <= SumoLook.VIEW_W + float(SumoLook.CLOUDS[i][2])
	_check(wrapped and SumoLook.cloud_x(0, 10.0) > SumoLook.cloud_x(0, 0.0),
			"the clouds drift to the right and come back on the left")
	_check(SumoLook.rim_color(0.0).is_equal_approx(SumoLook.RIM) and SumoLook.rim_color(1.0).is_equal_approx(SumoLook.DANGER),
			"the rim of the island goes from brown to red")
	_check(SumoLook._inside(Rect2(-5, -5, 10, 10), Vector2.ZERO, 8.0)
			and not SumoLook._inside(Rect2(-5, -5, 10, 10), Vector2.ZERO, 6.0),
			"a grass square is drawn only when all of it is inside the island")


func _round_clock() -> void:
	print("round clock")
	var c = RoundClock.new()
	_check(c.is_counting() and not c.is_playing() and c.count_number() == 3, "a new clock counts down from 3 (REQ-GM-35)")
	_check(not c.tick(0.5) and c.count_number() == 3 and is_equal_approx(c.count_elapsed(), 0.5),
			"after 0.5 s the number is still 3 and half a second old")
	c.tick(0.6)
	_check(c.count_number() == 2 and is_equal_approx(c.count_elapsed(), 0.1), "after 1.1 s the number is 2")
	_check(not c.tick(1.0) and c.count_number() == 1, "after 2.1 s the number is 1")
	var started: bool = c.tick(1.0)
	_check(started and c.is_playing() and c.count_number() == 0 and is_equal_approx(c.time, 0.1),
			"the tick that ends the countdown says so, and keeps the overshoot (%.2f)" % c.time)
	_check(not c.tick(1.0) and is_equal_approx(c.time, 1.1), "later ticks add time and do not say it again")
	var short = RoundClock.new(1.0)
	_check(short.tick(1.0) and short.is_playing() and short.time == 0.0, "a countdown of 1 s ends after 1 s")
	var frames = RoundClock.new()
	var ends := 0
	for i in 400:
		if frames.tick(1.0 / 60.0):
			ends += 1
	_check(ends == 1 and frames.is_playing(), "the countdown ends once at 60 fps")


func _haptics() -> void:
	print("haptics cool-down")
	var h = load("res://scripts/game/haptics.gd").new()
	_check(h.allow(0, 150, 1000), "the first pulse of a slot is allowed")
	_check(not h.allow(0, 150, 1100), "a second pulse 100 ms later waits for the 150 ms cool-down")
	_check(h.allow(0, 150, 1150), "a pulse 150 ms after the first is allowed")
	_check(h.allow(1, 150, 1160), "the cool-down of one slot does not block another slot")
	_check(not h.allow(0, 150, 1200), "a refused pulse is not noted: 50 ms after the pulse at 1150 is too early")
	_check(h.allow(0, 150, 1300), "and 150 ms after the pulse at 1150 is allowed")


func _shell_leader() -> void:
	print("leader chip")
	var board = Scoreboard.new([0, 1, 2])
	_check(board.leaders().size() == 3, "before anybody scores all players lead: a tie (REQ-GM-46)")
	_check(not board.has_lead(), "no leader chip while everybody has 0 (REQ-GM-46)")
	board.add(1, 5.0)
	var lead: Array = board.leaders()
	_check(lead.size() == 1 and lead[0].slot == 1 and lead[0].score == 5.0, "one leader: the slot with the best score")
	_check(board.has_lead(), "the chip shows as soon as the best score is above 0")
	board.add(2, 5.0)
	_check(board.leaders().map(func(e): return e.slot) == [1, 2], "equal best scores are a tie, in slot order")
	board.remove(1)
	board.remove(2)
	_check(board.leaders().map(func(e): return e.slot) == [0], "a player that left does not lead; the last one leads alone")
	_check(Scoreboard.new([]).leaders().is_empty() and not Scoreboard.new([]).has_lead(), "no player, no leader")
	_check(not Scoreboard.new([4]).has_lead(), "one player at 0 shows no chip either")
	var race = Scoreboard.new([], true)
	race.set_unfinished(0, 40.0)
	race.set_unfinished(1, 55.0)
	_check(race.leaders()[0].slot == 1 and not race.leaders()[0].finished,
			"in a race the furthest marble leads before anybody finishes")
	_check(race.has_lead(), "a race with one marble ahead shows its leader")
	race.set_unfinished(1, 40.0)
	_check(not race.has_lead(), "marbles level before the start show no leader")
	race.set_unfinished(1, 55.0)
	race.set_score(2, 31.2)
	_check(race.leaders()[0].slot == 2 and race.leaders()[0].finished, "a finished marble leads over the others")
	# The countdown has no name tags (removed 2026-10-21): the players are known by the color of their objects.
	var shell_script: Script = Shell
	var shell_methods: Array = shell_script.get_script_method_list().map(func(m: Dictionary) -> String: return m.name)
	_check(not shell_methods.has("name_tag_rects") and not shell_methods.has("name_tags"),
			"the shell has no name tags for the countdown")
	var game_methods: Array = ResourceLoader.load("res://scripts/game/minigame.gd").get_script_method_list() \
			.map(func(m: Dictionary) -> String: return m.name)
	_check(not game_methods.has("draw_name_tags"), "a minigame has no hook to draw name tags")


func _shell_layout() -> void:
	print("chip and ball layout")
	_check(is_equal_approx(Shell.leader_chip_x(1920.0, 300.0), 1560.0)
			and is_equal_approx(Shell.leader_chip_x(1280.0, 300.0), 920.0),
			"the leader chip ends at the 60 px safe margin on 1920 and 1280 wide screens (REQ-GM-40)")
	_check(Shell.ball_metrics(24.0).outline == 6.0 and Shell.ball_metrics(20.0).outline == 6.0
			and Shell.ball_metrics(19.0).outline == 4.0, "a ball of 40 px or more has a 6 px outline, a smaller one 4 px (REQ-GM-47b)")


## The black plate behind a banner (REQ-AB-16): as wide as the text of the language, centered on the given x.
func _label_plate() -> void:
	print("label plate")
	var at := Vector2(960.0, 400.0)
	for code in ["en", "he"]:
		Lang.set_language(code, root)
		var short := Shell.label_plate_rect(at, "marble_race.go", 72)
		var long := Shell.label_plate_rect(at, "asteroid_blast.all_ships_gone", 72)
		_check(long.size.x > short.size.x and is_equal_approx(short.get_center().x, 960.0)
				and is_equal_approx(long.get_center().x, 960.0)
				and short.position.y < at.y and short.end.y > at.y,
				"the plate of a banner is as wide as its text, centered, and holds the baseline (%s)" % code)
	Lang.set_language("en", root)


## The chip with a score: the score always shows in full, also with 4 to 6 digits and a long name (REQ-GM-41, 46).
func _score_chip() -> void:
	print("score chip")
	var f: Font = UiTheme.font()
	var height := 64.0
	var all_fit := true
	var name_ok := true
	var widths_ok := true
	for player_name in ["Phone 1", "Sim0", "Player 3", "A very long phone name"]:
		for score in ["0", "85", "1000", "12345", "123456"]:
			var width := Shell.score_chip_width(player_name, score)
			widths_ok = widths_ok and width >= 200.0
			var parts: Dictionary = Shell.score_chip_parts(player_name, score, width, height)
			if parts.score_x + parts.score_w > width - Shell.CHIP_PAD + 0.5 or parts.score_x < parts.name_x:
				all_fit = false
				print("    the score ", score, " does not fit with the name ", player_name)
			var shown := String(parts.name).to_upper()
			var name_end: float = parts.name_x + f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, Shell.CHIP_FONT).x
			if name_end > parts.score_x + 0.5:
				name_ok = false
				print("    the name ", player_name, " runs into the score ", score)
	_check(widths_ok, "a chip is at least 200 px wide")
	_check(all_fit, "a score of 1 to 6 digits ends inside the chip, with any name")
	_check(name_ok, "the name never runs into the score")
	var w4 := Shell.score_chip_width("Phone 1", "1000")
	var short: Dictionary = Shell.score_chip_parts("Phone 1", "1000", w4, height)
	_check(short.name == "Phone 1", "a short name and a score of 4 digits fit together without a cut (the bug of the first try)")
	var w6 := Shell.score_chip_width("A very long phone name", "123456")
	var long_part: Dictionary = Shell.score_chip_parts("A very long phone name", "123456", w6, height)
	_check(long_part.name == "A very long phone name", "a long name is never cut: the chip gets wider")
	_check(w6 > Shell.score_chip_width("Phone 1", "1000"), "a longer name makes a wider chip")
	# The leader chip of the worst size (a name of 16 letters, a score of 5 digits) leaves room for the title and the timer of
	# each game on a 1920 wide screen.
	var worst := Shell.score_chip_width("ABCDEFGHIJKLMNOP", "12345")
	var left := Shell.leader_chip_x(1920.0, worst)
	var room_ok := true
	for path in ["snowball_splat/snowball_splat_game", "paint_grab/paint_grab_game", "sumo_bumpers/sumo_bumpers_game",
			"maze/maze_game"]:
		var consts: Dictionary = load("res://scripts/game/%s.gd" % path).get_script_constant_map()
		if left < float(consts["TIMER_X"]) + float(consts["TIMER_W"]) + 80.0:
			room_ok = false
			print("    no room in ", path)
	_check(room_ok and is_equal_approx(left + worst, 1860.0),
			"the widest leader chip ends at the margin and clears the timer of every game, in one row")


func _round_length() -> void:
	print("round length")
	var c = RoundClock.new(3.0, 45.0)
	_check(is_equal_approx(c.remaining(), 45.0) and not c.is_time_up(), "during the countdown the whole length is left")
	c.tick(3.0)
	c.tick(10.0)
	_check(is_equal_approx(c.remaining(), 35.0) and not c.is_time_up(), "10 s of play leave 35 s")
	c.tick(34.9)
	_check(not c.is_time_up() and c.remaining() > 0.0, "just before the end the time is not up")
	c.tick(0.2)
	_check(c.is_time_up() and c.remaining() == 0.0, "the time is up after 45 s and nothing is left")
	var open_clock = RoundClock.new()
	open_clock.tick(100.0)
	_check(not open_clock.is_time_up() and open_clock.remaining() == 0.0, "a round without a length never ends by time")


func _scoreboard() -> void:
	print("scoreboard")
	var board_script: GDScript = Scoreboard
	var b = board_script.new([2, 0, 1])
	_check(b.size() == 3 and b.score(1) == 0.0 and b.winners().size() == 3, "all players start at 0 and tie for first place")
	b.add(0, 5)
	b.add(0, 2.5)
	b.set_score(2, 7.5)
	b.add(1, 3)
	var r: Array = b.ranking()
	_check(r.map(func(e): return e.slot) == [0, 2, 1] and r.map(func(e): return e.rank) == [1, 1, 3],
			"7.5 and 7.5 share the first place and the next player is third: %s" % str(r))
	_check(_ints(b.winners()) == [0, 2], "a tie has two winners, in slot order")
	b.remove(0)
	_check(_ints(b.winners()) == [2] and b.size() == 2 and not b.has(0), "a player who leaves is not ranked any more")
	_check(b.score(0) == 0.0, "the score of an unknown slot is 0")
	var times = board_script.new([0, 1, 2], true)
	times.set_score(0, 31.2)
	times.set_score(1, 28.9)
	times.set_score(2, 40.0)
	_check(times.ranking().map(func(e): return e.slot) == [1, 0, 2] and _ints(times.winners()) == [1],
			"with lower_is_better the smallest time wins")
	var race = board_script.new([0, 1, 2, 3], true)
	race.set_score(2, 61.5)
	race.set_unfinished(0, 120.0)
	race.set_unfinished(1, 250.0)
	race.set_unfinished(3, 120.0)
	var rr: Array = race.ranking()
	_check(rr.map(func(e): return e.slot) == [2, 1, 0, 3] and rr.map(func(e): return e.rank) == [1, 2, 3, 3]
			and rr.map(func(e): return e.finished) == [true, false, false, false],
			"unfinished players rank after the finished one, the furthest first, equal progress shares a rank: %s" % str(rr))
	_check(_ints(race.winners()) == [2] and race.is_finished(2) and not race.is_finished(1) and race.size() == 4,
			"only a player with a score can win")
	race.set_score(1, 70.0)
	race.remove(0)
	_check(race.is_finished(1) and not race.has(0) and race.size() == 3,
			"set_score finishes a player, remove deletes either kind")
	var nobody = board_script.new([0, 1])
	nobody.set_unfinished(0, 1.0)
	nobody.set_unfinished(1, 2.0)
	_check(nobody.winners().is_empty() and nobody.ranking()[0].slot == 1 and nobody.ranking()[0].rank == 1,
			"nobody has a score: no winner, but the furthest player is listed first")
	var empty = board_script.new()
	_check(empty.ranking().is_empty() and empty.winners().is_empty(), "no player, no ranking")
	_check([1, 2, 3, 4].map(func(n): return board_script.ordinal(n)) == ["1ST", "2ND", "3RD", "4TH"], "ordinals")
	_check(board_script.ordinal(0) == "1ST" and board_script.ordinal(9) == "4TH", "an ordinal outside 1 to 4 stays in range")
	_check(board_script.format(12.0) == "12" and board_script.format(12.5) == "12.5", "a whole score has no decimals")


func _medals() -> void:
	print("medals")
	var medals: GDScript = load("res://scripts/game/medals.gd")
	_check([1, 2, 3, 4, 0, -1].map(func(p): return medals.for_place(p)) == ["gold", "silver", "bronze", "", "", ""],
			"the medal of a place: 1st gold, 2nd silver, 3rd bronze and nobody else (REQ-GM-73)")
	# There are no score tiers (REQ-GM-73, issue #119): the script must not offer them again.
	_check(not medals.has_method("medal") and not medals.has_method("is_valid"), "Medals has no score tiers (REQ-GM-73)")


func _game_settings() -> void:
	print("game settings")
	GameSettings.clear()
	var game := {"id": "t", "settings": [{"key": "mode", "label": "Mode", "values": ["a", "b"], "titles": ["A", "B"]}]}
	var rows := GameSettings.rows_for(game)
	_check(rows.size() == 2 and rows[0].key == "difficulty" and rows[1].key == "mode", "Difficulty is the first row (REQ-GM-91)")
	_check(GameSettings.has_view(game) and GameSettings.has_view({"settings": []}) and not GameSettings.has_view({"id": "x"}),
			"a game has a settings view when its entry has a settings list")
	_check(GameSettings.value(game, rows[0]) == "medium" and GameSettings.value(game, rows[1]) == "a",
			"Medium and the first value are the start values")
	var diff: Dictionary = GameSettings.DIFFICULTY
	_check(GameSettings.step(diff, "easy", 1) == "medium" and GameSettings.step(diff, "medium", 1) == "hard",
			"Right goes to the next value")
	_check(GameSettings.step(diff, "hard", 1) == "hard" and GameSettings.step(diff, "easy", -1) == "easy",
			"the row stops at the last and the first value (REQ-GM-92)")
	GameSettings.set_value(game, rows[0], "hard")
	GameSettings.set_value(game, rows[1], "nope")
	_check(GameSettings.value(game, rows[0]) == "hard" and GameSettings.value(game, rows[1]) == "a",
			"the choice is kept and a value that does not exist is refused (REQ-GM-94)")
	_check(GameSettings.value({"id": "other"}, diff) == "medium", "the choice belongs to one game")
	game["props"] = {"track": 3}
	var props := GameSettings.props_for(game)
	_check(props.difficulty == "hard" and props.mode == "a" and props.track == 3,
			"the props of the game are its own props and the chosen values (REQ-GM-93)")
	_check(GameSettings.title_of(diff, "hard") == "game_settings.hard", "the title of a value")
	var tracks: Dictionary = {}
	for r in GameSettings.rows_for(Registry.find("marble_race")):
		if r.key == "track_choice":
			tracks = r
	Lang.set_language("he", root)
	_check(GameSettings.title_text(tracks, "3") == "מסלול 3"
			and GameSettings.title_text(tracks, "random") == Lang.t("registry.random"),
			"a numbered track title is written in the TV language, not left in English (REQ-FL-63)")
	Lang.set_language("en", root)
	GameSettings.clear()
	_check(GameSettings.value(game, diff) == "medium", "clear forgets the choices")


## A chip shows the avatar next to the color square, and a chip is laid out left to right in both languages (REQ-GM-46b).
func _chip_avatar() -> void:
	print("chip avatar")
	var plain := Shell.name_x()
	var with_avatar := Shell.name_x(3)
	_check(is_equal_approx(with_avatar - plain, Shell.CHIP_AVATAR + Shell.CHIP_GAP),
			"the text of a chip with an avatar starts one picture later")
	_check(is_equal_approx(Shell.name_x(-1), plain) and is_equal_approx(Shell.name_x(999), plain),
			"a guest and an avatar that the sheet does not have leave the chip as it was")
	_check(Shell.score_chip_width("Maya", "120", 64.0, 200.0, Shell.CHIP_FONT, 3) > Shell.score_chip_width("Maya", "120"),
			"a chip with an avatar is wider, so the name is not cut")
	var parts: Dictionary = Shell.score_chip_parts("Maya", "120", 400.0, 64.0, Shell.CHIP_FONT, 3)
	_check(is_equal_approx(parts.name_x, with_avatar) and parts.score_x > parts.name_x,
			"the name is after the avatar, the score at the end")


## The medal sheet and the medal of a place (REQ-GM-73): 1st gold, 2nd silver, 3rd bronze, ties share, nothing after the 3rd.
func _medal_icon() -> void:
	print("medals")
	var Medal = load("res://scripts/ui/medal.gd")
	var sheet: Image = Medal.texture().get_image()
	_check(sheet.get_width() == Medal.CELL * 3 and sheet.get_height() == Medal.CELL, "the sheet is three medals of 16 x 16 px")
	var middles := []
	var all_drawn := true
	for tier in Medal.TIERS:
		var r: Rect2 = Medal.region(tier)
		middles.append(sheet.get_pixel(int(r.position.x) + 10, 11))   # A pixel of the base color of the medal.
		var opaque := 0
		for y in Medal.CELL:
			for x in Medal.CELL:
				opaque += 1 if sheet.get_pixel(int(r.position.x) + x, y).a > 0.0 else 0
		all_drawn = all_drawn and opaque > 100 and opaque < 200 and sheet.get_pixel(int(r.position.x), 0).a == 0.0
	_check(all_drawn, "each medal is a round picture on a transparent background")
	_check(middles[0] != middles[1] and middles[1] != middles[2] and middles[0] != middles[2],
			"gold, silver and bronze have different colors")
	_check(middles[0].r > 0.9 and middles[0].b < 0.4 and absf(middles[1].r - middles[1].b) < 0.05 and middles[2].r > middles[2].b,
			"gold is yellow, silver is gray and bronze is brown: %s" % str(middles))
	_check(Medal.is_known("gold") and not Medal.is_known("") and not Medal.is_known("wood"),
			"only the three tiers are on the sheet")
	var canvas := Control.new()
	root.add_child(canvas)
	# Drawing is only allowed inside `draw`, so the calls run in the draw signal of the canvas.
	var results := []
	canvas.draw.connect(func() -> void:
		results.append(Medal.draw(canvas, Rect2(0, 0, 48, 48), "silver"))
		results.append(Medal.draw(canvas, Rect2(0, 0, 48, 48), "wood")))
	canvas.queue_redraw()
	await process_frame
	await process_frame
	_check(results.size() >= 2 and results[0] == true and results[1] == false, "a known tier is drawn, an unknown one is not")
	canvas.queue_free()


## A text that does not fit its box goes on more lines or the box grows; it is never made smaller or cut (issue #246).
func _fit_size() -> void:
	print("text fit")
	var f: Font = UiTheme.font()
	var mini = load("res://scripts/game/mini_golf/mini_golf_game.gd")
	var w32: float = f.get_string_size("HELLO WORLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	_check(UiTheme.wrap_lines(f, "HELLO WORLD", w32 + 1.0, 32) == ["HELLO WORLD"], "a text that fits is one line")
	_check(UiTheme.wrap_lines(f, "HELLO WORLD", w32 * 0.8, 32) == ["HELLO", "WORLD"],
			"a text that is a little too wide goes on two lines")
	var narrow := UiTheme.wrap_lines(f, "HELLO WORLD", 10.0, 32)
	_check("".join(narrow) == "HELLOWORLD", "a box narrower than a letter still keeps every letter")
	var long_word := UiTheme.wrap_lines(f, "ABCDEFGHIJ", 5.0 * 32.0, 32)
	_check(long_word == ["ABCDE", "FGHIJ"], "a word wider than the box is broken between letters: %s" % str(long_word))
	var he := UiTheme.wrap_lines(f, "אבגדהוזחטי", 5.0 * 32.0, 32)
	_check("".join(he) == "אבגדהוזחטי" and he.size() == 2, "Hebrew keeps every letter on two lines: %s" % str(he))
	for line in long_word:
		_check(f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x <= 5.0 * 32.0, "every line is inside the box (%s)" % line)
	# A chip grows with its text (the name column of Pin Pals and the bar of Mini Golf were cutting a name of 10 letters).
	var need: float = Shell.name_x(3) + 10.0 * 32.0 + Shell.CHIP_PAD
	_check(Shell.chip_width("WWWWWWWWWW", 100.0, 3) == need, "a chip is as wide as a name of 10 letters needs (%.0f px)" % need)
	_check(Shell.chip_width("1P", 240.0, 3) == 240.0, "a short text keeps the width the game asked for")
	var rows: Array = mini.bar_lines([560.0, 560.0, 560.0, 560.0], 1800.0, 16.0)
	_check(rows == [[0, 1, 2], [3]], "four wide chips of Mini Golf go on two rows: %s" % str(rows))
	rows = mini.bar_lines([300.0, 300.0, 300.0, 300.0], 1800.0, 16.0)
	_check(rows == [[0, 1, 2, 3]], "four short chips stay on one row: %s" % str(rows))
