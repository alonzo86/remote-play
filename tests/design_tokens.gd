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
