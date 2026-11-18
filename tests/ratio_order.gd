extends SceneTree
## "8 / 11" reads in the same order in Hebrew as in English (issue #480, REQ-FL-54a). In a right-to-left line the bidi
## rules put the "/" with spaces around it in the direction of the line, so the count was drawn "11 / 8".
## Every text of the form "a / b" goes through `Lang.ltr_ratio()` or `Lang.f()` (left-to-right isolate, Hebrew only). The test
## shapes the text as the label does (the project font, right to left paragraph) and reads the visual order of the digits. Run:
##   godot --headless --path . --script tests/ratio_order.gd -- --role=controller

const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const ResultText = preload("res://scripts/core/result_text.gd")

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


## The digits and slashes of `text` as they are drawn from the left to the right, in a right to left paragraph.
func _visual(text: String) -> String:
	var para := TextParagraph.new()
	para.direction = TextServer.DIRECTION_RTL
	para.add_string(text, UiTheme.font(), 32)
	var out := ""
	for g in TextServerManager.get_primary_interface().shaped_text_get_glyphs(para.get_line_rid(0)):
		var c := text.unicode_at(int(g.start))
		if (c >= 0x30 and c <= 0x39) or c == 0x2F:
			out += char(c)
	return out


func _run() -> void:
	Lang.set_language("he")
	_check(_visual("8 / 11 כבשים") == "11/8", "the problem: the raw Hebrew line is drawn 11 / 8 (%s)" % _visual("8 / 11 כבשים"))
	_check(_visual(Lang.f("sheep_herding.count", [8, 11])) == "8/11", "the result row of Sheep Herding reads 8 / 11")
	_check(_visual(Lang.ltr_ratio(8, 11)) == "8/11", "the team chip and the HUD read 8 / 11")
	_check(_visual(ResultText.text("mini_golf.leader_score", [2, 17])) == "2/17", "Mini Golf strokes read 2 / 17")
	_check(_visual(Lang.ltr_ratio(3, 10)) == "3/10", "the Settings level reads 3 / 10")
	var c := ControllerClient.new()
	_check(_visual(c._clean_line(Lang.ltr_ratio(8, 11))) == "8/11" and c._clean_line(Lang.ltr_ratio(8, 11)).length() == 8,
			"the phone line cleaning keeps the isolates")
	var once := Lang.ltr_ratios(Lang.ltr_ratio(8, 11))
	_check(once == Lang.ltr_ratio(8, 11) and once.length() == 8, "a text with the isolates is not wrapped twice")
	_check(Lang.f("sheep_herding.count", [8, 11]).length() == "8 / 11 כבשים".length() + 2, "only two marks are added to the row")
	c._handle({"t": "score", "rank": 0, "of": 0, "v": "8 / 11"}, 0)
	_check(_visual(c.score_text) == "8/11" and c.score_text.length() <= 12, "the phone shows the TV count 8 / 11 in order in Hebrew")
	Lang.set_language("en")
	_check(Lang.ltr_ratio(8, 11) == "8 / 11" and Lang.f("sheep_herding.count", [8, 11]) == "8 / 11 sheep",
			"in English the text has no mark")
	c._handle({"t": "score", "rank": 0, "of": 0, "v": "8 / 11"}, 0)
	_check(c.score_text == "8 / 11", "English phone: the score text is as it came")
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
