extends RefCounted
## The settings of a game (REQ-GM-90 to 94): the rows of the settings view, the value of each row, and the props that
## the game gets. Pure logic: the view (`scripts/ui/tv_game_settings.gd`) only draws it.
## A game has a settings view when its registry entry has a `settings` list (it may be empty). Every such game has the row
## Difficulty first (REQ-GM-91). `settings` lists more rows: {key, label, values: [...], titles: [...], default: "..."} (a choice row;
## `default` is the value when nothing was chosen, the first value when it is missing).

const DIFFICULTY := {
	"key": "difficulty", "label": "Difficulty", "values": ["easy", "medium", "hard"], "titles": ["Easy", "Medium", "Hard"],
}
const DEFAULT_DIFFICULTY := "medium"

## The chosen values of this run of the app, for each game id (REQ-GM-94). Nothing is saved to the disk.
static var _chosen := {}


static func has_view(game: Dictionary) -> bool:
	return game.has("settings")


## The rows of a game: Difficulty, then the rows of the game.
static func rows_for(game: Dictionary) -> Array:
	var rows: Array = [DIFFICULTY]
	rows.append_array(game.get("settings", []))
	return rows


## The chosen value of a row (the first value, or Medium for Difficulty, when nothing was chosen yet).
static func value(game: Dictionary, row: Dictionary) -> String:
	var chosen: Dictionary = _chosen.get(String(game.id), {})
	var key := String(row.key)
	if chosen.has(key) and row.values.has(chosen[key]):
		return String(chosen[key])
	if key == "difficulty":
		return DEFAULT_DIFFICULTY
	return String(row.get("default", row.values[0]))


static func set_value(game: Dictionary, row: Dictionary, v: String) -> void:
	if not row.values.has(v):
		return
	var chosen: Dictionary = _chosen.get(String(game.id), {})
	chosen[String(row.key)] = v
	_chosen[String(game.id)] = chosen


## The value after `delta` steps. It stops at the first and last value and does not wrap (REQ-GM-92).
static func step(row: Dictionary, current: String, delta: int) -> String:
	var i := clampi(row.values.find(current) + delta, 0, row.values.size() - 1)
	return String(row.values[i])


## The title of a value ("easy" -> "Easy").
static func title_of(row: Dictionary, v: String) -> String:
	var i: int = row.values.find(v)
	return String(row.titles[i]) if i >= 0 else v


## The props the game gets: the props of its registry entry and the chosen value of each row (REQ-GM-93).
static func props_for(game: Dictionary) -> Dictionary:
	var props: Dictionary = game.get("props", {}).duplicate()
	for row in rows_for(game):
		props[String(row.key)] = value(game, row)
	return props


static func clear() -> void:
	_chosen.clear()
