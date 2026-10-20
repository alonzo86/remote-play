extends SceneTree
## More checks of the phone profile screens that a machine can do (tests 20 and 21 of docs/MANUAL_TESTS.md): no profile switch
## while
## joined (REQ-FL-71), a second phone with the same profile (REQ-FL-73), the avatar line of the edit screen (REQ-FL-72), the
## layout
## of the Connect screen on tall and wide phones with a cut-out (REQ-FL-68, 85), and the size of the largest player code.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/ui_profile_extra.gd --
## --role=controller

const ControllerClient = preload("res://scripts/net/controller_client.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")
const Profile = preload("res://scripts/core/profile.gd")
const QrEncoder = preload("res://scripts/core/qr_encoder.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")
const PencilIcon = preload("res://scripts/ui/pencil_icon.gd")
const Lang = preload("res://scripts/core/lang.gd")
const SafeArea = preload("res://scripts/ui/safe_area.gd")

const PATH := "user://test_ui_profile_extra.cfg"

var _checks := 0
var _fails := 0
var _app: Node
var _real_store


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


func _run() -> void:
	await process_frame
	_app = root.get_node("App")
	_real_store = _app.profiles
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	_app.profiles = ProfileStore.new(PATH)
	_app.apply_profile()
	_replaced()
	await _joined_screens()
	await _edit_screen()
	await _connect_layout()
	_largest_code()
	_app.profiles = _real_store
	_app.apply_profile()
	_app.set_language("en", false)
	for f in [PATH, PATH + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func _buttons(node: Node) -> Array:
	return node.find_children("*", "Button", true, false)


func _find_button(node: Node, text: String) -> Button:
	for b in _buttons(node):
		if b.text == text:
			return b
	return null


## Test 20 step 8a: another phone took this phone's profile. The TV sends "kicked / replaced"; the phone goes to the Connect
## screen
## and says so (REQ-FL-73).
func _replaced() -> void:
	print("a phone that was replaced")
	_app.last_error = ""
	_app.client.rejected.emit("replaced")
	_check(_app.last_error == Lang.t("app.player_already_in_room") and _app.last_error != "",
			"the reason 'replaced' gives the text of app.player_already_in_room")


## Test 20 step 3b: when the phone is joined, the waiting, settings and pad screens have no PLAYER button, no dropdown and no
## way to the profile screens (REQ-FL-71).
func _joined_screens() -> void:
	print("no profile switch while joined")
	_app.profiles.create("Maya", 3)
	_app.apply_profile()
	_app.last_error = ""
	_app.client._set_state(ControllerClient.State.CONNECTED)
	_app.client.phase = "menu"
	_app._show_phone_screen()
	await process_frame
	var offenders: Array = []
	var wait: Control = _app.current_screen()
	var wait_ok: bool = wait.get_script() == _app.ControllerWait
	offenders.append_array(_profile_ways("wait", wait))
	_find_button(wait, "common.settings").pressed.emit()
	await process_frame
	var settings: Control = _app.current_screen()
	var settings_ok: bool = settings.get_script() == _app.ControllerSettings
	offenders.append_array(_profile_ways("settings", settings))
	_app.client.phase = "playing"
	_app._show_phone_screen()
	var pad: Control = _app.current_screen()
	var pad_ok: bool = pad.get_script() == _app.ControllerPad
	offenders.append_array(_profile_ways("pad", pad))
	_app.client._set_state(ControllerClient.State.IDLE)
	await process_frame
	_check(wait_ok and settings_ok and pad_ok, "the waiting, settings and pad screens were reached while joined")
	_check(offenders.is_empty(), "none of them has a PLAYER button, a dropdown or a profile screen: %s" % str(offenders))
	_app.client.phase = "connect"
	_app.profiles.delete(_app.profiles.profiles[0].id)
	_app.apply_profile()


## What on a screen leads to a profile: a PLAYER, PLAYERS, GUEST, + or SHARE button, the dropdown, or a profile screen script.
func _profile_ways(name: String, screen: Control) -> Array:
	var out: Array = []
	for b in _buttons(screen):
		if b.text in ["wait.player", "common.players", "connect.guest", "+", "profiles.share"]:
			out.append("%s: button %s" % [name, b.text])
	for n in screen.find_children("*", "", true, false):
		var path: String = n.get_script().resource_path if n.get_script() != null else ""
		if path.ends_with("profile_dropdown.gd") or path.contains("controller_profile"):
			out.append("%s: %s" % [name, path])
	return out


## Test 20 steps 16a, 16c, 16d, 16e, 16f: the avatar line of the edit screen.
func _edit_screen() -> void:
	print("the edit screen")
	_app.set_language("en", false)
	_app.go(_app.ControllerConnect)
	await process_frame
	var p = _app.profiles.create("Maya", 22)
	_app.apply_profile()
	_app.go(_app.ControllerConnect)
	await process_frame
	var dropdown: Control = _app.current_screen().find_children("*", "VBoxContainer", true, false).filter(
			func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("profile_dropdown.gd")).front()
	var head_avatars: Array = dropdown._head.find_children("*", "Control", true, false).filter(func(n): return n is AvatarView)
	_check(head_avatars.size() == 1 and head_avatars[0].index == 22, "the dropdown head holds the avatar view of the active player")

	_app.go(_app.ControllerProfileEdit, {"profile_id": p.id})
	await process_frame
	await process_frame
	await process_frame
	var edit: Control = _app.current_screen()
	var views: Array = edit._views
	var y0: float = views[0].get_global_rect().position.y
	_check(views.size() == 32 and views.all(func(v): return is_equal_approx(v.get_global_rect().position.y, y0)),
			"the 32 avatars are in one line: all have the same top")
	var scroll_rect: Rect2 = edit._scroll.get_global_rect()
	var picked: Rect2 = views[22].get_global_rect()
	_check(views[22].selected and scroll_rect.encloses(picked), "at open the avatar of the player is inside the visible line")
	edit._scroll.scroll_horizontal = 0
	await process_frame
	var step := int(edit.AVATAR_STEP) * 3
	edit._arrow_right.pressed.emit()
	await create_timer(0.4).timeout
	_check(edit._scroll.scroll_horizontal == step, "the right arrow moves the line by exactly 3 avatars (%d px): %d"
			% [step, edit._scroll.scroll_horizontal])
	edit._arrow_left.pressed.emit()
	await create_timer(0.4).timeout
	_check(edit._scroll.scroll_horizontal == 0, "the left arrow moves it back")
	edit._arrow_left.pressed.emit()
	await create_timer(0.4).timeout
	_check(edit._arrow_left.disabled and edit._scroll.scroll_horizontal == 0,
			"at the start the dim left arrow leaves the line where it is")
	edit._scroll.scroll_horizontal = edit.max_scroll()
	await process_frame
	edit._arrow_right.pressed.emit()
	await create_timer(0.4).timeout
	_check(edit._arrow_right.disabled and edit._scroll.scroll_horizontal == edit.max_scroll(),
			"at the end the dim right arrow leaves the line where it is")

	# Save and Back sit at the bottom of the screen, below the avatar line (16f).
	var save: Button = _find_button(edit, "profile_edit.save")
	var back: Button = _find_button(edit, "common.back")
	var window := edit.get_global_rect()
	_check(save.get_global_rect().position.y > scroll_rect.end.y and back.get_global_rect().position.y > save.get_global_rect().end.y
			and back.get_global_rect().end.y <= window.end.y - 60.0 + 0.5,
			"SAVE and BACK are below the avatar line, BACK is last and ends 60 px or more above the screen bottom")

	# Hebrew (16e): the line and the arrows keep their direction, so the right arrow brings the avatars on its right.
	_app.set_language("he", false)
	_app.go(_app.ControllerProfileEdit, {"profile_id": p.id})
	await process_frame
	await process_frame
	await process_frame
	edit = _app.current_screen()
	edit._scroll.scroll_horizontal = 0
	await process_frame
	var left_x: float = edit._arrow_left.get_global_rect().position.x
	var right_x: float = edit._arrow_right.get_global_rect().position.x
	var first_x: float = edit._views[0].get_global_rect().position.x
	var second_x: float = edit._views[1].get_global_rect().position.x
	_check(left_x < edit._scroll.get_global_rect().position.x and right_x > edit._scroll.get_global_rect().end.x - 1.0
			and first_x < second_x, "in Hebrew the arrows and the avatars keep their English order (< left, > right, 1 before 2)")
	var before: float = edit._views[5].get_global_rect().position.x
	edit._arrow_right.pressed.emit()
	await create_timer(0.4).timeout
	var after: float = edit._views[5].get_global_rect().position.x
	_check(edit._scroll.scroll_horizontal == step and is_equal_approx(before - after, float(step)),
			"in Hebrew the arrow that points right moves the avatars to the left (shows the ones on its right)")
	edit._arrow_left.pressed.emit()
	await create_timer(0.4).timeout
	_check(edit._scroll.scroll_horizontal == 0, "in Hebrew the arrow that points left moves the line back")
	_app.set_language("en", false)
	_app.profiles.delete(p.id)
	_app.apply_profile()


## Test 21 steps 9a and 9e: the Connect screen on a tall phone (1080x2400) and a wide phone (a viewport 1920x886) with a cut-out,
## in English and Hebrew: About, the dropdown, the pencil and the + are inside the safe area and do not touch each other.
func _connect_layout() -> void:
	print("the Connect screen on tall and wide phones")
	var p = _app.profiles.create("Maya", 3)
	_app.apply_profile()
	var cases := [
		{"name": "tall", "view": Vector2(1080, 2400), "safe": Vector4(0, 130, 0, 90)},
		{"name": "wide", "view": Vector2(1920, 886), "safe": Vector4(130, 0, 130, 40)},
	]
	for lang in ["en", "he"]:
		_app.set_language(lang, false)
		for c in cases:
			var host := Control.new()
			host.size = c.view
			host.layout_direction = Control.LAYOUT_DIRECTION_LTR   # The host is the window: it must not mirror itself in Hebrew.
			root.add_child(host)
			var screen: Control = _app.ControllerConnect.new()
			screen.theme = _app.theme_res
			screen.layout_direction = Control.LAYOUT_DIRECTION_RTL if lang == "he" else Control.LAYOUT_DIRECTION_LTR
			host.add_child(screen)
			screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var m: Vector4 = c.safe
			screen.offset_left = m.x
			screen.offset_top = m.y
			screen.offset_right = -m.z
			screen.offset_bottom = -m.w
			for _i in 4:
				await process_frame
			var safe := Rect2(m.x, m.y, c.view.x - m.x - m.z, c.view.y - m.y - m.w)
			var about: Button = _find_button(screen, "common.about")
			var plus: Button = _find_button(screen, "+")
			var pencil: Button = _buttons(screen).filter(
					func(b): return b.get_child_count() > 0 and b.get_child(0).get_script() == PencilIcon).front()
			var dropdown_head: Control = null
			for n in screen.find_children("*", "VBoxContainer", true, false):
				if n.get_script() != null and n.get_script().resource_path.ends_with("profile_dropdown.gd"):
					dropdown_head = n._head
			var rects := {"about": about.get_global_rect(), "head": dropdown_head.get_global_rect(),
					"pencil": pencil.get_global_rect(), "plus": plus.get_global_rect()}
			var inside := rects.values().all(func(r: Rect2): return safe.grow(0.5).encloses(r))
			var names := rects.keys()
			var touching: Array = []
			for i in names.size():
				for j in range(i + 1, names.size()):
					if rects[names[i]].intersects(rects[names[j]]):
						touching.append("%s/%s" % [names[i], names[j]])
			var label := "%s, %s" % [c.name, lang]
			_check(inside, "%s: About, the dropdown, the pencil and the + are inside the safe area" % label)
			_check(touching.is_empty(), "%s: they do not overlap each other: %s" % [label, str(touching)])
			var centre: float = c.view.x * 0.5
			var about_centre: float = rects.about.get_center().x
			_check((about_centre > centre) if lang == "en" else (about_centre < centre),
					"%s: About is on the %s of the screen" % [label, "right" if lang == "en" else "left"])
			if c.name == "tall":
				about.pressed.emit()
				await process_frame
				var opened: Control = _app.current_screen()
				_check(opened.get_script() == _app.AboutScreen and opened.back_screen == _app.ControllerConnect,
						"%s: About opens the About list, and Back leads to the Connect screen" % label)
				_app.go(_app.ControllerConnect)
				await process_frame
			host.queue_free()
	_app.set_language("en", false)
	_app.profiles.delete(p.id)
	_app.apply_profile()


## Test 20 step 12c: the code of the largest profile (a 10 letter name and a best for each of the 42 keys, each with 5 bytes) fits
## in a QR code of the encoder and is made fast.
func _largest_code() -> void:
	print("the largest player code")
	var p = Profile.new()
	p.id = "9f2c4e7a1b3d5f60718293a4b5c6d7e8"
	p.player_name = "Abcdefghij"
	p.avatar = 31
	p.rev = 100000
	for key in ProfileKeys.all_keys():
		p.bests[key] = 4000000000
	var code := ProfileCode.encode(p)
	var decoded := ProfileCode.decode(code)
	_check(decoded.ok and decoded.profile.bests.size() == ProfileKeys.all_keys().size(),
			"the largest profile makes a code that holds all %d bests" % ProfileKeys.all_keys().size())
	var t0 := Time.get_ticks_usec()
	var modules := QrEncoder.encode(code)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var version := (modules.size() - 17) / 4
	_check(not modules.is_empty() and version <= QrEncoder.MAX_VERSION and (modules.size() - 17) % 4 == 0,
			"its QR code is made, version %d of at most %d (the code is %d characters)" % [version, QrEncoder.MAX_VERSION, code.length()])
	_check(ms < 1000.0, "the QR code is made in less than 1 s in a headless run (about 200 ms on the test machine): %.0f ms" % ms)
