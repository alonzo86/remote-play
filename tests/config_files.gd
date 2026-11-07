extends SceneTree
## The settings file and the last-TV file (issue #309): a write that fails is reported and the values stay in memory, and a
## file with values of the wrong type (damaged or edited by hand) loads the defaults instead of the wrong value.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/config_files.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const ConfigIO = preload("res://scripts/core/config_io.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

const SETTINGS_TEMP := "user://test_settings_309.cfg"
const LAST_TEMP := "user://test_last_309.cfg"
const NO_DIR := "user://no_such_folder_309/file.cfg"

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
	_fit()
	_settings()
	_last()
	_cleanup()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _cleanup() -> void:
	for f in [SETTINGS_TEMP, LAST_TEMP]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func _write(path: String, section: String, values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value(section, k, values[k])
	cfg.save(path)


func _fit() -> void:
	print("ConfigIO.fit")
	_check(ConfigIO.fit(5, 7) == 5 and ConfigIO.fit("a", "") == "a" and ConfigIO.fit(true, false) == true, "the same type is kept")
	_check(ConfigIO.fit("loud", 7) == 7 and ConfigIO.fit(5, "") == "" and ConfigIO.fit([1], false) == false
			and ConfigIO.fit({}, "x") == "x" and ConfigIO.fit(1, true) == true, "another type gives the default")
	var f: Variant = ConfigIO.fit(7.0, 3)
	_check(typeof(f) == TYPE_INT and f == 7 and ConfigIO.fit(7.5, 3) == 3 and ConfigIO.fit(INF, 3) == 3,
			"a float without a fraction stands for an integer, a fraction or INF does not")
	var g: Variant = ConfigIO.fit(2, 0.5)
	_check(typeof(g) == TYPE_FLOAT and g == 2.0, "an integer stands for a float")
	_check(ConfigIO.fit_range(99, 7, 0, 10) == 10 and ConfigIO.fit_range(-4, 7, 0, 10) == 0
			and ConfigIO.fit_range("x", 7, 0, 10) == 7,
			"fit_range cuts to the ends and gives the default for a wrong type")


func _settings() -> void:
	print("the settings file")
	var app: Node = load("res://scripts/app.gd").new()
	_write(SETTINGS_TEMP, "settings",
			{"music_volume": "loud", "sfx_volume": 5, "language": 5, "haptics": "yes", "invert_tilt": [1]})
	app._load_settings(SETTINGS_TEMP)
	_check(app.settings.music_volume == 7, "a music volume that is a text loads the default 7")
	_check(app.settings.sfx_volume == 5, "a good value in the same file is still taken")
	_check(app.settings.language == "", "a language that is a number loads the default (the first start choice)")
	_check(app.settings.haptics == true and app.settings.invert_tilt == false, "a boolean that is a text or Array loads the default")

	_write(SETTINGS_TEMP, "settings", {"music_volume": 99, "sfx_volume": -3, "language": "fr"})
	app._load_settings(SETTINGS_TEMP)
	_check(app.settings.music_volume == 10 and app.settings.sfx_volume == 0, "a volume outside 0 to 10 is cut to the nearest end")
	_check(app.settings.language == "", "a language that the app does not have loads the default")

	_write(SETTINGS_TEMP, "settings", {"music_volume": 4.0, "language": "he", "mute": "yes"})
	app._load_settings(SETTINGS_TEMP)
	_check(app.settings.music_volume == 4 and typeof(app.settings.music_volume) == TYPE_INT, "a volume 4.0 is the integer 4")
	_check(app.settings.language == "he" and app.settings.sfx_volume == 0, "a good language is kept (mute as a text is no mute)")

	# Issue #393, REQ-FL-93: "approve new players" is ON by default, a file keeps OFF, a wrong type loads ON.
	var fresh: Node = app.get_script().new()
	_check(fresh.settings.approve_players == true, "approve_players is ON in the settings of a new App")
	fresh.free()
	_write(SETTINGS_TEMP, "settings", {"music_volume": 3})
	app._load_settings(SETTINGS_TEMP)
	_check(app.settings.approve_players == true, "a file with no approve_players key loads ON")
	_write(SETTINGS_TEMP, "settings", {"approve_players": false})
	app._load_settings(SETTINGS_TEMP)
	_check(app.settings.approve_players == false, "a file with approve_players = false keeps OFF")
	for bad in ["no", [false], 0, 1.5, {"a": false}]:
		_write(SETTINGS_TEMP, "settings", {"approve_players": bad})
		var one: Node = app.get_script().new()
		one._load_settings(SETTINGS_TEMP)
		_check(one.settings.approve_players == true, "approve_players of the type %d loads ON (the default)" % typeof(bad))
		one.free()
	app.settings.approve_players = false
	_check(app.save_settings(SETTINGS_TEMP), "a save with the setting OFF works")
	app.settings.approve_players = true
	app._load_settings(SETTINGS_TEMP)
	_check(app.settings.approve_players == false, "the saved OFF is read back")

	app.settings.music_volume = 6
	_check(app.save_settings(SETTINGS_TEMP), "a save to a good path reports true")
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_TEMP)
	_check(cfg.get_value("settings", "music_volume", -1) == 6, "the saved file has the value")
	_check(not app.save_settings(NO_DIR) and app.settings.music_volume == 6,
			"a save to a path that cannot be written reports false and the settings stay in memory")
	app.free()


func _last() -> void:
	print("the last-TV file")
	var c := ControllerClient.new()
	_write(LAST_TEMP, "last", {"host": "192.168.1.5", "port": "47801", "room": ["AB"], "token": 7})
	var l := c.load_last(LAST_TEMP)
	_check(l.host == "192.168.1.5" and l.port == Protocol.WS_PORT and l.room == "" and l.token == "",
			"a port, a room and a token of the wrong type load the defaults; the good host is kept")
	_write(LAST_TEMP, "last", {"host": "10.0.0.2", "port": 70000, "room": "ABCD", "token": "t"})
	_check(c.load_last(LAST_TEMP).port == Protocol.WS_PORT, "a port above 65535 loads the default")
	_write(LAST_TEMP, "last", {"host": "10.0.0.2", "port": 0})
	_check(c.load_last(LAST_TEMP).port == Protocol.WS_PORT, "port 0 loads the default")
	_write(LAST_TEMP, "last", {"host": "10.0.0.2", "port": 5000.0, "room": "ABCD", "token": "t"})
	var ok := c.load_last(LAST_TEMP)
	_check(ok.port == 5000 and typeof(ok.port) == TYPE_INT and ok.room == "ABCD" and ok.token == "t", "a good file loads as it is")
	_check(c.load_last("user://no_file_309.cfg").is_empty(), "a missing file gives an empty answer")
	_check(c._save_last(false, LAST_TEMP), "the save of the last TV to a good path reports true")
	_check(not c._save_last(false, NO_DIR), "the save of the last TV to a path that cannot be written reports false")
	c.free()
