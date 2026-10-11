extends Control
## The About screen of the TV and of the phone (FD-23). A list of pages (what Wobble does with data, the Godot notice, the font
## licenses, the parts of Godot) and one page of text at a time. The licenses must travel with the app (MIT, OFL), so they are
## shown here. Back goes to the list, and from the list to `back_screen`.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const About = preload("res://scripts/core/about.gd")

const TEXT_SIZE := 24
const SCROLL_STEP := 240

var back_screen: GDScript   # The screen that opened this one. App sets it when it switches here.
var scanner_note := false   # The Android phone adds the note about the Google code scanner.
var open_page := -1         # The index of the page on screen, or -1 for the list.

var _pages: Array = []
var _box: VBoxContainer
var _scroll: ScrollContainer
var _first: Control


func _ready() -> void:
	_pages = About.pages(scanner_note)
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
	_box.add_child(UiKit.title("About", 56))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_box.add_child(_scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(list)
	for i in _pages.size():
		var idx := i
		var b := _button(String(_pages[i].title), func(): show_page(idx))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # These are names and license names.
		list.add_child(b)
		if _first == null:
			_first = b
	_box.add_child(_button("Back", on_back))
	UiKit.focus_later(_first)


func show_page(i: int) -> void:
	_clear()
	open_page = i
	var page: Dictionary = _pages[i]
	var t := UiKit.title(String(page.title), 40)
	t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	_box.add_child(t)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(_scroll)
	var body := Label.new()   # Not UiKit.label: a license is shown as it is written, in lower case too.
	body.text = About.text(page)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.text_direction = Control.TEXT_DIRECTION_LTR
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", TEXT_SIZE)
	body.add_theme_constant_override("line_spacing", TEXT_SIZE / 4)
	_scroll.add_child(body)
	var back := _button("Back", on_back)
	_box.add_child(back)
	UiKit.focus_later(back)


## A TV button has the cursor and takes the remote; a phone button is a box.
func _button(text: String, cb: Callable) -> Button:
	if Role.is_controller():
		var b := UiKit.box_button(text, cb, UiTheme.SIZE_ITEM)
		b.custom_minimum_size = Vector2(0, 110)
		return b
	return UiKit.item(text, cb, UiTheme.SIZE_ITEM)


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
		_show_list()
	elif back_screen != null:
		App.go(back_screen)
	else:
		App.go_games()
