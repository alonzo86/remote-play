extends SceneTree
## Test 20 (profiles), the phone side and the share/import flow, with the real phone screens and a real TV server on the
## loopback (docs/MANUAL_TESTS.md test 20): the pencil, the edit screen and Back (16g, 16h), the name that the TV shows is the
## name on the phone (2a, 2b), a parent phone that picks another profile (3a), two names that differ only in case (4a), the
## waiting screen with DISCONNECT, SETTINGS and ABOUT only (17a), a phone that is replaced by a second phone (8a), the copy of a
## player to a second phone: added, updated, the older copy, the better bests (12b, 13a to 13c) and the broken code, the room
## link and the scan of a player code on the Connect screen (15a to 15c), and the 32 avatars at the size of the HUD chip and of
## the result row (7a).
## Run by tests/run_all.sh and tools/coverage.sh:
##   godot --headless --path . --script tests/r4_phone_profiles.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const About = preload("res://scripts/core/about.gd")
const PlayerInput = preload("res://scripts/input/player_input.gd")
const PencilIcon = preload("res://scripts/ui/pencil_icon.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")
const Shell = preload("res://scripts/game/shell.gd")
const Lang = preload("res://scripts/core/lang.gd")

const PATH_A := "user://test_r4_phone_a.cfg"
const PATH_B := "user://test_r4_phone_b.cfg"

var _checks := 0
var _fails := 0
var _app: Node
var _real_store
var _server: TvServer
var _port := 0


class FakeQrPlugin extends Object:
	signal scanned(text: String)
	signal failed(reason: String)
	var calls: Array[String] = []

	func scan() -> void:
		calls.append("scan")

	# gdlint:ignore=function-name
	func acquireWifiLocks() -> void:
		calls.append("acquireWifiLocks")


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_until(cond: Callable, max_ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < max_ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _clean_files() -> void:
	for f in [PATH_A, PATH_A + ".bak", PATH_B, PATH_B + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## A fresh store for the phone of the test (no profile).
func _reset_store() -> void:
	_clean_files()
	_app.profiles = ProfileStore.new(PATH_A)
	_app.apply_profile()


## A fresh TV on its own port, in a menu phase. The phone of the App joins it like a phone on the Wi-Fi.
func _new_tv() -> void:
	if _server != null:
		_server.stop()
		_server.queue_free()
	_port = 48100 + randi() % 400
	_server = TvServer.new()
	_server.port = _port
	root.add_child(_server)
	_server.start({})
	_server.set_phase("menu")
	_app.server = _server


func _join_app_client() -> bool:
	_app.last_error = ""
	_app.client.use_saved_token("")
	_app.client.connect_to("127.0.0.1", _port, _server.room_code)
	return await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 4000)


func _leave_app_client() -> void:
	_app.client.leave()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	await _frames(2)


func _back() -> void:
	_app._last_back_ms = 0
	_app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)   # What Android sends for the Back key.
	await _frames(3)


func _buttons(node: Node) -> Array:
	return node.find_children("*", "Button", true, false)


func _pencil(screen: Node) -> Button:
	for b in _buttons(screen):
		if b.get_child_count() > 0 and b.get_child(0).get_script() == PencilIcon:
			return b
	return null


func _dropdown(screen: Node) -> Control:
	for n in screen.find_children("*", "VBoxContainer", true, false):
		if n.get_script() != null and n.get_script().resource_path.ends_with("profile_dropdown.gd"):
			return n
	return null


## The row of the open dropdown that shows `shown` (the upper case name).
func _dropdown_row(dropdown: Control, shown: String) -> Button:
	for b in dropdown._list.get_children():
		if b is Button and b.find_children("*", "Label", true, false).any(func(l): return l.text == shown):
			return b
	return null


