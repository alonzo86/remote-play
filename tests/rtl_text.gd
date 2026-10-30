extends SceneTree
## Hebrew text in the pixel fonts (issue #229, related to #151). Run:
##   godot --headless --path . --script tests/rtl_text.gd -- --role=tv
## 1. Every Hebrew letter and mark of the Hebrew column (the geresh and the gershayim too) has a glyph in the project fonts.
## 2. Every Hebrew row with a number or a name inside, filled with a number, a Latin name and a Hebrew name, is shaped in right
##    to left order: the parts follow each other from the right to the left, a number and a Latin name keep their own order,
##    and no character is drawn as the "missing glyph" box.

const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

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


func _is_hebrew(c: int) -> bool:
	return c >= 0x590 and c <= 0x5FF


func _is_latin_or_digit(c: int) -> bool:
	return (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A)


## The runs of `text`: [start, end, "he" or "lat"]; spaces and marks between them belong to no run.
func _runs(text: String) -> Array:
	var out: Array = []
	var i := 0
	while i < text.length():
		var c := text.unicode_at(i)
		var kind := "he" if _is_hebrew(c) else ("lat" if _is_latin_or_digit(c) else "")
		if kind == "":
			i += 1
			continue
		var j := i
		while j < text.length():
			var d := text.unicode_at(j)
			var same := _is_hebrew(d) if kind == "he" else _is_latin_or_digit(d)
			# A separator between two numbers ("12-12", "3.5", "2/10") belongs to the number: the bidi rules keep it in order.
			if kind == "lat" and not same and "-./:,".contains(text[j]) and j + 1 < text.length() \
					and _is_latin_or_digit(text.unicode_at(j + 1)) and _is_latin_or_digit(text.unicode_at(j - 1)):
				same = true
			if not same:
				break
			j += 1
		out.append([i, j, kind])
		i = j
	return out


## The position in the visual line (from the left) of the first glyph of the text from `from` to `to`; -1 when no glyph is there.
func _visual_pos(glyphs: Array[Dictionary], from: int, to: int) -> int:
	for k in glyphs.size():
		var g: Dictionary = glyphs[k]
		if int(g.start) >= from and int(g.start) < to:
			return k
	return -1


func _run() -> void:
	var table: Dictionary = Lang.table()
	var font: Font = UiTheme.font()
	# 1. The glyphs.
	var missing: Array = []
	var marks := {}
	for k in table:
		var he := String(table[k].he)
		for i in he.length():
			var c := he.unicode_at(i)
			if _is_hebrew(c):
				marks[c] = true
				if not font.has_char(c):
					missing.append("U+%04X (%s)" % [c, k])
	_check(marks.has(0x5F3) and marks.has(0x5F4),
			"the Hebrew column uses the geresh (ש׳, מ׳, ג׳ונגל) and the gershayim (סה״כ), so this test covers them")
	_check(missing.is_empty(),
			"every Hebrew letter and mark of the table has a glyph in the project fonts " + str(missing.slice(0, 5)))
	# 2. The order.
	var sample_args := {"d": 12, "f": 3.5}
	var names := ["Noam", "שירה"]
	var rx := RegEx.create_from_string("%[-+ 0#]*[0-9]*(?:\\.[0-9]+)?([sdf])")
	var rows := 0
	var bad: Array = []
	var tofu: Array = []
	var te := TextServerManager.get_primary_interface()
	for k in table:
		var he := String(table[k].he)
		if not rx.search(he):
			continue
		for name_value in names:
			var args: Array = []
			for m in rx.search_all(he):
				var t := m.get_string(1)
				args.append(name_value if t == "s" else sample_args[t])
			var text: String = he % args
			rows += 1
			var para := TextParagraph.new()
			para.direction = TextServer.DIRECTION_RTL
			para.add_string(text, font, 32)
			var glyphs: Array[Dictionary] = te.shaped_text_get_glyphs(para.get_line_rid(0))
			for i in text.length():
				if text.unicode_at(i) > 0x20 and not font.has_char(text.unicode_at(i)):
					tofu.append("%s: U+%04X" % [k, text.unicode_at(i)])
			var runs := _runs(text)
			# A line with a Hebrew letter runs from the right to the left; a line with none ("Noam: 12") stays left to right.
			var rtl := runs.any(func(r: Array) -> bool: return r[2] == "he")
			var prev := 1000000 if rtl else -1
			for r in runs:
				var pos := _visual_pos(glyphs, r[0], r[1])
				if pos < 0 or (pos >= prev if rtl else pos <= prev):
					bad.append("%s '%s' (the run %d-%d is on the wrong side of the run before it)" % [k, text, r[0], r[1]])
					break
				prev = pos
				if r[2] == "lat" and r[1] - r[0] > 1:   # A name or a number keeps its own order from the left.
					var first := _visual_pos(glyphs, r[0], r[0] + 1)
					var second := _visual_pos(glyphs, r[0] + 1, r[0] + 2)
					if first < 0 or second <= first:
						bad.append("%s '%s' (the Latin text or the number is reversed)" % [k, text])
						break
	_check(rows >= 40, "Hebrew rows with a number or a name, each shaped with a Latin and a Hebrew name (%d)" % rows)
	_check(bad.is_empty(), "each Hebrew row: the parts keep the order of the line, a number and a name keep their own order "
			+ str(bad.slice(0, 3)))
	_check(tofu.is_empty(), "no character of those rows is drawn as a missing glyph " + str(tofu.slice(0, 3)))
	# The order check can fail: a row with a Latin name at the start must have the name at the right.
	var probe := TextParagraph.new()
	probe.direction = TextServer.DIRECTION_RTL
	probe.add_string("Noam עזב", font, 32)
	var pg: Array[Dictionary] = te.shaped_text_get_glyphs(probe.get_line_rid(0))
	_check(_visual_pos(pg, 0, 4) > _visual_pos(pg, 5, 8), "a Latin name at the start of a Hebrew line is at its right end")
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
