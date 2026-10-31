extends Control
## The About screen of the TV and of the phone (FD-25). A list of pages (what Sababi does with data, the Godot notice, 3rd Party
## Libraries) and one page of text at a time. "3rd Party Libraries" is a second list: a row for each library with its name and the
## type of its license, and a tap opens the copyright lines and the license text. The licenses must travel with the app (MIT,
## OFL and others), so they are shown here. Back goes up one step, and from the main list to `back_screen`.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const About = preload("res://scripts/core/about.gd")
const Lang = preload("res://scripts/core/lang.gd")

const TEXT_SIZE := 32          # The text of a page on the TV (REQ-FL-40: TV text is 32 px or more).
const PHONE_TEXT_SIZE := 24   # On a phone screen of about 1080 px width (REQ-FL-40: 24 px or more).
const SCROLL_STEP := 240
const CHUNK_LINES := 40

var back_screen: GDScript   # The screen that opened this one. App sets it when it switches here.
var scanner_note := false   # The Android phone adds the note about the Google code scanner.
var open_page := -1         # The index of the page on screen (in `_current`), or -1 for a list.
var in_libraries := false   # The list on screen (or the page behind it) is the list of 3rd party libraries.

var _pages: Array = []
var _libs: Array = []
var _current: Array = []    # The pages of the list that is open: `_pages`, or `_libs`.
var _box: VBoxContainer
var _scroll: ScrollContainer
var _first: Control


func _ready() -> void:
	_pages = About.pages(scanner_note)
	_libs = About.libraries(OS.get_name() == "Android")
	var m := UiKit.margin(self, 60, 60, 60, 60)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 20)
	m.add_child(_box)
	_show_list()


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_first = null


func _show_list() -> void:
	_clear()
	open_page = -1
	in_libraries = false
	_current = _pages
	_list_screen("common.about", func(idx: int) -> void:
		if String(_pages[idx].kind) == "libraries":
			_show_libraries()
		else:
			show_page(idx), false)


## The second list: a row for each library, "name  (license types)".
func _show_libraries() -> void:
	_clear()
	open_page = -1
	in_libraries = true
	_current = _libs
	_list_screen("about.third_party_libraries", show_page, true)


## A title, a scrolling list of buttons (one for each page of `_current`) and Back.
func _list_screen(title: String, on_pick: Callable, with_license: bool) -> void:
	var head := UiKit.title(title, 56)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # A long title breaks into lines and stays inside the 60 px edge.
	_box.add_child(head)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_box.add_child(_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	for i in _current.size():
		var idx := i
		var label := String(_current[i].title)
		if with_license:
			label = "%s  (%s)" % [About.title_text(_current[i]), About.safe(String(_current[i].license))]
		else:
			label = Lang.t(label)
		var b := _button(label, func(): on_pick.call(idx), with_license)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # These are names and license names.
		list.add_child(b)
		if _first == null:
			_first = b
	_box.add_child(_button("common.back", on_back, false, "quiet"))
	UiKit.focus_later(_first)


func show_page(i: int) -> void:
	_clear()
	open_page = i
	var page: Dictionary = _current[i]
	var t := UiKit.title(About.title_text(page), 40)
	t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	_box.add_child(t)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(_scroll)
	var body := VBoxContainer.new()   # Labels of CHUNK_LINES lines: a long text is shaped in parts, not in one piece.
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	for chunk in chunks(About.text(page)):
		body.add_child(_text_label(chunk))
	var back := _button("common.back", on_back, false, "quiet")
	_box.add_child(back)
	UiKit.focus_later(back)


## A label for a part of a text. Not UiKit.label: a license is shown as it is written, in lower case too.
func _text_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.text_direction = Control.TEXT_DIRECTION_LTR
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var size := text_size()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("line_spacing", size / 4)
	return l


## The size of the text of a page: 32 px on the TV, 24 px on the phone (REQ-FL-40).
static func text_size() -> int:
	return PHONE_TEXT_SIZE if Role.is_controller() else TEXT_SIZE


## The text in parts of at most CHUNK_LINES lines (the lines of the source text, before the wrap).
static func chunks(text: String) -> Array:
	var lines := text.split("\n")
	var out: Array = []
	for i in range(0, lines.size(), CHUNK_LINES):
		out.append("\n".join(lines.slice(i, i + CHUNK_LINES)))
	return out


## A TV button has the cursor and takes the remote; a phone button is a box. A `wrapped` row (a library) is a box on both
## and breaks a long name into lines.
func _button(text: String, cb: Callable, wrapped := false, role := "") -> Button:
	if wrapped:
		var w := UiKit.box_button(text, cb, UiTheme.SIZE_ITEM)
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.alignment = HORIZONTAL_ALIGNMENT_LEFT
		w.custom_minimum_size = Vector2(0, 84)
		return w
	if Role.is_controller():
		var b := UiKit.box_button(text, cb, UiTheme.SIZE_ITEM)
		b.custom_minimum_size = Vector2(0, 110)
		return b
	return UiKit.item(text, cb, UiTheme.SIZE_ITEM, role)


## Up and Down of the remote scroll a page of text.
func _unhandled_input(event: InputEvent) -> void:
	if open_page < 0 or _scroll == null:
		return
	if event.is_action_pressed("ui_down"):
		_scroll.scroll_vertical += SCROLL_STEP
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_scroll.scroll_vertical = maxi(_scroll.scroll_vertical - SCROLL_STEP, 0)
		get_viewport().set_input_as_handled()


func on_back() -> void:
	if open_page >= 0:
		if in_libraries:
			_show_libraries()
		else:
			_show_list()
	elif in_libraries:
		_show_list()
	elif back_screen != null:
		App.go(back_screen)
	else:
		App.go_games()
