extends Control
## Draws a QR code on a white square. Set `text`. The TV shows it on the Connect screen
## and in the Players modal.

const QrEncoder = preload("res://scripts/core/qr_encoder.gd")

var text := "":
	set(v):
		if v != text:
			text = v
			_qr = QrEncoder.encode(v) if v != "" else []
			queue_redraw()

## Quiet zone in modules for a code that is made to be scanned from another phone (FD-22). -1 keeps the TV look: a pad of 6%
## and one module. A value of 0 or more draws every module as a whole number of pixels (no blur), with that quiet zone.
var quiet := -1:
	set(v):
		quiet = v
		queue_redraw()

var _qr: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var side := minf(size.x, size.y)
	draw_set_transform(((size - Vector2(side, side)) * 0.5).floor())   # The square sits in the middle of a larger area.
	var box := Rect2(Vector2.ZERO, Vector2(side, side))
	draw_rect(box, Color.WHITE)
	if _qr.is_empty():
		return
	var n := _qr.size()
	if quiet >= 0:
		var whole := maxi(int(side) / (n + 2 * quiet), 1)
		var start := Vector2.ONE * floorf((side - float(whole * n)) * 0.5)
		for y in n:
			for x in n:
				if _qr[y][x]:
					draw_rect(Rect2(start + Vector2(x, y) * float(whole), Vector2(whole, whole)), Color.BLACK)
		return
	var pad := side * 0.06
	var cell := (side - pad * 2.0) / float(n + 2) # One module of quiet zone on each side.
	var origin := Vector2(pad + cell, pad + cell)
	for y in n:
		for x in n:
			if _qr[y][x]:
				draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)).grow(0.4), Color.BLACK)
