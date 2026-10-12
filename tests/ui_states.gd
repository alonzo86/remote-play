extends SceneTree
## Menu item states and the pixel cursor, the double frame, blinking prompts (REQ-FL-38, 41, 42, 53), the Leave box of the phone
## wait screen (REQ-FL-52), English and left to right (REQ-FL-54), the game tile images and the Back key (REQ-FL-55).
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/ui_states.gd -- --role=controller

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Shell = preload("res://scripts/game/shell.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")

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


func _run() -> void:
	_button_styles()
	await _wait_screen_leave()
	await _profile_screens()
	await _keyboard_focus()
	await _modal_focus()
	await _connect_scan()
	_english_ltr()
	_back_key()
	_tile_images()
	_safe_area()


func _button_styles() -> void:
	print("menu items")
	# A menu item is text: no box. The focused item is yellow, a destructive one is red, a quiet one is dim. A disabled
	# one is dim. The text of every state has a contrast of 4.5:1 or more on the black screen (REQ-FL-41, 53).
	var theme := UiTheme.make()
	var focus_colors := {"Button": UiTheme.ACCENT, "DangerButton": UiTheme.BAD, "QuietButton": UiTheme.ACCENT}
	var item_ok := true
	for type in focus_colors:
		item_ok = item_ok and theme.get_color("font_focus_color", type) == focus_colors[type]
		for c in ["font_color", "font_focus_color", "font_disabled_color", "font_pressed_color"]:
			item_ok = item_ok and UiTheme.contrast(theme.get_color(c, type), UiTheme.BG) >= 4.5
		for st in ["normal", "focus", "pressed", "disabled"]:
			item_ok = item_ok and theme.get_stylebox(st, type) is StyleBoxEmpty   # No box, no shadow, no outline.
	_check(item_ok, "menu items: no box, yellow with the focus, red for a destructive item, 4.5:1 or more in every state")
	_check(theme.get_color("font_color", "QuietButton") == UiTheme.TEXT_DIM and theme.get_color("font_disabled_color", "Button")
			== UiTheme.DISABLED, "a quiet item and a disabled item are dim")
	# The cursor is made of pixels: 4 columns of 7, 5, 3 and 1 pixels, tall in the middle (REQ-FL-41).
	var rects := UiTheme.cursor_rects(Vector2(0, 100), 5.0)
	_check(rects.size() == 4 and rects[0].size == Vector2(5, 35) and rects[1].size == Vector2(5, 25)
			and rects[3].size == Vector2(5, 5) and rects[0].position.y == 100.0 - 17.5 and rects[3].position.x == 15.0,
			"the cursor is a stepped triangle that points right")
	var flipped := UiTheme.cursor_rects(Vector2(0, 100), 5.0, true)
	_check(flipped[0].position.x == 15.0 and flipped[3].position.x == 0.0, "a flipped cursor points left (right to left layouts)")
	var item: Button = UiKit.item("Quit", func(): pass, 40, "danger")
	root.add_child(item)
	_check(item.text == "QUIT" and item.theme_type_variation == "DangerButton" and item.focus_mode == Control.FOCUS_ALL,
			"a menu item shows upper case text and keeps its role")
	item.queue_free()
	# The double frame: a 6 px line, 6 px of black, a 6 px line, and the content margin covers all three.
	var fr := UiTheme.frame(24)
	_check(fr.rings() == [6, 6, 6] and fr.get_margin(SIDE_LEFT) == 42.0 and fr.outer_color == UiTheme.TEXT
			and fr.inner_color == UiTheme.FRAME,
			"a panel has a double frame: white line, black gap, blue line")
	var box := UiTheme.card(UiTheme.BG, UiTheme.TEXT, 6, 30, true)
	_check(box.corner_radius_top_left == 0 and box.shadow_size == 0,
			"boxes have square corners and no shadow, whatever the game asks for")
	# A prompt blinks with a hard step: 0.55 s on, 0.55 s off.
	_check(UiTheme.blink_on(0.0) and UiTheme.blink_on(0.54) and not UiTheme.blink_on(0.56) and not UiTheme.blink_on(1.09)
			and UiTheme.blink_on(1.11), "a prompt is on for 0.55 s and off for 0.55 s")
	var blink: Label = UiKit.blinking("Press OK")
	root.add_child(blink)
	blink._process(0.6)
	_check(blink.text == "PRESS OK" and blink.modulate.a == 0.0, "the blinking label is hidden in the off half")
	blink._process(0.55)
	_check(blink.modulate.a == 1.0, "and shows again in the next on half")
	blink.queue_free()
	_check(Shell.countdown_size(0.0) == 352 and Shell.countdown_size(0.1) == 320 and Shell.countdown_size(0.2) == 288
			and Shell.countdown_size(1.0) == 256, "the countdown number settles in 4 steps of the font grid")
	var fonts_ok := true
	for path in [UiTheme.FONT_FILE, UiTheme.FONT_HEBREW]:
		var imp := FileAccess.get_file_as_string(path + ".import")
		fonts_ok = fonts_ok and imp.contains("antialiasing=0") and imp.contains("hinting=0") and imp.contains("subpixel_positioning=0")
	_check(fonts_ok, "both pixel fonts are imported with no smoothing and no hinting, so the pixels stay sharp (REQ-FL-39)")
	_check(UiTheme.font().fallbacks.size() == 1 and UiTheme.font().has_char("A".unicode_at(0)),
			"the Hebrew pixel font is the fallback of the arcade font")


