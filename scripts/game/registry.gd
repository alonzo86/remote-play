extends RefCounted
## List of all minigames. The TV menu is built from this list.
## To add a game: add one entry to GAMES. The script loads when the player picks the game.
##   id      unique short name
##   title   text on the menu button
##   dim     "2d" (extends minigame.gd) or "3d" (extends minigame_3d.gd)
##   path    script path
##   doc     requirements file of the game (REQ-GM-6)
##   description  one line for the Games screen (REQ-FL-13)
##   how_to  the key of the how-to-play text, shown in the settings view (issue #77, REQ-GM-103). Required.
##   tile    16:9 screenshot for the Games screen, 640x360 (REQ-FL-20). A missing file shows a placeholder.
##   props   optional. Values set on the game before it starts.
##   settings  optional. The game has a settings view (REQ-GM-90) when this list exists. It lists the rows after Difficulty
##             (see game_settings.gd). An empty list means Difficulty only. A row with `"type": "tracks"` is the track list
##             of Car Race (`scripts/ui/track_picker.gd`).
##   pad     the controls of the phone pad while the game runs (issue #80, REQ-GM-37a): "a", "b", "recenter". The pad shows only
##           these. Pin Pals also has the aim strip on the turn of a phone (REQ-BW-4); it is not listed here.
##   swing   optional. True for a game played with swings of the phone (issue #79; also Freeze Dance, where it is wiggled): the
##           settings view shows the safety line and every phone shows the card "hold on tight" once, before the game can start
##           (REQ-GM-102).
##   enroll  optional. True for a game whose players enroll in the game at every start (Air Hockey, REQ-GM-106): the settings view
##           has no IN and OUT, and the game has all connected phones when it starts. It takes the first two that press A.
##   min_players / max_players  allowed player count (REQ-GM-20). The Games screen dims a game that does not fit.

const Lang = preload("res://scripts/core/lang.gd")

