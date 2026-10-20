extends SceneTree
## Test 18 steps 4a and 4b: the phone app makes no sound. Only the TV has the players and buses of the Sound manager.
## On the phone every call does nothing, so the media volume of the phone has no effect. Run:
##   godot --headless --path . --script tests/audio_controller.gd -- --role=controller

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
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _players(node: Node) -> Array:
	return node.find_children("*", "AudioStreamPlayer*", true, false)


func _run() -> void:
	for i in 5:
		await process_frame
	var sound: Node = root.get_node("Sound")
	var app: Node = root.get_node("App")
	_check(not sound.enabled, "the phone: the Sound manager is off")
	_check(AudioServer.get_bus_index("Music") < 0 and AudioServer.get_bus_index("SFX") < 0, "the phone has no Music or SFX bus")
	_check(_players(root).is_empty(), "the phone has no audio player at the start")
	# Every call of the games and menus does nothing.
	_check(not sound.sfx("select") and not sound.sfx("go"), "sfx() plays nothing on the phone")
	sound.music("menu")
	sound.music_at_go("maze")
	sound.start_queued_music()
	sound.duck(true)
	await process_frame
	_check(_players(root).is_empty() and sound._music == null, "music() makes no player on the phone")
	# Through the screens of a phone and a haptic message from the TV: still no player, and the master bus stays silent.
	var wait = load("res://scripts/ui/controller_wait.gd")
	var settings = load("res://scripts/ui/controller_settings.gd")
	for s in [wait, settings, wait]:
		app.go(s)
		for i in 10:
			await process_frame
	_check(_players(root).is_empty(), "after the phone screens there is still no audio player")
	_check(AudioServer.get_bus_peak_volume_left_db(0, 0) <= -60.0,
			"the master bus is silent (%.0f dB)" % AudioServer.get_bus_peak_volume_left_db(0, 0))