## Disconnect on the waiting screen leaves the TV with one tap, and sits at the top (REQ-FL-52).
func _wait_screen_leave() -> void:
	print("wait screen Disconnect")
	var app: Node = root.get_node("App")
	var wait: Control = load("res://scripts/ui/controller_wait.gd").new()
	root.add_child(wait)
	await process_frame
	_check(wait._leave.text == "DISCONNECT", "the button says DISCONNECT")
	_check(wait._leave.get_global_rect().position.y < wait._name.get_global_rect().position.y,
			"Disconnect is above the content of the waiting screen")
	app.client._set_state(ControllerClient.State.CONNECTED)
	wait._leave.pressed.emit()
	_check(app.client.state == ControllerClient.State.IDLE, "one tap leaves the TV")
	_check(wait.find_children("*", "Button", true, false).all(func(b): return b.text != "PLAYER"),
			"there is no PLAYER button while joined (REQ-FL-71)")
	wait.queue_free()


## The layout direction follows the language of the app and not the locale of the device (REQ-FL-54, 60): Hebrew is right to left,
## English is left to right, also on a device whose locale says otherwise.
func _english_ltr() -> void:
	print("language and layout direction")
	var app: Node = root.get_node("App")
	var probe := Control.new()
	root.add_child(probe)
	app.set_language("he", false)
	_check(probe.is_layout_rtl(), "the Hebrew language makes the layout right to left")
	app.set_language("en", false)
	_check(not probe.is_layout_rtl(), "the English language makes it left to right")
	TranslationServer.set_locale("ar_SA")
	_check(not probe.is_layout_rtl(), "an Arabic locale of the device does not change the direction")
	app.set_language("en", false)   # The locale goes back to English.
	_check(TranslationServer.get_locale().begins_with("en"), "the locale is English again: %s" % TranslationServer.get_locale())
	probe.queue_free()


## The screenshots of the Games screen: loaded as they are (square corners, REQ-FL-57), and a warning when one cannot load.
func _tile_images() -> void:
	print("game tile images")
	var tile_script: GDScript = load("res://scripts/ui/game_tile.gd")
	var registry: GDScript = load("res://scripts/game/registry.gd")
	_check(tile_script.load_tile("") == null and tile_script.load_tile("res://assets/tiles/does_not_exist.png") == null,
			"no path or a missing file gives no texture, so the tile shows its placeholder")
	var all_load := true
	for g in registry.GAMES:
		var t: Texture2D = tile_script.load_tile(String(g.tile))
		if t == null or t.get_width() != 640 or t.get_height() != 360:
			all_load = false
			print("    the tile of ", g.id, " did not load")
	_check(all_load, "the tile of every game in the registry loads, 640x360")