const GAMES: Array[Dictionary] = [
	{"id": "maze", "doc": "res://docs/games/maze.md", "title": "registry.treasure_maze", "dim": "2d",
			"pad": [],
			"how_to": "how_to.maze",
			"description": "registry.desc_maze",
			"tile": "res://assets/tiles/maze.png",
			"path": "res://scripts/game/maze/maze_game.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "maze_theme", "label": "registry.theme", "values": ["garden", "castle", "ice"],
					"titles": ["registry.garden", "registry.castle", "registry.ice"], "default": "garden"}]},
	{"id": "marble_race", "doc": "res://docs/games/marble_race.md", "title": "registry.marble_race", "dim": "2d",
			"pad": [],
			"how_to": "how_to.marble_race",
			"description": "registry.desc_marble_race",
			"tile": "res://assets/tiles/marble_race.png",
			"path": "res://scripts/game/marble_race/marble_race.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "race_theme", "label": "registry.theme", "values": ["candy", "space", "jungle"],
					"titles": ["registry.candy", "registry.space", "registry.jungle"], "default": "candy"},
					{"key": "track_choice", "label": "registry.track", "type": "tracks",
					"values": ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "random"],
					"titles": ["settings.track_n", "settings.track_n", "settings.track_n", "settings.track_n", "settings.track_n",
							"settings.track_n", "settings.track_n", "settings.track_n", "settings.track_n", "settings.track_n",
							"registry.random"], "format_number": true}]},
	{"id": "paint_grab", "doc": "res://docs/games/paint_grab.md", "title": "registry.paint_grab",
			"dim": "2d",
			"pad": [],
			"how_to": "how_to.paint_grab",
			"description": "registry.desc_paint_grab",
			"tile": "res://assets/tiles/paint_grab.png",
			"path": "res://scripts/game/paint_grab/paint_grab_game.gd", "min_players": 1, "max_players": 4, "settings": []},
	{"id": "sumo_bumpers", "doc": "res://docs/games/sumo_bumpers.md", "title": "registry.sumo_bumpers", "dim": "2d",
			"pad": ["a"],
			"how_to": "how_to.sumo_bumpers",
			"description": "registry.desc_sumo_bumpers",
			"tile": "res://assets/tiles/sumo_bumpers.png",
			"path": "res://scripts/game/sumo_bumpers/sumo_bumpers_game.gd", "min_players": 2, "max_players": 4, "settings": []},
	{"id": "snowball_splat", "doc": "res://docs/games/snowball_splat.md", "title": "registry.snowball_splat", "dim": "2d",
			"pad": ["a", "recenter"],
			"how_to": "how_to.snowball_splat",
			"description": "registry.desc_snowball_splat",
			"tile": "res://assets/tiles/snowball_splat.png",
			"path": "res://scripts/game/snowball_splat/snowball_splat_game.gd", "min_players": 1, "max_players": 4,
			"settings": []},
	{"id": "asteroid_blast", "doc": "res://docs/games/asteroid_blast.md", "title": "registry.galaxy_protector", "dim": "2d",
			"pad": [],
			"how_to": "how_to.asteroid_blast",
			"description": "registry.desc_asteroid_blast",
			"tile": "res://assets/tiles/asteroid_blast.png",
			"path": "res://scripts/game/asteroid_blast/asteroid_blast_game.gd", "min_players": 1, "max_players": 4, "settings": []},
	{"id": "bowling", "doc": "res://docs/games/bowling.md", "title": "registry.pin_pals", "dim": "2d",
			"pad": ["a"],
			"swing": true,
			"how_to": "how_to.bowling",
			"description": "registry.desc_bowling",
			"tile": "res://assets/tiles/bowling.png",
			"path": "res://scripts/game/bowling/bowling_game.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "rails", "label": "bowling.rails", "values": ["off", "on"],
					"titles": ["bowling.without_rails", "bowling.with_rails"], "default": "off"}]},
	{"id": "tennis", "doc": "res://docs/games/tennis.md", "title": "registry.tennis", "dim": "2d",
			"pad": ["a"],
			"swing": true,
			"how_to": "how_to.tennis",
			"description": "registry.desc_tennis",
			"tile": "res://assets/tiles/tennis.png",
			"path": "res://scripts/game/tennis/tennis_game.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "scoring", "label": "tennis.scoring", "values": ["real", "quick"],
					"titles": ["tennis.real", "tennis.quick"], "default": "real"}]},
	{"id": "mini_golf", "doc": "res://docs/games/mini_golf.md", "title": "registry.mini_golf", "dim": "2d",
			"pad": ["a"],
			"swing": true,
			"how_to": "how_to.mini_golf",
			"description": "registry.desc_mini_golf",
			"tile": "res://assets/tiles/mini_golf.png",
			"path": "res://scripts/game/mini_golf/mini_golf_game.gd", "min_players": 1, "max_players": 4,
			"settings": [{"key": "holes", "label": "mini_golf.holes", "values": ["1", "2", "3", "4", "5"],
					"titles": ["mini_golf.holes_1", "mini_golf.holes_2", "mini_golf.holes_3", "mini_golf.holes_4",
					"mini_golf.holes_5"], "default": "3"}]},
	{"id": "whack_a_mole", "doc": "res://docs/games/whack_a_mole.md", "title": "registry.whack_a_mole", "dim": "2d",
			"pad": ["a", "recenter"],
			"how_to": "how_to.whack_a_mole",
			"description": "registry.desc_whack_a_mole",
			"tile": "res://assets/tiles/whack_a_mole.png",
			"path": "res://scripts/game/whack_a_mole/whack_a_mole_game.gd", "min_players": 1, "max_players": 4,
			"settings": []},
		{"id": "air_hockey", "doc": "res://docs/games/air_hockey.md", "title": "registry.air_hockey", "dim": "2d",
				"pad": ["a"],
				"enroll": true,
				"how_to": "how_to.air_hockey",
				"description": "registry.desc_air_hockey",
				"tile": "res://assets/tiles/air_hockey.png",
				"path": "res://scripts/game/air_hockey/air_hockey_game.gd", "min_players": 1, "max_players": 4,
				"settings": [{"key": "goals", "label": "air_hockey.goals_to_win",
						"values": ["3", "4", "5", "6", "7", "8", "9", "10"],
						"titles": ["air_hockey.n_goals", "air_hockey.n_goals", "air_hockey.n_goals", "air_hockey.n_goals",
						"air_hockey.n_goals", "air_hockey.n_goals", "air_hockey.n_goals", "air_hockey.n_goals"],
						"format_number": true, "default": "5"}]},
	{"id": "bumper_cars", "doc": "res://docs/games/bumper_cars.md", "title": "registry.bumper_cars", "dim": "2d",
			"pad": [],
			"how_to": "how_to.bumper_cars",
			"description": "registry.desc_bumper_cars",
			"tile": "res://assets/tiles/bumper_cars.png",
			"path": "res://scripts/game/bumper_cars/bumper_cars_game.gd", "min_players": 2, "max_players": 4, "settings": []},
	{"id": "sheep_herding", "doc": "res://docs/games/sheep_herding.md", "title": "registry.sheep_herding", "dim": "2d",
			"pad": [],
			"how_to": "how_to.sheep_herding",
			"description": "registry.desc_sheep_herding",
			"tile": "res://assets/tiles/sheep_herding.png",
			"path": "res://scripts/game/sheep_herding/sheep_herding_game.gd", "min_players": 1, "max_players": 4, "settings": []},
		{"id": "tower_builder", "doc": "res://docs/games/tower_builder.md", "title": "registry.tower_builder", "dim": "2d",
				"pad": ["a"],
				"how_to": "how_to.tower_builder",
				"description": "registry.desc_tower_builder",
				"tile": "res://assets/tiles/tower_builder.png",
				"path": "res://scripts/game/tower_builder/tower_builder_game.gd", "min_players": 1, "max_players": 4, "settings": []},
	{"id": "freeze_dance", "doc": "res://docs/games/freeze_dance.md", "title": "registry.freeze_dance", "dim": "2d",
			"pad": [],
			"swing": true,
			"how_to": "how_to.freeze_dance",
			"description": "registry.desc_freeze_dance",
			"tile": "res://assets/tiles/freeze_dance.png",
			"path": "res://scripts/game/freeze_dance/freeze_dance_game.gd", "min_players": 1, "max_players": 4,
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
		return Lang.t("minigame.no_players_connected") if int(game.min_players) == 1 else Lang.f("games.needs_players",
				[int(game.min_players)])
	return Lang.f("games.up_to_players", [int(game.max_players)])


## True when the pad of the game has the control `key` ("a", "b" or "recenter"), issue #80.
static func has_control(game: Dictionary, key: String) -> bool:
	return key in game.get("pad", [])


## The buttons of the pad that the game uses, as the letters of the `ab` field of the protocol: "", "a", "b" or "ab".
static func buttons_of(game: Dictionary) -> String:
	return ("a" if has_control(game, "a") else "") + ("b" if has_control(game, "b") else "")


## True when `players` is inside the allowed range of the game.
static func accepts(game: Dictionary, players: int) -> bool:
	return players >= int(game.min_players) and players <= int(game.max_players)
