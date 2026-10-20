extends SceneTree
## docs/design-system/tokens.json must follow UiTheme and Protocol (the code is the source of truth).
## Run by tests/run_all.sh

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const Protocol = preload("res://scripts/core/protocol.gd")

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
	_run()
	_avatar_sheet()
	_font_licences()
	_app_identity()
	_images()
	_export_pack()
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
	var named := {"bg": UiTheme.BG, "text": UiTheme.TEXT, "text-dim": UiTheme.TEXT_DIM, "accent": UiTheme.ACCENT,
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
	_check(icon.contains(String(by_name["brand-dark"]).substr(0, 6)) and icon.contains(String(by_name["brand-yellow"]).substr(0, 6)),
			"the brand tokens are the colors in icon.svg")
	var theme: Theme = UiTheme.make()
	var sizes := {}
	for g in data.type.groups:
		for st in g.styles:
			sizes[st.name] = String(st.fontSize)
	_check(sizes.get("body", "") == "%dpx" % theme.default_font_size, "body size token matches the theme default")
	_check(sizes.get("button", "") == "%dpx" % theme.get_font_size("font_size", "Button"), "button size token matches the theme")
	_check(sizes.get("title", "") == "%dpx" % UiTheme.SIZE_TITLE and sizes.get("logo", "") == "%dpx" % UiTheme.SIZE_LOGO
			and sizes.get("countdown", "") == "%dpx" % UiTheme.SIZE_COUNTDOWN, "title, logo and countdown size tokens match the theme")
	var on_grid := true
	for size_name in sizes:
		on_grid = on_grid and int(String(sizes[size_name]).trim_suffix("px")) % 8 == 0
	_check(on_grid, "every type size is a multiple of 8, the grid of the font (REQ-FL-40)")
	var box: StyleBoxFlat = UiTheme.card()
	_check(_family(data, "spacing", "space-32") == "%dpx" % box.content_margin_left
			and _family(data, "spacing", "space-14") == "%dpx" % box.content_margin_top, "card padding tokens match UiTheme.card()")


## The text colors are readable on black, and the text on a player color is readable (REQ-GM-46, REQ-FL-40).
func _contrast_checks() -> void:
	print("contrast")
	var palette := {"TEXT": UiTheme.TEXT, "TEXT_DIM": UiTheme.TEXT_DIM, "ACCENT": UiTheme.ACCENT, "OK": UiTheme.OK,
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
			"the manifest patch gives the TV build a banner and the leanback launcher")
	_check(ProjectSettings.get_setting("display/window/handheld/orientation.controller", -1) == 1,
			"the phone app starts in portrait (orientation.controller = 1)")
	_check(ios.get("application/bundle_identifier", "") != "" and ios.get("application/targeted_device_family", "") == "0",
			"the iOS preset is for iPhone and iPad and has a bundle id")
	_check(String(ios.get("application/additional_plist_content", "")).contains("<key>NSLocalNetworkUsageDescription</key><string>Sababi"),
			"the iOS preset has the Local Network usage text (NSLocalNetworkUsageDescription)")
	_check(String(ios.get("privacy/camera_usage_description", "")) != "", "the iOS preset has the camera usage text")
	var main_scene := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(main_scene == "res://scenes/boot.tscn", "one start scene")
	var boot := FileAccess.get_file_as_string("res://scenes/boot.tscn") + FileAccess.get_file_as_string("res://scripts/app.gd")
	var app_src := FileAccess.get_file_as_string("res://scripts/app.gd")
	var ctrl := app_src.substr(app_src.find("func _start_controller"))
	_check(not ctrl.contains("go(TvLogo)") and ctrl.contains("go(ControllerConnect)")
			and ctrl.contains("screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)"),
			"the phone app starts straight on Connect, with no logo screen, and sets portrait in code too")
	_check(boot != "" and app_src.contains("DisplayServer.screen_set_keep_on(true)"), "the app keeps the screen on (no idle lock)")
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
	_check(counts.yellow > counts.other_color and counts.yellow > 200, "the splash has yellow as its main color on black (yellow %d, other %d)" % [counts.yellow, counts.other_color])
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
	_check(banner_counts.yellow > 100 and banner_counts.black > banner_counts.yellow * 0.2, "the banner has yellow on a dark ground")
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
	var registry: GDScript = load("res://scripts/game/registry.gd")
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
