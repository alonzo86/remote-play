extends SceneTree
## Player profiles (FD-22, docs/PROFILES_PLAN.md): the name rules, the profile store, the avatar sheet.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/profiles.gd -- --role=controller

const Protocol = preload("res://scripts/core/protocol.gd")
const Profile = preload("res://scripts/core/profile.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")
const UiTheme = preload("res://scripts/ui/ui_theme.gd")

const TEMP := "user://test_profiles.cfg"

var _checks := 0
var _fails := 0


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _run() -> void:
	_names()
	_ids()
	_store()
	_store_files()
	await _avatars()
	await _avatar_view()


func _clean_files() -> void:
	for f in [TEMP, TEMP + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func _names() -> void:
	print("names")
	_check(Protocol.NAME_MAX == 10, "a name has at most 10 characters (docs/PROFILES_PLAN.md, decision 9)")
	_check(Profile.clean_name("  Maya  ") == "Maya", "spaces at the ends are cut")
	_check(Profile.clean_name("ABCDEFGHIJKLMNOP") == "ABCDEFGHIJ", "a long name is cut to 10 characters")
	_check(Profile.clean_name("Sam  Lee") == "Sam  Lee", "spaces inside a name stay")
	_check(Profile.clean_name("Noam\nX\t!?") == "NoamX", "control characters and signs are dropped")
	_check(Profile.clean_name("שירה") == "שירה", "a Hebrew name is allowed")
	_check(Profile.clean_name("שירה\u200f\u0591") == "שירה", "direction marks and nikud are dropped")
	_check(Profile.clean_name("Ann😀") == "Ann", "an emoji is dropped")
	_check(Profile.clean_name("   ") == "" and Profile.clean_name("!!!") == "", "a name with nothing left is empty")
	_check(Profile.filter_name("Ab ") == "Ab ", "while typing, a space at the end stays")
	_check(Profile.clean_name("12345678901") == "1234567890", "digits count as characters")
	# Every allowed character is drawn by one of the two fonts, so a name is always readable (FD-18).
	var latin := load(UiTheme.FONT_FILE) as Font
	var hebrew := load(UiTheme.FONT_HEBREW) as Font
	var missing: Array[int] = []
	for code in range(32, 0x05EB):
		if Profile.is_allowed_char(code) and not latin.has_char(code) and not hebrew.has_char(code):
			missing.append(code)
	_check(missing.is_empty(), "both pixel fonts together draw every allowed character " + str(missing))
	_check(Profile.clean_avatar(3) == 3 and Profile.clean_avatar(3.0) == 3 and Profile.clean_avatar(-1) == -1
			and Profile.clean_avatar(300) == -1 and Profile.clean_avatar("x") == -1 and Profile.clean_avatar(null) == -1,
			"an avatar index from 0 to 255 is taken, anything else is none")


func _ids() -> void:
	print("IDs")
	var a := Profile.make_id()
	var b := Profile.make_id()
	_check(a.length() == 32 and Profile.clean_id(a) == a and a != b, "an ID is 32 hex characters and two IDs differ")
	_check(Profile.clean_id(a.to_upper()) == a, "an ID in upper case is made lower case")
	_check(Profile.clean_id("-" + "a".repeat(31)) == "" and Profile.clean_id("+" + "a".repeat(31)) == ""
			and Profile.clean_id("0x" + "a".repeat(30)) == "", "an ID with a sign or a 0x prefix is empty")
	_check(Profile.clean_id("abc") == "" and Profile.clean_id("z".repeat(32)) == "" and Profile.clean_id("") == ""
			and Profile.clean_id(a + "0") == "", "a text that is not an ID is empty")
	_check(Profile.from_dict({"id": a, "name": "Maya", "avatar": 5, "rev": 2, "bests": {"x": 1}}).avatar == 5
			and Profile.from_dict({"id": "bad", "name": "Maya"}) == null and Profile.from_dict({"id": a, "name": "!!"}) == null,
			"a saved profile is read back, and a broken one is refused")


func _store() -> void:
	print("the store")
	_clean_files()
	var s := ProfileStore.new(TEMP)
	var p = s.create("  Maya ", 4)
	_check(p != null and p.player_name == "Maya" and p.avatar == 4 and s.active_id == p.id and s.profiles.size() == 1,
			"a new profile is made, cleaned, and becomes the active one")
	_check(s.create("!!!", 0) == null and s.profiles.size() == 1, "a name with nothing left makes no profile")
	var noam = s.create("Noam", 700)
	_check(noam.avatar == 255 and s.active() == noam, "an avatar index is kept in 0 to 255")
	_check(s.set_active(p.id) and s.active() == p and s.set_active("") and s.active() == null and not s.set_active("nope"),
			"the active profile can be changed, the guest is an empty ID, an unknown ID is refused")
	var rev0: int = p.rev
	_check(s.update(p.id, "Maya", 4) and p.rev == rev0, "saving the same values does not count as an edit")
	_check(s.update(p.id, "Mayaaaaaaaaaaa", 9) and p.player_name == "Mayaaaaaaa" and p.avatar == 9 and p.rev == rev0 + 1,
			"an edit cuts the name, keeps the avatar and raises the edit number")
	_check(not s.update(p.id, "", 1) and not s.update("nope", "X", 1), "an empty name and an unknown ID are refused")
	for i in 6:
		s.create("P%d" % i, i)
	_check(s.profiles.size() == ProfileStore.MAX_PROFILES and s.is_full() and s.create("Extra", 1) == null,
			"a phone holds 8 profiles and not more")
	s.set_active(noam.id)
	_check(s.delete(noam.id) and s.find(noam.id) == null and s.active_id == "" and not s.delete(noam.id),
			"deleting the active profile makes the guest active")
	_clean_files()


func _store_files() -> void:
	print("the file")
	_clean_files()
	var s := ProfileStore.new(TEMP)
	var maya = s.create("Maya", 2)
	maya.bests["k"] = 12
	var noam = s.create("Noam", 5)
	s.set_active(maya.id)
	_check(s.last_save_ok and FileAccess.file_exists(TEMP), "a change is written at once")
	var r := ProfileStore.new(TEMP)
	r.load_from_disk()
	_check(r.profiles.size() == 2 and r.active_id == maya.id and r.find(noam.id).player_name == "Noam"
			and r.find(maya.id).avatar == 2 and r.find(maya.id).bests.get("k", 0) == 12,
			"the profiles, the active one and the bests are read back")
	var f := FileAccess.open(TEMP, FileAccess.WRITE)   # A broken file: the copy before the last write is used.
	f.store_string("not a config [[[")
	f.close()
	var b := ProfileStore.new(TEMP)
	b.load_from_disk()
	_check(b.profiles.size() == 2, "a file that cannot be read is replaced by the .bak copy")
	b.set_active(maya.id)   # The next write must not copy the broken file over the good copy.
	var kept := ConfigFile.new()
	_check(kept.load(TEMP + ".bak") == OK and kept.has_section("meta"), "a broken file never replaces the good .bak copy")
	_clean_files()
	var e := ProfileStore.new(TEMP)
	e.load_from_disk()
	_check(e.profiles.is_empty() and e.active_id == "", "no file is an empty list and the guest")
	var bad := ProfileStore.new("user://no_such_dir/profiles.cfg")
	bad.create("Maya", 1)
	_check(not bad.last_save_ok and bad.profiles.size() == 1, "a failed write is reported and the change stays in memory")
	_clean_files()


func _avatars() -> void:
	print("the avatar sheet")
	_check(Avatar.texture() != null and Avatar.texture().get_width() == 64 and Avatar.texture().get_height() == 128,
			"the sheet is 64 x 128 px: 32 avatars of 16 px in 4 columns and 8 rows")
	_check(Avatar.is_known(0) and Avatar.is_known(31) and not Avatar.is_known(32) and not Avatar.is_known(-1),
			"avatars 0 to 31 exist; an index of a later sheet is unknown")
	_check(Avatar.region(0) == Rect2(0, 0, 16, 16) and Avatar.region(5) == Rect2(16, 16, 16, 16)
			and Avatar.region(15) == Rect2(48, 48, 16, 16) and Avatar.region(31) == Rect2(48, 112, 16, 16),
			"an index maps to its cell, row by row")
	_check(Avatar.scale_for(15.0) == 1 and Avatar.scale_for(16.0) == 1 and Avatar.scale_for(47.0) == 2
			and Avatar.scale_for(280.0) == 17, "an avatar is drawn at a whole-number scale, 1 at the least")
	# Every avatar has pixels, a black outline and a different picture (an empty cell would be an empty avatar).
	var img := Avatar.texture().get_image()
	var seen := {}
	var all_ok := true
	for i in Protocol.AVATAR_COUNT:
		var cell := img.get_region(Rect2i(Avatar.region(i)))
		var opaque := 0
		for y in 16:
			for x in 16:
				if cell.get_pixel(x, y).a > 0.0:
					opaque += 1
		all_ok = all_ok and opaque > 60 and cell.get_pixel(8, 8).a > 0.0
		seen[cell.get_data().hex_encode()] = true
	_check(all_ok and seen.size() == Protocol.AVATAR_COUNT, "all 32 avatars are drawn and no two are the same")
	var canvas := Control.new()
	root.add_child(canvas)
	var drew := []
	var area := Rect2(0, 0, 64, 64)
	canvas.draw.connect(func(): drew.append([Avatar.draw(canvas, area, 3), Avatar.draw(canvas, area, 40)]))
	canvas.queue_redraw()
	await process_frame
	await process_frame
	_check(not drew.is_empty() and drew[0] == [true, false] and canvas.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"drawing an avatar uses sharp pixels; an unknown index draws nothing")
	canvas.queue_free()


func _avatar_view() -> void:
	print("the avatar control")
	var view: Control = load("res://scripts/ui/avatar_view.gd").new(2, 80.0)
	root.add_child(view)
	view.size = Vector2(80, 80)
	var taps := []
	view.pressed.connect(func(): taps.append(view.index))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	var tap := func(down_at: Vector2, up_at: Vector2) -> void:
		click.pressed = true
		click.position = down_at
		view._gui_input(click)
		click.pressed = false
		click.position = up_at
		view._gui_input(click)
	tap.call(Vector2(40, 40), Vector2(44, 41))
	_check(taps == [2], "a tap (the finger goes down and up in the same place) sends pressed with the avatar")
	tap.call(Vector2(40, 10), Vector2(40, 70))
	_check(taps == [2], "a drag that scrolls the picker does not pick")
	view.tappable = false
	tap.call(Vector2(40, 40), Vector2(40, 40))
	_check(taps == [2], "a control that is not tappable sends nothing")
	view.set_index(7)
	view.set_selected(true)
	await process_frame
	_check(view.index == 7 and view.selected and view.custom_minimum_size == Vector2(80, 80), "the picker can move the choice")
	view.queue_free()
