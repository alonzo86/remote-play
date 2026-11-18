extends SceneTree
## The line gap of a wrapped text (issue #403, #406). Run:
##   godot --headless --path . --script tests/line_gap.gd -- --role=controller
## The Hebrew final letters (ק ך ן ף ץ) go one font pixel below the line, so a wrapped Hebrew text needs a larger gap than a
## Latin one. 1. The gap of each size in both languages. 2. The descender of a final letter keeps at least two font pixels
## (a quarter of the size) from the top of the next line (measured on the outline of the glyphs of the project font).
## 3. A screen that stays open when the language changes gets the new gap (`UiTheme.refresh_line_gaps`).
## 4. The pad (`controller_pad.gd`): a two-line name in the header does not touch the score row, in both languages; a long
## score text (two lines) starts where the one-line row starts, is below the name and ends above the turn row (issue #408).

const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

const SIZES := [24, 32, 40, 48, 56, 64]

var _fails := 0
var _checks := 0


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## The lowest and the highest y (a negative y is above the baseline) of the outline of the first glyph of `ch` at `size`.
func _extent(ch: String, size: int) -> Vector2:
	var ts := TextServerManager.get_primary_interface()
	var sl := ts.create_shaped_text()
	ts.shaped_text_add_string(sl, ch, UiTheme.font().get_rids(), size)
	var g: Dictionary = ts.shaped_text_get_glyphs(sl)[0]
	var pts := ts.font_get_glyph_contours(g["font_rid"], size, g["index"])["points"] as PackedVector3Array
	var top := 1e9
	var bottom := -1e9
	for p in pts:
		top = minf(top, p.y)
		bottom = maxf(bottom, p.y)
	ts.free_rid(sl)
	return Vector2(top, bottom)


## The top and the bottom y of the ink of `n` lines of size `fs` drawn like `controller_pad._draw_lines_centered` in `rect`;
## `letter` is a letter of the lines (a final letter goes below the baseline). `from_top`: the score row (the first line stays).
func _block_ink(rect: Rect2, n: int, fs: int, letter: String, from_top := false) -> Vector2:
	var f := UiTheme.font()
	var step := UiTheme.line_step(f, fs)
	var ext := _extent(letter, fs)
	var first_center := UiTheme.line_center(rect.get_center().y, n, step, 0, from_top)
	var last_center := UiTheme.line_center(rect.get_center().y, n, step, n - 1, from_top)
	var first_base := first_center + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	var last_base := last_center + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	return Vector2(first_base + _extent("ב", fs).x, last_base + ext.y)


func _run() -> void:
	# 1. The gap of each size.
	Lang.set_language("en")
	_check(UiTheme.line_gap(32) == 8 and UiTheme.line_gap(40) == 10 and UiTheme.line_gap(64) == 16, "English: a quarter of the size")
	Lang.set_language("he")
	_check(UiTheme.line_gap(32) == 12 and UiTheme.line_gap(40) == 15 and UiTheme.line_gap(64) == 24,
			"Hebrew: a quarter of the size and an eighth more")

	# 2. The descender keeps a quarter of the size from the next line.
	for size in SIZES:
		var latin := _extent("ב", size)
		var final := _extent("ק", size)
		_check(final.y > latin.y, "%d px: the final letter goes below the other letters" % size)
		# The next line has its top ink line_gap below the baseline of this one (its cell top is at the baseline, minus the size).
		var gap_he := float(UiTheme.line_gap(size)) - final.y
		_check(gap_he >= float(size) / 4.0, "%d px: Hebrew, the descender is %d px from the next line (at least %d)"
				% [size, int(gap_he), size / 4])
	Lang.set_language("en")
	for size in SIZES:
		_check(UiTheme.line_gap(size) == size / 4, "%d px: English, the gap stays a quarter of the size (%d)" % [size, size / 4])

	# 3. An open screen gets the new gap.
	Lang.set_language("en")
	var open_label := UiKit.label("SOME TEXT", 40)
	var plain := Label.new()
	root.add_child(open_label)
	root.add_child(plain)
	_check(open_label.get_theme_constant("line_spacing") == 10, "a label made in English has the gap 10 at 40 px")
	Lang.set_language("he")
	UiTheme.refresh_line_gaps(root)
	_check(open_label.get_theme_constant("line_spacing") == 15, "after the change to Hebrew, the open label has the gap 15")
	_check(not plain.has_theme_constant_override("line_spacing"), "a label with no gap of its own is left alone")
	Lang.set_language("en")
	UiTheme.refresh_line_gaps(root)
	_check(open_label.get_theme_constant("line_spacing") == 10, "and back to English: 10")

	# 4. The pad.
	var pad: Control = (load("res://scripts/ui/controller_pad.gd") as GDScript).new()   # load: the script names the autoload App
	# The pad reads the state of the phone (the pause button, the result line): a pad in the app always has a client. A new client is
	# not connected and is in no game, so the pause button and the result are hidden, as at the start of a game.
	var app: Node = root.get_node("App")
	var client := ControllerClient.new()
	app.client = client
	pad.size = Vector2(1080, 1920)
	for code in ["en", "he"]:
		Lang.set_language(code)
		var letter := "ק" if code == "he" else "A"
		var name_ink := _block_ink(pad._rect_name(true), 2, pad.NAME_SIZE, letter)
		var score_rect: Rect2 = pad._rect_score()
		var score_ink := _block_ink(score_rect, 1, pad.LINE_SIZE, "ב", pad.SCORE_GROWS_DOWN)
		_check(name_ink.y < score_ink.x, "%s: a two-line name (ink to y %.0f) is above the score row (ink from y %.0f)"
				% [code, name_ink.y, score_ink.x])
		# A long score text (two lines, 64 px) grows downward: it starts at the same place and ends above the turn row (issue #408).
		var score2_ink := _block_ink(score_rect, 2, pad.LINE_SIZE, "ק" if code == "he" else "A", pad.SCORE_GROWS_DOWN)
		_check(name_ink.y < score2_ink.x, "%s: a two-line name is above a two-line score row (ink from y %.0f)" % [code, score2_ink.x])
		_check(is_equal_approx(score2_ink.x, score_ink.x), "%s: a two-line score row starts where the one-line row starts" % code)
		var turn_top: float = pad._rect_turn().position.y
		_check(score2_ink.y < turn_top, "%s: a two-line score row ends (y %.0f) above the turn row (y %.0f)"
				% [code, score2_ink.y, turn_top])
	pad.free()
	app.client = null
	client.free()
	Lang.set_language("en")
	open_label.queue_free()
	plain.queue_free()

	print("\n%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
