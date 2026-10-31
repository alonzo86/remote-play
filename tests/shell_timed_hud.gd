extends SceneTree
## The shared HUD of the timed games (issue #293, REQ-GM-47o): `Shell.timed_hud` draws the timer box only while the round runs
## (and not when the game is over), the countdown number only when somebody plays, and the hint during the first seconds. It
## draws at the same place in every game, with the width `Shell.TIMER_W`.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/shell_timed_hud.gd -- --role=tv

const Shell = preload("res://scripts/game/shell.gd")
const RoundClock = preload("res://scripts/game/round_clock.gd")

var _checks := 0
var _fails := 0
var _seen: Array = []
var _canvas: Control


class Canvas extends Control:
	var clock: RoundClock
	var over := false
	var has_players := true

	func _draw() -> void:
		Shell.timed_hud(self, Vector2(1920, 1080), clock, over, has_players, "bumper_cars.hint", 4.0)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	await _run()
	Shell.recorder = Callable()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _kinds(clock: RoundClock, over := false, has_players := true) -> Array:
	_seen = []
	Shell.recorder = func(kind: String, _ci: CanvasItem, rect: Rect2, info: Dictionary) -> void:
		_seen.append({"kind": kind, "rect": rect, "info": info})
	_canvas.clock = clock
	_canvas.over = over
	_canvas.has_players = has_players
	_canvas.queue_redraw()
	await process_frame
	await process_frame
	var kinds := []
	for e in _seen:
		kinds.append(e.kind)
	return kinds


func _run() -> void:
	_canvas = Canvas.new()
	_canvas.size = Vector2(1920, 1080)
	_canvas.clock = RoundClock.new(3.0, 30.0)
	root.add_child(_canvas)
	await process_frame

	print("countdown")
	var c := RoundClock.new(3.0, 30.0)
	c.time = -2.5
	var k := await _kinds(c)
	_check(k.has("countdown") and not k.has("timer"), "in the countdown: the number, no timer box")
	_check(k.has("hint"), "in the countdown the hint shows (the time is below the hint time)")
	k = await _kinds(c, false, false)
	_check(not k.has("countdown"), "with nobody playing no countdown number is drawn")

	print("playing")
	var p := RoundClock.new(3.0, 30.0)
	p.time = 1.0
	k = await _kinds(p)
	_check(k.has("timer") and k.has("hint") and not k.has("countdown"), "early in the round: the timer and the hint")
	var timer_rect: Rect2 = _seen.filter(func(e): return e.kind == "timer")[0].rect
	_check(timer_rect.position.x == Shell.TIMER_X and timer_rect.position.y == Shell.TIMER_Y and timer_rect.size.x >= Shell.TIMER_W,
			"the timer box is at TIMER_X, TIMER_Y and at least TIMER_W wide")
	var text: String = _seen.filter(func(e): return e.kind == "timer")[0].info.text
	_check(text.begins_with("29.0"), "the box shows the seconds that are left (29.0, was %s)" % text)
	p.time = 4.5
	k = await _kinds(p)
	_check(k.has("timer") and not k.has("hint"), "after the hint time the hint is gone")
	p.time = 60.0
	k = await _kinds(p)
	_check(k.has("timer") and _seen.filter(func(e): return e.kind == "timer")[0].info.text.begins_with("0.0"),
			"past the length of the round the box shows 0.0, not a negative time")

	print("game over")
	p.time = 1.0
	k = await _kinds(p, true)
	_check(not k.has("timer") and not k.has("hint") and not k.has("countdown"), "when the game is over nothing of it is drawn")
	_canvas.queue_free()
