extends VBoxContainer
## The PIN pad of the phone (FD-23). The player reads the PIN on the TV and types it here when the phone joins a TV from the list.
## `entered(pin)` comes when the last digit is typed. A scan of the QR code needs no pad: the link carries the PIN.

const Protocol = preload("res://scripts/core/protocol.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

signal entered(pin: String)
signal cancelled()

var digits := ""
var _shown: Label


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	var ask := UiKit.label("pin.type_prompt", UiTheme.SIZE_BODY, UiTheme.TEXT_DIM)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ask)
	_shown = UiKit.title("", 56)
	_shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_shown)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.layout_direction = Control.LAYOUT_DIRECTION_LTR   # A keypad has the same order in every language.
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	add_child(grid)
	for d in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "X"]:
		var key: String = d
		var b := UiKit.box_button(key, func(): _key(key), 48)
		b.text = key   # box_button upper-cases; these are not words.
		b.custom_minimum_size = Vector2(0, 120)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	_refresh()


## "<" deletes the last digit, "X" cancels, a digit is added. The last digit sends `entered`.
func _key(k: String) -> void:
	if k == "X":
		cancelled.emit()
	elif k == "<":
		digits = digits.substr(0, digits.length() - 1)
		_refresh()
	elif digits.length() < Protocol.PIN_LENGTH:
		digits += k
		_refresh()
		if digits.length() == Protocol.PIN_LENGTH:
			entered.emit(digits)


func _refresh() -> void:
	if _shown == null:
		return
	var out := ""
	for i in Protocol.PIN_LENGTH:
		out += (digits[i] if i < digits.length() else "_") + " "
	_shown.text = out.strip_edges()