func _run() -> void:
	await _frames(3)
	_app = root.get_node("App")
	_real_store = _app.profiles
	_app.client.leave()   # A saved room from an earlier run in user:// must not make the phone reconnect.
	_app.set_language("en", false)
	_reset_store()
	_new_tv()
	await _edit_and_join()
	await _waiting_screen()
	await _switch_profile()
	await _equal_names()
	await _replaced()
	await _share_flow()
	await _scan_flow()
	_avatars_small()
	if _app.client.state != ControllerClient.State.IDLE:
		_app.client.leave()
	_server.stop()
	_app.server = null
	_app.profiles = _real_store
	_app.apply_profile()
	_app.set_language("en", false)
	_clean_files()


## 16h, 16g, 2a, 2b: the pencil opens the edit screen and Back leaves it; a new name and avatar that are saved are the ones that
## the TV shows after the join, within 3 s, and the phone shows the name that the TV shows.
func _edit_and_join() -> void:
	print("the pencil, the edit screen, SAVE and the join")
	var maya = _app.profiles.create("Maya", 3)
	_app.apply_profile()
	_app.go(_app.ControllerConnect)
	await _frames(3)
	var pencil := _pencil(_app.current_screen())
	_check(pencil != null, "the Connect screen has the pencil button next to the dropdown")
	pencil.pressed.emit()
	await _frames(3)
	var edit: Control = _app.current_screen()
	_check(edit.get_script() == _app.ControllerProfileEdit and edit.profile_id == maya.id,
			"the pencil opens the edit screen of the active player")
	await _back()
	_check(_app.current_screen().get_script() == _app.ControllerConnect and _app.client.state == ControllerClient.State.IDLE,
			"Back from the edit screen goes to the Connect screen")
	_check(maya.player_name == "Maya" and maya.avatar == 3 and maya.rev == 0, "and the player did not change")

	_pencil(_app.current_screen()).pressed.emit()
	await _frames(3)
	edit = _app.current_screen()
	edit._name.text = "Dana"
	edit._views[9].pressed.emit()
	edit._save.pressed.emit()
	await _frames(3)
	_check(_app.current_screen().get_script() == _app.ControllerConnect and maya.player_name == "Dana" and maya.avatar == 9
			and maya.rev == 1, "SAVE keeps the new name and avatar and returns to the Connect screen")
	_check(_app.client.player_name == "Dana" and _app.client.avatar == 9 and _app.client.pid == maya.id,
			"and the phone is ready to send them to the TV")

	var t0 := Time.get_ticks_msec()
	var ok := await _join_app_client()
	var slot: PlayerInput = _server.players[0]
	var shown := await _wait_until(func(): return slot.player_name == "Dana" and slot.avatar == 9, 3000)
	var ms := Time.get_ticks_msec() - t0
	_check(ok and shown and ms < 3000 and slot.profile_id == maya.id and slot.has_profile(),
			"the TV has the new name Dana and avatar 9 within 3 s of the join (%d ms)" % ms)
	await _frames(3)
	var wait: Control = _app.current_screen()
	_check(wait.get_script() == _app.ControllerWait and wait._name.text == slot.player_name.to_upper() and wait._name.text == "DANA",
			"the phone shows the name that the TV shows: '%s'" % wait._name.text)
	_check(_app.client.tv_player_name == "Dana" and _app.client.tv_avatar == 9, "and the TV told the phone the same avatar")


## 17a: the waiting screen of a joined phone has DISCONNECT, SETTINGS and ABOUT, in this order, and no other button.
func _waiting_screen() -> void:
	print("the waiting screen")
	var wait: Control = _app.current_screen()
	var names: Array = _buttons(wait).filter(func(b): return b.is_visible_in_tree()).map(func(b): return str(b.name))
	_check(names == ["AboutButton", "SettingsButton", "DisconnectButton"],
			"the waiting screen has only the icon buttons ABOUT, SETTINGS and DISCONNECT: %s" % str(names))
	var leave: Rect2 = wait._leave.get_global_rect()
	var settings: Rect2 = wait.find_child("SettingsButton", true, false).get_global_rect()
	_check(absf(settings.position.y - leave.position.y) < 1.0 and settings.end.x < leave.position.x,
			"DISCONNECT is in the corner at the end of the top row, after ABOUT and SETTINGS")
	await _leave_app_client()


