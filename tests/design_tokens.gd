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
			"card": UiTheme.CARD, "card-text": UiTheme.CARD_TEXT, "card-dim": UiTheme.CARD_DIM, "room": UiTheme.ROOM,
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
