extends SceneTree
## Copy a player to another phone (FD-22, REQ-FL-76, 77): the Share screen (on the edit screen), IMPORT on the new
## player screen (PASTE A CODE and the player list were removed on 2026-11-02), and the Connect screen that sends a
## player code to the same import.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/ui_share.gd -- --role=controller

const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Lang = preload("res://scripts/core/lang.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")
const Profile = preload("res://scripts/core/profile.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")

const PATH := "user://test_ui_share.cfg"
const ID_B := "00112233445566778899aabbccddeeff"

var _checks := 0
var _fails := 0
var _app: Node


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


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var f := _find_button(c, text)
		if f != null:
			return f
	return null


func _code(p_id: String, p_name: String, av: int, rev := 0, bests := {}) -> String:
	var p = Profile.new()
	p.id = p_id
	p.player_name = p_name
	p.avatar = av
	p.rev = rev
	p.bests = bests
	return ProfileCode.encode(p)


func _run() -> void:
	await process_frame
	_app = root.get_node("App")
	var real_store = _app.profiles
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	_app.profiles = ProfileStore.new(PATH)
	var maya = _app.profiles.create("Maya", 4)
	await _save_fails()
	await _share(maya)
	await _import()
	await _connect_screen()
	await _round_closes_share()
	await _new_best()
	_app.profiles = real_store
	_app.apply_profile()
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func _share(maya: RefCounted) -> void:
	print("the Share screen")
	_app.go(_app.ControllerProfileEdit, {"profile_id": maya.id})
	await process_frame
	var share_button := _find_button(_app.current_screen(), "profiles.share")
	_check(share_button != null, "the edit screen of a player has a SHARE button")
	share_button.pressed.emit()
	await process_frame
	var screen: Control = _app.current_screen()
	var qr: Control = screen.find_children("*", "Control", true, false).filter(
			func(n: Node) -> bool: return n.get_script() != null and n.get_script().resource_path.ends_with("qr_view.gd"))[0]
	_check(screen.get_script() == _app.ControllerProfileShare and screen.code == ProfileCode.encode(maya) and qr.text == screen.code,
			"it shows the QR code of the profile, made from the same text as the code")
	_check(qr.quiet == 4 and qr._qr.size() >= 21, "the code has a quiet zone of 4 modules and was made when the screen opened")
	var decoded := ProfileCode.decode(screen.code)
	_check(decoded.ok and decoded.profile.id == maya.id and decoded.profile.player_name == "Maya" and decoded.profile.avatar == 4,
			"the text is the profile of that player")
	_find_button(screen, "profile_share.copy_code").pressed.emit()
	_check(_find_button(screen, "CODE COPIED") != null, "COPY CODE says the code was copied")
	_check(screen._timer.wait_time == 60.0 and not screen._timer.is_stopped(), "the code goes away after 60 seconds")
	screen._timer.timeout.emit()
	await process_frame
	_check(_app.current_screen().get_script() == _app.ControllerProfileEdit and _app.current_screen().profile_id == maya.id,
			"when the time is over the screen goes back to the edit screen of that player")
	_find_button(_app.current_screen(), "profiles.share").pressed.emit()
	await process_frame
	_find_button(_app.current_screen(), "common.back").pressed.emit()
	await process_frame
	_check(_app.current_screen().get_script() == _app.ControllerProfileEdit and _app.current_screen().profile_id == maya.id,
			"BACK on the Share screen also goes back to the edit screen")