## 3a: a parent phone with 3 profiles leaves the TV, picks another profile on the Connect screen and joins again: the TV shows
## the new name and avatar.
func _switch_profile() -> void:
	print("another profile on the same phone")
	_reset_store()
	var p1 = _app.profiles.create("Maya", 3)
	var p2 = _app.profiles.create("Noam", 7)
	_app.profiles.create("Dana", 11)
	_app.profiles.set_active(p1.id)
	_app.apply_profile()
	_app.go(_app.ControllerConnect)
	await _frames(3)
	var ok := await _join_app_client()
	await _frames(3)
	var first: PlayerInput = _server.players[0]
	_check(ok and first.player_name == "Maya" and first.avatar == 3 and first.profile_id == p1.id,
			"the first round: the TV shows Maya with avatar 3")
	var wait: Control = _app.current_screen()
	wait._leave.pressed.emit()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	await _frames(3)
	var connect: Control = _app.current_screen()
	_check(connect.get_script() == _app.ControllerConnect and _app.client.state == ControllerClient.State.IDLE,
			"DISCONNECT leads to the Connect screen")
	var dropdown := _dropdown(connect)
	dropdown.toggle()
	await _frames(2)
	var row := _dropdown_row(dropdown, "NOAM")
	_check(row != null, "the dropdown lists the other profiles")
	row.pressed.emit()
	await _frames(3)
	_check(_app.profiles.active_id == p2.id and _app.client.pid == p2.id, "a tap on Noam makes Noam the player of this phone")
	ok = await _join_app_client()
	await _frames(3)
	var slot: PlayerInput = _server.players[0]
	_check(ok and slot.player_name == "Noam" and slot.avatar == 7 and slot.profile_id == p2.id,
			"the second round: the TV shows Noam with avatar 7")
	_check(_app.current_screen()._name.text == "NOAM", "and the phone shows NOAM")
	await _leave_app_client()


## 4a (the phone side): the names Sam and sam. The TV makes the second one Sam 2 (REQ-FL-39: upper case on the screens) and the
## phone with the second name shows SAM 2.
func _equal_names() -> void:
	print("Sam and sam")
	_reset_store()
	var first := ControllerClient.new()
	root.add_child(first)
	first.set_profile("a1".repeat(16), "Sam", 1)
	first.connect_to("127.0.0.1", _port, _server.room_code)
	await _wait_until(func(): return first.state == ControllerClient.State.CONNECTED, 4000)
	var sam = _app.profiles.create("sam", 2)
	_app.apply_profile()
	_app.go(_app.ControllerConnect)
	await _frames(3)
	var ok := await _join_app_client()
	await _frames(3)
	_check(ok and _server.players[0].player_name == "Sam" and _server.players[1].player_name == "sam 2",
			"the TV names the phones Sam and sam 2")
	_check(_app.client.tv_pid == sam.id and _app.client.tv_player_name == "sam 2", "the TV told the second phone its name")
	var shown: String = _app.current_screen()._name.text
	_check(shown == "SAM 2", "the second phone shows SAM 2 (upper case): '%s'" % shown)
	first.leave()
	first.queue_free()
	await _leave_app_client()


