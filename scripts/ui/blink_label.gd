extends Label
## A prompt that blinks (REQ-FL-42): on for 0.55 s, off for 0.55 s, a hard step and not a fade. It keeps its place when it is
## off, so the layout does not jump. Use it for "PRESS OK TO CONTINUE".

const UiTheme = preload("res://scripts/ui/ui_theme.gd")

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	modulate.a = 1.0 if UiTheme.blink_on(_time) else 0.0
