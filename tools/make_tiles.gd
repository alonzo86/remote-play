extends SceneTree
## Makes the tile screenshots of the Games screen (REQ-FL-20): assets/tiles/<id>.png, 640x360.
## Every game in the registry runs with two simulated phones. The picture is taken after a
## short time per game. It needs a display and the TV role. Run:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##       --script tools/make_tiles.gd -- --role=tv
## Run it again after a visible change to a game. Commit the new files.

const Protocol = preload("res://scripts/core/protocol.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")
const GameSettings = preload("res://scripts/game/game_settings.gd")

const OUT_DIR := "res://assets/tiles/"
const TILE_SIZE := Vector2i(640, 360)
## Seconds to wait before the picture. The default is for games that need no countdown.
const WAIT := {"maze": 4.6, "marble_race": 5.4, "snowball_splat": 11.0, "paint_grab": 4.0, "sumo_bumpers": 4.0,
		"asteroid_blast": 4.0, "bowling": 4.0, "tennis": 4.0}
## Games with a pointer: each phone turns a little after GO (gyroscope, rad/s), so the cursors are apart.
const AIM_GYRO := {"snowball_splat": [Vector3(0.25, 0.0, 0.7), Vector3(-0.2, 0.0, -0.55), Vector3(-0.3, 0.0, 0.5),
		Vector3(0.18, 0.0, -0.6)]}

## Games that need more phones for a good picture: the race shows 4 marbles close together.
const EXTRA_PHONES := {"maze": 2, "marble_race": 2, "snowball_splat": 2, "paint_grab": 2, "sumo_bumpers": 2, "asteroid_blast": 2,
		"bowling": 2, "tennis": 2}
## Props of a game for its picture, instead of the ones of the settings view. A race with many posts, on the first track.
const SCENE_PROPS := {"marble_race": {"track_choice": "1", "difficulty": "hard"}}

