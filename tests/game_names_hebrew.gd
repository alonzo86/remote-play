extends SceneTree
## With the TV in Hebrew, every game name shows in Hebrew (REQ-FL-87, Alon 2026-10-29): the tiles and the info bar of the Games
## screen, the settings view of each game and the title of the HUD. No screen shows the English name of a game. Run:
##   godot --headless --path . --script tests/game_names_hebrew.gd -- --role=tv

const Lang = preload("res://scripts/core/lang.gd")
const Registry = preload("res://scripts/game/registry.gd")
const Shell = preload("res://scripts/game/shell.gd")

var _checks := 0
var _fails := 0
var _hud: Array = []


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


static func _latin(text: String) -> bool:
	var re := RegEx.new()
	re.compile("[A-Za-z]")
	return re.search(text) != null


## The text that a label or a button shows now: a key is translated by the node.
static func _shown(n: Node) -> String:
	return n.tr(String(n.get("text"))) if n is Label or n is Button else ""


## Every text shown by `root_node` and its children.
static func _texts(root_node: Node) -> Array[String]:
	var out: Array[String] = []
	var todo: Array[Node] = [root_node]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		var s := _shown(n)
		if s != "":
			out.append(s)
		todo.append_array(n.get_children())
	return out


func _on_hud(kind: String, _ci: CanvasItem, _rect: Rect2, info: Dictionary) -> void:
	if kind == "title":
		_hud.append(String(info.text))


func _run() -> void:
	await _frames(5)
	var app: Node = root.get_node("App")
	root.size = Vector2i(1920, 1080)
	app.server.players[0].state = 1
	app.set_language("he", false)
	var games := Registry.all()
	var english: Array[String] = []
	var hebrew: Dictionary = {}
	for g in games:
		var row: Dictionary = Lang.table()[String(g.title)]
		english.append(String(row.en).to_upper())
		hebrew[String(g.id)] = String(row.he).to_upper()
		_check(String(row.he) != "" and not _latin(String(row.he)),
				"%s: the Hebrew title of the key %s is Hebrew (%s)" % [g.id, g.title, row.he])
		var desc: Dictionary = Lang.table()[String(g.description)]
		_check(String(desc.he) != "" and not _latin(String(desc.he)),
				"%s: the description has a Hebrew text without Latin letters" % g.id)
	_check(english.size() == 15, "15 games are checked (%d)" % english.size())

	# The Games screen: a tile title for every game, and the info bar for the focused tile.
	app.go_games()
	await _frames(10)
	var screen: Control = app.current_screen()
	_check(screen._tiles.size() == games.size(), "the Games screen has a tile for every game (%d)" % screen._tiles.size())
	for t in screen._tiles:
		var shown: String = t._name.tr(t._name.text)
		_check(shown.to_upper() == hebrew[String(t.game.id)], "%s: the tile title is the Hebrew name (%s)" % [t.game.id, shown])
		t.grab_focus()
		await _frames(2)
		var info: String = screen._info.tr(screen._info.text)
		_check(info != "" and not _latin(info), "%s: the info bar is Hebrew (%s)" % [t.game.id, info])
	var leaks: Array[String] = []
	for s in _texts(screen):
		if s.to_upper() in english:
			leaks.append(s)
	_check(leaks.is_empty(), "no text of the Games screen is the English name of a game (%s)" % str(leaks))

	# The settings view of each game, and the title of its HUD.
	Shell.recorder = _on_hud
	for g in games:
		app.go_game_settings(String(g.id))
		await _frames(4)
		var view: Control = app.current_screen()
		var texts := _texts(view)
		var named := false
		var settings_leaks: Array[String] = []
		for s in texts:
			named = named or s.to_upper() == hebrew[String(g.id)]
			if s.to_upper() in english:
				settings_leaks.append(s)
		_check(named, "%s: the settings view shows the Hebrew name" % g.id)
		_check(settings_leaks.is_empty(), "%s: the settings view shows no English game name (%s)" % [g.id, str(settings_leaks)])
		_hud.clear()
		var holder := Control.new()
		holder.draw.connect(func(): Shell.title(holder, String(g.title)))
		root.add_child(holder)
		await _frames(2)
		holder.queue_free()
		_check(_hud == [hebrew[String(g.id)]], "%s: the HUD title is the Hebrew name (%s)" % [g.id, str(_hud)])
	Shell.recorder = Callable()

	# The HUD of each game passes its own registry key to Shell.title (not a name written in the script).
	for g in games:
		var src := FileAccess.get_file_as_string(String(g.path))
		_check(src.contains('Shell.title(self, "%s"' % g.title) or src.contains('Shell.title_wrapped(self, "%s"' % g.title),
				"%s: its HUD title is the key %s" % [g.id, g.title])

	# No script writes the English name of a game as a literal text: it always goes through the key.
	var literal: Array[String] = []
	for path in _script_files("res://scripts"):
		var src := FileAccess.get_file_as_string(path)
		for name in english:   # Case matters: the ids are in lower case ("tennis").
			if src.contains('"' + name + '"') or src.contains('"' + name.capitalize() + '"'):
				literal.append("%s: %s" % [path.get_file(), name])
	_check(literal.is_empty(), "no script holds the English name of a game as a text (%s)" % str(literal))
	app.set_language("en", false)


func _script_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_script_files(dir.path_join(d)))
	return out
