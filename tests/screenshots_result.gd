extends SceneTree
## Screenshots of the result on the phone (issue #455, REQ-FL-67a): the real pad, drawn from the real code at 1080x1920 (and
## 1080x1440). The PNGs go to the folder after `--out=` (default `user://`). Run with --role=controller and a display:
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --script tests/screenshots_result.gd \
##     -- --role=controller --out=/tmp/shots/
## Each case sets what the phone has after a `final` message (game, place, score, medal) and the personal best of the player.

const Lang = preload("res://scripts/core/lang.gd")
const ControllerClient = preload("res://scripts/net/controller_client.gd")

const AVATARS := {"DAN": 9, "MIA": 14, "ELI": 20}
const SLOT_COLORS: Array[Color] = [Color8(0x3d, 0xce, 0xf2), Color8(0xcc, 0x7e, 0x0a), Color8(0xaa, 0x3d, 0xf2),
		Color8(0xf2, 0x0c, 0x68)]

# [file, language, size, game id, place, score, medal, a personal best, player name, slot]
const CASES := [
	["01-first-place-gold", "en", Vector2i(1080, 1920), "snowball_splat", "1ST", "12", "gold", false, "NOA", 0],
	["02-second-place-silver", "en", Vector2i(1080, 1920), "snowball_splat", "2ND", "9", "silver", false, "DAN", 1],
	["04-fourth-place-no-medal", "en", Vector2i(1080, 1920), "snowball_splat", "4TH", "3", "", false, "ELI", 3],
	["07-not-finished", "en", Vector2i(1080, 1920), "maze", "3RD", "NOT FINISHED", "", false, "MIA", 2],
	["08-time", "en", Vector2i(1080, 1920), "marble_race", "1ST", "4.22 s", "gold", false, "NOA", 0],
	["20-new-best-first-score", "en", Vector2i(1080, 1920), "snowball_splat", "1ST", "12", "gold", true, "NOA", 0],
	["21-new-best-time", "en", Vector2i(1080, 1920), "marble_race", "1ST", "12.34 s", "gold", true, "NOA", 0],
	["10a-hebrew-first-place", "he", Vector2i(1080, 1920), "snowball_splat", "ראשון", "12", "gold", false, "נועה", 0],
	["24-new-best-hebrew-time", "he", Vector2i(1080, 1920), "bumper_cars", "ראשון", "123.45 ש׳", "gold", true, "נועה", 0],
	["31-new-best-1080x1440", "en", Vector2i(1080, 1440), "marble_race", "1ST", "12.34 s", "gold", true, "NOA", 0],
]


func _initialize() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _out_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			return a.trim_prefix("--out=")
	return "user://"


func _run() -> void:
	await _frames(5)
	var app: Node = root.get_node("App")
	var out := _out_dir()
	DirAccess.make_dir_recursive_absolute(out)
	var c: Node = app.client
	c._set_state(ControllerClient.State.CONNECTED)
	c.phase = "playing"
	c.tv_pid = "shot"
	c.pid = "shot"
	for cs in CASES:
		Lang.set_language(cs[1])
		var size: Vector2i = cs[2]
		var vp := SubViewport.new()
		vp.size = size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		c.slot = cs[9]
		c.color = SLOT_COLORS[cs[9]]
		c.tv_player_name = cs[8]
		c.tv_avatar = AVATARS.get(cs[8], 5)
		c.final_text = "%s   %s   %s" % [cs[4], cs[8], cs[5]]
		c.final_game = cs[3]
		c.final_place = cs[4]
		c.final_score = cs[5]
		c.final_medal = cs[6]
		app.last_best = {"pid": "shot", "key": "%s|medium" % cs[3], "value": 12, "old": 5} if cs[7] else {}
		var pad: Control = load("res://scripts/ui/controller_pad.gd").new()
		pad.theme = app.theme_res
		vp.add_child(pad)
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames(4)
		vp.get_texture().get_image().save_png("%s/%s.png" % [out, cs[0]])
		print("saved ", cs[0], " ", size)
		vp.queue_free()
		await _frames(2)
	Lang.set_language("en")
	quit()
