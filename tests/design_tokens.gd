extends SceneTree
## docs/design-system/tokens.json must follow UiTheme and Protocol (the code is the source of truth).
## Run by tests/run_all.sh

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Protocol = preload("res://scripts/core/protocol.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const GearButton = preload("res://scripts/ui/gear_button.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Registry = preload("res://scripts/game/registry.gd")

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
	_run()
	_white_buttons()
	_avatar_sheet()
	_font_licences()
	_app_identity()
	_release_presets()
	_images()
	_export_pack()
	_info_text()
	_game_names()
	_typed_sizes()
	_no_avatar_on_objects()
	_confetti_in_code()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _family(data: Dictionary, family: String, name: String) -> String:
	for t in data[family].tokens:
		if t.name == name:
			return String(t.value)
	return ""


## The avatar sheet is 4 columns by 8 rows of 16 px cells and is imported without mipmaps, so a 16 px picture stays sharp (FD-22).
func _avatar_sheet() -> void:
	print("avatar sheet")
	var img: Image = load("res://assets/avatars/avatars.png").get_image()
	_check(img.get_width() == 64 and img.get_height() == 128, "the avatar sheet is 64 x 128 pixels (32 avatars of 16 x 16)")
	var imp := FileAccess.get_file_as_string("res://assets/avatars/avatars.png.import")
	_check(imp.contains("mipmaps/generate=false") and imp.contains("compress/mode=0"),
			"the sheet is imported lossless and without mipmaps")


## The OFL requires the licence text to travel with the font, so every export preset packs the OFL files (REQ-FL-39).
func _font_licences() -> void:
	print("font licences")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var filters := 0
	var csv_filters := 0
	var licence_filters := 0
	var presets_count := 0
	for line in presets.split("\n"):
		if line.begins_with("[preset.") and not line.contains(".options"):
			presets_count += 1
		if line.begins_with("include_filter=") and line.contains("assets/fonts/OFL-*.txt"):
			filters += 1
		if line.begins_with("include_filter=") and line.contains("assets/licenses/*.txt"):
			licence_filters += 1
		if line.begins_with("include_filter=") and line.contains("assets/lang/strings.csv"):
			csv_filters += 1
	_check(presets_count > 0 and filters == presets_count, "every export preset packs the font licence files")
	_check(presets_count > 0 and licence_filters == presets_count,
			"every export preset packs the licence files of the Android libraries")
	_check(presets_count > 0 and csv_filters == presets_count,
			"every export preset packs the table of texts (assets/lang/strings.csv)")
	var imp := FileAccess.get_file_as_string("res://assets/lang/strings.csv.import")
	_check(imp.contains('importer="keep"'),
			"the table of texts is not imported as a Godot translation: the app reads the file itself")
	for f in ["OFL-PressStart2P.txt", "OFL-SababiPixelHebrew.txt"]:
		_check(FileAccess.file_exists("res://assets/fonts/" + f), f + " exists")
	_check(FileAccess.file_exists("res://assets/licenses/android-libraries.txt"), "android-libraries.txt exists")


func _run() -> void:
	_contrast_checks()
	print("design tokens")
	var f := FileAccess.open("res://docs/design-system/tokens.json", FileAccess.READ)
	_check(f != null, "design system tokens file exists")
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	_check(data is Dictionary, "design system tokens file is valid JSON")
	if not data is Dictionary:
		return
	var known := {}
	var by_name := {}
	for t in data.color.tokens:
		var hex := String(t.value).trim_prefix("#").to_lower()
		known[hex if hex.length() == 8 else hex + "ff"] = t.name
		by_name[t.name] = hex if hex.length() == 8 else hex + "ff"
	var consts: Dictionary = (UiTheme as GDScript).get_script_constant_map()
	var wanted: Array = []
	for k in consts:
		if consts[k] is Color:
			wanted.append(consts[k])
		elif consts[k] is Array:
			wanted.append_array(consts[k].filter(func(v): return v is Color))
	wanted.append_array(Protocol.PLAYER_COLORS)
	# Colors the theme derives in code.
	wanted.append(Color(UiTheme.BG, 0.8))
	# Each named token holds the value of its UiTheme constant (a swap of two values is caught).
	var named := {"bg": UiTheme.BG, "text": UiTheme.TEXT, "text-info": UiTheme.TEXT_INFO,
			"text-dim": UiTheme.TEXT_DIM, "accent": UiTheme.ACCENT,
			"frame": UiTheme.FRAME, "ok": UiTheme.OK, "bad": UiTheme.BAD, "slot-empty": UiTheme.SLOT_EMPTY,
			"dim-layer": Color(UiTheme.BG, 0.8), "player-1": Protocol.PLAYER_COLORS[0],
			"player-2": Protocol.PLAYER_COLORS[1], "player-3": Protocol.PLAYER_COLORS[2],
			"player-4": Protocol.PLAYER_COLORS[3]}
	var wrong: Array[String] = []
	for n in named:
		if by_name.get(n, "") != (named[n] as Color).to_html(true):
			wrong.append(n)
	_check(wrong.is_empty(), "each named token holds its UiTheme value (wrong: %s)" % str(wrong))
	var missing: Array[String] = []
	for c in wanted:
		if not known.has((c as Color).to_html(true)):
			missing.append((c as Color).to_html(true))
	_check(missing.is_empty(), "every UiTheme and player color is a design token (missing: %s)" % str(missing))
	_check(_family(data, "border", "line-w") == "%dpx" % UiTheme.LINE, "frame line token matches UiTheme")
	var Shell = load("res://scripts/game/shell.gd")
	_check(_family(data, "border", "chip-line-w") == "%dpx" % Shell.CHIP_LINE, "chip frame line token matches Shell.CHIP_LINE")
	_check(data.has("color") and not data.has("radius") and not data.has("shadow"),
			"the design system has no radius and no shadow tokens: the style has square corners and no shadows (REQ-FL-38)")

	_check_outside_theme(data, by_name)


## Tokens whose source is not a UiTheme color: game backgrounds (REQ-GM-48), the app icon, type sizes, card padding.
func _check_outside_theme(data: Dictionary, by_name: Dictionary) -> void:
	var doc := FileAccess.get_file_as_string("res://docs/GAME_REQUIREMENTS.md")
	var worlds := {}
	for line in doc.split("\n"):
		if line.begins_with("- REQ-GM-48"):
			var re := RegEx.create_from_string("`#([0-9a-fA-F]{6})`")
			for m in re.search_all(line):
				worlds[m.get_string(1).to_lower() + "ff"] = true
	var tokens_worlds := {}
	for n in by_name:
		if String(n).begins_with("world-"):
			tokens_worlds[by_name[n]] = true
	_check(worlds.size() == 6 and worlds.keys().all(func(k): return k == by_name["bg"] or tokens_worlds.has(k)),
			"the game background tokens are the REQ-GM-48 colors")
	var icon := FileAccess.get_file_as_string("res://icon.svg")
	_check(icon.contains(String(by_name["brand-dark"]).substr(0,
			6)) and icon.contains(String(by_name["brand-yellow"]).substr(0, 6)),
			"the brand tokens are the colors in icon.svg")
	var theme: Theme = UiTheme.make()
	var sizes := {}
	for g in data.type.groups:
		for st in g.styles:
			sizes[st.name] = String(st.fontSize)
	_check(sizes.get("body", "") == "%dpx" % theme.default_font_size, "body size token matches the theme default")
	_check(sizes.get("button", "") == "%dpx" % theme.get_font_size("font_size", "Button"), "button size token matches the theme")
	_check(sizes.get("title", "") == "%dpx" % UiTheme.SIZE_TITLE and sizes.get("logo", "") == "%dpx" % UiTheme.SIZE_LOGO
			and sizes.get("countdown",
					"") == "%dpx" % UiTheme.SIZE_COUNTDOWN, "title, logo and countdown size tokens match the theme")
	var on_grid := true
	for size_name in sizes:
		on_grid = on_grid and int(String(sizes[size_name]).trim_suffix("px")) % 8 == 0
	_check(on_grid, "every type size is a multiple of 8, the grid of the font (REQ-FL-40)")
	var box: StyleBoxFlat = UiTheme.card()
	_check(_family(data, "spacing", "space-32") == "%dpx" % box.content_margin_left
			and _family(data, "spacing",
					"space-14") == "%dpx" % box.content_margin_top, "card padding tokens match UiTheme.card()")


## The text colors are readable on black, and the text on a player color is readable (REQ-GM-46, REQ-FL-40).
func _contrast_checks() -> void:
	print("contrast")
	var palette := {"TEXT": UiTheme.TEXT, "TEXT_INFO": UiTheme.TEXT_INFO,
			"TEXT_DIM": UiTheme.TEXT_DIM, "ACCENT": UiTheme.ACCENT, "OK": UiTheme.OK,
			"BAD": UiTheme.BAD}
	var low: Array[String] = []
	for n in palette:
		if UiTheme.contrast(palette[n], UiTheme.BG) < 4.5:
			low.append(n)
	_check(low.is_empty(), "every text color has a contrast of 4.5:1 or more on the black screen (low: %s)" % str(low))
	var player_ok := true
	for c in Protocol.PLAYER_COLORS:
		player_ok = player_ok and UiTheme.contrast(c, UiTheme.BG) >= 4.5
	_check(player_ok, "every player color has a contrast of 4.5:1 or more on black (a square next to the slot number)")
	var on_ok := true
	var black_text := true
	for c in Protocol.PLAYER_COLORS:
		on_ok = on_ok and UiTheme.contrast(UiTheme.text_on(c), c) >= 4.5
		black_text = black_text and UiTheme.text_on(c) == UiTheme.BG
	_check(on_ok, "the number on every slot color has 4.5:1 or more (text_on)")
	_check(black_text and UiTheme.text_on(Color.BLACK) == UiTheme.TEXT, "black text on every player color, white text on black")
	_check(UiTheme.contrast(UiTheme.BG, UiTheme.OK) >= 4.5 and UiTheme.contrast(UiTheme.BG, UiTheme.BAD) >= 4.5,
			"black text on the A button (green) and the B button (red) has 4.5:1 or more")
	_check(UiTheme.contrast(Color.WHITE, Color.BLACK) > 20.0 and UiTheme.contrast(Color.WHITE, Color.WHITE) < 1.01,
			"the contrast function is right")


## Issue #173, REQ-FL-38a: every enabled button is white (the face is the white token, the text is black and readable), a
## disabled button keeps its dim look, and the focus is a yellow face with black text, distinct from a mark (a thick border
## on the white face). A new button cannot use another color.
func _white_buttons() -> void:
	print("white buttons")
	_check(UiTheme.BUTTON_FACE == UiTheme.TEXT and UiTheme.BUTTON_FACE == Color("fcfcfc"),
			"the button face token is the white token")
	_check(UiTheme.contrast(UiTheme.BUTTON_TEXT, UiTheme.BUTTON_FACE) >= 4.5, "the text on a white button has 4.5:1 or more")
	_check(UiTheme.contrast(UiTheme.BUTTON_EDGE, UiTheme.BUTTON_FACE) >= 1.5, "the lower edge of A and B shows on the white face")
	_check(UiTheme.contrast(UiTheme.ACCENT, UiTheme.BG) >= 4.5 and UiTheme.MARK_W == 2 * UiTheme.LINE,
			"the yellow mark is 4.5:1 on the black screen and twice as thick as a normal line")
	var buttons: Array[Button] = [UiKit.box_button("x", func(): pass), UiKit.box_button("x", func(): pass, 40, true),
			GearButton.new()]
	for b in buttons:
		b.size = Vector2(300, 84)
	buttons[2]._ready()   # The OPTIONS button sets its look in `_ready()`.
	var names := ["a box button", "a marked box button", "OPTIONS"]
	for i in buttons.size():
		var b := buttons[i]
		var rest: StyleBoxFlat = b.get_theme_stylebox("normal")
		_check(rest.bg_color == UiTheme.BUTTON_FACE, "%s: an enabled button has the white face" % names[i])
		_check(b.get_theme_color("font_color") == UiTheme.BUTTON_TEXT, "%s: its text is black" % names[i])
		_check(b.get_theme_stylebox("hover").bg_color == UiTheme.BUTTON_FACE, "%s: hovered, it is still white" % names[i])
		var focus: StyleBoxFlat = b.get_theme_stylebox("focus")
		_check(focus.bg_color == UiTheme.ACCENT and focus.border_color == UiTheme.ACCENT
				and focus.border_width_left == UiTheme.MARK_W
				and UiTheme.contrast(b.get_theme_color("font_focus_color"), focus.bg_color) >= 4.5,
				"%s: the focus is a yellow face with a thick yellow border and readable black text" % names[i])
		var margins := {}
		for st in ["normal", "hover", "focus", "pressed", "disabled"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(st)
			margins[[sb.content_margin_left, sb.content_margin_top, sb.content_margin_right, sb.content_margin_bottom]] = true
		_check(margins.size() == 1, "%s: all five states have the same content margins, so a focus never moves the layout" % names[i])
		# Issue #221: the disabled color belongs to the disabled state only.
		var uses_disabled := false
		for st in ["normal", "hover", "focus", "pressed"]:
			var sb2: StyleBoxFlat = b.get_theme_stylebox(st)
			uses_disabled = uses_disabled or sb2.bg_color == UiTheme.DISABLED or sb2.border_color == UiTheme.DISABLED \
					or b.get_theme_color("font_%s_color" % st if st != "normal" else "font_color") == UiTheme.DISABLED
		_check(not uses_disabled, "%s: no enabled state (normal, hover, focus, pressed) uses the disabled color" % names[i])
		var off: StyleBoxFlat = b.get_theme_stylebox("disabled")
		_check(off.bg_color == UiTheme.BG and off.border_color == UiTheme.TEXT_DIM
				and b.get_theme_color("font_disabled_color") == UiTheme.DISABLED, "%s: disabled keeps the dim look" % names[i])
		var down: StyleBoxFlat = b.get_theme_stylebox("pressed")
		_check(down.bg_color == UiTheme.BG and b.get_theme_color("font_pressed_color") == UiTheme.TEXT,
				"%s: pressed is the reverse, a black face with white text" % names[i])
	_check((buttons[1].get_theme_stylebox("normal") as StyleBoxFlat).border_color == UiTheme.ACCENT
			and (buttons[0].get_theme_stylebox("normal") as StyleBoxFlat).border_color == UiTheme.BUTTON_FACE,
			"a marked button has the thick yellow border and the face stays white; an unmarked one has a white edge")
	for b in buttons:
		b.free()
	# The players badge needs the autoloads (it reads the server), so its source is checked: it takes the same look.
	var badge_src := FileAccess.get_file_as_string("res://scripts/ui/players_badge.gd")
	_check(badge_src.contains("UiTheme.style_button(self)") and badge_src.contains("content_margin_left = UiTheme.LINE + 20.0"),
			"the players badge takes the white button look and keeps the room for its slot squares")
	# The text menus (REQ-FL-41) have no face: an enabled item is white text (also the quiet one), the focus is yellow or red.
	var theme := UiTheme.make()
	var menu_white := true
	for type in ["Button", "DangerButton", "QuietButton"]:
		menu_white = menu_white and theme.get_color("font_color", type) == UiTheme.TEXT
	_check(menu_white, "every enabled menu item type is white at rest")
	# No script may give a button a look of its own: the styleboxes of a button come from UiTheme.button_box. The menu item
	# and the game tile are not boxed buttons (a text with a cursor, a picture with a frame).
	var allowed := ["ui_theme.gd", "menu_item.gd", "game_tile.gd", "players_badge.gd"]   # The badge is checked above.
	var offenders: Array[String] = []
	for f in DirAccess.get_files_at("res://scripts/ui"):
		if f.ends_with(".gd") and not allowed.has(f):
			var src := FileAccess.get_file_as_string("res://scripts/ui/" + f)
			if src.contains('add_theme_stylebox_override("normal"') or src.contains("box_button(") and _has_color_arg(src):
				offenders.append(f)
	_check(offenders.is_empty(), "no screen styles a button by itself or gives box_button a color (%s)" % str(offenders))


## True when a call of `box_button(` in `src` passes a UiTheme color name as an argument. The call is read up to its closing
## parenthesis, over several lines.
func _has_color_arg(src: String) -> bool:
	var re := RegEx.create_from_string("UiTheme\\.(OK|BAD|DANGER|TEXT_DIM|ACCENT|TEXT)\\b")
	var from := src.find("box_button(")
	while from >= 0:
		var i := from + "box_button(".length()
		var depth := 1
		while i < src.length() and depth > 0:
			depth += 1 if src[i] == "(" else (-1 if src[i] == ")" else 0)
			i += 1
		if re.search(src.substr(from, i - from)) != null:
			return true
		from = src.find("box_button(", i)
	return false


## The text of one `[preset.N.options]` block of export_presets.cfg as {key: value (raw text)}, by the name of its preset.
func _preset_options(preset_name: String) -> Dictionary:
	var lines := FileAccess.get_file_as_string("res://export_presets.cfg").split("\n")
	var index := ""
	for i in lines.size():
		if lines[i] == 'name="%s"' % preset_name:
			for j in range(i, -1, -1):
				if lines[j].begins_with("[preset."):
					index = lines[j].trim_prefix("[preset.").trim_suffix("]")
					break
			break
	var out := {}
	if index == "":
		return out
	var inside := false
	for line in lines:
		if line == "[preset.%s.options]" % index:
			inside = true
		elif line.begins_with("["):
			inside = false
		elif inside and line.contains("="):
			var eq := line.find("=")
			out[line.substr(0, eq)] = line.substr(eq + 1)
	return out


## The top-level keys of one `[preset.N]` block (name, export_path, include_filter, ...) as {key: value (raw text)}.
func _preset_top(preset_name: String) -> Dictionary:
	var out := {}
	var lines := FileAccess.get_file_as_string("res://export_presets.cfg").split("\n")
	var start := -1
	for i in lines.size():
		if lines[i] == 'name="%s"' % preset_name:
			start = i
			break
	if start < 0:
		return out
	var first := start
	while first > 0 and not lines[first].begins_with("[preset."):
		first -= 1
	for i in range(first + 1, lines.size()):
		if lines[i].begins_with("["):
			break
		if lines[i].contains("="):
			var eq := lines[i].find("=")
			out[lines[i].substr(0, eq)] = lines[i].substr(eq + 1)
	return out


## The Android App Bundle presets for the stores (issue #289): AAB format, same app as the APK twin, no secrets.
func _release_presets() -> void:
	print("release presets (AAB)")
	var pairs := [["tv", "tv-release", "build/sababi-tv.aab"],
			["controller", "controller-release", "build/sababi-controller.aab"]]
	for pair in pairs:
		var dbg_top := _preset_top(pair[0])
		var rel_top := _preset_top(pair[1])
		var dbg := _preset_options(pair[0])
		var rel := _preset_options(pair[1])
		_check(not rel.is_empty() and rel.get("gradle_build/export_format", "") == "1",
				"%s exports an Android App Bundle (export_format=1)" % pair[1])
		_check(dbg.get("gradle_build/export_format", "") == "0", "%s still exports an APK for testing" % pair[0])
		_check(rel_top.get("export_path", "") == '"%s"' % pair[2], "%s writes %s" % [pair[1], pair[2]])
		_check(rel_top.get("platform", "") == '"Android"' and rel_top.get("runnable", "") == "false",
				"%s is an Android preset that is not run on a device" % pair[1])
		_check(rel.get("package/signed", "") == "true", "%s signs the bundle" % pair[1])
		for key in ["include_filter", "exclude_filter", "export_filter", "custom_features"]:
			_check(rel_top.has(key) and rel_top.get(key) == dbg_top.get(key), "%s has the %s of %s" % [pair[1], key, pair[0]])
		for key in ["package/unique_name", "package/name", "version/code", "version/name", "gradle_build/gradle_build_directory",
				"architectures/arm64-v8a", "architectures/armeabi-v7a", "package/show_in_android_tv"]:
			_check(rel.has(key) and rel.get(key) == dbg.get(key), "%s has the %s of %s" % [pair[1], key, pair[0]])
		for key in ["keystore/release", "keystore/release_user", "keystore/release_password", "keystore/debug",
				"keystore/debug_user", "keystore/debug_password"]:
			_check(rel.get(key, '""') == '""', "%s has no value in %s (the keystore comes from the environment)" % [pair[1], key])
	# No secret anywhere in the file: every key that names a keystore, a password or a key is empty.
	var leaks := 0
	for line in FileAccess.get_file_as_string("res://export_presets.cfg").split("\n"):
		var lower := line.to_lower()
		if line.contains("=") and (lower.begins_with("keystore/") or lower.contains("password") or lower.contains("keystore")):
			if line.substr(line.find("=") + 1) not in ['""', ""]:
				leaks += 1
	_check(leaks == 0, "export_presets.cfg holds no keystore path, user or password (%d found)" % leaks)
	_check(not FileAccess.get_file_as_string("res://export_presets.cfg").contains(".keystore")
			and not FileAccess.get_file_as_string("res://export_presets.cfg").contains(".jks"),
			"export_presets.cfg names no keystore file")


## Names, launcher, orientation and the iPhone keys (docs/MANUAL_TESTS.md tests 1, 2, 8, 13: the part a machine can read).
func _app_identity() -> void:
	print("app identity")
	var tv := _preset_options("tv")
	var phone := _preset_options("controller")
	var ios := _preset_options("controller-ios")
	_check(tv.get("package/name", "") == '"Sababi: TV Games"', "the TV app is called 'Sababi: TV Games'")
	_check(phone.get("package/name", "") == '"Sababi: Remote"', "the Android phone app is called 'Sababi: Remote'")
	_check(tv.get("package/show_in_android_tv", "") == "true", "the TV preset shows the app in the Android TV launcher")
	_check(tv.get("launcher_icons/main_192x192", "") == '"res://assets/icons/icon_192.png"'
			and tv.get("launcher_icons/adaptive_foreground_432x432", "") == '"res://assets/icons/adaptive_foreground_432.png"'
			and tv.get("launcher_icons/adaptive_background_432x432", "") == '"res://assets/icons/adaptive_background_432.png"',
			"the TV preset names the 192 icon and the two 432 adaptive icon layers")
	var patch := FileAccess.get_file_as_string("res://tools/patch_android_manifest.sh")
	_check(patch.contains("assets/icons/banner.png") and patch.contains('android:banner="@drawable/banner"')
			and patch.contains("LEANBACK_LAUNCHER") and patch.contains("android.software.leanback"),
			"the manifest patch gives the TV build a banner and the leanback launcher (REQ-FL-30)")
	_check(ProjectSettings.get_setting("display/window/handheld/orientation.controller", -1) == 1,
			"the phone app starts in portrait (orientation.controller = 1)")
	_check(ios.get("application/bundle_identifier", "") != "" and ios.get("application/targeted_device_family", "") == "0",
			"the iOS preset is for iPhone and iPad and has a bundle id")
	_check(String(ios.get("application/additional_plist_content",
			"")).contains("<key>NSLocalNetworkUsageDescription</key><string>Sababi uses the room code to find your TV"),
			"the iOS preset has the Local Network usage text (NSLocalNetworkUsageDescription)")
	_check(String(ios.get("privacy/camera_usage_description", "")) != "", "the iOS preset has the camera usage text")
	# REQ-FL-92 (issue #299): the camera question says what it is for and that the picture is not kept.
	var cam_en := String(ios.get("privacy/camera_usage_description", ""))
	_check(cam_en.contains("QR") and cam_en.contains("not saved or sent"),
			"the iOS camera text names the QR code and says the picture is not saved or sent")
	_check(String(ios.get("privacy/camera_usage_description_localized", "")).contains("\"he\"")
			and String(ios.get("privacy/camera_usage_description_localized", "")).contains("QR"),
			"the iOS preset has a Hebrew camera text (REQ-FL-92)")
	var main_scene := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(main_scene == "res://scenes/boot.tscn", "one start scene")
	var boot := FileAccess.get_file_as_string("res://scenes/boot.tscn") + FileAccess.get_file_as_string("res://scripts/app.gd")
	var app_src := FileAccess.get_file_as_string("res://scripts/app.gd")
	var ctrl := app_src.substr(app_src.find("func _start_controller"))
	var from := app_src.find("func _start_tv")
	var tv_start := app_src.substr(from, app_src.find("func toggle_overlay") - from)
	_check(main_scene == "res://scenes/boot.tscn" and tv_start.strip_edges().ends_with("go_logo()")
			and app_src.contains("func go_logo() -> void:\n\tgo(TvLogo)"),
			"REQ-FL-30: the one start scene boots the app and the TV app opens on the logo screen")
	_check(not ctrl.contains("go(TvLogo)") and ctrl.contains("go(ControllerConnect)")
			and ctrl.contains("screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)"),
			"the phone app starts straight on Connect, with no logo screen, and sets portrait in code too")
	_check(boot != "" and app_src.contains("DisplayServer.screen_set_keep_on(true)"),
			"the app keeps the screen on (no idle lock)")
	_check(ProjectSettings.get_setting("application/boot_splash/bg_color") == Color(0, 0, 0, 1)
			and ProjectSettings.get_setting("application/boot_splash/show_image") == true
			and ProjectSettings.get_setting("application/boot_splash/use_filter") == false
			and ProjectSettings.get_setting("application/boot_splash/image") == "res://assets/logo/splash.png",
			"one splash: black, the splash picture, sharp pixels (no filter)")


## The pictures: the splash and the icons have the sizes and the colors of the mascot, the logo has hard pixels.
func _images() -> void:
	print("pictures")
	var splash: Image = load("res://assets/logo/splash.png").get_image()
	var counts := _color_counts(splash)
	_check(counts.yellow > counts.other_color and counts.yellow > 200,
			"the splash has yellow as its main color on black (yellow %d, other %d)" % [counts.yellow, counts.other_color])
	var sizes := {"res://assets/icons/icon_192.png": Vector2i(192, 192),
			"res://assets/icons/adaptive_foreground_432.png": Vector2i(432, 432),
			"res://assets/icons/adaptive_background_432.png": Vector2i(432, 432),
			"res://assets/icons/banner.png": Vector2i(320, 180),
			"res://assets/icons/icon_1024.png": Vector2i(1024, 1024)}
	var wrong: Array[String] = []
	for path in sizes:
		var img: Image = load(path).get_image()
		if Vector2i(img.get_width(), img.get_height()) != sizes[path]:
			wrong.append("%s %dx%d" % [path.get_file(), img.get_width(), img.get_height()])
	_check(wrong.is_empty(), "the icons, the adaptive layers and the banner have their sizes (wrong: %s)" % str(wrong))
	var icon_counts := _color_counts((load("res://assets/icons/icon_192.png") as Texture2D).get_image())
	_check(icon_counts.yellow > icon_counts.other_color, "the 192 icon is mostly yellow")
	var banner_counts := _color_counts((load("res://assets/icons/banner.png") as Texture2D).get_image())
	_check(banner_counts.yellow > 100 and banner_counts.black > banner_counts.yellow * 0.2,
			"the banner has yellow on a dark ground")
	# The logo: only fully opaque or fully clear pixels, no blend (sharp pixels, REQ-FL-50).
	var logo: Image = load("res://assets/logo/logo.png").get_image()
	var partial := 0
	for y in logo.get_height():
		for x in logo.get_width():
			var a := logo.get_pixel(x, y).a
			if a > 0.02 and a < 0.98:
				partial += 1
	_check(partial == 0, "the logo has no half-clear pixel (%d found)" % partial)
	var logo_src := FileAccess.get_file_as_string("res://scripts/ui/tv_logo.gd")
	_check(logo_src.contains("texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST"), "the logo is drawn with the nearest filter")
	var imp := FileAccess.get_file_as_string("res://assets/logo/logo.png.import")
	_check(imp.contains("mipmaps/generate=false"), "the logo is imported without mipmaps")


## Counts of pixels: yellow (hue 40..65 degrees, saturated), black, and other colors.
func _color_counts(img: Image) -> Dictionary:
	var yellow := 0
	var black := 0
	var other := 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if c.v < 0.12:
				black += 1
			elif c.s > 0.5 and c.h * 360.0 >= 38.0 and c.h * 360.0 <= 65.0:
				yellow += 1
			else:
				other += 1
	return {"yellow": yellow, "black": black, "other_color": other}


## An exported build holds the picture of every game tile (the cause candidate of "missing screenshots" on the TV): export the
## pack of the TV preset with a second Godot process and read the names of the files in it.
func _export_pack() -> void:
	print("export pack")
	var out := ProjectSettings.globalize_path("user://design_tokens_tv.pck")
	if FileAccess.file_exists(out):
		DirAccess.remove_absolute(out)
	var log: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--export-pack", "tv", out], log, true)
	_check(code == 0 and FileAccess.file_exists(out), "the TV preset exports its pack headless (exit %d)" % code)
	if not FileAccess.file_exists(out):
		return
	var hex := FileAccess.get_file_as_bytes(out).hex_encode()
	var registry: GDScript = Registry
	var missing: Array[String] = []
	for g in registry.GAMES:
		var tile := String(g.tile)
		var base := tile.get_file()
		# The import file and the imported texture are in the pack: the picture loads in an exported build.
		if not hex.contains(tile.to_utf8_buffer().hex_encode()):
			missing.append(tile)
		elif not hex.contains((".godot/imported/" + base + "-").to_utf8_buffer().hex_encode()):
			missing.append(tile + " (not imported)")
	_check(missing.is_empty(), "every game tile picture is in the exported pack (missing: %s)" % str(missing))
	_check(hex.contains("assets/lang/strings.csv".to_utf8_buffer().hex_encode())
			and hex.contains("assets/logo/logo.png".to_utf8_buffer().hex_encode()), "the pack holds the table of texts and the logo")
	_check(not hex.contains("res://tests/".to_utf8_buffer().hex_encode()), "the pack holds no test file")
	DirAccess.remove_absolute(out)


## Issue #221: grey is for what is disabled. Info text that is active (hints, the player range, WAIT, empty slots) has its own
## lighter token, and no text of the TV or the phone is drawn with the disabled color.
func _info_text() -> void:
	print("info text and the disabled color")
	_check(UiTheme.DISABLED == UiTheme.TEXT_DIM and UiTheme.TEXT_INFO != UiTheme.TEXT_DIM,
			"the disabled color is TEXT_DIM and the info text has another token")
	var info := UiTheme.TEXT_INFO
	_check(info.r >= 0xb0 / 255.0 - 0.001 and info.g >= 0xb0 / 255.0 - 0.001 and info.b >= 0xb0 / 255.0 - 0.001,
			"the info text is #b0b0b0 or lighter")
	var c_info := UiTheme.contrast(info, UiTheme.BG)
	var c_dim := UiTheme.contrast(UiTheme.TEXT_DIM, UiTheme.BG)
	_check(c_info >= 7.0 and c_info > c_dim, "the info text has 7:1 or more on black (%.1f), more than the disabled color (%.1f)"
			% [c_info, c_dim])
	_check(UiTheme.contrast(info, UiTheme.BG) < UiTheme.contrast(UiTheme.TEXT, UiTheme.BG), "the info text is quieter than white")
	var re := RegEx.create_from_string("label\\(|draw_string|font_color|blinking\\(|draw_centered|Shell\\.(text|hint)")
	var offenders: Array[String] = []
	for dir in ["res://scripts/ui", "res://scripts/game"]:
		for f in _gd_files(dir):
			if f.ends_with("debug_overlay.gd") or f.ends_with("ui_theme.gd"):
				continue
			var n := 0
			for line in FileAccess.get_file_as_string(f).split("\n"):
				n += 1
				if line.contains("TEXT_DIM") and re.search(line) != null:
					offenders.append("%s:%d" % [f.trim_prefix("res://"), n])
	_check(offenders.is_empty(), "no text is drawn in the disabled color; use TEXT_INFO (%s)" % str(offenders))
	# The test itself: a text line with TEXT_DIM is found by the pattern.
	_check(re.search("UiKit.label(\"x\", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)") != null
			and re.search("draw_style_box(UiTheme.line_box(UiTheme.TEXT_DIM))") == null, "the pattern finds a text, not a frame")


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + "/" + d))
	return out