var _seq := [0, 0, 0, 0]


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _stream(c: Array, seconds: float, accel: Array, gyro := []) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in c.size():
			c[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(),
					gyro[i] if not gyro.is_empty() else Vector3.ZERO,
					accel[i], 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


## The Pin Pals picture: a few frames in the sheet and a ball that is about to hit the pins.
func _place_bowling(game: Control) -> void:
	for n in [10, 7, 2, 9, 1, 10, 6, 3]:
		game.rules.record_roll(n)
	game.sim.set_rack(game.FULL_RACK)
	game._before = game.sim.standing_mask()
	game.sim.throw(0.06, 7.0, false)
	game.phase = game.Phase.ROLL
	while game.sim.ball_pos.y < 17.6:
		game.sim.tick(1.0 / 60.0)


## The Tennis picture: a doubles serve just hit, the ball high over the near half of the court.
func _place_tennis(game: Control) -> void:
	var server: int = game.play.server_slot()
	game.play.press_a(server)
	for i in 36:
		game._game_tick(0.016)
	game._tick_ms = Time.get_ticks_msec()
	game.play.swing(server, 0.9, true, 0.2, 0.0)
	for i in 30:
		game._game_tick(0.016)
	game.set_process(false)
	game._request_redraw()


## The Galaxy Protector picture: rocks of all sizes, beams in the air, two pickups, a force field, 3 lasers and an explosion.
func _place_blast(game: Node) -> void:
	var f = game.field
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	f.asteroids.clear()
	f.beams.clear()
	f.upgrades.clear()
	f.phase_time = 14.0
	game._time = 30.0   # Past the hint of the first seconds.
	f._upgrade_timer = 100.0
	for a in [[2, 420.0, 250.0], [1, 1000.0, 140.0], [0, 700.0, 430.0], [1, 1420.0, 390.0], [0, 1660.0, 180.0], [2, 1160.0,
			560.0], [0, 230.0, 90.0]]:
		f._make(a[0], a[1], a[2], rng)
	f.ships[1].shield = true
	f.ships[2].lasers = 3
	f.ships[3].lasers = 2
	for s in f.ships.values():
		for dy in [150.0, 420.0]:
			for dx in f.laser_offsets(s.lasers):
				var b = f.Beam.new()
				b.x = s.x + dx
				b.y = f.SHIP_Y - dy
				b.owner = s.slot
				f.beams.append(b)
	var u1 = f.Upgrade.new()
	u1.kind = f.SHIELD
	u1.x = 900.0
	u1.y = 470.0
	var u2 = f.Upgrade.new()
	u2.kind = f.WEAPON
	u2.x = 1550.0
	u2.y = 250.0
	f.upgrades.append(u1)
	f.upgrades.append(u2)
	f.scores[0] = 1250
	f.scores[1] = 980
	f.scores[2] = 640
	f.scores[3] = 310
	game._booms.append({"x": 560.0, "y": 330.0, "age": 0.2, "scale": 1.0})


## The race picture: the marbles side by side before a post, so that the bend, the post and the others are in view.
func _place_race(race: Node) -> void:
	var track = race.track
	var post_arc: float = track.bumpers[2][0] if track.bumpers.size() > 2 else 40.0
	var slots: Array = race.participants
	for i in slots.size():
		var arc := post_arc - 7.0 + (i % 2) * 2.2
		var side := (float(i) - (slots.size() - 1) * 0.5) * 1.5
		var r = race._racers[slots[i]]
		r.pos = track.point_at(arc) + race._perp(track.dir_at(arc)) * side
		r.vel = Vector2.ZERO


## The sumo picture: the platform has shrunk a little, two bumpers bump, one is on the edge and one has just fallen ("Whee!").
func _place_sumo(game: Node) -> void:
	game.phase = game.Phase.PLAY
	game.round_no = 2
	game.arena.time = 4.0
	var r: float = game.arena.radius()
	var slots: Array = game.participants
	var places := [Vector2(-r * 0.35, -r * 0.1), Vector2(-r * 0.35 + 62.0, r * 0.05), Vector2(r * 0.55, r * 0.5),
			Vector2(r * 0.15, -r * 1.12)]
	for i in slots.size():
		game._bodies[slots[i]].pos = places[i % places.size()]
		game._bodies[slots[i]].vel = Vector2.ZERO
	game._bodies[slots[0]].vel = Vector2(160.0, 40.0)
	var fallen: int = slots[slots.size() - 1]
	game._alive.erase(fallen)
	game._falling[fallen] = {"pos": places[3], "age": 0.25}
	for i in slots.size():
		game._board.set_score(slots[i], [1, 0, 1, 0][i % 4])
	game.set_process(false)   # Freeze the picture.
	game._request_redraw()   # Also the pixel view of the world.
	await _frames(3)


## The paint picture: each player owns a patch of the floor and the blobs sit at the edge of their patch.
func _place_paint(game: Node) -> void:
	var f = game.floor_map
	game._round.time = 27.0
	var slots: Array = game.participants
	var corners := [Vector2i(0, 0), Vector2i(f.cols / 2, f.rows / 2), Vector2i(f.cols / 2, 0), Vector2i(0, f.rows / 2)]
	for i in slots.size():
		var from: Vector2i = corners[i % corners.size()]
		for r in range(from.y, mini(from.y + (f.rows + 1) / 2, f.rows)):
			for c in range(from.x, mini(from.x + (f.cols + 1) / 2, f.cols)):
				# Ragged edges: some tiles of a patch are left out or belong to a neighbour.
				if (c * 7 + r * 13 + i * 5) % 5 < 3:
					f.paint(Vector2i(c, r), slots[i])
		var body = game._bodies[slots[i]]
		body.pos = (Vector2(from) + Vector2(2.5, 2.5) + Vector2(i % 2, i / 2) * 0.5) * 100.0
		body.vel = Vector2(80.0, 40.0)
	var pot = game.PaintPots.Pot.new()   # A gold pot is waiting in the middle of the floor.
	pot.kind = "gold"
	pot.cell = Vector2i(f.cols / 2, f.rows / 2)
	game._pots.pots.append(pot)
	for s in slots:
		game._board.set_score(s, f.count(s))


## The maze picture: four balls on the way to the exit, one behind the other, so that the way and the race can be seen.
func _place_maze(game: Node) -> void:
	var m = game._maze
	var cell: float = game.cell
	# The shortest way from the start cell (0, 0) to the exit cell, by a search over the cells.
	var came := {Vector2i(0, 0): Vector2i(-1, -1)}
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	var exit := Vector2i(m.cols - 1, m.rows - 1)
	while not queue.is_empty() and not came.has(exit):
		var c: Vector2i = queue.pop_front()
		var moves := {Vector2i(0, -1): m.h[c.y][c.x], Vector2i(0, 1): m.h[c.y + 1][c.x],
				Vector2i(-1, 0): m.v[c.y][c.x], Vector2i(1, 0): m.v[c.y][c.x + 1]}
		for d in moves:
			var n: Vector2i = c + d
			if not moves[d] and not came.has(n) and n.x >= 0 and n.y >= 0 and n.x < m.cols and n.y < m.rows:
				came[n] = c
				queue.append(n)
	var way: Array[Vector2i] = []
	var at := exit
	while at != Vector2i(-1, -1):
		way.push_front(at)
		at = came[at]
	game._round.time = 12.4   # The clock agrees with the balls: they have been on the way for a while.
	var shares := [0.78, 0.6, 0.42, 0.24]
	for i in game._balls.size():
		var c: Vector2i = way[int(float(way.size() - 1) * shares[i % shares.size()])]
		game._balls[i].pos = Vector2(c.x + 0.5, c.y + 0.5) * cell
		game._balls[i].vel = Vector2.ZERO


## The snowball picture: four scores, a Puff that was just hit (snow cap, "+10") and a snowball in the air for another one.
func _place_snow(game: Node, pad: Array, flats: Array) -> void:
	var PuffField = load("res://scripts/game/snowball_splat/puff_field.gd")
	var area: Rect2 = game._area()
	var scores := [120, 85, 60, 40]
	for i in game.participants.size():
		game._board.set_score(game.participants[i], scores[i % scores.size()])
	var puffs: Array = game._field.puffs
	if puffs.size() < 2:
		return
	var first = puffs[0]
	game._throwers[game.participants[0]].aim = PuffField.center_of(first, area)
	game._throw(game.participants[0], area)
	await _stream(pad, 0.3, flats)
	var second = null
	for p in game._field.puffs:   # The one that is farthest from the first, so that the two actions are apart.
		if second == null or p.x > second.x:
			second = p
	if second == null:
		return
	var slot: int = game.participants[1 % game.participants.size()]
	game._throwers[slot].aim = PuffField.center_of(second, area)
	game._throw(slot, area)
	for f in game._flights:
		if f.age >= 0.0:
			f.age = game.FLIGHT_TIME * 0.55   # Half way: the snowball is in the air.
	game.set_process(false)   # Freeze the picture.
	game._request_redraw()
	await _frames(3)


func _run() -> void:
	await _frames(5)
	var app: Node = root.get_node("App")
	var Registry = load("res://scripts/game/registry.gd")
	if app.overlay.visible:
		app.toggle_overlay()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var clients := []
	for i in 2:
		var c := ControllerClient.new()
		c.player_name = "Phone %d" % (i + 1)
		root.add_child(c)
		c.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
		clients.append(c)
	var flat := Vector3(0, 0, 9.81)
	await _stream(clients, 0.6, [flat, flat])
	var lean_a := deg_to_rad(10.0)
	var right := Vector3(-sin(lean_a), 0, cos(lean_a)) * 9.81
	var left := Vector3(sin(lean_a), 0.0, cos(lean_a)) * 9.81
	for g in Registry.all():
		var props: Dictionary = g.get("props", {})
		if g.has("settings"):
			props = GameSettings.props_for(g)
		if SCENE_PROPS.has(String(g.id)):
			props = SCENE_PROPS[String(g.id)].duplicate()
		var extra := []
		for i in int(EXTRA_PHONES.get(String(g.id), 0)):
			var e := ControllerClient.new()
			e.player_name = "Phone %d" % (clients.size() + i + 1)
			root.add_child(e)
			e.connect_to("127.0.0.1", Protocol.WS_PORT, app.server.room_code)
			extra.append(e)
		var t_join := Time.get_ticks_msec()
		while app.server.connected_slots().size() < clients.size() + extra.size() and Time.get_ticks_msec() - t_join < 4000:
			await _frames(1)
		var pad: Array = clients + extra
		var flats: Array = []
		for c in pad:
			flats.append(flat)
		app.go(Registry.load_script(String(g.id)), props)
		await _stream(pad, 3.2, flats) # The countdown.
		var wait: float = float(WAIT.get(String(g.id), 3.0)) - 3.2
		if AIM_GYRO.has(String(g.id)):
			await _stream(pad, 0.5, flats, AIM_GYRO[String(g.id)])
			wait -= 0.5
		if String(g.id) == "maze":
			_place_maze(app.current_screen())
			await _stream(pad, 0.5, flats)
			wait = 0.0
		if String(g.id) == "sumo_bumpers":
			await _place_sumo(app.current_screen())
			wait = 0.0
		if String(g.id) == "bowling":
			_place_bowling(app.current_screen())
			await _frames(2)
			wait = 0.0
		if String(g.id) == "tennis":
			_place_tennis(app.current_screen())
			await _frames(2)
			wait = 0.0
		if String(g.id) == "asteroid_blast":
			_place_blast(app.current_screen())
			await _frames(2)
			wait = 0.0
		if String(g.id) == "paint_grab":
			_place_paint(app.current_screen())
			await _stream(pad, 0.5, flats)
			wait = 0.0
		if String(g.id) == "marble_race":
			_place_race(app.current_screen())
			await _stream(pad, 1.6, flats)
			wait = 0.0
		if String(g.id) == "snowball_splat":
			await _stream(pad, wait, flats, AIM_GYRO[String(g.id)])
			await _place_snow(app.current_screen(), pad, flats)
			wait = 0.0
		if wait > 0.0:
			await _stream(clients, wait, [right, left])
		await _frames(3)
		var img := root.get_texture().get_image()
		img.resize(TILE_SIZE.x, TILE_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var path := OUT_DIR + String(g.id) + ".png"
		var err := img.save_png(ProjectSettings.globalize_path(path))
		print("%s: %s (%d)" % [g.id, path, err])
		for e in extra:
			e.leave()
		if not extra.is_empty():
			await _frames(30)
	app.go_menu()
	for c in clients:
		c.leave()
	await _frames(20)
	quit()
