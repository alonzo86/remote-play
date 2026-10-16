extends SceneTree
## The copy of a player profile (FD-22, docs/PROFILES_PLAN.md 6): the table of best keys, the text of a profile (`WP1.`), the
## rules for a code that comes from outside, and the merge of an imported profile.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/profile_code.gd -- --role=controller

const Profile = preload("res://scripts/core/profile.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")
const ProfileStore = preload("res://scripts/core/profile_store.gd")
const QrEncoder = preload("res://scripts/core/qr_encoder.gd")

const ID_A := "9f2c4e7a1b3d5f60718293a4b5c6d7e8"
const ID_B := "00112233445566778899aabbccddeeff"
const TEMP := "user://test_profile_code.cfg"
const GOLDEN := "WP1.AZ8sTnobPV9gcYKTpLXG1-gLAwRNYXlhAwLUAgQRHpLCArDh"

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
	_keys()
	_round_trip()
	_refused()
	_skipped_and_cleaned()
	_merge()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _profile(p_id: String, p_name: String, av: int, rev := 0, bests := {}) -> RefCounted:
	var p = Profile.new()
	p.id = p_id
	p.player_name = p_name
	p.avatar = av
	p.rev = rev
	p.bests = bests
	return p


## A code from raw bytes, with a right checksum, so that a test can break one rule at a time.
func _raw(body: PackedByteArray) -> String:
	var b := body.duplicate()
	var crc := ProfileCode.crc16(b)
	b.append(crc >> 8)
	b.append(crc & 0xFF)
	return ProfileCode.PREFIX + Marshalls.raw_to_base64(b).replace("+", "-").replace("/", "_").replace("=", "")


## The bytes of a valid code up to the name, then `rest` (the number of bests and the bests).
func _body(p_name: String, rest: Array) -> PackedByteArray:
	var b := PackedByteArray([1])
	b.append_array(ID_A.hex_decode())
	b.append_array(PackedByteArray([3, 5]))
	var nb := p_name.to_utf8_buffer()
	b.append(nb.size())
	b.append_array(nb)
	b.append_array(PackedByteArray(rest))
	return b


func _keys() -> void:
	print("the table of keys")
	var keys := ProfileKeys.all_keys()
	var round_ok := true
	for i in keys.size():
		round_ok = round_ok and ProfileKeys.number_of(keys[i]) == i + 1 and ProfileKeys.key_of(i + 1) == keys[i]
	_check(keys.size() == 39 and round_ok and keys.size() <= ProfileKeys.MAX_KEYS, "39 keys, each with its own number from 1")
	_check(ProfileKeys.number_of("snowball_splat|easy") == 1 and ProfileKeys.number_of("paint_grab|hard") == 6
			and ProfileKeys.number_of("marble_race|easy|1") == 7 and ProfileKeys.number_of("marble_race|hard|10") == 36
			and ProfileKeys.number_of("asteroid_blast|easy") == 37 and ProfileKeys.number_of("asteroid_blast|hard") == 39,
			"the numbers are fixed (a saved code depends on them)")
	_check(ProfileKeys.number_of("maze|easy") == 0 and ProfileKeys.number_of("sumo_bumpers|easy") == 0
			and ProfileKeys.key_of(0) == "" and ProfileKeys.key_of(40) == "", "maze, sumo and an unknown number have no key")
	_check(ProfileKeys.lower_is_better("marble_race|easy|2") and not ProfileKeys.lower_is_better("paint_grab|easy"),
			"a race time is better when lower, a score when higher")
	_check(ProfileKeys.is_better("paint_grab|easy", 9, 5) and not ProfileKeys.is_better("paint_grab|easy", 5, 9)
			and ProfileKeys.is_better("marble_race|easy|1", 9000, 12000) and not ProfileKeys.is_better("marble_race|easy|1", 12000, 9000)
			and ProfileKeys.is_better("paint_grab|easy", 1, 0) and not ProfileKeys.is_better("paint_grab|easy", 0, 5)
			and not ProfileKeys.is_better("paint_grab|easy", 5, 5), "better, worse, the first value, a value of 0 and a tie")


