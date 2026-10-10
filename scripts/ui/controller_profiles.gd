extends Control
## Phone screen "WHO IS PLAYING?" (FD-22, REQ-FL-71): the profiles of this phone, the guest, and NEW PLAYER. A tap on a row makes
## it the active profile. It is opened from the Connect screen and from the waiting screen, and it is closed when the TV starts a
## round (`App._show_phone_screen`).

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Lang = preload("res://scripts/core/lang.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")

var _list: VBoxContainer
var _note: Label
var _new_button: Button


func _ready() -> void:
	var m := UiKit.margin(self, 40, 60, 40, 60)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	m.add_child(box)
	var title := UiKit.title("Who is playing?", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 16)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_note = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_note)
	_new_button = UiKit.box_button("New player", _on_new, UiTheme.SIZE_ITEM)
	_new_button.custom_minimum_size = Vector2(0, 110)
	box.add_child(_new_button)
	var back := UiKit.box_button("Back", on_back, UiTheme.SIZE_ITEM, UiTheme.TEXT_DIM)
	back.custom_minimum_size = Vector2(0, 96)
	box.add_child(back)
	_rebuild()


## The rows: one for each profile, then the guest.
func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var store: ProfileStore = App.profiles
	for p in store.profiles:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var av := AvatarView.new(p.avatar, 110.0)
		av.set_selected(p.id == store.active_id)
		av.pressed.connect(_on_pick.bind(p.id))
		row.add_child(av)
		var b := UiKit.box_button(p.player_name, _on_pick.bind(p.id), UiTheme.SIZE_ITEM,
				UiTheme.ACCENT if p.id == store.active_id else UiTheme.TEXT)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # A player name is never translated (REQ-FL-63).
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 110)
		row.add_child(b)
		var edit := UiKit.box_button("Edit", _on_edit.bind(p.id), UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
		edit.custom_minimum_size = Vector2(0, 110)
		row.add_child(edit)
		_list.add_child(row)
	var guest := UiKit.box_button("Guest", _on_pick.bind(""), UiTheme.SIZE_ITEM,
			UiTheme.ACCENT if store.active_id == "" else UiTheme.TEXT)
	guest.custom_minimum_size = Vector2(0, 110)
	_list.add_child(guest)
	_new_button.disabled = store.is_full()
	_note.text = Lang.f("%d players is the maximum", [ProfileStore.MAX_PROFILES]).to_upper() if store.is_full() else ""
	if not store.last_save_ok:
		_note.text = Lang.t("Could not save").to_upper()


func _on_pick(id: String) -> void:
	App.profiles.set_active(id)
	App.apply_profile()
	_rebuild()


func _on_edit(id: String) -> void:
	App.go(App.ControllerProfileEdit, {"profile_id": id})


func _on_new() -> void:
	App.go(App.ControllerProfileEdit, {"profile_id": ""})


func on_back() -> void:
	App.leave_profile_screens()
