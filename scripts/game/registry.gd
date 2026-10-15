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
##   props   optional. Values set on the game before it starts.
##   settings  optional. The game has a settings view (REQ-GM-90) when this list exists. It lists the rows after Difficulty
##             (see game_settings.gd). An empty list means Difficulty only. A row with `"type": "tracks"` is the track list
##             of The Amazing Race (`scripts/ui/track_picker.gd`).
##   min_players / max_players  allowed player count (REQ-GM-20). The Games screen dims a game that does not fit.

const Lang = preload("res://scripts/core/lang.gd")

const GAMES: Array[Dictionary] = [
	{"id": "maze", "doc": "res://docs/games/maze.md", "title": "Treasure Maze", "dim": "2d",
			"description": "Tilt your phone to roll your ball through the maze. The first ball in the exit wins.",
			"tile": "res://assets/tiles/maze.png",
			"path": "res://scripts/game/maze/maze_game.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "maze_theme", "label": "Theme", "values": ["castle", "garden", "ice"],
					"titles": ["Castle", "Garden", "Ice"], "default": "garden"}]},
	{"id": "marble_race", "doc": "res://docs/games/marble_race.md", "title": "The Amazing Race", "dim": "2d",
			"description": "Tilt to steer your car along the road. The first car over the line wins.",
			"tile": "res://assets/tiles/marble_race.png",
			"path": "res://scripts/game/marble_race/marble_race.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "race_theme", "label": "Theme", "values": ["candy", "space", "jungle"],
					"titles": ["Candy Road", "Space Rally", "Jungle Run"], "default": "candy"},
					{"key": "track_choice", "label": "Track", "type": "tracks",
					"values": ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "random"],
					"titles": ["Track 1", "Track 2", "Track 3", "Track 4", "Track 5", "Track 6", "Track 7", "Track 8", "Track 9",
							"Track 10", "Random"]}]},
	{"id": "paint_grab", "doc": "res://docs/games/paint_grab.md", "title": "Paint Grab", "dim": "2d",
			"description": "Tilt your phone to roll your paint blob over the floor. The most painted tiles in 60 s wins.",
			"tile": "res://assets/tiles/paint_grab.png",
			"path": "res://scripts/game/paint_grab/paint_grab_game.gd", "min_players": 1, "max_players": 4, "settings": []},
	{"id": "sumo_bumpers", "doc": "res://docs/games/sumo_bumpers.md", "title": "Sumo Bumpers", "dim": "2d",
			"description": "Tilt to roll your bumper and push the others off the shrinking platform. Most points in 3 rounds wins.",
			"tile": "res://assets/tiles/sumo_bumpers.png",
			"path": "res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd", "min_players": 2, "max_players": 4, "settings": []},
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
		return Lang.t("Needs 1 player") if int(game.min_players) == 1 else Lang.f("Needs %d players", [int(game.min_players)])
	return Lang.f("Up to %d players", [int(game.max_players)])


## True when `players` is inside the allowed range of the game.
static func accepts(game: Dictionary, players: int) -> bool:
	return players >= int(game.min_players) and players <= int(game.max_players)