## REQ-GM-6a (issue #231): docs/GAME_REQUIREMENTS.md has one table of game ids and names. Every registry id has a row, the name in
## the row is the English text of the title key, and the table has no row of a game that is not in the registry.
func _game_names() -> void:
	print("game ids and names")
	var rows := {}
	for line in FileAccess.get_file_as_string("res://docs/GAME_REQUIREMENTS.md").split("\n"):
		var cells := line.strip_edges().trim_prefix("|").split("|")
		if cells.size() >= 3 and cells[0].strip_edges().begins_with("`"):
			var id: String = cells[0].strip_edges().trim_prefix("`").trim_suffix("`")
			rows[id] = {"name": cells[1].strip_edges(), "doc": cells[2].strip_edges()}
	var ids: Array[String] = []
	var missing: Array[String] = []
	var wrong: Array[String] = []
	for g in Registry.GAMES:
		var id := String(g.id)
		ids.append(id)
		if not rows.has(id):
			missing.append(id)
			continue
		var english := String(Lang.table()[String(g.title)].en)
		if rows[id].name != english:
			wrong.append("%s: '%s' is '%s' in the app" % [id, rows[id].name, english])
		if rows[id].doc != "`%s`" % String(g.doc).trim_prefix("res://"):
			wrong.append("%s: file %s" % [id, rows[id].doc])
	var extra: Array[String] = []
	for id in rows:
		if not ids.has(id):
			extra.append(id)
	_check(not ids.is_empty() and missing.is_empty(),
			"every registry id has a row in the id-to-name table (missing: %s)" % str(missing))
	_check(wrong.is_empty(),
			"each row has the English name of the title key and the doc of the registry (wrong: %s)" % str(wrong))
	_check(extra.is_empty(), "the table has no row of a game that is not in the registry (extra: %s)" % str(extra))


