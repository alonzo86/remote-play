extends "res://scripts/ui/tv_modal.gd"
## The card of a phone that asks to join (issue #393, docs/JOIN_APPROVAL_PLAN.md 7.1 and 7.2, REQ-FL-97): the title, the avatar
## and the name, WANTS TO JOIN, "+N WAITING" when others wait, and two buttons, ALLOW and REFUSE. The focus starts on ALLOW.
## The card owns the arrows and OK; they do nothing in its first second (`guard_ms`), and BACK does nothing after
## that too (`JoinRequests` consumes it). It has no key hint and no time (FD-30.14). `JoinRequests` makes it and calls `update()`.

const Lang = preload("res://scripts/core/lang.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")
const AvatarView = preload("res://scripts/ui/avatar_view.gd")

signal allowed(id: int)
signal refused(id: int)

## The request that this card shows (`TvServer.shown_request()`): id, name, av, slot_hint, others.
var request := {}
## The time after the card shows in which no key does anything (D6).
var guard_ms := 1000
var shown_ms := 0

var _allow: Button
var _refuse: Button
var _others: PanelContainer
var _others_label: Label


func _init() -> void:
	card_width = 1200


func _ready() -> void:
	shown_ms = Time.get_ticks_msec()
	super()


## True while the first second after the card showed is not over.
func guarded() -> bool:
	return Time.get_ticks_msec() - shown_ms < guard_ms


func request_id() -> int:
	return int(request.get("id", -1))


func _build() -> void:
	body.add_theme_constant_override("separation", 40)   # The room of the mock between the three parts.
	var head := HBoxContainer.new()
	var title := UiKit.title("approval.title", 48)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_others = UiKit.panel(0)
	_others.add_theme_stylebox_override("panel", UiTheme.line_box(UiTheme.TEXT_DIM, UiTheme.BG, 4))
	_others_label = UiKit.label("", UiTheme.SIZE_BODY, UiTheme.TEXT)
	_others_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # A resolved text, not a key.
	_others.add_child(_others_label)
	head.add_child(_others)
	body.add_child(head)

	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 24)
	var av := int(request.get("av", -1))
	if Avatar.is_known(av):
		var view := AvatarView.new(av, 128.0)
		view.framed = false
		view.tappable = false
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		who.add_child(view)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 12)
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_l := UiKit.label(_name_text(), 64, UiTheme.TEXT)
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # A player name is never translated (REQ-FL-63).
	name_l.text_direction = Control.TEXT_DIRECTION_AUTO
	name_l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # A name of 10 letters fits; a longer one would wrap, never shrink.
	texts.add_child(name_l)
	texts.add_child(UiKit.label("approval.wants", UiTheme.SIZE_BODY, UiTheme.TEXT_DESC))
	who.add_child(texts)
	body.add_child(who)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 160)   # The mock. The layout direction mirrors it in Hebrew.
	_allow = UiKit.item("approval.allow", _on_allow)
	_tint(_allow, UiTheme.OK)
	_refuse = UiKit.item("approval.refuse", _on_refuse)
	_tint(_refuse, UiTheme.BAD)
	row.add_child(_allow)
	row.add_child(_refuse)
	body.add_child(row)
	_buttons = [_allow, _refuse]
	update(request)
	UiKit.focus_later(_allow)


## The color of a button in every state: the word is the cue and the cursor has this color too (the mock).
func _tint(b: Button, color: Color) -> void:
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, color)


func _name_text() -> String:
	var n := String(request.get("name", ""))
	if n != "":
		return n
	return Lang.f("players.default_name", [maxi(0, int(request.get("slot_hint", 0))) + 1])


## The same request with a new number of other requests: the label changes in place and the focus stays.
func update(r: Dictionary) -> void:
	request = r
	var n := int(r.get("others", 0))
	if _others != null:
		_others.visible = n > 0
		# The table has no plural: exactly 1 other has its own row.
		var text := "" if n <= 0 else Lang.t("approval.one_waiting")
		if n >= 2:
			text = Lang.f("approval.others_waiting", [n])
		_others_label.text = text


## The card owns the arrows and, in its first second, OK too (nothing reaches the screen under it).
func _input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	var guard := guarded()
	if event.is_action_pressed("ui_accept"):
		# A button acts when the key is let go, and its GUI does not consume the press: the screen under the card would see the
		# press (the Connect screen goes on to Games). So the card takes the press and answers itself.
		get_viewport().set_input_as_handled()
		if guard:
			return
		var owner := get_viewport().gui_get_focus_owner()
		if owner == _allow:
			_on_allow()
		elif owner == _refuse:
			_on_refuse()
		else:
			_allow.grab_focus()   # OK never acts on the screen under the card.
		return
	for action in MOVES:
		if event.is_action_pressed(action, true):
			get_viewport().set_input_as_handled()
			if guard or action == "ui_up" or action == "ui_down":
				return
			_move(action)
			return


## Left and Right move the focus between the two buttons (the geometry decides, so Hebrew mirrors). At the edge nothing happens.
func _move(action: String) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner != _allow and owner != _refuse:
		_allow.grab_focus()
		return
	var next := owner.find_valid_focus_neighbor(MOVES[action])
	if next != null and next != owner and is_ancestor_of(next):
		next.grab_focus()
		Sound.sfx("move")


func _on_allow() -> void:
	if guarded() or is_queued_for_deletion():
		return
	allowed.emit(request_id())


func _on_refuse() -> void:
	if guarded() or is_queued_for_deletion():
		return
	Sound.sfx("denied")
	refused.emit(request_id())


## BACK does not close the card (D12): only a button or the time limit of the TV server ends a request.
func on_back() -> void:
	pass


## The controls of a screen that was built under the card cannot take the focus either (`JoinRequests.on_screen_changed`).
func suspend_again() -> void:
	_suspend_focus_below()