## The Back key goes back one step in the app. It must not quit the app by itself (REQ-FL-55).
func _back_key() -> void:
	print("back key")
	_check(ProjectSettings.get_setting("application/config/quit_on_go_back", true) == false,
			"the engine does not quit on the Back key: the app decides (project.godot, quit_on_go_back)")


## The safe area of a phone (REQ-FL-68): the margins that a notch, a Dynamic Island and the home bar need.
func _safe_area() -> void:
	print("safe area")
	var safe_area := load("res://scripts/ui/safe_area.gd")
	# An iPhone with a Dynamic Island: 1179x2556 px, a safe area from y 177 to y 2457, drawn in a viewport 1920 wide.
	var m: Vector4 = safe_area.insets(Vector2(1179, 2556), Rect2(0, 177, 1179, 2280), Vector2(1920, 4162))
	_check(is_equal_approx(m.x, 0.0) and is_equal_approx(m.z, 0.0) and is_equal_approx(m.y, 177.0 * 1920.0 / 1179.0)
			and is_equal_approx(m.w, 99.0 * 1920.0 / 1179.0), "the top and the bottom margins are in viewport units: %s" % str(m))
	_check(safe_area.insets(Vector2(1080, 1920), Rect2(0, 0, 1080, 1920), Vector2(1080, 1920)) == Vector4.ZERO,
			"a screen with no cut-out has no margin")
	_check(safe_area.insets(Vector2(1080, 1920), Rect2(), Vector2(1080, 1920)) == Vector4.ZERO
			and safe_area.insets(Vector2.ZERO, Rect2(0, 0, 10, 10), Vector2(1080, 1920)) == Vector4.ZERO,
			"an unknown safe area or window gives no margin")
	_check(safe_area.insets(Vector2(1080, 1920), Rect2(-20, -20, 1400, 2400), Vector2(1080, 1920)) == Vector4.ZERO,
			"a safe area larger than the window gives no negative margin")
	var landscape: Vector4 = safe_area.insets(Vector2(2556, 1179), Rect2(177, 0, 2202, 1179), Vector2(1920, 886))
	_check(landscape.x > 0.0 and landscape.z > 0.0 and landscape.y == 0.0, "a turned phone has the cut-out at the side")
	_check(safe_area.current(Vector2(1920, 1080)) == Vector4.ZERO, "a desktop window has no margin")


func _dropdown(screen: Node) -> Control:
	for n in screen.find_children("*", "VBoxContainer", true, false):
		if n.get_script() != null and n.get_script().resource_path.ends_with("profile_dropdown.gd"):
			return n
	return null


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var f := _find_button(c, text)
		if f != null:
			return f
	return null


