extends SceneTree
## Test 21 on the phone (docs/MANUAL_TESTS.md test 21), with the real Connect screen, the real PIN pad and a real TV server that
## asks the phone on this device for the PIN: a tap on a TV opens the pad (3a), a wrong PIN shows its text (3b), the right PIN
## joins (3c), five wrong PINs, the sixth try with the right PIN is turned away with the lock text (4a, 4b), the lock is 30 s long
## and the right PIN joins after it (4c), the PIN of the TV and the first phone are not changed (4d), the keys of the pad are in
## the same places in English and in Hebrew and the typed digits show in the order they were typed (10c), and the pencil opens
## the edit screen with the name field and SAVE (9f).
## The steps of the PIN change with issue #52: this suite changes with them.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/r4_pin.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const TvServer = preload("res://scripts/net/tv_server.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const PencilIcon = preload("res://scripts/ui/pencil_icon.gd")
const Lang = preload("res://scripts/core/lang.gd")

const PATH := "user://test_r4_pin.cfg"
const TV_PIN := "4827"

var _checks := 0
var _fails := 0
var _app: Node
var _real_store
var _server: TvServer
var _port := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


## A known bug: it counts as a failure until the bug is fixed.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what, " (the bug is fixed: use _check)")
	else:
		_fails += 1
		print("  FAIL (known bug) ", issue, ": ", what)


func _initialize() -> void:
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
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


## A TV on its own port that asks every phone for the PIN (the test phone is on this device, like a phone on the Wi-Fi).
func _new_tv() -> void:
	if _server != null:
		_server.stop()
		_server.queue_free()
	_port = 48100 + randi() % 400
	_server = TvServer.new()
	_server.port = _port
	root.add_child(_server)
	_server.start({})
	_server.pin_exempt_loopback = false
	_server.pin = TV_PIN
	_server.set_phase("connect")
	_app.server = _server


func _connect_screen() -> Control:
	_app.go(_app.ControllerConnect)
	await _frames(3)
	return _app.current_screen()


## What a tap on the TV in the list does: the pad opens for that TV.
func _open_pad(screen: Control) -> Control:
	screen._ask_pin("127.0.0.1", _port, _server.room_code)
	await _frames(3)
	return screen._pad


func _pin_pad(cover: Control) -> Control:
	for n in cover.find_children("*", "VBoxContainer", true, false):
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("pin_pad.gd"):
			return n
	return null


func _pad_key(pad: Control, text: String) -> Button:
	for b in pad.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


## The player types the PIN: one tap for each digit. Returns the text of the PIN line after the last digit.
func _type(pad: Control, pin: String) -> String:
	for ch in pin:
		_pad_key(pad, ch).pressed.emit()
	return pad._shown.text


## Opens the pad on the Connect screen, types the PIN and waits for the answer of the TV.
func _try_pin(screen: Control, pin: String) -> void:
	var cover := await _open_pad(screen)
	_type(_pin_pad(cover), pin)
	await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED or _app.last_error != "", 4000)
	await _frames(3)


func _run() -> void:
	await _frames(3)
	_app = root.get_node("App")
	_real_store = _app.profiles
	_app.set_language("en", false)
	_clean_files()
	_app.profiles = ProfileStore.new(PATH)
	_app.apply_profile()
	_new_tv()
	await _pad_flow()
	await _lock_flow()
	await _pad_keys_in_hebrew()
	await _edit_screen()
	if _app.client.state != ControllerClient.State.IDLE:
		_app.client.leave()
	_server.stop()
	_app.server = null
	_app.profiles = _real_store
	_app.apply_profile()
	_app.set_language("en", false)
	_clean_files()


## 3a, 3b, 3c: the pad, a wrong PIN, the right PIN.
func _pad_flow() -> void:
	print("the PIN pad: a wrong PIN and the right PIN")
	var screen := await _connect_screen()
	var cover := await _open_pad(screen)
	_check(cover != null and _pin_pad(cover) != null, "3a: a tap on the TV opens the PIN pad")
	var prompt := _pin_pad(cover).find_children("*", "Label", true, false).filter(func(l): return l.text == "pin.type_prompt")
	_check(prompt.size() == 1, "3a: the pad asks for the PIN that is shown on the TV")
	_type(_pin_pad(cover), "0000")
	await _wait_until(func(): return _app.last_error != "", 4000)
	await _frames(3)
	_check(_app.last_error == Lang.t("pin.wrong"), "3b: a wrong PIN: the text is '%s'" % _app.last_error)
	_check(_app.client.state == ControllerClient.State.IDLE and _server.player_count() == 0 and screen._pad == null,
			"3b: the phone did not join and the pad is closed")
	var now_screen: Control = _app.current_screen()
	_known_bug("issue-needed: the Connect screen shows no error after a reject (the status line is not refreshed)",
			now_screen.get_script() == _app.ControllerConnect and now_screen._status.text == Lang.t("pin.wrong").to_upper(),
			"3b: the Connect screen shows WRONG PIN in its status line")
	await _try_pin(screen, TV_PIN)
	_check(_app.client.state == ControllerClient.State.CONNECTED and _server.player_count() == 1,
			"3c: the right PIN joins")
	_check(_app.current_screen().get_script() == _app.ControllerWait, "3c: the phone shows the waiting screen")
	_app.client.leave()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	await _frames(3)


