extends Control
## Phone screen to make or change a profile (FD-22, REQ-FL-72): the name (at most 10 letters), the avatar from the sheet, SAVE and
## DELETE. `profile_id` is set before the screen enters the tree: empty makes a new profile.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Lang = preload("res://scripts/core/lang.gd")
const Profile = preload("res://scripts/core/profile.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")

const DELETE_ARM_SECONDS := 3.0
const AVATAR_SIDE := 144.0
const AVATAR_STEP := AVATAR_SIDE + 12.0   # One avatar and the gap after it.

var profile_id := ""
var from_list := false   # Opened from the list "WHO IS PLAYING?": Back goes there. Otherwise Back goes to the main screen.

var _name: LineEdit
var _hint: Label
var _save: Button
var _delete: Button
var _delete_timer: Timer
var _views: Array = []
var _scroll: ScrollContainer
var _arrow_left: Button
var _arrow_right: Button
var _avatar := 0


func _ready() -> void:
	var existing = App.profiles.find(profile_id) if profile_id != "" else null
	if existing != null:
		_avatar = existing.avatar
	var m := UiKit.margin(self, 40, 60, 40, 60)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	m.add_child(box)
	var title := UiKit.title("profile_edit.edit_player" if existing != null else "profile_edit.new_player", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UiKit.label("profile_edit.name", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM))
	_name = LineEdit.new()
	_name.max_length = Protocol.NAME_MAX
	_name.add_theme_font_size_override("font_size", 56)
	_name.custom_minimum_size = Vector2(0, 120)
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_name.text = existing.player_name if existing != null else ""
	_name.text_changed.connect(_on_text)
	box.add_child(_name)
	_hint = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.ACCENT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_hint)
	# 32 avatars in one line: drag the line, or use the arrows (REQ-FL-72). The line keeps its direction in Hebrew too.
	var carousel := HBoxContainer.new()
	carousel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	carousel.add_theme_constant_override("separation", 12)
	box.add_child(carousel)
	_arrow_left = _arrow("<", -1)
	carousel.add_child(_arrow_left)
	_scroll = ScrollContainer.new()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, AVATAR_SIDE + 8)
	carousel.add_child(_scroll)
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 12)
	_scroll.add_child(strip)
	for i in Protocol.AVATAR_COUNT:
		var v := AvatarView.new(i, AVATAR_SIDE)
		v.set_selected(i == _avatar)
		v.pressed.connect(_on_avatar.bind(i))
		strip.add_child(v)
		_views.append(v)
	_arrow_right = _arrow(">", 1)
	carousel.add_child(_arrow_right)
	var bar := _scroll.get_h_scroll_bar()
	bar.value_changed.connect(func(_v): _update_arrows())
	bar.changed.connect(_update_arrows)
	_show_picked.call_deferred()
	box.add_child(UiKit.spacer(0, true))   # Save, Delete and Back sit at the bottom of the screen.
	_save = UiKit.box_button("profile_edit.save", _on_save, UiTheme.SIZE_ITEM, UiTheme.OK)
	_save.custom_minimum_size = Vector2(0, 110)
	box.add_child(_save)
	if existing != null:
		_delete = UiKit.box_button("profile_edit.delete", _on_delete, UiTheme.SIZE_ITEM, UiTheme.BAD)
		_delete.custom_minimum_size = Vector2(0, 110)
		box.add_child(_delete)
		_delete_timer = Timer.new()
		_delete_timer.one_shot = true
		_delete_timer.wait_time = DELETE_ARM_SECONDS
		_delete_timer.timeout.connect(_disarm_delete)
		add_child(_delete_timer)
	var back := UiKit.box_button("common.back", on_back, UiTheme.SIZE_ITEM, UiTheme.TEXT_DIM)
	back.custom_minimum_size = Vector2(0, 96)
	box.add_child(back)
	_refresh()


## Keeps only the characters that both fonts draw. A short line says so when something was dropped.
func _on_text(text: String) -> void:
	var kept := Profile.filter_name(text).substr(0, Protocol.NAME_MAX)
	if kept != text:
		_name.text = kept
		_name.caret_column = kept.length()
		_hint.text = Lang.t("profile_edit.letters_digits_space_only").to_upper()
	else:
		_hint.text = ""
	_refresh()


func _refresh() -> void:
	_save.disabled = Profile.clean_name(_name.text) == ""


## An arrow of the carousel: moves the line by three avatars.
func _arrow(text: String, dir: int) -> Button:
	var b := UiKit.box_button(text, _scroll_by.bind(dir), UiTheme.SIZE_ITEM)
	b.custom_minimum_size = Vector2(90, AVATAR_SIDE + 8)
	b.text_direction = Control.TEXT_DIRECTION_LTR   # Hebrew would mirror the "<" and ">" glyphs.
	return b


func _scroll_by(dir: int) -> void:
	var to := clampi(_scroll.scroll_horizontal + dir * int(AVATAR_STEP) * 3, 0, max_scroll())
	create_tween().tween_property(_scroll, "scroll_horizontal", to, 0.15)


## The farthest the line can scroll: the length of the content minus what is in view.
func max_scroll() -> int:
	var bar := _scroll.get_h_scroll_bar()
	return maxi(0, int(bar.max_value - bar.page))


## An arrow is dim and does nothing when the line is at that end.
func _update_arrows() -> void:
	if _arrow_left == null or _arrow_right == null:
		return
	_arrow_left.disabled = _scroll.scroll_horizontal <= 0
	_arrow_right.disabled = _scroll.scroll_horizontal >= max_scroll()


## Scrolls the line so the chosen avatar is in the middle (after the layout is done).
func _show_picked() -> void:
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_horizontal = maxi(0, int(_avatar * AVATAR_STEP - (_scroll.size.x - AVATAR_SIDE) * 0.5))
	_update_arrows()


func _on_avatar(i: int) -> void:
	_avatar = i
	for k in _views.size():
		_views[k].set_selected(k == i)


func _on_save() -> void:
	var store = App.profiles
	if profile_id == "":
		if store.create(_name.text, _avatar) == null:
			return
	elif not store.update(profile_id, _name.text, _avatar):
		return
	App.apply_profile()
	on_back()


## The first tap arms DELETE (it asks for the name), the second tap deletes.
func _on_delete() -> void:
	if _delete_timer.is_stopped():
		var p = App.profiles.find(profile_id)
		_delete.text = Lang.f("profile_edit.delete_ask", [p.player_name if p != null else ""]).to_upper()
		_delete_timer.start()
	else:
		App.profiles.delete(profile_id)
		App.apply_profile()
		on_back()


func _disarm_delete() -> void:
	_delete.text = Lang.t("profile_edit.delete").to_upper()


## Back goes to the main screen, or to the list when the screen was opened from the list (REQ-FL-72).
func on_back() -> void:
	if from_list:
		App.go(App.ControllerProfiles)
	else:
		App.leave_profile_screens()
