extends RefCounted
## Small rules for the two files that the app keeps in `user://` (the settings of `App`, the last TV of `ControllerClient`).
## A write can fail (full disk, read-only path) and a file can hold anything (a damaged or hand-edited file): the app keeps its
## values in memory, says so in the log, and takes from a file only a value of the type that it expects (issue #309).


## Writes `cfg` to `path`. Returns false and puts a warning in the log when the write fails.
static func save(cfg: ConfigFile, path: String) -> bool:
	var err := cfg.save(path)
	if err != OK:
		push_warning("Could not save %s (error %d). The values stay in memory only." % [path, err])
		return false
	return true


## `value` when it has the type of `default`, else `default`. A whole number may stand for a float, and a float with no
## fraction for an integer (a hand-edited `7.0`). A text, a boolean, a number and a list never stand for one another.
static func fit(value: Variant, default: Variant) -> Variant:
	if typeof(value) == typeof(default):
		return value
	if default is float and value is int:
		return float(value)
	if default is int and value is float and is_finite(value) and value == floorf(value):
		return int(value)
	return default


## `fit` for an integer that must lie in `lo` to `hi`: a value outside is cut to the nearest end.
static func fit_range(value: Variant, default: int, lo: int, hi: int) -> int:
	return clampi(int(fit(value, default)), lo, hi)