## Issue #302: a size typed in a screen or a game is a multiple of 8 too (the font is crisp only on the 8 px grid, REQ-FL-40).
## It looks at the literals of `draw_string(...)`, `box_button(text, cb, N)`, the font size overrides and the `*_FONT := N`
## constants.
func _typed_sizes() -> void:
	print("typed font sizes")
	var rx := RegEx.new()
	rx.compile("(?:HORIZONTAL_ALIGNMENT_[A-Z]+, *-?[0-9.]+, *([0-9]+),|box_button\\([^\\n]*, *([0-9]+)\\)"
			+ "|\"font_size\", *([0-9]+)\\)|\\b[A-Z_]*FONT[A-Z_]* *:?= *([0-9]+))")
	var bad: Array[String] = []
	var seen := 0
	var dirs: Array[String] = ["res://scripts"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd") or f == "debug_overlay.gd":   # The debug overlay is a developer tool, not a screen.
				continue
			var lines := FileAccess.get_file_as_string(d + "/" + f).split("\n")
			for i in lines.size():
				for m in rx.search_all(lines[i]):
					for g in range(1, 5):
						if m.get_string(g) != "":
							seen += 1
							if int(m.get_string(g)) % 8 != 0:
								bad.append("%s/%s:%d size %s" % [d, f, i + 1, m.get_string(g)])
	_check(seen >= 8, "the scan found the typed sizes (%d)" % seen)
	_check(bad.is_empty(), "every typed font size is a multiple of 8 (off the grid: %s)" % str(bad))


## REQ-FL-70: the player objects of a game have neither a number nor an avatar. The avatar is drawn by the HUD chip (shell.gd) and
## by the result rows (minigame.gd) only: no other script of a game uses the avatar sheet.
func _no_avatar_on_objects() -> void:
	print("no avatar on a game object")
	var users: Array[String] = []
	for f in _gd_files("res://scripts/game"):
		var src := FileAccess.get_file_as_string(f)
		if (src.contains("avatar.gd") or src.contains("avatar_view.gd") or src.contains("Avatar.draw")) \
				and not f.ends_with("/shell.gd") and not f.ends_with("/minigame.gd"):
			users.append(f)
	_check(users.is_empty(), "REQ-FL-70: only the HUD chip and the result rows use an avatar (others: %s)" % str(users))


## REQ-FL-45: the background is plain black and the confetti of the logo is drawn in code: the particles carry a texture that is
## made at run time (no resource path), and there is no image file for them in assets/.
func _confetti_in_code() -> void:
	print("confetti in code")
	var Confetti = load("res://scripts/ui/confetti.gd")
	var c: CPUParticles2D = Confetti.new()
	c._ready()
	var tex: Texture2D = c.texture
	_check(tex != null and tex.resource_path == "" and tex.get_size() == Vector2(Confetti.PIXEL, Confetti.PIXEL),
			"REQ-FL-45: the confetti piece is a square made in code (no file)")
	_check(c.color_initial_ramp != null and c.color_initial_ramp.colors == PackedColorArray(UiTheme.CONFETTI),
			"REQ-FL-45: and the pieces take the colors of the palette")
	c.free()
	var pictures: Array[String] = []
	for f in _files("res://assets"):
		if f.get_file().to_lower().contains("confetti"):
			pictures.append(f)
	_check(pictures.is_empty(), "REQ-FL-45: no image of confetti in assets/ (%s)" % str(pictures))
	var back := load("res://scripts/ui/backdrop.gd")
	_check(back.get_script_constant_map().has("UiTheme") and UiTheme.BG == Color.BLACK
			and not FileAccess.get_file_as_string("res://scripts/ui/backdrop.gd").contains("texture"),
			"REQ-FL-45: the backdrop is drawn in code in plain black, with no texture")


func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + "/" + d))
	return out
