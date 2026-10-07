extends RefCounted
## List of all minigames. The TV menu is built from this list.
## To add a game: add one entry to GAMES. The script loads when the player picks the game.
##   id      unique short name
##   title   text on the menu button
##   dim     "2d" (extends minigame.gd) or "3d" (extends minigame_3d.gd)
##   path    script path
##   doc     requirements file of the game (REQ-GM-6)
##   props   optional. Values set on the game before it starts (for example the track of a race).
##   variants  optional. List of {title, props}. The menu asks which variant to start before the game
##             starts (for example the track of a race). The props of the variant are used.
##   min_players / max_players  allowed player count (REQ-GM-20). The menu does not check it yet.

const GAMES: Array[Dictionary] = [
	{"id": "maze", "doc": "res://docs/games/maze.md", "title": "Tilt Maze", "dim": "2d",
			"path": "res://scripts/game/maze/maze_game.gd", "min_players": 1, "max_players": 4},
	{"id": "pointer_test", "doc": "res://docs/games/pointer_test.md", "title": "Pointer Test", "dim": "2d",
			"path": "res://scripts/game/pointer_test/pointer_test.gd", "min_players": 1, "max_players": 4},
	{"id": "marble_race", "doc": "res://docs/games/marble_race.md", "title": "Marble Race", "dim": "3d",
			"path": "res://scripts/game/marble_race/marble_race.gd", "min_players": 1, "max_players": 4,
			"variants": [
				{"title": "Classic", "props": {"track_id": "classic"}},
				{"title": "Sprint", "props": {"track_id": "sprint"}},
				{"title": "Zigzag", "props": {"track_id": "zigzag"}},
				{"title": "Gauntlet", "props": {"track_id": "gauntlet"}},
			]},
	{"id": "demo3d", "doc": "res://docs/games/demo3d.md", "title": "3D Demo (tilt balls)", "dim": "3d",
			"path": "res://scripts/game/demo3d/demo3d_game.gd", "min_players": 1, "max_players": 4},
]


static func all() -> Array[Dictionary]:
	return GAMES


static func find(id: String) -> Dictionary:
	for g in GAMES:
		if g.id == id:
			return g
	return {}


static func load_script(id: String) -> GDScript:
	var g := find(id)
	if g.is_empty():
		return null
	return load(String(g.path)) as GDScript


## True when `players` is inside the allowed range of the game.
static func accepts(game: Dictionary, players: int) -> bool:
	return players >= int(game.min_players) and players <= int(game.max_players)