## 8a: a second phone with the same profile tries to join while the TV is in a menu. While the first phone is connected it keeps
## the profile and the second phone is sent away with THIS PLAYER IS ALREADY IN THE ROOM. and takes no slot (owner decision
## 2026-11-07, issue #388). When the first phone is lost, the second one takes the profile and the first one is sent to the
## Connect screen with the same text when it comes back.
func _replaced() -> void:
	print("the same profile on a second phone")
	_reset_store()
	var maya = _app.profiles.create("Maya", 3)
	_app.apply_profile()
	var holder := ControllerClient.new()
	root.add_child(holder)
	holder.set_profile(maya.id, "Maya", 3)
	holder.connect_to("127.0.0.1", _port, _server.room_code)
	await _wait_until(func(): return holder.state == ControllerClient.State.CONNECTED, 4000)
	var holder_rejected := []
	holder.rejected.connect(func(reason): holder_rejected.append(reason))
	# The App is the newer phone, with the same profile.
	_app.go(_app.ControllerConnect)
	await _frames(3)
	_app.last_error = ""
	_app.client.use_saved_token("")
	_app.client.connect_to("127.0.0.1", _port, _server.room_code)
	await _wait_until(func(): return _app.last_error != "", 4000)
	await _frames(3)
	var newer: Control = _app.current_screen()
	_check(newer.get_script() == _app.ControllerConnect and _app.client.state == ControllerClient.State.IDLE
			and _app.last_error == Lang.t("app.player_already_in_room"),
			"the newer phone stays on the Connect screen with THIS PLAYER IS ALREADY IN THE ROOM. (issue #388): '%s'" % _app.last_error)
	_check(newer._status.text == Lang.t("app.player_already_in_room").to_upper(),
			"the Connect screen of the newer phone shows that text in its status line: '%s'" % newer._status.text)
	_check(_app.client._token == "" and _app.client.slot == -1, "the rejected phone keeps no token and no slot")
	_check(holder.state == ControllerClient.State.CONNECTED and holder_rejected.is_empty() and _server.player_count() == 1
			and _server.players[0].profile_id == maya.id and not _server.players[1].is_present(),
			"the connected holder is not touched and the newer phone has no slot")
	holder.leave()
	holder.queue_free()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	# The App is now the holder, and a second phone with its profile comes.
	_app.go(_app.ControllerConnect)
	await _frames(3)
	var ok := await _join_app_client()
	await _frames(2)
	_check(ok and _app.current_screen().get_script() == _app.ControllerWait, "the first phone is joined")
	var second := ControllerClient.new()
	root.add_child(second)
	var second_rejected := []
	second.rejected.connect(func(reason): second_rejected.append(reason))
	second.set_profile(maya.id, "Maya", 3)
	second.connect_to("127.0.0.1", _port, _server.room_code)
	await _wait_until(func(): return not second_rejected.is_empty(), 4000)
	await _frames(3)
	_check(second_rejected == ["replaced"] and _app.client.state == ControllerClient.State.CONNECTED
			and _app.current_screen().get_script() == _app.ControllerWait and _app.last_error == "",
			"the connected holder stays on its screen (issue #388, REQ-FL-74)")
	_check(_server.player_count() == 1 and _server.players[0].profile_id == maya.id,
			"the newer phone took no slot and the holder keeps the profile")
	# The holder is lost (the phone stops): a takeover is allowed, and the old phone is sent away when it comes back.
	_app.client.set_process(false)
	await _wait_until(func(): return _server.players[0].state == PlayerInput.State.LOST, 8000)
	second.queue_free()
	second = ControllerClient.new()
	root.add_child(second)
	second.set_profile(maya.id, "Maya", 3)
	second.connect_to("127.0.0.1", _port, _server.room_code)
	await _wait_until(func(): return second.state == ControllerClient.State.CONNECTED, 4000)
	_check(second.state == ControllerClient.State.CONNECTED and _server.player_count() == 1
			and _server.players[0].profile_id == maya.id and _server.players[0].state == PlayerInput.State.CONNECTED,
			"a lost holder is replaced: the newer phone holds the one slot")
	_app.client.set_process(true)
	var kicked := await _wait_until(func(): return _app.client.state == ControllerClient.State.IDLE, 8000)
	await _frames(3)
	var screen: Control = _app.current_screen()
	_check(kicked and screen.get_script() == _app.ControllerConnect, "the older phone goes to the Connect screen when it comes back")
	_check(_app.last_error == Lang.t("app.player_already_in_room"),
			"and its message is THIS PLAYER IS ALREADY IN THE ROOM. (REQ-FL-74): '%s'" % _app.last_error)
	_check(screen._status.text == Lang.t("app.player_already_in_room").to_upper(),
			"the Connect screen shows that text in its status line: '%s'" % screen._status.text)
	second.leave()
	second.queue_free()
	await _wait_until(func(): return _server.player_count() == 0, 3000)