func _round_trip() -> void:
	print("encode and decode")
	var bests := {"snowball_splat|medium": 340, "marble_race|hard|4": 41234, "paint_grab|easy": 17}
	var p := _profile(ID_A, "Maya", 11, 3, bests)
	var code := ProfileCode.encode(p)
	var r := ProfileCode.decode(code)
	var q = r.get("profile")
	_check(code.begins_with("WP1.") and r.ok and q.id == ID_A and q.player_name == "Maya" and q.avatar == 11 and q.rev == 3
			and q.bests == bests, "a profile gives the same profile back: %s" % code)
	var heb = ProfileCode.decode(ProfileCode.encode(_profile(ID_B, "אבגדהוזחטי", 255, 20000))).get("profile")
	_check(heb != null and heb.player_name == "אבגדהוזחטי" and heb.avatar == 255 and heb.rev == 20000,
			"a Hebrew name of 10 letters (20 bytes), avatar 255 and a big rev stay the same")
	var all := {}
	for k in ProfileKeys.all_keys():
		all[k] = 4000000000
	var big := ProfileCode.encode(_profile(ID_A, "אבגדהוזחטי", 15, 300, all))
	var back = ProfileCode.decode(big).get("profile")
	_check(back != null and back.bests == all and not QrEncoder.encode(big).is_empty(),
			"the largest profile (39 bests, a name of 20 bytes) is read back and fits in a QR code: %d characters" % big.length())
	var blast := {"asteroid_blast|easy": 800, "asteroid_blast|medium": 1800, "asteroid_blast|hard": 3200}
	var blast_back = ProfileCode.decode(ProfileCode.encode(_profile(ID_A, "Maya", 3, 1, blast))).get("profile")
	_check(blast_back != null and blast_back.bests == blast,
			"the bests of keys 37 to 39 (Galaxy Protector) survive a code (REQ-AB-18)")
	var small := ProfileCode.encode(_profile(ID_A, "Maya", 1))
	_check(small.length() < 70 and not QrEncoder.encode(small).is_empty(),
			"a profile with no bests is short: %d characters" % small.length())
	var odd := {"maze|easy": 5, "paint_grab|easy": 0, "paint_grab|hard": 4500000000}
	var clean_out := ProfileCode.encode(_profile(ID_A, "Maya", 1, 0, odd))
	_check(ProfileCode.decode(clean_out).profile.bests == {}, "a best that has no key, is 0, or is too big is not written")
	_check(ProfileCode.decode("  " + code + "\n").ok, "spaces and a new line around the code are removed")
	_check(code == GOLDEN, "a fixed profile gives a fixed text (this protects the numbers of ProfileKeys): %s" % code)


func _refused() -> void:
	print("a code that is refused")
	var good := ProfileCode.encode(_profile(ID_A, "Maya", 1, 0, {"paint_grab|easy": 7}))
	var at := good.length() - 3
	var broken := good.substr(0, at) + ("A" if good[at] != "A" else "B") + good.substr(at + 1)
	var cases := {
		"a wrong prefix": "WP2." + good.substr(4),
		"no prefix": good.substr(4),
		"a TV link": "ws://192.168.1.5:47801/KQZM",
		"empty": "",
		"one changed letter (the checksum)": broken,
		"a cut code": good.substr(0, good.length() - 8),
		"a sign that base64url does not have": good.substr(0, 10) + "!" + good.substr(11),
		"another format version": _raw(PackedByteArray([2]) + _body("Maya", [0]).slice(1)),
		"a name of 21 bytes": _raw(_body("a".repeat(21), [0])),
		"an empty name": _raw(_body("", [0])),
		"a name with no allowed letter": _raw(_body("!!!", [0])),
		"40 bests": _raw(_body("Maya", [40])),
		"the same key twice": _raw(_body("Maya", [2, 1, 5, 1, 6])),
		"bytes after the last best": _raw(_body("Maya", [0, 9])),
		"a best that is cut": _raw(_body("Maya", [1, 1])),
		"a number that never ends": _raw(_body("Maya", [1, 1, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80])),
	}
	var ok := true
	for what in cases:
		var r := ProfileCode.decode(cases[what])
		if r.ok or r.get("reason", "") != ProfileCode.REASON_BAD:
			ok = false
			print("    accepted: ", what)
	_check(ok, "all %d broken codes are refused with the one message" % cases.size())