func _save_fails() -> void:
	print("a save that fails")
	var old_path: String = _app.profiles.path
	_app.profiles.path = "user://no_such_folder_375/profiles.cfg"
	_app.go(_app.ControllerProfileEdit, {"profile_id": ""})
	await process_frame
	var screen: Control = _app.current_screen()
	screen._name.text = "Zed"
	screen._on_text("Zed")
	screen._save.pressed.emit()
	await process_frame
	_check(_app.current_screen() == screen and screen._hint.text == Lang.t("profiles.could_not_save").to_upper(),
			"a save that fails keeps the screen and says COULD NOT SAVE: '%s'" % screen._hint.text)
	var made = _app.profiles.profiles.back()
	_check(made != null and made.player_name == "Zed", "and the player stays in memory")
	var count: int = _app.profiles.profiles.size()
	screen._save.pressed.emit()
	await process_frame
	_check(_app.profiles.profiles.size() == count and screen.profile_id == made.id,
			"a second tap on SAVE changes that player and makes no second one (%d players)" % _app.profiles.profiles.size())
	_app.profiles.path = old_path
	_app.profiles.delete(made.id)
	_app.apply_profile()


func _import() -> void:
	print("import a code")
	_app.go(_app.ControllerProfileEdit, {"profile_id": ""})
	await process_frame
	var list: Control = _app.current_screen()
	list._on_scanned(_code(ID_B, "Noam", 6, 1, {"paint_grab|easy": 12}))
	_check(list._hint.text == "PLAYER ADDED." and _app.profiles.find(ID_B) != null and _app.profiles.profiles.size() == 2,
			"a good code adds the player and the screen says so")
	list._on_scanned(_code(ID_B, "Noam2", 7, 2, {"paint_grab|easy": 3}))
	_check(list._hint.text == "PLAYER UPDATED." and _app.profiles.find(ID_B).player_name == "Noam2"
			and _app.profiles.find(ID_B).bests["paint_grab|easy"] == 12, "the same player again: newer name, better best")
	list._on_scanned("WP1.not-a-code")
	_check(list._hint.text == "THIS CODE DOES NOT WORK.", "a broken code is refused with a message")
	list._on_scanned("ws://192.168.1.5:47801/KQZM")
	_check(list._hint.text == "THIS IS A ROOM LINK.", "a room link on this screen is said to be a room link")
	list._on_scanned("hello")
	_check(list._hint.text == "THIS CODE DOES NOT WORK.", "other text is refused")
	list._hint.text = "SENTINEL"
	list._on_scan_failed("cancelled")
	_check(list._hint.text == "SENTINEL", "a cancelled scan changes nothing")
	list._on_scan_failed("camera")
	_check(list._hint.text.contains("CAMERA"), "a failed scan says why")
	# A scan that comes late, when a round has started, changes nothing (plan 6.4).
	var late: Node = _app.client
	late._set_state(ControllerClient.State.CONNECTED)
	late.phase = "playing"
	var count: int = _app.profiles.profiles.size()
	list._on_scanned(_code("ef".repeat(16), "Late", 3))
	_check(_app.profiles.profiles.size() == count and _app.profiles.find("ef".repeat(16)) == null, "a code in a round is ignored")
	late.phase = "menu"
	late._set_state(ControllerClient.State.IDLE)
	# The active profile is merged: the new name goes to the TV at once.
	var c: Node = _app.client
	_app.profiles.set_active(ID_B)
	_app.apply_profile()
	_app.import_profile_text(_code(ID_B, "Noa", 9, 5))
	_check(c.player_name == "Noa" and c.avatar == 9, "when the imported player is the active one, the phone uses the new values")
	# A full list refuses a new player.
	while not _app.profiles.is_full():
		_app.profiles.create("P%d" % _app.profiles.profiles.size(), 1)
	_check(_app.import_profile_text(_code("ab".repeat(16), "Late", 1)).contains("8"), "a new player is refused when the phone has 8")


func _connect_screen() -> void:
	print("the Connect screen")
	_app.go(_app.ControllerConnect)
	await process_frame
	var connect: Control = _app.current_screen()
	_app.profiles.delete(_app.profiles.profiles[2].id)
	connect._on_qr_text(_code("cd".repeat(16), "Dana", 2))
	await process_frame
	connect = _app.current_screen()   # The screen is built again with the new player selected (2026-11-06).
	_check(connect.get_script() == _app.ControllerConnect and connect._status.text == "PLAYER ADDED."
			and _app.profiles.find("cd".repeat(16)) != null and _app.profiles.active_id == "cd".repeat(16),
			"a player code on the Connect screen is taken, selected, and the status line says so (no list screen)")