## 12b, 13a, 13b, 13c (and 15a, 15b): one player is copied from a first phone to a second phone with the code of the QR.
func _share_flow() -> void:
	print("a player copied from one phone to another")
	_clean_files()
	var sender := ProfileStore.new(PATH_A)
	var receiver := ProfileStore.new(PATH_B)
	var maya = sender.create("Maya", 4)
	sender.record_best(maya.id, "paint_grab|easy", 10)
	sender.record_best(maya.id, "snowball_splat|medium", 340)
	sender.record_best(maya.id, "marble_race|easy|1", 30000)
	_check(maya.bests.size() == 3, "the first phone has 3 bests")
	_app.profiles = receiver
	_app.apply_profile()
	var text: String = _app.import_profile_text(ProfileCode.encode(maya))
	var got = receiver.find(maya.id)
	_check(text == Lang.t("app.player_added") and got != null and got.player_name == "Maya" and got.avatar == 4,
			"the second phone says PLAYER ADDED. and has the same name and avatar")
	_check(got != null and got.bests == maya.bests and got.bests.size() == 3,
			"12b: the 3 personal bests on the second phone equal the ones on the first phone")

	sender.update(maya.id, "Mia", 12)
	text = _app.import_profile_text(ProfileCode.encode(maya))
	_check(text == Lang.t("app.player_updated") and got.player_name == "Mia" and got.avatar == 12,
			"13a: after a rename on the first phone the second phone says PLAYER UPDATED. and has the newer name and avatar")

	receiver.update(maya.id, "Max", 15)
	var older := ProfileCode.encode(maya)   # The first phone has not changed: this is the old copy of the player.
	text = _app.import_profile_text(older)
	_check(got.player_name == "Max" and got.avatar == 15 and got.rev == 2,
			"13b: after a rename on the second phone the old copy keeps the newer name Max and avatar 15")

	sender.record_best(maya.id, "paint_grab|easy", 50)         # a better score on the first phone
	receiver.record_best(maya.id, "snowball_splat|medium", 500)   # a better score on the second phone
	receiver.record_best(maya.id, "marble_race|easy|1", 28000)    # a better (lower) time on the second phone
	_app.import_profile_text(ProfileCode.encode(maya))
	_app.profiles = sender
	_app.apply_profile()
	_app.import_profile_text(ProfileCode.encode(got))
	var want := {"paint_grab|easy": 50, "snowball_splat|medium": 500, "marble_race|easy|1": 28000}
	_check(got.bests == want and maya.bests == want,
			"13c: after a scan in both directions each phone has the better value for each game: %s and %s"
			% [str(got.bests), str(maya.bests)])

	_app.profiles = receiver
	_app.apply_profile()
	var good := ProfileCode.encode(maya)
	var at := 10   # A letter in the middle: a change in the last letter can leave the bytes as they are.
	var broken := good.substr(0, at) + ("A" if good[at] != "A" else "B") + good.substr(at + 1)
	_check(broken != good and _app.import_profile_text(broken) == Lang.t("app.code_does_not_work"),
			"15a: a code with one changed letter says THIS CODE DOES NOT WORK.")
	_check(_app.import_profile_text("ws://192.168.1.5:47801/KQZM") == Lang.t("app.room_link"),
			"15b: the code of a TV says THIS IS A ROOM LINK.")
	_check(got.player_name == "Max" and receiver.profiles.size() == 1, "and neither of them changed the profiles")
	_app.profiles = sender
	_app.apply_profile()


