extends SceneTree
## The text of the HUD of Sumo Bumpers and Star Shield: every font is 28 px or more and every plate is inside the 60 px
## margin of the screen, in English and in Hebrew (REQ-GM-45, REQ-SB-15, REQ-AB-16). A person reading it from 3 m stays a manual
## step; this checks the numbers. Run:
##   godot --headless --path . --script tests/layout_hud_fonts.gd -- --role=tv

const SimInput = preload("res://tests/sim_input.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Lang = preload("res://scripts/core/lang.gd")
const SumoArena = preload("res://scripts/game/sumo_bumpers/sumo_arena.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const MARGIN := 60.0
const LONG_NAME := "WWWWWWWWWW"   # 10 letters, the longest name (Protocol.NAME_MAX), in the widest letter.

var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A check of something that is wrong in the game today: it counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool) -> void:
	_checks += 1
	if cond:
		print("  ok   (known bug is fixed, make this a normal check) ", issue)
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _inside(r: Rect2, area: Vector2) -> bool:
	return r.position.x >= MARGIN - 0.01 and r.position.y >= MARGIN - 0.01 and r.end.x <= area.x - MARGIN + 0.01 \
			and r.end.y <= area.y - MARGIN + 0.01


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	var app: Node = root.get_node("App")
	var clients: Array = await SimInput.connect_phones(self, app, 2)
	var sumo: Control = SimInput.start_game(app, load("res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd"),
			{"difficulty": "easy"})
	await _frames(2)
	for code in ["en", "he"]:
		Lang.set_language(code, root)
		_sumo(sumo, code)
	var blast: Control = SimInput.start_game(app, load("res://scripts/game/asteroid_blast/asteroid_blast_game.gd"), {})
	await _frames(2)
	for code in ["en", "he"]:
		Lang.set_language(code, root)
		_asteroid(blast, code)
	Lang.set_language("en", root)
	_countdown()
	for c in clients:
		c.leave()
	await _frames(10)
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## 15.11d: "WHEE!", the round banner and the round number of Sumo Bumpers.
func _sumo(game: Control, code: String) -> void:
	print("Sumo Bumpers in ", code)
	var area: Vector2 = game.size
	_check(game.WHEE_FONT >= 28 and game.ROUND_FONT >= 28 and game.BANNER_FONT >= 28,
			"%s: the fonts of WHEE!, the round number and the banner are %d, %d and %d px (28 or more)"
			% [code, game.WHEE_FONT, game.ROUND_FONT, game.BANNER_FONT])
	var banners := [Lang.f("sumo_bumpers.round_winner", [LONG_NAME]), Lang.t("sumo_bumpers.round_draw")]
	var banners_ok := true
	var widest := 0.0
	for msg in banners:
		var r := Shell.label_plate_rect(game.banner_at(), msg, game.banner_font(msg))
		widest = maxf(widest, r.size.x)
		banners_ok = banners_ok and _inside(r, area)
	_check(banners_ok, "%s: the banner plates (long name too) are inside the 60 px margin, the widest is %.0f px"
			% [code, widest])
	var round_text := Lang.f("sumo_bumpers.round_n_of", [3, game.ROUNDS]).to_upper()
	var round_w := UiTheme.font().get_string_size(round_text, HORIZONTAL_ALIGNMENT_LEFT, -1, game.ROUND_FONT).x
	_check(round_w <= 480.0, "%s: the round number is %.0f px wide, centered at x = %.0f of the bar" % [code, round_w,
			game.TIMER_X + 120.0])
	# "WHEE!" is over the bumper that fell, at the edge of the island: the plate must stay under the bar and inside the margin.
	var worst_top := 1.0e9
	var worst_side := 1.0e9
	for d in ["easy", "medium", "hard"]:
		var radius: float = SumoArena.LEVELS[d].radius
		for angle in [0.0, 0.5 * PI, PI, 1.5 * PI]:
			for age in [0.0, 0.4]:
				var r := Shell.label_plate_rect(game.whee_at(Vector2.from_angle(angle) * (radius + 20.0), age),
						"sumo_bumpers.whee",
						game.WHEE_FONT)
				worst_top = minf(worst_top, r.position.y)
				worst_side = minf(worst_side, minf(r.position.x, area.x - r.end.x))
	_check(worst_side >= MARGIN, "%s: WHEE! over a bumper at the edge of the island stays %.0f px from the sides (60 or more)"
			% [code, worst_side])
	_check(worst_top >= game.BAR_H, "%s: WHEE! over a bumper that falls off the top has its plate %.0f px from the top "
			% [code, worst_top] + "(under the 112 px bar)")


## 22.12e: the wave number, the banners and the line of Star Shield.
func _asteroid(game: Control, code: String) -> void:
	print("Star Shield in ", code)
	var area: Vector2 = game.size
	_check(game.WAVE_FONT >= 28 and game.BANNER_FONT >= 28 and game.SUB_FONT >= 28,
			"%s: the fonts of the wave number, the banner and the second line are %d, %d and %d px (28 or more)"
			% [code, game.WAVE_FONT, game.BANNER_FONT, game.SUB_FONT])
	var ok := true
	var widest := 0.0
	var texts := [Lang.f("asteroid_blast.wave_n", [88]), Lang.f("asteroid_blast.wave_clear", [88]),
			Lang.t("asteroid_blast.all_ships_gone")]
	for msg in texts:
		var r := Shell.label_plate_rect(game.banner_at(), msg, game.banner_font(msg))
		widest = maxf(widest, r.size.x)
		ok = ok and _inside(r, area)
	var sub := Shell.label_plate_rect(game.banner_at() + Vector2(0.0, 110.0), Lang.f("asteroid_blast.next_wave_in", [5]),
			game.SUB_FONT)
	_check(ok and _inside(sub, area), "%s: the banners and 'Next wave in' are inside the 60 px margin, the widest is %.0f px"
			% [code, widest])
	var wave_w := UiTheme.font().get_string_size(Lang.f("asteroid_blast.wave_n", [88]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1,
			game.WAVE_FONT).x
	_check(wave_w <= game.TIMER_W + 80.0, "%s: 'Wave 88' in the bar is %.0f px wide in a box of %.0f px" % [code, wave_w,
			game.TIMER_W + 80.0])
	var line_ok: bool = game.BAR_LINE_Y + game.BAR_LINE_H <= game.BAR_H and game.AREA_MARGIN >= MARGIN
	_check(line_ok, "%s: the line of the wave is inside the bar and starts at the 60 px margin" % code)


## 15.11d: the countdown digits are far above 28 px at every step.
func _countdown() -> void:
	var smallest := 1000000
	for step in 11:
		smallest = mini(smallest, Shell.countdown_size(float(step) / 10.0))
	_check(smallest >= 28 and smallest == 256, "the countdown digits are %d px or more at every step" % smallest)
