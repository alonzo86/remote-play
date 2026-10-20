extends RefCounted
## Helpers of the tests of Treasure Maze, Road Rally and Banana Party (tests/smoke_maze.gd, smoke_race.gd, smoke_banana.gd,
## device_mocks_b.gd): simulated phones on the loopback network, a sensor stream that is written straight into the players
## (with a fake clock) and a game that is stepped by hand, so a test of 60 game seconds takes less than a real second.

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

const DT := 1.0 / 60.0
const FLAT := Vector3(0.0, 0.0, 9.81)

var tree: SceneTree
var app: Node
var clients: Array = []
var _ts := {}    # slot -> the fake time of the phone in ms
var _seq := {}


func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	app = tree.root.get_node("App")


func frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## Joins `n` simulated phones with the TV over the loopback network. Slot i is client i.
func join(n: int) -> void:
	for i in n:
		var c := ControllerClient.new()
		c.player_name = "Sim%d" % i
		tree.root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
	var start := Time.get_ticks_msec()
	while app.server.connected_slots().size() < n and Time.get_ticks_msec() - start < 5000:
		await tree.process_frame
	await frames(2)


func leave_all() -> void:
	for c in clients:
		c.leave()
		c.queue_free()
	clients.clear()
	await frames(3)


## The accelerometer reading of a phone that is tilted `right_deg` to the right (right side down) and `up_deg` with its top up.
static func lean(right_deg := 0.0, up_deg := 0.0) -> Vector3:
	var r := deg_to_rad(right_deg)
	var u := deg_to_rad(up_deg)
	return Vector3(-sin(r), sin(u), sqrt(maxf(0.0, 1.0 - sin(r) * sin(r) - sin(u) * sin(u)))) * 9.81


## One sensor packet for `slot` (the fake clock moves by 16 ms), straight into the player like the server does it.
func feed(slot: int, accel: Vector3, gyro := Vector3.ZERO, buttons := 0) -> void:
	_ts[slot] = int(_ts.get(slot, 0)) + 16
	_seq[slot] = int(_seq.get(slot, 0)) + 1
	var pkt := Protocol.decode_sensor(Protocol.encode_sensor(_seq[slot], _ts[slot], gyro, accel, buttons, 0, Vector2.ZERO))
	app.server.players[slot].on_sensor(pkt, Time.get_ticks_msec())


## Feeds `n` packets of the same reading, so that the tilt filter has settled.
func settle(slot: int, accel: Vector3, n := 150) -> void:
	for i in n:
		feed(slot, accel)


## Starts a game and stops its own `_process`: the test ticks it by hand.
func start(script: GDScript, props := {}) -> Control:
	app.go(script, props)
	await frames(2)
	var game: Control = app.current_screen()
	game.set_process(false)
	return game


## Steps `game` for `seconds` of game time. `accels` is slot -> accelerometer reading (or a Callable(tick) -> reading) that is
## fed before every tick. Returns the number of ticks.
func step(game: Control, seconds: float, accels := {}) -> int:
	var n := roundi(seconds / DT)
	for t in n:
		for s in accels:
			var a: Variant = accels[s]
			feed(s, a.call(t) if a is Callable else a)
		game._game_tick(DT)
	return n


## Steps the countdown out (the phones keep their readings) and returns when the round plays.
func through_countdown(game: Control, accels := {}) -> void:
	var guard := 0
	while game._round.is_counting() and guard < 600:
		step(game, DT, accels)
		guard += 1
