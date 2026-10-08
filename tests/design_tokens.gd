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
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _family(data: Dictionary, family: String, name: String) -> String:
	for t in data[family].tokens:
		if t.name == name:
			return String(t.value)
	return ""


func _run() -> void:
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
	wanted.append_array([UiTheme.ACCENT.lightened(0.35), UiTheme.DISABLED.darkened(0.35),
			UiTheme.TEXT_DIM.darkened(0.2), Color(UiTheme.TEXT_DIM, 0.55), Color(UiTheme.OUTLINE, 0.72),
			Color(UiTheme.CARD, 0.5)])
	# Each named token holds the value of its UiTheme constant (a swap of two values is caught).
	var named := {"bg": UiTheme.BG, "bg-dark": UiTheme.BG_DARK, "panel-light": UiTheme.PANEL_LIGHT,
			"button": UiTheme.BUTTON, "disabled": UiTheme.DISABLED, "outline": UiTheme.OUTLINE, "text": UiTheme.TEXT,
			"text-dim": UiTheme.TEXT_DIM, "accent": UiTheme.ACCENT, "ok": UiTheme.OK, "bad": UiTheme.BAD,
			"card": UiTheme.CARD, "card-ready": UiTheme.CARD_READY, "slot-empty": UiTheme.SLOT_EMPTY,
			"badge-empty": UiTheme.BADGE_EMPTY, "card-text": UiTheme.CARD_TEXT, "card-dim": UiTheme.CARD_DIM, "room": UiTheme.ROOM,
			"shadow-ink": UiTheme.SHADOW_COLOR, "confetti-pink": UiTheme.CONFETTI[0],
			"confetti-cyan": UiTheme.CONFETTI[1], "player-1": Protocol.PLAYER_COLORS[0],
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
	_check(_family(data, "border", "outline-w") == "%dpx" % UiTheme.OUTLINE_W, "outline width token matches UiTheme")
	_check(_family(data, "radius", "radius-lg") == "%dpx" % UiTheme.RADIUS, "card radius token matches UiTheme")
	_check(_family(data, "shadow", "shadow-hard").begins_with("%dpx %dpx" % [UiTheme.SHADOW.x, UiTheme.SHADOW.y]),
			"shadow offset token matches UiTheme")

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
	var box: StyleBoxFlat = UiTheme.card()
	_check(_family(data, "spacing", "space-32") == "%dpx" % box.content_margin_left
			and _family(data, "spacing", "space-14") == "%dpx" % box.content_margin_top, "card padding tokens match UiTheme.card()")
