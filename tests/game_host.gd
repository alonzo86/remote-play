extends SceneTree
## The `GameHost` of the minigame base class (issue #300, step 1): a `Minigame` asks the TV app for everything through
## `game_host`, so it runs here with a stub host and no TV server. The stub records each call.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/game_host.gd -- --role=tv

const PlayerInput = preload("res://scripts/input/player_input.gd")

var _checks := 0
var _fails := 0
var _stub_host: GDScript
var _minigame: GDScript


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
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _names(host: Object) -> Array:
	return host.calls.map(func(c: Array) -> String: return c[0])


func _run() -> void:
	print("a game with a stub host")
	var Minigame = load("res://scripts/game/minigame.gd")   # Loaded here: the game needs the App autoload to compile.
	_minigame = Minigame
	_stub_host = load("res://tests/stub_game_host.gd")
	var host = _stub_host.new()
	var game = Minigame.new()
	game.game_host = host
	root.add_child(game)
	await process_frame
	_check(game.participants == [0, 2] and game.players_at_start == 2, "the participants are the players that the host gives")
	_check(host.calls.size() >= 2 and host.calls[0] == ["pad", false, ""] and host.calls[1] == ["phase", "playing", [0, 2]],
			"the pad of the phones and the phase 'playing' go to the host, in this order")
	_check(game.player(2) == host.player(2), "player(slot) comes from the host")

	print("a lost phone pauses the game through the host")
	host.player(2).state = PlayerInput.State.LOST
	await process_frame
	await process_frame
	_check(["phase", "paused", [0, 2]] in host.calls, "the phase 'paused' is sent for the participants")
	host.calls.clear()
	game._resume_without_lost()
	_check(["drop", 2] in host.calls and game.participants == [0], "'Resume without' frees the slot through the host")
	_check(["phase", "playing", [0]] in host.calls, "and the phase 'playing' is sent for the players that stay")

	print("the ways out")
	host.calls.clear()
	game.restart()
	_check(host.calls == [["go", game.start_props]], "Try again asks the host to start the game again with its props")
	game.on_back()
	game.close_menu()
	game.is_over = true
	game.on_back()
	_check(_names(host).count("menu") == 1, "Back on a game that is over goes to the menu through the host")
	game.queue_free()
	await process_frame

	print("no players")
	var empty = _stub_host.new()
	var none: Array[int] = []
	empty.slots = none
	var g2 = Minigame.new()
	g2.game_host = empty
	root.add_child(g2)
	await process_frame
	_check(g2.is_over, "a host with no players ends the game with the 'No players connected' menu")
	empty.calls.clear()
	g2.menu_buttons()[0].pressed.emit()
	_check(_names(empty).has("menu"), "its button goes to the menu through the host")
	g2.queue_free()
	await process_frame
	await _phone_leave_ask()
	await _haptics()
	_no_app_in_games()


## REQ-FL-52c (issue #435): a phone asks the game to end with `leave_ask`; `request_leave(from_phone)` opens the question
## "End the game?" only for a participant, only when no menu is open and only while the game is not over.
func _phone_leave_ask() -> void:
	print("a phone asks to end the game")
	var host = _stub_host.new()
	var game = _minigame.new()
	game.game_host = host
	root.add_child(game)
	await process_frame
	game.request_leave(1)   # Slot 1 does not take part (the stub host gives the slots 0 and 2).
	_check(not game._menu_open, "a phone that does not take part cannot open the question")
	game.request_leave(0)
	_check(game._menu_open and not _names(host).has("menu"), "a participant opens the question and the game does not leave at once")
	var first_button = game.menu_buttons()[0]
	game.request_leave(2)
	_check(game._menu_open and game.menu_buttons()[0] == first_button, "a second request while the question is open changes nothing")
	game.close_menu()
	game.is_over = true
	game.request_leave(0)
	_check(not game._menu_open and not _names(host).has("menu"),
			"a request on a game that is over does nothing (the result menu stays, the game does not leave)")
	game.queue_free()
	await process_frame


## Step 2 of the plan of issue #300: a buzz goes through the host, also the one of the `Haptics` helper of a game.
func _haptics() -> void:
	print("haptics through the host")
	var host = _stub_host.new()
	var game = load("res://tests/buzz_game.gd").new()
	game.game_host = host
	root.add_child(game)
	await process_frame
	game.haptic(1, 50)
	_check(["haptic", 1, 50] in host.calls, "Minigame.haptic goes to the host")
	_check(game._haptics.host == host, "the Haptics helper of the game gets the host when the game starts")
	host.calls.clear()
	_check(game._haptics.pulse(0, 30, 100) and ["haptic", 0, 30] in host.calls, "a pulse of the helper goes to the host")
	_check(not game._haptics.pulse(0, 30, 100) and host.calls.size() == 1, "and the cool-down still holds back a second pulse")
	game.queue_free()
	await process_frame


## REQ-GM-12 (issue #300): a game file does not name the `App` autoload. The host is the only class of `scripts/game/` that does;
## `Haptics` keeps the phone side (the HAPTICS switch).
func _no_app_in_games() -> void:
	print("no game names App")
	var offenders: Array[String] = []
	var stack: Array[String] = ["res://scripts/game"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + sub)
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f in ["game_host.gd", "haptics.gd"]:
				continue
			var code := FileAccess.get_file_as_string(dir + "/" + f)
			for line in code.split("\n"):
				var body := line.split("#")[0]
				if body.contains("App.") or body.contains("App)"):
					offenders.append("%s/%s: %s" % [dir, f, line.strip_edges()])
	_check(offenders.is_empty(), "no file under scripts/game (but the host and Haptics) names App: %s" % str(offenders))
