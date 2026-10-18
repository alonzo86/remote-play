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
##             of Road Rally (`scripts/ui/track_picker.gd`).
##   min_players / max_players  allowed player count (REQ-GM-20). The Games screen dims a game that does not fit.

const Lang = preload("res://scripts/core/lang.gd")

const GAMES: Array[Dictionary] = [
	{"id": "maze", "doc": "res://docs/games/maze.md", "title": "registry.treasure_maze", "dim": "2d",
			"description": "registry.tilt_phone_roll_ball",
			"tile": "res://assets/tiles/maze.png",
			"path": "res://scripts/game/maze/maze_game.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "maze_theme", "label": "registry.theme", "values": ["castle", "garden", "ice"],
					"titles": ["registry.castle", "registry.garden", "registry.ice"], "default": "garden"}]},
	{"id": "marble_race", "doc": "res://docs/games/marble_race.md", "title": "registry.marble_race", "dim": "2d",
			"description": "registry.tilt_roll_marble_along",
			"tile": "res://assets/tiles/marble_race.png",
			"path": "res://scripts/game/marble_race/marble_race.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "race_theme", "label": "registry.theme", "values": ["candy", "space", "jungle"],
					"titles": ["registry.candy_road", "registry.space_rally", "registry.jungle_run"], "default": "candy"},
					{"key": "track_choice", "label": "registry.track", "type": "tracks",
					"values": ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "random"],
					"titles": ["settings.track_n", "settings.track_n", "settings.track_n", "settings.track_n", "settings.track_n",
							"settings.track_n", "settings.track_n", "settings.track_n", "settings.track_n", "settings.track_n",
							"registry.random"], "format_number": true}]},
	{"id": "paint_grab", "doc": "res://docs/games/paint_grab.md", "title": "registry.paint_grab", "dim": "2d",
			"description": "registry.tilt_phone_roll_paint",
			"tile": "res://assets/tiles/paint_grab.png",
			"path": "res://scripts/game/paint_grab/paint_grab_game.gd", "min_players": 1, "max_players": 4, "settings": []},
	{"id": "sumo_bumpers", "doc": "res://docs/games/sumo_bumpers.md", "title": "registry.sumo_bumpers", "dim": "2d",
			"description": "registry.tilt_roll_bumper_push",
			"tile": "res://assets/tiles/sumo_bumpers.png",
			"path": "res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd", "min_players": 2, "max_players": 4, "settings": []},
	{"id": "snowball_splat", "doc": "res://docs/games/snowball_splat.md", "title": "registry.snowball_splat", "dim": "2d",
			"description": "registry.point_phone_at_screen",
			"tile": "res://assets/tiles/snowball_splat.png",
			"path": "res://scripts/game/snowball_splat/snowball_splat_game.gd", "min_players": 1, "max_players": 4,
			"settings": []},
	{"id": "asteroid_blast", "doc": "res://docs/games/asteroid_blast.md", "title": "registry.galaxy_protector", "dim": "2d",
			"description": "registry.tilt_fly_spaceship_blast",
			"tile": "res://assets/tiles/asteroid_blast.png",
			"path": "res://scripts/game/asteroid_blast/asteroid_blast_game.gd", "min_players": 1, "max_players": 4, "settings": []},
	{"id": "bowling", "doc": "res://docs/games/bowling.md", "title": "registry.pin_pals", "dim": "2d",
			"description": "registry.move_phone_aim_swing",
			"tile": "res://assets/tiles/bowling.png",
			"path": "res://scripts/game/bowling/bowling_game.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "rails", "label": "bowling.rails", "values": ["off", "on"],
					"titles": ["bowling.off", "bowling.on"], "default": "off"}]},
	{"id": "tennis", "doc": "res://docs/games/tennis.md", "title": "registry.tennis", "dim": "2d",
			"description": "registry.swing_phone_hit_ball",
			"tile": "res://assets/tiles/tennis.png",
			"path": "res://scripts/game/tennis/tennis_game.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "scoring", "label": "tennis.scoring", "values": ["real", "quick"],
					"titles": ["tennis.real", "tennis.quick"], "default": "real"}]},
	{"id": "mini_golf", "doc": "res://docs/games/mini_golf.md", "title": "registry.mini_golf", "dim": "2d",
			"description": "registry.swing_phone_putt",
			"tile": "res://assets/tiles/mini_golf.png",
			"path": "res://scripts/game/mini_golf/mini_golf_game.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "holes", "label": "mini_golf.holes", "values": ["1", "2", "3", "4", "5"],
					"titles": ["mini_golf.holes_1", "mini_golf.holes_2", "mini_golf.holes_3", "mini_golf.holes_4",
					"mini_golf.holes_5"], "default": "3"}]},
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
		return Lang.t("minigame.no_players_connected") if int(game.min_players) == 1 else Lang.f("games.needs_players",
				[int(game.min_players)])
	return Lang.f("games.up_to_players", [int(game.max_players)])


## True when `players` is inside the allowed range of the game.
static func accepts(game: Dictionary, players: int) -> bool:
	return players >= int(game.min_players) and players <= int(game.max_players)
