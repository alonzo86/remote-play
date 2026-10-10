extends RefCounted
## The part of the phone screen that a notch, a camera cut-out, a Dynamic Island, the status bar or the home bar covers
## (REQ-FL-68). The phone screens keep their content inside the rest.


## The room to leave at the left, the top, the right and the bottom (x, y, z, w), in the units of the viewport.
## `window` is the size of the window in pixels, `safe` the safe area in the same pixels and `viewport` the size of the
## viewport in its units. An empty or unknown safe area gives no margin. A safe area that is larger than the window gives none.
static func insets(window: Vector2, safe: Rect2, viewport: Vector2) -> Vector4:
	if window.x <= 0.0 or window.y <= 0.0 or safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Vector4.ZERO
	var k := viewport.x / window.x
	return Vector4(maxf(safe.position.x, 0.0) * k, maxf(safe.position.y, 0.0) * k,
			maxf(window.x - safe.end.x, 0.0) * k, maxf(window.y - safe.end.y, 0.0) * k)


## The insets of this device now. Only a phone or a tablet has them: a desktop window has none, because its "safe area" is the
## desktop without the menu bar.
static func current(viewport: Vector2) -> Vector4:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return Vector4.ZERO
	return insets(Vector2(DisplayServer.window_get_size()), Rect2(DisplayServer.get_display_safe_area()), viewport)
