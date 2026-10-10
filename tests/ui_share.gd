extends SceneTree
## Copy a player to another phone (FD-22, REQ-FL-76, 77): the Share screen, SCAN A PLAYER and PASTE A CODE, and the Connect screen
## that sends a player code to the same import.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/ui_share.gd -- --role=controller

const ControllerClient = preload("res://scripts/net/controller_client.gd")
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
	await _share(maya)
	await _import()
	await _connect_screen()
	await _round_closes_share()
	_app.profiles = real_store
	_app.apply_profile()
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func _share(maya: RefCounted) -> void:
	print("the Share screen")
	_app.go(_app.ControllerProfiles)
	await process_frame
	var share_button := _find_button(_app.current_screen(), "SHARE")
	_check(share_button != null, "each profile row has a SHARE item")
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
			"the text is the profile of that row")
	_find_button(screen, "COPY CODE").pressed.emit()
	_check(_find_button(screen, "CODE COPIED") != null, "COPY CODE says the code was copied")
	_check(screen._timer.wait_time == 60.0 and not screen._timer.is_stopped(), "the code goes away after 60 seconds")
	screen._timer.timeout.emit()
	await process_frame
	_check(_app.current_screen().get_script() == _app.ControllerProfiles, "when the time is over the screen goes back to the list")


func _import() -> void:
	print("paste a code")
	_app.go(_app.ControllerProfiles)
	await process_frame
	var list: Control = _app.current_screen()
	_check(_find_button(list, "PASTE A CODE") != null, "the list has PASTE A CODE")
	list._on_code(_code(ID_B, "Noam", 6, 1, {"paint_grab|easy": 12}))
	_check(list._note.text == "PLAYER ADDED." and _app.profiles.find(ID_B) != null and _app.profiles.profiles.size() == 2,
			"a good code adds the player and the screen says so")
	list._on_code(_code(ID_B, "Noam2", 7, 2, {"paint_grab|easy": 3}))
	_check(list._note.text == "PLAYER UPDATED." and _app.profiles.find(ID_B).player_name == "Noam2"
			and _app.profiles.find(ID_B).bests["paint_grab|easy"] == 12, "the same player again: newer name, better best")
	list._on_code("WP1.not-a-code")
	_check(list._note.text == "THIS CODE DOES NOT WORK.", "a broken code is refused with a message")
	list._on_code("ws://192.168.1.5:47801/KQZM")
	_check(list._note.text == "THIS IS A TV LINK.", "a TV link on this screen is said to be a TV link")
	list._on_code("hello")
	_check(list._note.text == "THIS CODE DOES NOT WORK.", "other text is refused")
	list._on_scan_failed("cancelled")
	_check(list._note.text == "THIS CODE DOES NOT WORK.", "a cancelled scan changes nothing")
	list._on_scan_failed("camera")
	_check(list._note.text.contains("CAMERA"), "a failed scan says why")
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
	var list: Control = _app.current_screen()
	_check(list.get_script() == _app.ControllerProfiles and list._note.text == "PLAYER ADDED."
			and _app.profiles.find("cd".repeat(16)) != null, "a player code on the Connect screen is taken and opens the list")


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