## 4a to 4d: a first phone holds slot 1; a second phone types 5 wrong PINs, then the right one.
func _lock_flow() -> void:
	print("five wrong PINs and the lock")
	_server._bad_pins = 0
	_server._pin_locked_until_ms = 0
	var first := ControllerClient.new()
	root.add_child(first)
	first.connect_to("127.0.0.1", _port, _server.room_code, TV_PIN)
	await _wait_until(func(): return first.state == ControllerClient.State.CONNECTED, 4000)
	_check(first.state == ControllerClient.State.CONNECTED and first.slot == 0, "the first phone holds slot 1")
	var first_token: String = _server.players[0].token
	var screen := await _connect_screen()
	var all_wrong := true
	for i in Protocol.PIN_TRIES:
		await _try_pin(screen, "0000")
		if _app.last_error != Lang.t("pin.wrong"):
			all_wrong = false
			print("    try %d shows '%s'" % [i + 1, _app.last_error])
	_check(all_wrong, "4a: each of the %d wrong PINs shows WRONG PIN." % Protocol.PIN_TRIES)
	var left_ms: int = _server._pin_locked_until_ms - Time.get_ticks_msec()
	_check(left_ms > Protocol.PIN_LOCK_MS - 3000 and left_ms <= Protocol.PIN_LOCK_MS,
			"4c: after the fifth wrong PIN the lock runs %d ms (30 s)" % left_ms)
	_check(Protocol.PIN_LOCK_MS >= 30000 and Protocol.PIN_LOCK_MS <= 35000,
			"4c: the lock is 30 s, so a retry works within 35 s of the fifth wrong PIN")

	await _try_pin(screen, TV_PIN)
	_check(_app.last_error == Lang.f("pin.locked", [Protocol.PIN_LOCK_MS / 1000]),
			"4b: the sixth try with the right PIN says '%s'" % _app.last_error)
	_check(_app.client.state != ControllerClient.State.CONNECTED and _server.player_count() == 1,
			"4b: and the phone did not join")
	var locked_screen: Control = _app.current_screen()
	_known_bug("issue-needed: the Connect screen shows no error after a reject (the status line is not refreshed)",
			locked_screen.get_script() == _app.ControllerConnect
			and locked_screen._status.text == Lang.f("pin.locked", [Protocol.PIN_LOCK_MS / 1000]).to_upper(),
			"4b: the Connect screen shows TOO MANY WRONG PINS in its status line")

	_server._pin_locked_until_ms = 0   # The 30 s are over (a fake clock: the server compares the time with this value).
	await _try_pin(locked_screen, TV_PIN)
	_check(_app.client.state == ControllerClient.State.CONNECTED and _app.client.slot == 1,
			"4c: after the lock the right PIN joins (slot 2)")
	_check(_server.pin == TV_PIN and first.state == ControllerClient.State.CONNECTED and first.slot == 0
			and _server.players[0].token == first_token and _server.players[0].is_present(),
			"4d: the PIN of the TV did not change and the first phone is still in slot 1")
	_app.client.leave()
	first.leave()
	first.queue_free()
	await _wait_until(func(): return _server.player_count() == 0, 3000)
	await _frames(3)


## The places of the keys of the pad, relative to the key 1, and the place of the key 1.
func _key_places(pad: Control) -> Dictionary:
	var out := {}
	var one := _pad_key(pad, "1")
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "X"]:
		var b := _pad_key(pad, k)
		out[k] = b.get_global_rect().position - one.get_global_rect().position
		out[k + "_size"] = b.get_global_rect().size
	out["x"] = one.get_global_rect().position.x
	return out


## 10c: the keys of the pad are where they are in English, and 1, 2, 3, 4 show as 1 2 3 4 in Hebrew.
func _pad_keys_in_hebrew() -> void:
	print("the PIN pad in Hebrew")
	var places := {}
	var shown := {}
	for lang in ["en", "he"]:
		_app.set_language(lang, false)
		var screen := await _connect_screen()
		var cover := await _open_pad(screen)
		var pad := _pin_pad(cover)
		places[lang] = _key_places(pad)
		_check(pad.find_children("*", "GridContainer", true, false)[0].layout_direction == Control.LAYOUT_DIRECTION_LTR,
				"10c: the key grid is left to right in %s" % lang)
		shown[lang] = _type(pad, "123")
		_check(shown[lang] == "1 2 3 _", "10c: in %s the digits 1, 2, 3 show in the order typed: '%s'" % [lang, shown[lang]])
		_server.pin = "1234"
		_pad_key(pad, "4").pressed.emit()
		var line: String = pad._shown.text
		_check(line == "1 2 3 4", "10c: and with the fourth digit: '%s' (%s)" % [line, lang])
		await _wait_until(func(): return _app.client.state == ControllerClient.State.CONNECTED, 4000)
		_app.client.leave()
		await _wait_until(func(): return _server.player_count() == 0, 3000)
		_server.pin = TV_PIN
		await _frames(2)
	_check(places["en"] == places["he"], "10c: the 12 keys are in the same places and sizes in English and in Hebrew")
	_app.set_language("en", false)


func _pencil(screen: Node) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if b.get_child_count() > 0 and b.get_child(0).get_script() == PencilIcon:
			return b
	return null


## 9f: the pencil next to the player opens the edit screen of the active profile: the name field and SAVE show.
func _edit_screen() -> void:
	print("the pencil")
	var maya = _app.profiles.create("Maya", 3)
	_app.apply_profile()
	var screen := await _connect_screen()
	var pencil := _pencil(screen)
	_check(pencil != null, "9f: the Connect screen has the pencil next to the player")
	if pencil == null:
		return
	pencil.pressed.emit()
	await _frames(3)
	var edit: Control = _app.current_screen()
	_check(edit.get_script() == _app.ControllerProfileEdit and edit.profile_id == maya.id,
			"9f: the pencil opens the edit screen of the active profile")
	_check(edit._name.is_visible_in_tree() and edit._name.text == "Maya" and edit._save.is_visible_in_tree()
			and edit._save.text == "profile_edit.save", "9f: the name field (Maya) and SAVE show")
