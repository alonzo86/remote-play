extends Control
## One medal of the sheet as a control (REQ-GM-73), for the rows of the result menu. `tier` is "gold", "silver" or "bronze".

const Medal = preload("res://scripts/ui/medal.gd")
const _SELF = preload("res://scripts/ui/medal_view.gd")

var tier := "gold"


func _init(p_tier := "gold", side := 48.0) -> void:
	tier = p_tier
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The tiers of the medals in a card (a menu), from top to bottom (a test uses it).
static func tiers_in(card: Node) -> Array:
	var views := card.find_children("*", "Control", true, false).filter(func(n): return n.get_script() == _SELF)
	return views.map(func(n): return n.tier)


func _draw() -> void:
	Medal.draw(self, Rect2(Vector2.ZERO, size), tier)
