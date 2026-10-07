extends Node
## Child of a control. After one frame it gives the parent the focus, if the parent is still in the tree.
## It frees itself. UiKit.focus_later() adds it.


func _process(_delta: float) -> void:
	var c := get_parent() as Control
	if c != null and c.is_inside_tree() and c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE:
		c.grab_focus()
	queue_free()