## The phone screens of the profiles (FD-22, REQ-FL-71, 72): the row on the Connect screen, the list, the edit screen, the avatar
## on the waiting screen, and the screens that close when a round starts.
func _profile_screens() -> void:
	print("profile screens")
	var app: Node = root.get_node("App")
	var real_store = app.profiles
	var path := "user://test_ui_profiles.cfg"
	for f in [path, path + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	app.profiles = ProfileStore.new(path)
	app.apply_profile()
	app.go(app.ControllerConnect)
	await process_frame
	var connect: Control = app.current_screen()
	var dropdown: Control = _dropdown(connect)
	_check(dropdown._head.get_child(0).get_child(1).text == "GUEST" and not dropdown.open,
			"a phone with no profile shows GUEST in a closed dropdown on the Connect screen")
	_find_button(connect, "+").pressed.emit()
	await process_frame
	var edit: Control = app.current_screen()
	_check(edit.get_script() == app.ControllerProfileEdit and edit.profile_id == "", "the + opens the new player screen")
	edit.on_back()
	await process_frame
	_check(app.current_screen().get_script() == app.ControllerConnect, "Back from a new player goes to the main screen")
	app.go(app.ControllerProfileEdit, {"profile_id": ""})
	await process_frame
	await process_frame
	edit = app.current_screen()
	_check(edit._arrow_left.disabled and not edit._arrow_right.disabled,
			"at the start the left arrow is dim and the right one works")
	edit._scroll.scroll_horizontal = edit.max_scroll()
	await process_frame
	_check(edit._arrow_right.disabled and not edit._arrow_left.disabled,
			"at the end the right arrow is dim and the left one works")
	edit._scroll.scroll_horizontal = 200
	await process_frame
	_check(not edit._arrow_left.disabled and not edit._arrow_right.disabled,
			"in the middle both arrows work")
	_check(edit._scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
			and edit._scroll.get_child(0).get_child_count() == Protocol.AVATAR_COUNT
			and edit._scroll.get_child(0) is HBoxContainer, "the avatars are in one line")
	_check(edit.get_script() == app.ControllerProfileEdit and edit.profile_id == "" and edit._save.disabled,
			"it opens the new player screen, and SAVE waits for a name")
	edit._on_text("Ma ya!@#")
	_check(edit._name.text == "Ma ya" and edit._hint.text != "" and not edit._save.disabled,
			"the name field keeps only letters, digits and spaces, and says so")
	edit._on_text("Ma ya12345678901")
	_check(edit._name.text == "Ma ya12345", "the name field keeps at most 10 characters")
	edit._name.text = "Maya"
	edit._name.text_changed.emit("Maya")
	_check(edit._hint.text == "", "the hint goes when the name is right")
	edit._views[5].pressed.emit()
	_check(edit._views[5].selected and not edit._views[4].selected, "a tap on an avatar picks it")
	edit._save.pressed.emit()
	await process_frame
	var made = app.profiles.profiles[0]
	_check(app.profiles.profiles.size() == 1 and made.player_name == "Maya" and made.avatar == 5
			and app.profiles.active_id == made.id and app.client.pid == made.id and app.client.avatar == 5
			and app.client.player_name == "Maya",
			"SAVE makes the profile, makes it active and gives it to the client")
	_check(app.current_screen().get_script() == app.ControllerConnect, "SAVE of a new player goes to the main screen")
	app.go(app.ControllerConnect)
	await process_frame
	dropdown = _dropdown(app.current_screen())
	_check(dropdown._head.get_child(0).get_child(1).text == "MAYA", "the dropdown head shows the active player")
	dropdown.toggle()
	_check(dropdown.open and dropdown._list.get_child_count() == 3, "it opens a row for the player, one for the guest and PLAYERS")
	dropdown._pick("")
	await process_frame
	_check(app.profiles.active_id == "" and app.client.pid == "", "a tap on GUEST in the dropdown makes the phone a guest")
	dropdown = _dropdown(app.current_screen())
	dropdown._pick(made.id)
	await process_frame
	_check(app.client.pid == made.id, "a tap on a player in the dropdown makes it active")
	await process_frame
	var rev_before: int = made.rev
	var edit_button := _find_button(app.current_screen(), "EDIT")
	_check(edit_button != null, "the Connect screen has an EDIT button for the active player")
	edit_button.pressed.emit()
	await process_frame
	edit = app.current_screen()
	_check(edit.get_script() == app.ControllerProfileEdit and edit.profile_id == made.id and edit._name.text == "Maya",
			"EDIT opens the active player with its name")
	edit._name.text = "Mayo"
	edit._on_text("Mayo")
	edit._views[9].pressed.emit()
	edit._save.pressed.emit()
	await process_frame
	_check(made.player_name == "Mayo" and made.avatar == 9 and app.client.player_name == "Mayo" and app.client.avatar == 9,
			"a new name and a new avatar are saved and go to the TV")
	_check(app.current_screen().get_script() == app.ControllerConnect, "Save goes back to the main screen")
	app.go(app.ControllerProfileEdit, {"profile_id": made.id})
	await process_frame
	app.current_screen().on_back()
	await process_frame
	_check(app.current_screen().get_script() == app.ControllerConnect, "Back from EDIT goes to the main screen")
	app.profiles.update(made.id, "Maya", 5)   # The tests below go on with the first name and avatar and the first edit number.
	made.rev = rev_before
	app.apply_profile()
	app.go(app.ControllerProfiles)
	await process_frame
	var list: Control = app.current_screen()
	# The list: rows for the profiles and the guest, the active one in yellow; a tap changes the active profile.
	list._on_pick("")
	_check(app.profiles.active_id == "" and app.client.pid == "" and app.client.avatar == -1,
			"the guest row makes the phone a guest")
	list._on_pick(made.id)
	_check(app.client.pid == made.id, "a profile row makes it the active one again")
	# The edit screen of a profile: a change of the name raises the edit number; DELETE asks first.
	list._on_edit(made.id)
	await process_frame
	edit = app.current_screen()
	_check(edit._name.text == "Maya" and edit._views[5].selected and edit._delete != null, "the edit screen shows the profile")
	edit._name.text = "Mia"
	edit._on_text("Mia")
	edit._views[2].pressed.emit()
	edit._save.pressed.emit()
	await process_frame
	_check(made.player_name == "Mia" and made.avatar == 2 and made.rev == 1 and app.client.player_name == "Mia",
			"an edit changes the profile and the client")
	app.go(app.ControllerProfileEdit, {"profile_id": made.id, "from_list": true})
	await process_frame
	edit = app.current_screen()
	edit._delete.pressed.emit()
	_check(app.profiles.profiles.size() == 1 and edit._delete.text == "DELETE MIA?", "the first tap on DELETE asks for the name")
	edit._delete_timer.timeout.emit()
	_check(edit._delete.text == "DELETE", "DELETE goes back to its text when the time is over")
	edit._delete.pressed.emit()
	edit._delete.pressed.emit()
	await process_frame
	_check(app.profiles.profiles.is_empty() and app.client.pid == ""
			and app.current_screen().get_script() == app.ControllerProfiles,
			"the second tap deletes the profile, the phone is a guest")
	# A full list.
	for i in ProfileStore.MAX_PROFILES:
		app.profiles.create("P%d" % i, i)
	app.go(app.ControllerProfiles)
	await process_frame
	list = app.current_screen()
	_check(list._new_button.disabled and list._note.text.contains("8"), "8 profiles: NEW PLAYER is dim and a line says why")
	app.profiles.delete(app.profiles.profiles[0].id)
	list._rebuild()
	_check(not list._new_button.disabled and list._note.text == "", "with room again NEW PLAYER works")

	# The waiting screen shows the avatar and the name that the TV has, and the PLAYER button only in a menu phase.
	var c: Node = app.client
	c._set_state(ControllerClient.State.CONNECTED)
	c.phase = "menu"
	c.tv_pid = "ab".repeat(16)
	c.tv_avatar = 3
	c.tv_player_name = "Maya"
	app.go(app.ControllerWait)
	await process_frame
	var wait: Control = app.current_screen()
	_check(wait._name.text == "MAYA", "the waiting screen shows the profile name")
	c.tv_pid = ""
	wait._refresh()
	_check(wait._name.text == "%dP" % (c.slot + 1), "a guest sees the slot number")
	# The profile screens close when a round starts, and stay in a menu phase.
	c.phase = "menu"
	app.go(app.ControllerProfiles)
	await process_frame
	app._show_phone_screen()
	_check(app.current_screen().get_script() == app.ControllerProfiles, "the list stays open in a menu phase")
	c.phase = "waiting"
	app._show_phone_screen()
	_check(app.current_screen().get_script() == app.ControllerWait, "a round that this phone joined late closes the list")
	c.phase = "menu"
	app.go(app.ControllerProfileEdit, {"profile_id": ""})
	await process_frame
	c.phase = "playing"
	app._show_phone_screen()
	_check(app.current_screen().get_script() == app.ControllerPad, "a round closes the edit screen")
	c.phase = "menu"
	app.leave_profile_screens()
	await process_frame
	_check(app.current_screen().get_script() == app.ControllerWait,
			"leaving the profile screens goes to the waiting screen when joined")
	app.go(app.ControllerProfileEdit, {"profile_id": ""})
	await process_frame
	c._set_state(ControllerClient.State.IDLE)
	await process_frame
	_check(app.current_screen().get_script() == app.ControllerProfileEdit, "a lost connection does not close the edit screen")
	app.leave_profile_screens()
	await process_frame
	_check(app.current_screen().get_script() == app.ControllerConnect, "and to the Connect screen when not joined")
	app.profiles = real_store
	app.apply_profile()
	for f in [path, path + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


## A tap does not drop the focus of a text field (it closes the keyboard).
func _keyboard_focus() -> void:
	print("keyboard focus")
	var app: Node = root.get_node("App")
	app.go(app.ControllerConnect)
	await process_frame
	var field := LineEdit.new()
	app.current_screen().add_child(field)
	field.position = Vector2(100, 100)
	field.size = Vector2(300, 80)
	field.grab_focus()
	app._release_focus(field.get_global_rect().get_center())
	_check(field.has_focus(), "a tap on a text field keeps its focus")
	app._release_focus(Vector2(900, 900))
	_check(not field.has_focus(), "a tap outside the text field drops its focus, and the keyboard closes (REQ-FL-72)")
	var button := Button.new()
	app.current_screen().add_child(button)
	button.grab_focus()
	app._release_focus()
	_check(not button.has_focus(), "a tap drops the focus of a button")
	field.queue_free()
	button.queue_free()


## A modal holds the focus: the controls under the dim layer cannot take it while the modal is open, and they can again after
## it closes (TV-2: the arrow keys selected the games under the Players modal).
func _modal_focus() -> void:
	print("modal focus")
	var app: Node = root.get_node("App")
	var below := Button.new()
	below.focus_mode = Control.FOCUS_ALL
	app.add_child(below)
	var Modal: GDScript = load("res://scripts/ui/tv_modal.gd")
	var modal: Control = Modal.new()
	modal.entries = [["One", func(): pass], ["Two", func(): pass]]
	app.add_child(modal)
	await process_frame
	await process_frame
	_check(below.focus_mode == Control.FOCUS_NONE, "a control under the modal cannot take the focus")
	var first: Control = modal.first_focusable()
	_check(first != null and first.has_focus(), "the first item of the modal has the focus")
	var down := first.find_valid_focus_neighbor(SIDE_BOTTOM)
	_check(down != null and modal.is_ancestor_of(down), "an arrow key from the modal goes to another item of the modal")
	# The arrow keys: a move inside the modal goes on, a move that would leave it is stopped, and a focus that is outside comes back.
	var second: Control = first.find_valid_focus_neighbor(SIDE_BOTTOM)
	first.grab_focus()
	_check(not modal.blocks_move("ui_down"), "an arrow key between two items of the modal is not stopped")
	_check(modal.blocks_move("ui_up") and first.has_focus(), "an arrow key that would leave the modal is stopped, the focus stays")
	below.focus_mode = Control.FOCUS_ALL
	below.grab_focus()
	_check(modal.blocks_move("ui_left") and modal.is_ancestor_of(root.gui_get_focus_owner()),
			"a focus that is outside the modal is stopped and comes back into it")
	below.focus_mode = Control.FOCUS_NONE
	modal._input(_arrow("ui_down"))   # The event path calls the same check.
	modal._input(InputEventKey.new())   # Not an arrow key: nothing happens.
	modal.close()
	_check(below.focus_mode == Control.FOCUS_ALL, "the control can take the focus again when the modal closes")
	_check(second != null and modal.is_queued_for_deletion(), "the modal is closed after Back")
	below.queue_free()


## An input event of a UI action (an arrow key of the remote).
func _arrow(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


## The Connect screen asks the network for a TV when Refresh is tapped (REQ-FL-83), says "SEARCHING..." meanwhile, and a join
## stops the scan.
func _connect_scan() -> void:
	print("connect screen scan")
	var app: Node = root.get_node("App")
	app.go(app.ControllerConnect)
	await process_frame
	var screen: Control = app.current_screen()
	_check(not screen._prober.running, "the scan does not start by itself")
	screen._prober.start(["10.9.9.9"], 30)
	await process_frame
	screen._rebuild_list()
	var texts: Array = screen._list.find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(screen._prober.running and "SEARCHING..." in texts, "while the scan runs the list says SEARCHING...")
	screen._join("127.0.0.1", 1, "ABCD")
	_check(not screen._prober.running, "a join stops the scan")
	app.client.leave()
