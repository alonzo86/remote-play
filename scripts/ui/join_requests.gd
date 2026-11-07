extends CanvasLayer
## The layer of the TV that shows the card of a phone that asks to join (issue #393, docs/JOIN_APPROVAL_PLAN.md 7.1, FD-30.12).
## The App makes it for the run of the TV app and keeps it the last child, so its `_input` runs before the screens. It reads the
## TV server (`shown_request()`), opens the card for the shown request, closes it when the request ends, and is the only UI code
## that calls `allow_request()` and `refuse_request()`. It builds no node while no request is shown.
## BACK does nothing while a card shows (D12): `_input` consumes `ui_cancel` and `KEY_BACK`, and `App._back()` returns for the
## notification of the Android Back key.

const JoinCard = preload("res://scripts/ui/join_card.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

var server: Node
var card: Control

## The first second of a card (D6). A test can shorten it before a card shows.
var guard_ms := 1000


func _init() -> void:
	layer = 90   # Above the screens, below the debug overlay (100).


func setup(p_server: Node) -> void:
	server = p_server
	server.requests_changed.connect(_sync)
	_sync()


## True while a card shows.
func is_open() -> bool:
	return card != null and is_instance_valid(card) and not card.is_queued_for_deletion()


func _sync() -> void:
	var r: Dictionary = server.shown_request() if server != null else {}
	if r.is_empty():
		_close()
	elif is_open() and card.request_id() == int(r.id):
		card.update(r)   # Only the number of others changed.
	else:
		_open(r)


func _open(r: Dictionary) -> void:
	var prev: Control = null
	if is_open():
		prev = card._prev_focus   # A new request replaced the card: the focus goes back to the control under the first card.
		_discard()
	var c: Control = JoinCard.new()
	c.request = r
	c.guard_ms = guard_ms
	c.theme = App.theme_res
	c.allowed.connect(allow)
	c.refused.connect(refuse)
	card = c
	add_child(c)
	if prev != null:
		c._prev_focus = prev


## The card goes at once (not at the end of the frame) when the request ended.
func _close() -> void:
	if is_open():
		var c := card
		c.close()
		if c._prev_focus == null or not is_instance_valid(c._prev_focus) or not c._prev_focus.is_inside_tree():
			_focus_screen()   # The screen changed under the card: its first control takes the focus.
	card = null


func _focus_screen() -> void:
	var screen: Control = App.current_screen()
	if screen == null:
		return
	for n in screen.find_children("*", "Control", true, false):
		if n.focus_mode == Control.FOCUS_ALL and n.is_visible_in_tree():
			UiKit.focus_later(n)
			return


func _discard() -> void:
	remove_child(card)
	card.free()
	card = null


func allow(id: int) -> void:
	if server != null:
		server.allow_request(id)


func refuse(id: int) -> void:
	if server != null:
		server.refuse_request(id)


## A screen was built while a card shows: its controls cannot take the focus either.
func on_screen_changed() -> void:
	if is_open():
		card.suspend_again()


## BACK does nothing while a card shows (D12). The stamp makes the App drop the notification of the same press too.
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var back: bool = event.is_action_pressed("ui_cancel", true) \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_BACK)
	if back:
		get_viewport().set_input_as_handled()
		App.note_back()