func _skipped_and_cleaned() -> void:
	print("the rules for what is read")
	# 4 bests: an unknown number (200), a value of 0, a value above 4e9 (5 bytes: 0xFF 0xFF 0xFF 0xFF 0x1F) and a good one.
	var rest := [4, 200, 5, 1, 0, 2, 0xFF, 0xFF, 0xFF, 0xFF, 0x1F, 3, 9]
	var r := ProfileCode.decode(_raw(_body("Maya", rest)))
	_check(r.ok and r.profile.bests == {"snowball_splat|hard": 9},
			"an unknown key, a value of 0 and a value above 4 000 000 000 are skipped")
	var dirty := ProfileCode.decode(_raw(_body("Ma\nya!! 12345678", [0])))
	_check(dirty.ok and dirty.profile.player_name == "Maya 12345", "a name with other signs is cleaned and cut at 10 characters")


func _merge() -> void:
	print("import and merge")
	var s := ProfileStore.new(TEMP)
	var added := s.import_profile(_profile(ID_A, "Maya", 2, 4, {"paint_grab|easy": 10, "marble_race|easy|1": 30000}))
	_check(added.status == "added" and s.profiles.size() == 1 and s.active_id == ID_A,
			"a new profile is added and, as the first one, is active")
	var second := s.import_profile(_profile(ID_B, "Noam", 5))
	_check(second.status == "added" and s.profiles.size() == 2 and s.active_id == ID_A,
			"a second new profile does not change the active one")
	var better := {"paint_grab|easy": 8, "marble_race|easy|1": 25000, "snowball_splat|easy": 99}
	var merged := s.import_profile(_profile(ID_A, "Mia", 7, 6, better))
	var a = s.find(ID_A)
	_check(merged.status == "merged" and s.profiles.size() == 2 and a.player_name == "Mia" and a.avatar == 7 and a.rev == 6,
			"the copy with the higher rev gives the name and the avatar")
	_check(a.bests == {"paint_grab|easy": 10, "marble_race|easy|1": 25000, "snowball_splat|easy": 99},
			"each best is the better value (higher score, lower time) and a key in one profile only stays")
	s.import_profile(_profile(ID_A, "Old", 1, 2, {"paint_grab|easy": 3}))
	_check(a.player_name == "Mia" and a.avatar == 7 and a.rev == 6, "an old copy never replaces a newer rename")
	s.import_profile(_profile(ID_A, "Old", 1, 2, {"marble_race|easy|1": 40000}))
	_check(a.bests["marble_race|easy|1"] == 25000, "a slower imported time does not replace the local one")
	s.import_profile(_profile(ID_A, "Same", 9, 6))
	_check(a.player_name == "Mia", "with the same rev the local name stays")
	var s2 := ProfileStore.new(TEMP)
	s2.load_from_disk()
	_check(s2.find(ID_A) != null and s2.find(ID_A).player_name == "Mia" and s2.find(ID_A).bests["snowball_splat|easy"] == 99,
			"the merge is saved to the file")
	var f := ProfileStore.new(TEMP + ".full")
	for i in ProfileStore.MAX_PROFILES:
		f.create("P%d" % i, i)
	var full := f.import_profile(_profile(ID_B, "Late", 1))
	_check(full.status == "full" and f.profiles.size() == ProfileStore.MAX_PROFILES and f.find(ID_B) == null,
			"a new profile is refused when the phone has 8; a known one still merges")
	for path in [TEMP, TEMP + ".bak", TEMP + ".full", TEMP + ".full.bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
