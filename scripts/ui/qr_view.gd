extends Control
## Draws a QR code on a white rounded card. Set `text`. The TV shows it on the Connect screen
## and in the Players modal.

const QrEncoder = preload("res://scripts/core/qr_encoder.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var text := "":
	set(v):
		if v != text:
			text = v
			_qr = QrEncoder.encode(v) if v != "" else []
			queue_redraw()

var _qr: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var side := minf(size.x, size.y)
	var box := Rect2(Vector2.ZERO, Vector2(side, side))
	draw_style_box(UiTheme.card(Color.WHITE, UiTheme.OUTLINE, UiTheme.OUTLINE_W, 22, false), box)
	if _qr.is_empty():
		return
	var n := _qr.size()
	var pad := side * 0.06
	var cell := (side - pad * 2.0) / float(n + 2) # One module of quiet zone on each side.
	var origin := Vector2(pad + cell, pad + cell)
	for y in n:
		for x in n:
			if _qr[y][x]:
				draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)).grow(0.4), Color.BLACK)
