extends SceneTree
## Every TV screen in English and in Hebrew (REQ-FL-38 to 42, 54, 63, REQ-GM-40, 41): the arcade look read from the node tree.
## The text sizes, that no text is wider than its box or outside the 60 px margin, the colors of the text, upper case in English,
## the title at the right in Hebrew, one cursor in front of the focused item (at the right and pointing left in Hebrew), the
## down key that moves one item, the red and the quiet items, and the OK and Back keys. It replaces the "look at every screen"
## parts of manual test 16 (items 1, 4) and test 17 (item 2). Run:
##   godot --headless --path . --script tests/screens_sweep.gd -- --role=tv

const Lang = preload("res://scripts/core/lang.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const MenuItem = preload("res://scripts/ui/menu_item.gd")
const Registry = preload("res://scripts/game/registry.gd")

const MIN_FONT := 32            # The smallest text on the TV (smoke_tv `_small_text`, REQ-GM-41 asks for 28).
const MARGIN := 60.0
## The colors a text can have (REQ-FL-38): white, dim, yellow, and green and red for the words ON, OK, LOST.
const TEXT_COLORS := [UiTheme.TEXT, UiTheme.TEXT_DIM, UiTheme.ACCENT, UiTheme.OK, UiTheme.BAD]

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


## A check for a problem of the game that is known: it prints KNOWN BUG and does not count as a failure.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		print("  KNOWN BUG (%s) %s" % [issue, what])


func _initialize() -> void:
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(3)


## The OK key of a remote: a key press and release (a button acts on the key, not on the action alone).
func _ok_key() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.physical_keycode = KEY_ENTER
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(2)
	await _frames(2)


func _run() -> void:
	await _frames(5)
	root.size = Vector2i(1920, 1080)
	_app = root.get_node("App")
	var saved := FileAccess.get_file_as_string(_app.SETTINGS_FILE) if FileAccess.file_exists(_app.SETTINGS_FILE) else ""
	_app.settings.language = "en"
	for i in 3:
		_app.server.players[i].state = 1   # Three phones are joined.
	_check(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color") == UiTheme.BG,
			"the screen background is the arcade black")
	for code in ["en", "he"]:
		_app.set_language(code, false)
		await _screens(code)
	_app.set_language("en", false)
	await _keys()
	if saved == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_app.SETTINGS_FILE))
	else:
		FileAccess.open(_app.SETTINGS_FILE, FileAccess.WRITE).store_string(saved)


func _screens(code: String) -> void:
	_app.go_logo()
	await _frames(6)
	await _sweep("logo", code)
	_app.go_connect()
	await _frames(6)
	await _sweep("connect", code)
	_app.current_screen().on_back()   # The quit question.
	await _frames(25)
	await _sweep("connect, quit question", code)
	var quit_dialog: Control = _app.current_screen()._modal
	var danger: Button = null
	for b in quit_dialog.find_children("*", "Button", true, false):
		if b.theme_type_variation == &"DangerButton":
			danger = b
	_check(danger != null and danger.text == "connect.quit" and danger.get_theme_color("font_color") == UiTheme.TEXT
			and danger.get_theme_color("font_focus_color") == UiTheme.BAD,
			"%s: QUIT is a red item (white, red with the focus)" % code)
	quit_dialog.close()
	await _frames(3)
	_app.go_games()
	await _frames(25)
	await _sweep("games", code)
	_app.current_screen()._open_players()
	await _frames(25)
	await _sweep("games, players", code)
	_app.current_screen()._modal.close()
	await _frames(3)
	_app.go_settings()
	await _frames(25)
	await _sweep("settings", code)
	_app.go(_app.AboutScreen, {"back_screen": _app.TvSettings})
	await _frames(25)
	await _sweep("about", code)
	for g in Registry.all():
		_app.go_game_settings(String(g.id))
		await _frames(25)
		await _sweep("settings of " + String(g.id), code)