## 15b and 15c with a scanner: IMPORT on the new player screen (a scan of a TV code, a player code, a broken code, the buzz on an
## iPhone, a refused camera), and a scan of a player code on the Connect screen (owner, 2026-11-02: there is no list screen).
func _scan_flow() -> void:
	print("the camera scan on the profile screens")
	_reset_store()
	var other := ProfileStore.new(PATH_B)
	var noam = other.create("Noam", 6)
	var maya = other.create("Maya", 3)
	var fake := FakeQrPlugin.new()
	Engine.register_singleton("QrScanner", fake)
	_app.go(_app.ControllerProfileEdit, {"profile_id": ""})
	await _frames(3)
	var screen: Control = _app.current_screen()
	var import_button: Button = _buttons(screen).filter(func(b): return b.text == "profile_edit.import").front()
	_check(import_button != null, "with the scanner the new player screen has the button IMPORT")
	import_button.pressed.emit()
	fake.scanned.emit("ws://192.168.1.5:47801/KQZM")
	await _frames(2)
	_check(fake.calls == ["scan"] and screen._hint.text == Lang.t("app.room_link").to_upper(),
			"15b: a scan of the QR code of a TV says THIS IS A ROOM LINK.: '%s'" % screen._hint.text)
	fake.scanned.emit(ProfileCode.encode(noam))
	await _frames(2)
	# Owner, 2026-11-06 (REQ-FL-76): after a good scan the phone goes to the Connect screen with the new player selected.
	_check(_app.current_screen().get_script() == _app.ControllerConnect and _app.profiles.find(noam.id) != null
			and _app.profiles.find(noam.id).player_name == "Noam" and _app.profiles.active_id == noam.id
			and _app.current_screen()._status.text == Lang.t("app.player_added").to_upper(),
			"IMPORT of a player code adds the player and goes to the Connect screen with that player selected (%s)"
			% _app.profiles.active_id)
	_app.go(_app.ControllerProfileEdit, {"profile_id": ""})   # The new player screen again, for the next checks.
	await _frames(3)
	screen = _app.current_screen()
	fake.scanned.emit("WP1.not-a-code")
	await _frames(2)
	_check(screen._hint.text == Lang.t("app.code_does_not_work").to_upper(),
			"a broken code says the code does not work: '%s'" % screen._hint.text)
	# Issue #299: on an iPhone a scan buzzes once (REQ-FL-89), and a refused camera has its own text (REQ-FL-91).
	var Haptics: GDScript = load("res://scripts/game/haptics.gd")
	var buzzes: Array = []
	Haptics.vibrate_call = func(ms: int) -> void: buzzes.append(ms)
	var old_haptics: bool = _app.settings.get("haptics", true)
	_app.settings.haptics = true
	screen._qr.os_name = "iOS"
	fake.scanned.emit("ws://192.168.1.5:47801/KQZM")
	_check(buzzes.size() == 1, "on an iPhone one scan buzzes once (%d buzzes)" % buzzes.size())
	fake.failed.emit("camera_denied")
	await _frames(2)
	_check(screen._hint.text == Lang.t("connect.camera_denied").to_upper(),
			"a refused camera shows the camera text on the new player screen: '%s'" % screen._hint.text)
	_app.settings.haptics = old_haptics
	Haptics.vibrate_call = Callable()
	# IMPORT is on the new player screen only, not on the edit screen of an existing player.
	_app.go(_app.ControllerProfileEdit, {"profile_id": noam.id})
	await _frames(3)
	_check(not _buttons(_app.current_screen()).any(func(b): return b.text == "profile_edit.import"),
			"the edit screen of an existing player has no IMPORT button")

	_app.go(_app.ControllerConnect)
	await _frames(3)
	var connect: Control = _app.current_screen()
	var scan: Button = _buttons(connect).filter(func(b): return b.text == "connect.scan_qr_code").front()
	_check(scan != null, "with the scanner the Connect screen has SCAN QR CODE")
	scan.pressed.emit()
	fake.scanned.emit(ProfileCode.encode(maya))
	await _frames(3)
	connect = _app.current_screen()   # The Connect screen is built again, with the new player selected.
	_check(connect.get_script() == _app.ControllerConnect and connect._status.text == Lang.t("app.player_added").to_upper()
			and _app.profiles.find(maya.id) != null and _app.profiles.find(maya.id).player_name == "Maya"
			and _app.profiles.active_id == maya.id,
			"15c: a scan of a player code on the Connect screen adds the player, selects it and says PLAYER ADDED: '%s'"
			% connect._status.text)
	# The QR code "GET THE APP" of the TV is not a room code: the status line says so (owner, 2026-11-06).
	connect._on_qr_text(About.APP_URL)
	var app_text := Lang.t("connect.app_code_scanned")
	_check(_app.last_error == app_text and connect._status.text == app_text.to_upper(),
			"the Sababi scanner reading the app code says THAT IS THE APP CODE. SCAN THE OTHER ONE.: '%s'" % connect._status.text)
	_app.last_error = ""
	# Owner, 2026-11-06: ABOUT and SETTINGS (icons) are on the Connect screen too; Back from Settings returns to it.
	_check(connect.find_child("AboutButton", true, false) != null and connect.find_child("SettingsButton", true, false) != null,
			"the Connect screen has the icon buttons ABOUT and SETTINGS")
	connect.find_child("SettingsButton", true, false).pressed.emit()
	await _frames(3)
	var settings_screen: Control = _app.current_screen()
	_check(settings_screen.get_script() == _app.ControllerSettings, "SETTINGS on the Connect screen opens the phone Settings")
	settings_screen.on_back()
	await _frames(3)
	_check(_app.current_screen().get_script() == _app.ControllerConnect, "Back from Settings returns to the Connect screen")
	Engine.unregister_singleton("QrScanner")
	fake.free()
	_app.go(_app.ControllerProfileEdit, {"profile_id": ""})
	await _frames(3)
	_check(not _buttons(_app.current_screen()).any(func(b): return b.text == "profile_edit.import"),
			"without the scanner the new player screen has no IMPORT button")
	_app.go(_app.ControllerConnect)
	await _frames(2)


