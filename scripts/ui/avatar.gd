extends RefCounted
## The avatar sprite sheet (FD-22, docs/PROFILES_PLAN.md section 7): 32 avatars of 16 x 16 px in 4 columns and 8 rows, in
## `assets/avatars/avatars.png`. An avatar takes the place of the player number (REQ-FL-69). It is drawn at a whole-number scale
## with sharp pixels.

const Protocol = preload("res://scripts/core/protocol.gd")

const SHEET := "res://assets/avatars/avatars.png"
const CELL := 16
const COLUMNS := 4

static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null and ResourceLoader.exists(SHEET):
		_texture = load(SHEET) as Texture2D
	return _texture


## True for an index of the sheet. A later sheet can have more avatars: an index this app does not know shows the number.
static func is_known(index: int) -> bool:
	return index >= 0 and index < Protocol.AVATAR_COUNT and texture() != null


static func region(index: int) -> Rect2:
	return Rect2((index % COLUMNS) * CELL, (index / COLUMNS) * CELL, CELL, CELL)


## The whole-number scale that fits `side` pixels: 1 or more.
static func scale_for(side: float) -> int:
	return maxi(1, floori(side / CELL))


## Draws avatar `index` in the middle of `rect`, as large as a whole scale allows. Returns false when it drew nothing.
static func draw(ci: CanvasItem, rect: Rect2, index: int) -> bool:
	if not is_known(index):
		return false
	if ci.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # Sharp pixels.
	var side := float(scale_for(minf(rect.size.x, rect.size.y)) * CELL)
	var target := Rect2(rect.position + (rect.size - Vector2(side, side)) * 0.5, Vector2(side, side))
	ci.draw_texture_rect_region(texture(), target, region(index))
	return true