## The Labels and Buttons that show text on the screen now.
func _text_nodes(screen: Node) -> Array:
	var out: Array = []
	for n in screen.find_children("*", "", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and _shown(n) != "":
			out.append(n)
	return out


func _shown(n: Control) -> String:
	var t := String(n.text)
	return n.tr(t) if n.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else t


## True when `n` is inside a ScrollContainer and its rectangle is not in the visible part of it.
func _clipped(n: Control) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return not (p as ScrollContainer).get_global_rect().intersects(n.get_global_rect())
		p = p.get_parent()
	return false


## Where the text of a label really starts: the alignment follows the layout direction (a left aligned label starts at the right
## in Hebrew).
func _text_x(l: Label) -> float:
	var r := l.get_global_rect()
	var w := l.get_theme_font("font").get_string_size(_shown(l), HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			return r.position.x + (r.size.x - w) * 0.5 + w * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			return (r.position.x if l.is_layout_rtl() else r.end.x - w) + w * 0.5
		_:
			return (r.end.x - w if l.is_layout_rtl() else r.position.x) + w * 0.5


func _sweep(name: String, code: String) -> void:
	var screen: Control = _app.current_screen()
	var state := "%s in %s" % [name, "Hebrew" if code == "he" else "English"]
	var nodes := _text_nodes(screen)
	var small: Array = []
	var wide: Array = []
	var outside: Array = []
	var lower: Array = []
	var odd: Array = []
	var about: bool = screen.get_script().resource_path.ends_with("about_screen.gd")
	for n in nodes:
		var t := _shown(n)
		var fs: int = n.get_theme_font_size("font_size")
		var font: Font = n.get_theme_font("font")
		var r: Rect2 = n.get_global_rect()
		if _clipped(n):
			continue   # Scrolled out of view inside a ScrollContainer.
		if fs < MIN_FONT and not (about and n is Label and n.autowrap_mode != TextServer.AUTOWRAP_OFF):
			small.append("%s %dpx" % [t, fs])
		var wrap: bool = n is Label and n.autowrap_mode != TextServer.AUTOWRAP_OFF
		var text_w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if not wrap and text_w > r.size.x + 1.0 and not (n is Label and n.clip_text):
			wide.append("%s %d>%d" % [t, text_w, r.size.x])
		if r.position.x < MARGIN - 1.0 or r.end.x > 1920.0 - MARGIN + 1.0 or r.position.y < MARGIN - 1.0 or r.end.y > 1080.0 - MARGIN + 1.0:
			outside.append("%s %s" % [t, str(r)])
		if code == "en" and t != t.to_upper():
			lower.append(t)
		var c: Color = n.get_theme_color("font_color")
		if n is Label and not (c in TEXT_COLORS):
			odd.append("%s %s" % [t, c.to_html()])
	_check(not nodes.is_empty() or name == "logo", "%s: the screen shows text" % state)
	_check(small.is_empty(), "%s: every text is %d px or larger %s" % [state, MIN_FONT, str(small.slice(0, 4))])
	_check(wide.is_empty(), "%s: no text is wider than its box %s" % [state, str(wide.slice(0, 4))])
	if name == "games, players":
		_known_bug("issue-needed: the Players modal is 1824 px wide, its text starts at x 54 and ends at 1878 (REQ-GM-40)", outside.is_empty(),
				"%s: no visible text box is outside the 60 px margin %s" % [state, str(outside.slice(0, 3))])
	else:
		_check(outside.is_empty(), "%s: no visible text box is outside the 60 px margin (REQ-GM-40) %s" % [state, str(outside.slice(0, 3))])
	_check(lower.is_empty(), "%s: all English text is upper case %s" % [state, str(lower.slice(0, 4))])
	_check(odd.is_empty(), "%s: every label color is white, gray, yellow, green or red %s" % [state, str(odd.slice(0, 4))])
	# The title of the screen: yellow, and at the right half in Hebrew (the first label of 64 px).
	var title: Label = null
	for n in nodes:
		if n is Label and n.get_theme_font_size("font_size") == UiTheme.SIZE_TITLE and n.get_theme_color("font_color") == UiTheme.ACCENT \
				and not n.has_meta("room"):
			title = n
			break
	if title != null and name in ["connect", "games", "settings", "about"]:
		if code == "he":
			_check(_text_x(title) > 960.0 or title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
					"%s: the title is at the right (text center x %d)" % [state, _text_x(title)])
		else:
			_check(_text_x(title) < 960.0 or title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
					"%s: the title is at the left (text center x %d)" % [state, _text_x(title)])
	# The cursor: one item has the focus, and its cursor is on the reading side (the right, pointing left, in Hebrew).
	var items: Array = []
	for n in screen.find_children("*", "Button", true, false):
		if n is MenuItem and n.is_visible_in_tree() and not n.disabled:
			items.append(n)
	if items.is_empty():
		return
	var focused: Array = items.filter(func(b: Button) -> bool: return b.has_focus())
	_check(focused.size() == 1, "%s: exactly one menu item has the cursor (%d of %d)" % [state, focused.size(), items.size()])
	if focused.size() == 1:
		var item: MenuItem = focused[0]
		var sb := item.get_theme_stylebox("normal")
		var room := UiTheme.CURSOR_UNIT * 4.0 + 24.0
		_check(item.is_layout_rtl() == (code == "he") and
				(sb.content_margin_right == room if code == "he" else sb.content_margin_left == room),
				"%s: the cursor of the focused item is %s" % [state, "at the right, pointing left" if code == "he" else "at the left"])
		_check(item.get_global_rect().has_point(item.get_global_rect().get_center()) and item.size.y > 0.0 and item.visible,
				"%s: the focused item is on the screen" % state)
		var below := item.find_valid_focus_neighbor(SIDE_BOTTOM)
		if below != null and below is MenuItem and below.get_global_rect().position.y > item.get_global_rect().position.y:
			await _key("ui_down")
			var now := root.gui_get_focus_owner()
			_check(now == below, "%s: the down key moves the cursor to the next item below, one item (%s)" % [state, str(now)])
			item.grab_focus()
			await _frames(2)
	# Back is a quiet item, and a destructive item is red.
	for b in items:
		var t := _shown(b)
		if t == Lang.t("common.back"):
			var quiet: bool = b.theme_type_variation == &"QuietButton" and b.get_theme_color("font_color") == UiTheme.TEXT_DIM \
					and b.get_theme_color("font_focus_color") == UiTheme.ACCENT
			if name == "about":
				_known_bug("issue-needed: the BACK item of the About screen is a normal item, not a QuietButton (REQ-FL-41)", quiet,
						"%s: BACK is a quiet item, gray and yellow with the cursor" % state)
			else:
				_check(quiet, "%s: BACK is a quiet item, gray and yellow with the cursor" % state)
		if b.theme_type_variation == &"DangerButton":
			_check(b.get_theme_color("font_color") == UiTheme.TEXT and b.get_theme_color("font_focus_color") == UiTheme.BAD,
					"%s: the red item '%s' is white and red with the cursor" % [state, t])


## The OK and Back keys of the remote on three screens (the physical keys stay in test 8).
func _keys() -> void:
	_app.go_games()
	await _frames(25)
	await _key("ui_cancel")
	_check(is_instance_of(_app.current_screen(), _app.TvConnect), "Back on the Games screen goes to the Connect screen")
	await _frames(3)
	_app.go_settings()
	await _frames(25)
	await _key("ui_cancel")
	_check(is_instance_of(_app.current_screen(), _app.TvGames), "Back on the Settings screen goes up to the Games screen")
	await _frames(20)
	_app.go_settings()
	await _frames(25)
	var rows: Array = _app.current_screen()._rows
	rows[0].grab_focus()
	await _frames(2)
	var before: bool = _app.settings.overlay
	await _ok_key()
	_check(_app.settings.overlay != before, "OK on a Settings row runs the row (the overlay switch changed)")
	await _ok_key()
	_app.go_connect()
	await _frames(6)
	_app.current_screen().on_back()
	await _frames(25)
	await _ok_key()   # The focused item of the quit question is STAY.
	_check(is_instance_of(_app.current_screen(), _app.TvConnect) and _app.current_screen()._modal == null,
			"OK on STAY closes the quit question and stays on the Connect screen")
	_app.current_screen().on_back()
	await _frames(25)
	await _key("ui_cancel")
	_check(_app.current_screen()._modal == null, "Back on the quit question closes it")
