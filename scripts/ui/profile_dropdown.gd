extends VBoxContainer
## The player picker of the phone Connect screen (REQ-FL-71): a dropdown that shows the avatar and the name of the active
## profile, and a "+" next to it that opens the new player screen. The dropdown opens in place under the row. It lists the
## profiles and the guest, then "Players" for the list screen (edit, share, paste and scan a player).

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")
const PencilIcon = preload("res://scripts/ui/pencil_icon.gd")

const ROW_H := 110.0
const AVATAR_SIDE := 80.0

var _head: Button
var _list: VBoxContainer
var open := false


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var active = App.profiles.active()
	_head = _row(active.avatar if active != null else -1, active.player_name if active != null else "connect.guest",
			active != null, toggle, UiTheme.TEXT, true)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_head)
	if active != null:   # Rename the player, change the avatar, or delete it.
		var edit := UiKit.box_button("", _on_edit, UiTheme.SIZE_BODY, UiTheme.ACCENT)
		edit.custom_minimum_size = Vector2(ROW_H, ROW_H)
		var pencil := PencilIcon.new()
		pencil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
		edit.add_child(pencil)
		row.add_child(edit)
	var plus := UiKit.box_button("+", _on_new, UiTheme.SIZE_TITLE, UiTheme.ACCENT)
	plus.custom_minimum_size = Vector2(ROW_H, ROW_H)
	plus.disabled = App.profiles.is_full()
	row.add_child(plus)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.visible = false
	add_child(_list)


func toggle() -> void:
	open = not open
	_list.visible = open
	if open:
		_fill()


func _fill() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var store = App.profiles
	for p in store.profiles:
		_list.add_child(_row(p.avatar, p.player_name, true, _pick.bind(p.id),
				UiTheme.ACCENT if p.id == store.active_id else UiTheme.TEXT))
	_list.add_child(_row(-1, "connect.guest", false, _pick.bind(""), UiTheme.ACCENT if store.active_id == "" else UiTheme.TEXT))
	var manage := UiKit.box_button("common.players", _on_manage, UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	manage.custom_minimum_size = Vector2(0, 96)
	_list.add_child(manage)


## A framed row: the avatar (none for the guest), the name, and a triangle on the head row.
func _row(avatar: int, text: String, is_name: bool, cb: Callable, color: Color, head := false) -> Button:
	var b := UiKit.box_button("", cb, UiTheme.SIZE_ITEM, color)
	b.custom_minimum_size = Vector2(0, ROW_H)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 16)
	inner.alignment = BoxContainer.ALIGNMENT_BEGIN
	b.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 16
	inner.offset_right = -16
	var av := AvatarView.new(avatar, AVATAR_SIDE)
	av.tappable = false
	av.framed = false   # No border around the avatar on the Connect screen.
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(av)
	var l := UiKit.label(text, UiTheme.SIZE_ITEM, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	if is_name:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # A player name is never translated (REQ-FL-63).
	inner.add_child(l)
	if head:
		var tri := Control.new()
		tri.custom_minimum_size = Vector2(32, 32)
		tri.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tri.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tri.draw.connect(func(): tri.draw_colored_polygon(PackedVector2Array([Vector2(0, 6), Vector2(32, 6), Vector2(16, 26)]), color))
		inner.add_child(tri)
	return b


func _pick(id: String) -> void:
	App.profiles.set_active(id)
	App.apply_profile()
	App.go(App.ControllerConnect)   # The screen is built again with the new player in the head row.


func _on_new() -> void:
	App.go(App.ControllerProfileEdit, {"profile_id": ""})


func _on_edit() -> void:
	App.go(App.ControllerProfileEdit, {"profile_id": App.profiles.active_id})


func _on_manage() -> void:
	App.go(App.ControllerProfiles)