func _round_closes_share() -> void:
	print("a round")
	var c: Node = _app.client
	c._set_state(ControllerClient.State.CONNECTED)
	c.phase = "menu"
	_app.go(_app.ControllerProfileShare, {"profile_id": _app.profiles.profiles[0].id})
	await process_frame
	_app._show_phone_screen()
	_check(_app.current_screen().get_script() == _app.ControllerProfileShare, "the Share screen stays open in a menu phase")
	c.phase = "playing"
	_app._show_phone_screen()
	_check(_app.current_screen().get_script() == _app.ControllerPad, "a round closes the Share screen and hides the code")
	c.phase = "menu"
	c._set_state(ControllerClient.State.IDLE)


## A result from the TV: the profile keeps the best and the pad says NEW BEST! only while the result of the game is open
## (REQ-GM-99, 100): not on the waiting screen, not after the TV goes back to the menu, not after the player leaves.
func _new_best() -> void:
	print("new best")
	var c: Node = _app.client
	var who = _app.profiles.profiles[0]
	_app.profiles.set_active(who.id)
	_app.apply_profile()
	c._set_state(ControllerClient.State.CONNECTED)
	c.phase = "playing"
	c.result_received.emit("paint_grab|easy", 300)
	var first: Dictionary = _app.last_best
	c.result_received.emit("paint_grab|easy", 340)
	var second: Dictionary = _app.last_best
	_check(first.value == 300 and first.old == 0 and second.value == 340 and second.old == 300,
			"a result that beats the best is remembered with the old best")
	_check(who.bests["paint_grab|easy"] == 340, "and the profile keeps it")
	c.result_received.emit("paint_grab|easy", 100)
	_check(_app.last_best.value == 340 and who.bests["paint_grab|easy"] == 340, "a worse result changes nothing")
	_check(_app.current_best().value == 340, "the pad shows the best of this player while the result menu is open")
	var line: String = _app.ControllerPad.best_line(_app.current_best())
	_check(line == "NEW BEST! 340  BEFORE: 300", "the pad line: %s" % line)
	_check(_app.ControllerPad.best_game_name({"key": "paint_grab|easy"}) == "PAINT GRAB"
			and _app.ControllerPad.best_game_name({"key": "bowling|easy"}) == "PIN PALS"
			and _app.ControllerPad.best_game_name({"key": "asteroid_blast|hard"}) == "STAR SHIELD",
			"the pad writes the name of the game of the best above the line (also when the key id differs from the title)")
	c.phase = "paused"
	_check(not _app.current_best().is_empty(), "a paused result menu still shows it")
	var other_pid: String = c.pid
	c.pid = "f".repeat(32)   # The phone switched to another profile: the best is not theirs.
	_check(_app.current_best().is_empty(), "a best is not shown for another profile")
	c.pid = other_pid
	# The TV goes back to the menu: the message is gone for good, it does not come back with the next game phase.
	c.phase_changed.emit("menu")
	c.phase = "menu"
	_check(_app.last_best.is_empty() and _app.current_best().is_empty(), "the TV is back at the menu: no NEW BEST!")
	c.result_received.emit("paint_grab|easy", 400)
	c.phase = "waiting"
	_check(_app.current_best().is_empty(), "the waiting screen never shows NEW BEST!")
	c.phase = "playing"
	_check(not _app.current_best().is_empty(), "the pad shows it in the game phase")
	c._set_state(ControllerClient.State.RECONNECTING)
	_check(_app.current_best().is_empty(), "a phone that lost the link shows no NEW BEST!")
	c._set_state(ControllerClient.State.CONNECTED)
	c.phase_changed.emit("playing")
	_check(_app.last_best.is_empty(), "the next round clears the message")
	c.result_received.emit("paint_grab|easy", 500)
	c._set_state(ControllerClient.State.IDLE)
	_check(_app.last_best.is_empty(), "the player leaves the game: the message is cleared")

