extends Control
## Phone screen "SHARE PLAYER" (FD-22, REQ-FL-77): a QR code of one profile, which another phone scans (SCAN A PLAYER), and the
## text of the same code for COPY CODE and PASTE A CODE. `profile_id` is set before the screen enters the tree. The code is made
## once, when the screen opens, and it goes away after `SHOW_SECONDS`.

const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Lang = preload("res://scripts/core/lang.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const QrView = preload("res://scripts/ui/qr_view.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")

const SHOW_SECONDS := 60.0
const QUIET_MODULES := 4

var profile_id := ""
var code := ""

var _copy: Button
var _timer: Timer


func _ready() -> void:
	var p = App.profiles.find(profile_id)
	var m := UiKit.margin(self, 40, 60, 40, 60)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	m.add_child(box)
	var title := UiKit.title("Share player", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if p == null:
		on_back()
		return
	code = ProfileCode.encode(p)
	var who := HBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 16)
	who.add_child(AvatarView.new(p.avatar, 96.0))
	var name_label := UiKit.label(p.player_name, UiTheme.SIZE_ITEM)
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	who.add_child(name_label)
	box.add_child(who)
	var qr := QrView.new()
	qr.quiet = QUIET_MODULES
	qr.custom_minimum_size = Vector2(486, 486)   # The code takes the room that is left on a small screen (at least 486 px).
	qr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	qr.text = code
	box.add_child(qr)
	var lines: Array[Label] = []
	lines.append(UiKit.label("Everyone who scans this code gets this player and the best scores.", UiTheme.SIZE_BODY,
			UiTheme.TEXT_DIM))
	lines.append(UiKit.label("The two phones do not stay in sync after the copy.", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM))
	lines.append(UiKit.label("The code goes away after 60 seconds.", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM))
	for line in lines:
		line.autowrap_mode = TextServer.AUTOWRAP_WORD
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(line)
	_copy = UiKit.box_button("Copy code", _on_copy, UiTheme.SIZE_ITEM)
	_copy.custom_minimum_size = Vector2(0, 110)
	box.add_child(_copy)
	var back := UiKit.box_button("Back", on_back, UiTheme.SIZE_ITEM, UiTheme.TEXT_DIM)
	back.custom_minimum_size = Vector2(0, 96)
	box.add_child(back)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = SHOW_SECONDS
	_timer.timeout.connect(on_back)
	add_child(_timer)
	_timer.start()


func _on_copy() -> void:
	DisplayServer.clipboard_set(code)
	_copy.text = Lang.t("Code copied").to_upper()


func on_back() -> void:
	App.go(App.ControllerProfiles)
