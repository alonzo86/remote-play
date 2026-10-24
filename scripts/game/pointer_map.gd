extends RefCounted
## Where a phone that is a pointer points on the screen. Used by the games where each phone is a ring or cursor on the TV
## (Banana Party, Whack-a-Mole), so the mapping is the same in all of them (REQ-GM-24, REQ-SS-3, REQ-WM-3).


## `pointer` (-1 to 1 on both axes, `PlayerInput.pointer()`) mapped to the play area `area`: -1 is the left or top edge, +1 the
## right or bottom edge, 0 the center. Values outside -1 to 1 stay at the edge.
static func aim_to_screen(pointer: Vector2, area: Rect2) -> Vector2:
	var p := pointer.clamp(Vector2(-1, -1), Vector2(1, 1))
	return area.get_center() + p * area.size * 0.5


## The scale from the reference play area `ref` (at 1920x1080) to a real play area `area` (for the sizes).
static func scale_for(area: Rect2, ref: Vector2) -> float:
	return minf(area.size.x / ref.x, area.size.y / ref.y)
