extends RefCounted
## The medal sheet (REQ-GM-73): three medals of 16 x 16 px in one row in `assets/medals/medals.png`, gold, silver and bronze. A
## medal is drawn like an avatar, at a whole-number scale with sharp pixels, next to the name of a player in the result menu.

const SHEET := "res://assets/medals/medals.png"
const CELL := 16
const TIERS := ["gold", "silver", "bronze"]   # The order of the sheet, from the left.

static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null and ResourceLoader.exists(SHEET):
		_texture = load(SHEET) as Texture2D
	return _texture


## True for a tier that the sheet has.
static func is_known(tier: String) -> bool:
	return TIERS.has(tier) and texture() != null


static func region(tier: String) -> Rect2:
	return Rect2(TIERS.find(tier) * CELL, 0, CELL, CELL)


## Draws the medal of `tier` in the middle of `rect`, as large as a whole scale allows. Returns false when it drew nothing.
static func draw(ci: CanvasItem, rect: Rect2, tier: String) -> bool:
	if not is_known(tier):
		return false
	if ci.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # Sharp pixels.
	var side := float(maxi(1, floori(minf(rect.size.x, rect.size.y) / CELL)) * CELL)
	var target := Rect2(rect.position + (rect.size - Vector2(side, side)) * 0.5, Vector2(side, side))
	ci.draw_texture_rect_region(texture(), target, region(tier))
	return true
