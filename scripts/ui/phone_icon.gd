extends Control
## The pixel icons of the top buttons of the phone and of the TV: ABOUT (an "i" in a circle), SETTINGS (a gear),
## DISCONNECT (a door with an arrow that goes out) and QUIT (a power sign). A button shows the icon and no word, so it needs
## no Hebrew text and is small; the name and the tooltip say the word for a screen reader (keys `common.about`,
## `common.settings`, `pad.disconnect`, `connect.quit`). The cells are white, as the text of every enabled button
## (REQ-FL-38a). Rows run from the top. In a right to left layout the DISCONNECT arrow is mirrored.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Lang = preload("res://scripts/core/lang.gd")

const ABOUT := "about"
const SETTINGS := "settings"
const DISCONNECT := "disconnect"
const QUIT := "quit"
const BUTTON_SIZE := 96.0   # A button is a square of this size (px of the 1080 wide phone layout).

const ROWS := {
	ABOUT: [
		"...wwww...",
		"..w....w..",
		".w..ww..w.",
		"w........w",
		"w...ww...w",
		"w...ww...w",
		".w..ww..w.",
		"..w....w..",
		"...wwww...",
	],
	SETTINGS: [
		".....w.....",
		".w..www..w.",
		".wwwwwwwww.",
		"..www.www..",
		"..ww...ww..",
		"wwww...wwww",
		"..ww...ww..",
		"..www.www..",
		".wwwwwwwww.",
		".w..www..w.",
		".....w.....",
	],
	QUIT: [
		"....w....",
		"..w.w.w..",
		".w..w..w.",
		".w..w..w.",
		"w.......w",
		"w.......w",
		".w.....w.",
		"..w...w..",
		"...www...",
	],
	DISCONNECT: [
		"wwwwww.....",
		"w....w..w..",
		"w....w..ww.",
		"w..wwwwwwww",
		"w..wwwwwwww",
		"w....w..ww.",
		"w....w..w..",
		"wwwwww.....",
	],
}
## The key of the word of each icon (the name for a screen reader).
const WORDS := {ABOUT: "common.about", SETTINGS: "common.settings", DISCONNECT: "pad.disconnect", QUIT: "connect.quit"}

var kind := ABOUT


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_LAYOUT_DIRECTION_CHANGED:
		queue_redraw()


## The cells of an icon as {x, y, color}, mirrored left to right when `mirrored`. A test reads it, and `_draw()` paints it.
static func cells(icon: String, mirrored := false) -> Array:
	var out: Array = []
	var rows: Array = ROWS[icon]
	for y in rows.size():
		var cols := String(rows[y]).length()
		for x in cols:
			if String(rows[y])[x] == "w":
				out.append({"x": cols - 1 - x if mirrored else x, "y": y, "color": UiTheme.BUTTON_TEXT})
	return out


func _draw() -> void:
	var rows: Array = ROWS[kind]
	var cols := String(rows[0]).length()
	var cell := floorf(minf(size.x / float(cols), size.y / float(rows.size())))
	var origin := (size - Vector2(cols, rows.size()) * cell) / 2.0
	for c in cells(kind, kind == DISCONNECT and is_layout_rtl()):
		draw_rect(Rect2(origin + Vector2(c.x, c.y) * cell, Vector2(cell, cell)), c.color)


## A square button with the icon `icon` and no text. `node_name` is the name of the node (a test finds the button by it).
## `word` is the key of the name for a screen reader (default: the word of the icon). On the TV it has the focus, like any button.
static func button(icon: String, node_name: String, cb: Callable, word := "") -> Button:
	var key: String = word if word != "" else String(WORDS[icon])
	var b := UiKit.box_button("", cb, UiTheme.SIZE_ITEM)
	b.name = node_name
	b.accessibility_name = Lang.t(key)
	b.tooltip_text = Lang.t(key)
	b.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	var node: Control = load("res://scripts/ui/phone_icon.gd").new()
	node.set("kind", icon)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	b.add_child(node)
	return b
