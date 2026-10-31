extends SceneTree
## The rules of GAME_REQUIREMENTS.md and TV_FLOW.md that can be checked from the registry, the files of the games and the
## requirements files (issue #306): every game has its requirements file and its test section, extends Minigame, reads the phone
## only through PlayerInput, has a tile and its texts; the status words of the tables; the player counts and the pad of the
## games named by their own requirements; the Car Race track list. Run:
##   godot --headless --path . --script tests/req_registry.gd -- --role=controller

const Registry = preload("res://scripts/game/registry.gd")
const Lang = preload("res://scripts/core/lang.gd")

const STATUS_OK := "^(Done|Open|Device|Removed|Planned \\(issue #[0-9]+\\))$"

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
	_files_of_games()
	_game_scripts()
	_registry_texts()
	_registry_values()
	_status_words()
	_tile_step()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


## All files with `ext` under `dir` (res:// paths).
func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d), ext))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	return out


## REQ-GM-1 and REQ-GM-62: a game has its requirements file, and that file names a test of docs/MANUAL_TESTS.md that exists.
func _files_of_games() -> void:
	print("the files of the games")
	var manual := _read("res://docs/MANUAL_TESTS.md")
	var docs: Array[String] = []
	for g in Registry.GAMES:
		var path: String = g.doc
		docs.append(path)
		_check(FileAccess.file_exists(path) and path.begins_with("res://docs/games/"),
				"%s has its requirements file (REQ-GM-1)" % g.id)
		var re := RegEx.create_from_string("(?m)^\\| REQ-GM-62 \\|.*?[Tt]est ([0-9]+[a-z]?)")
		var m := re.search(_read(path))
		_check(m != null and manual.contains("\n## Test %s\n" % m.get_string(1)),
				"%s: its requirements file names a test section of MANUAL_TESTS.md that exists (REQ-GM-62)" % g.id)
	var listed := true
	for f in DirAccess.get_files_at("res://docs/games"):
		if f.ends_with(".md") and f != "TEMPLATE.md" and not docs.has("res://docs/games/" + f):
			listed = false
			print("    a requirements file of no game: ", f)
	_check(listed, "every file of docs/games (but the template) is the requirements file of a registry game (REQ-GM-1)")


## REQ-GM-10, REQ-2D-1: a game extends minigame.gd, and there is no 3D base class. REQ-GM-11: the files of the games do not read
## the sensors or the network themselves, they read PlayerInput.
func _game_scripts() -> void:
	print("the scripts of the games")
	for g in Registry.GAMES:
		var s: Script = load(g.path)
		var chain: Array[String] = []
		while s != null:
			chain.append(s.resource_path)
			s = s.get_base_script()
		_check(chain.has("res://scripts/game/minigame.gd") and g.dim == "2d",
				"%s extends minigame.gd and is 2D (REQ-GM-10, REQ-2D-1): %s" % [g.id, str(chain)])
	_check(not FileAccess.file_exists("res://scripts/game/minigame_3d.gd"), "there is no 3D base class (REQ-GM-10)")
	var banned := RegEx.create_from_string("Input\\.get_(accelerometer|gyroscope|gravity|magnetometer)"
			+ "|tv_server|TvServer|ControllerClient")
	var offenders: Array[String] = []
	for f in _files("res://scripts/game", ".gd"):
		for line in _read(f).split("\n"):
			var code := line.split("#")[0]
			if banned.search(code) != null:
				offenders.append("%s: %s" % [f, line.strip_edges()])
	_check(offenders.is_empty(), "no game reads a sensor or the network itself (REQ-GM-11) %s" % str(offenders))


## REQ-FL-22: every game has a tile file, a description and a how-to text.
func _registry_texts() -> void:
	print("the texts and tiles of the games")
	for g in Registry.GAMES:
		_check(FileAccess.file_exists(g.tile) and Lang.t(g.description) != g.description and Lang.t(g.how_to) != g.how_to
				and Lang.t(g.title) != g.title, "%s has a tile, a title, a description and a how-to text (REQ-FL-22)" % g.id)


## The player counts and the pad that a game's own requirements name, and the Car Race track list.
func _registry_values() -> void:
	print("the values of the registry")
	var seeds: int = load("res://scripts/game/marble_race/marble_track.gd").FIXED_SEEDS.size()
	var race: Dictionary = Registry.find("marble_race")
	var row: Dictionary = {}
	for r in race.settings:
		if r.key == "track_choice":
			row = r
	var want: Array = []
	for i in seeds:
		want.append(str(i + 1))
	want.append("random")
	_check(row.get("values", []) == want, "the track list has one value for each fixed seed and the random track (REQ-MR-25)")
	_check(row.get("titles", []).size() == row.get("values", []).size(), "every track value has a title")
	_check(race.min_players == 1 and race.max_players == 4, "Car Race: 1 to 4 players (REQ-MR-1)")
	var tower: Dictionary = Registry.find("tower_builder")
	_check(tower.min_players == 1 and tower.max_players == 4, "Tower Builder: 1 to 4 phones, one shared tower (REQ-TB-1)")
	_check(tower.pad == ["a"], "Tower Builder: the pad has button A alone (REQ-TB-17)")
	var hockey: Dictionary = Registry.find("air_hockey")
	_check(hockey.min_players == 1 and hockey.max_players == 4 and hockey.get("enroll", false),
			"Air Hockey: 1 to 4 phones, and the players enroll in the game (REQ-AH-2)")
	_check(Registry.find("bumper_cars").pad == [], "Bumper Cars: the pad has no Recenter box, no A and no B (REQ-BC-2)")


## REQ-GM-3: the status of a requirement is one of the words of the rule. A typo in it hides the requirement from the checks.
func _status_words() -> void:
	print("the status words")
	var re := RegEx.create_from_string(STATUS_OK)
	var bad: Array[String] = []
	var rows := 0
	for f in DirAccess.get_files_at("res://docs/games"):
		if not f.ends_with(".md") or f == "TEMPLATE.md":
			continue
		for line in _read("res://docs/games/" + f).split("\n"):
			if not line.begins_with("| REQ-"):
				continue
			var cells := line.split(" | ")
			var id := cells[0].trim_prefix("| ")
			if id.begins_with("REQ-GM-") or id.contains("-S") or cells.size() < 4:   # The tables of the general rules and of the sounds.
				continue
			rows += 1
			if cells.size() < 3 or re.search(cells[cells.size() - 2].strip_edges()) == null:
				bad.append("%s: %s" % [f, line.substr(0, 60)])
	_check(rows > 200 and bad.is_empty(),
			"%d requirement rows, every status is Done, Open, Device, Removed or Planned (issue #N) (REQ-GM-3) %s" % [rows, str(bad)])


## REQ-FL-21: the template of a requirements file and the add-minigame skill both tell how to make the tile.
func _tile_step() -> void:
	print("the tile step")
	for path in ["res://docs/games/TEMPLATE.md", "res://.claude/skills/add-minigame/SKILL.md"]:
		_check(_read(path).contains("tools/make_tiles.gd"),
				"%s tells how to make the tile with tools/make_tiles.gd (REQ-FL-21)" % path)
