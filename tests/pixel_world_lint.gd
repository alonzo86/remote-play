extends SceneTree
## Rules of the pixel worlds that can be read from the code of the world draw (issue #306). The world of a game is drawn by
## `_world_draw()` on the 480x270 layer (REQ-GM-47a). This lint reads the scripts of every game folder, follows the calls from
## `_world_draw()` to the functions it reaches in the same folder, and checks what those functions do:
##   REQ-GM-47n  no text is drawn in the pixel view (no draw_string, no Shell text or plate, no Label). A word in the world is
##               drawn by the HUD (`_game_draw()`), not by the world.
##   REQ-GM-47l  a position is moved to the grid with `Shell.snap()` (or drawn by `Shell.pixel_ball()` / `pixel_eyes()`, which
##               snap) before it is drawn: the world draw of a game reaches a call of one of them.
## The lint finds the problem in a made-up source first (so that it cannot pass by reading nothing), then reads the real games.
## Run: godot --headless --path . --script tests/pixel_world_lint.gd -- --role=controller

## Mini Golf draws its world without `Shell.snap()` today (issue #346). The entry goes when the issue is fixed: the lint fails
## for a game on this list that snaps.
const NOT_SNAPPED: Array[String] = ["mini_golf"]

const TEXT_CALL := "draw_string\\(|Label\\.new|UiKit\\.label|Shell\\.(text|text_centered|label_plate|status|hint|title|" \
		+ "title_wrapped|chip|score_chip|leader_chip|timer|countdown)\\("
const SNAP_CALL := "snap\\(|pixel_ball\\(|pixel_eyes\\("
const DRAW_CALL := "draw_(circle|rect|colored_polygon|polygon|line|polyline|texture|texture_rect|multiline|arc)"

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
	_detection()
	_real_games()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## {function name: [the lines of its body]} of the sources in `texts` (an array of file contents).
static func functions_of(texts: Array) -> Dictionary:
	var funcs := {}
	var head := RegEx.create_from_string("^(?:static )?func (\\w+)")
	for text in texts:
		var current := ""
		for line in String(text).split("\n"):
			var m := head.search(line)
			if m != null:
				current = m.get_string(1)
				if not funcs.has(current):
					funcs[current] = []
			elif current != "" and (line.begins_with("\t") or line.strip_edges() == ""):
				funcs[current].append(line)
			elif line.strip_edges() != "" and not line.begins_with("#") and not line.begins_with("\t"):
				current = ""
	return funcs


## The lines (code only, no comment) of the functions that `_world_draw()` reaches: [{fn, line}].
static func world_lines(texts: Array) -> Array:
	var funcs := functions_of(texts)
	var out: Array = []
	var seen := {}
	var queue: Array = ["_world_draw"]
	var call := RegEx.create_from_string("\\b(\\w+)\\(")
	while not queue.is_empty():
		var name: String = queue.pop_back()
		if seen.has(name) or not funcs.has(name):
			continue
		seen[name] = true
		for raw in funcs[name]:
			var line: String = String(raw).split("#")[0]
			out.append({"fn": name, "line": line})
			for m in call.search_all(line):
				queue.append(m.get_string(1))
	return out


static func count_matches(lines: Array, pattern: String) -> Array:
	var re := RegEx.create_from_string(pattern)
	return lines.filter(func(e: Dictionary) -> bool: return re.search(String(e.line)) != null)


func _detection() -> void:
	print("the lint finds what it looks for")
	var game := "extends Control\nfunc _world_draw(ci):\n\t_floor(ci)\nfunc _floor(ci):\n\tci.draw_rect(Rect2(), Color.RED)\n" \
			+ "\t_label(ci)\nfunc _label(ci):\n\tci.draw_string(font, pos, \"hi\")  # drawn in the world\n" \
			+ "func _game_draw():\n\tShell.text(self, pos, \"HUD\")\n"
	var lines := world_lines([game])
	_check(count_matches(lines, TEXT_CALL).size() == 1 and count_matches(lines, TEXT_CALL)[0].fn == "_label",
			"a draw_string in a function that the world draw reaches is found; the HUD text of _game_draw is not")
	_check(count_matches(lines, SNAP_CALL).is_empty() and count_matches(lines, DRAW_CALL).size() == 1,
			"a world draw with no snap is found")
	var snapped := game.replace("ci.draw_rect(Rect2(), Color.RED)", "ci.draw_rect(Rect2(Shell.snap(pos), s), Color.RED)")
	_check(count_matches(world_lines([snapped]), SNAP_CALL).size() == 1, "a call of Shell.snap is found")
	_check(count_matches(world_lines(["func _world_draw(ci):\n\t# draw_string(ci)\n\tpass\n"]), TEXT_CALL).is_empty(),
			"text in a comment is not text")


func _game_dirs() -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at("res://scripts/game"):
		out.append("res://scripts/game/" + d)
	out.sort()
	return out


func _texts_of(dir: String) -> Array:
	var texts: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			texts.append(FileAccess.get_file_as_string(dir + "/" + f))
	return texts


func _real_games() -> void:
	print("the pixel worlds of the games")
	var worlds := 0
	for dir in _game_dirs():
		var id := dir.get_file()
		var lines := world_lines(_texts_of(dir))
		if lines.is_empty():
			continue
		worlds += 1
		var texts := count_matches(lines, TEXT_CALL)
		_check(texts.is_empty(), "REQ-GM-47n: %s: no text is drawn by the world draw %s" % [id, str(texts.map(
				func(e: Dictionary) -> String: return "%s: %s" % [e.fn, String(e.line).strip_edges()]))])
		var draws := count_matches(lines, DRAW_CALL)
		var snaps := count_matches(lines, SNAP_CALL)
		if id in NOT_SNAPPED:
			_check(snaps.is_empty() and not draws.is_empty(),
					"REQ-GM-47l: %s is on the list of worlds without Shell.snap (issue #346): remove it when it snaps" % id)
		else:
			_check(not snaps.is_empty() and not draws.is_empty(),
					"REQ-GM-47l: %s: the world draw moves positions to the grid (%d calls of Shell.snap or pixel_ball)" % [id, snaps.size()])
	_check(worlds >= 15, "the lint read the world draw of %d games" % worlds)
