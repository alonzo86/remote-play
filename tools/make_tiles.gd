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
const WAIT := {"maze": 4.6, "marble_race": 5.4, "snowball_splat": 11.0}
## Games with a pointer: each phone turns a little after GO (gyroscope, rad/s), so the cursors are apart.
const AIM_GYRO := {"snowball_splat": [Vector3(0.25, 0.0, 0.7), Vector3(-0.2, 0.0, -0.55), Vector3(-0.3, 0.0, 0.5),
		Vector3(0.18, 0.0, -0.6)]}

## Games that need more phones for a good picture: the race shows 4 marbles close together.
const EXTRA_PHONES := {"marble_race": 2, "snowball_splat": 2}
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
			c[i].send_sensor(Protocol.encode_sensor(_seq[i], Time.get_ticks_msec(), gyro[i] if not gyro.is_empty() else Vector3.ZERO,
					accel[i], 0, 0, Vector2.ZERO))
			_seq[i] += 1
		await _frames(1)


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
	game.queue_redraw()
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