## 7a: the 32 avatars at the smallest sizes they have (the 32 px of the HUD chip and the 48 px of the result row), on each of the
## four slot colors: 32 different pictures at each size and color, none of them empty.
func _avatars_small() -> void:
	print("the avatars at their smallest sizes")
	var sheet := Avatar.texture().get_image()
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
	var worst := 1000000
	for side in [Shell.CHIP_AVATAR, 48.0]:
		var scale := Avatar.scale_for(side)
		for slot in Protocol.MAX_PLAYERS:
			var seen := {}
			var empty := 0
			for i in Protocol.AVATAR_COUNT:
				var cell := sheet.get_region(Rect2i(Avatar.region(i)))
				cell.resize(Avatar.CELL * scale, Avatar.CELL * scale, Image.INTERPOLATE_NEAREST)
				var back := Image.create(cell.get_width(), cell.get_height(), false, Image.FORMAT_RGBA8)
				back.fill(Protocol.PLAYER_COLORS[slot])
				var plain := back.get_data().hex_encode()
				back.blend_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i.ZERO)
				var key := back.get_data().hex_encode()
				seen[key] = true
				if key == plain:
					empty += 1
			_check(seen.size() == Protocol.AVATAR_COUNT and empty == 0,
					"%d px (scale %d) on slot color %d: %d different pictures of %d, %d empty"
					% [int(side), scale, slot + 1, seen.size(), Protocol.AVATAR_COUNT, empty])
	# How many pixels differ between the two most alike avatars (printed to look at; every pair differs).
	var cells: Array = []
	for i in Protocol.AVATAR_COUNT:
		cells.append(sheet.get_region(Rect2i(Avatar.region(i))))
	for i in cells.size():
		for j in range(i + 1, cells.size()):
			var diff := 0
			for y in Avatar.CELL:
				for x in Avatar.CELL:
					if cells[i].get_pixel(x, y) != cells[j].get_pixel(x, y):
						diff += 1
			worst = mini(worst, diff)
	print("       the two most alike avatars differ in %d of 256 pixels" % worst)
	_check(worst >= 1, "no two avatars are the same picture")
