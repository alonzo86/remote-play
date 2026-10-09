extends RefCounted
## List of all minigames. The TV menu is built from this list.
## To add a game: add one entry to GAMES. The script loads when the player picks the game.
##   id      unique short name
##   title   text on the menu button
##   dim     "2d" (extends minigame.gd) or "3d" (extends minigame_3d.gd)
##   path    script path
##   doc     requirements file of the game (REQ-GM-6)
##   description  one line for the Games screen (REQ-FL-13)
##   tile    16:9 screenshot for the Games screen, 640x360 (REQ-FL-20). A missing file shows a placeholder.
##   props   optional. Values set on the game before it starts (for example the track of a race).
##   variants  optional. List of {title, props}. The menu asks which variant to start before the game
##             starts (for example the track of a race). The props of the variant are used.
##   settings  optional. The game has a settings view (REQ-GM-90) when this list exists. It lists the rows after Difficulty
##             (see game_settings.gd). An empty list means Difficulty only.
##   min_players / max_players  allowed player count (REQ-GM-20). The Games screen dims a game that does not fit.

const GAMES: Array[Dictionary] = [
	{"id": "maze", "doc": "res://docs/games/maze.md", "title": "Tilt Maze", "dim": "2d",
			"description": "Tilt your phone to roll your ball through the maze. The first ball in the exit wins.",
			"tile": "res://assets/tiles/maze.png",
			"path": "res://scripts/game/maze/maze_game.gd", "min_players": 1, "max_players": 4, "settings": []},
	{"id": "marble_race", "doc": "res://docs/games/marble_race.md", "title": "Marble Race", "dim": "3d",
			"description": "Tilt to roll your marble along the track. The first marble over the line wins.",
			"tile": "res://assets/tiles/marble_race.png",
			"path": "res://scripts/game/marble_race/marble_race.gd", "min_players": 1, "max_players": 4,
			"variants": [
				{"title": "Classic", "props": {"track_id": "classic"}},
				{"title": "Sprint", "props": {"track_id": "sprint"}},
				{"title": "Zigzag", "props": {"track_id": "zigzag"}},
				{"title": "Gauntlet", "props": {"track_id": "gauntlet"}},
			]},
	{"id": "snowball_splat", "doc": "res://docs/games/snowball_splat.md", "title": "Snowball Splat", "dim": "2d",
			"description": "Point your phone at the screen and press A to throw snowballs at the silly Puffs. Most points in 60 s wins.",
			"tile": "res://assets/tiles/snowball_splat.png",
			"path": "res://scripts/game/snowball_splat/snowball_splat_game.gd", "min_players": 1, "max_players": 4,
			"settings": []},
]


static func all() -> Array[Dictionary]:
	return GAMES


static func find(id: String) -> Dictionary:
	for g in GAMES:
		if g.id == id:
			return g
	return {}


## The id of the game that has this script, or "".
static func id_of_script(script: Script) -> String:
	for g in GAMES:
		if String(g.path) == script.resource_path:
			return String(g.id)
	return ""


static func load_script(id: String) -> GDScript:
	var g := find(id)
	if g.is_empty():
		return null
	return load(String(g.path)) as GDScript


## Why a game cannot start with `players` players (REQ-FL-14).
static func reason(game: Dictionary, players: int) -> String:
	if players < int(game.min_players):
		return "Needs %d players" % int(game.min_players)
	return "Up to %d players" % int(game.max_players)


## True when `players` is inside the allowed range of the game.
static func accepts(game: Dictionary, players: int) -> bool:
	return players >= int(game.min_players) and players <= int(game.max_players)
