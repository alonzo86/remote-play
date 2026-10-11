extends RefCounted
## The profiles of one phone (FD-22): up to `MAX_PROFILES`, the active one, saved in a file. Before each write the old file is
## copied to `<path>.bak`; a file that cannot be read is replaced by the copy.

const Profile = preload("res://scripts/core/profile.gd")
const ProfileKeys = preload("res://scripts/core/profile_keys.gd")
const ProfileCode = preload("res://scripts/core/profile_code.gd")

const MAX_PROFILES := 8

var path := "user://profiles.cfg"
var profiles: Array = []   # of Profile
var active_id := ""        # Empty: the guest (no profile).
var last_save_ok := true


func _init(p_path := "user://profiles.cfg") -> void:
	path = p_path


func is_full() -> bool:
	return profiles.size() >= MAX_PROFILES


func find(id: String) -> Variant:
	for p in profiles:
		if p.id == id:
			return p
	return null


## The active profile, or null for the guest.
func active() -> Variant:
	return find(active_id) if active_id != "" else null


## Makes `id` the active profile ("" is the guest). Returns false for an ID that is not in the list.
func set_active(id: String) -> bool:
	if id != "" and find(id) == null:
		return false
	active_id = id
	save()
	return true


## Makes a profile and sets it active. Returns null when the list is full or the name is empty.
func create(p_name: String, avatar: int) -> Variant:
	var clean := Profile.clean_name(p_name)
	if is_full() or clean == "":
		return null
	var p = Profile.new()
	p.id = Profile.make_id()
	p.player_name = clean
	p.avatar = clampi(avatar, 0, 255)
	profiles.append(p)
	active_id = p.id
	save()
	return p


## Changes the name and the avatar. `rev` goes up when something changed. Returns false for an unknown ID or an empty name.
func update(id: String, p_name: String, avatar: int) -> bool:
	var p = find(id)
	var clean := Profile.clean_name(p_name)
	if p == null or clean == "":
		return false
	var av := clampi(avatar, 0, 255)
	if clean != p.player_name or av != p.avatar:
		p.player_name = clean
		p.avatar = av
		p.rev += 1
		save()
	return true


## Takes a profile that was read from a code (`ProfileCode.decode`). A profile with a new ID is added (it becomes the active one
## when the phone had no profile). A profile with an ID that the phone has is merged (docs/PROFILES_PLAN.md 6.5): the higher
## `rev` gives the name and the avatar (equal: the local one stays), and each best is the better value, a key in one profile
## only is kept. Returns {"status": "added" | "merged" | "full", "id": the ID}; "full" means 8 profiles and nothing changed.
func import_profile(imp: RefCounted) -> Dictionary:
	var local = find(imp.id)
	if local == null:
		if is_full():
			return {"status": "full", "id": imp.id}
		var first := profiles.is_empty()
		profiles.append(imp)
		if first:
			active_id = imp.id
		save()
		return {"status": "added", "id": imp.id}
	if imp.rev > local.rev:
		local.player_name = imp.player_name
		local.avatar = imp.avatar
		local.rev = imp.rev
	for key in imp.bests:
		if not local.bests.has(key) or ProfileKeys.is_better(String(key), int(imp.bests[key]), int(local.bests[key])):
			local.bests[key] = imp.bests[key]
	save()
	return {"status": "merged", "id": imp.id}


## Counts the result of a round for a profile (FD-22, REQ-GM-98): `value` becomes the best of that profile for `key` when it is
## better than the saved one (a lower time or a higher score, by `ProfileKeys`). A key that is not in the table, a value of 0 or
## less and a value above `ProfileCode.VALUE_MAX` change nothing.
## Returns {"new_best": bool, "old": the best before, 0 when there was none}.
func record_best(id: String, key: String, value: int) -> Dictionary:
	var p = find(id)
	if p == null or ProfileKeys.number_of(key) == 0 or value <= 0 or value > ProfileCode.VALUE_MAX:
		return {"new_best": false, "old": 0}
	var old := int(p.bests.get(key, 0))
	if not ProfileKeys.is_better(key, value, old):
		return {"new_best": false, "old": old}
	p.bests[key] = value
	save()
	return {"new_best": true, "old": old}


## Removes a profile. The guest becomes active when it was the active one.
func delete(id: String) -> bool:
	var p = find(id)
	if p == null:
		return false
	profiles.erase(p)
	if active_id == id:
		active_id = ""
	save()
	return true


## Writes the file. `last_save_ok` is false when it failed; the changes stay in memory.
func save() -> void:
	var current := ConfigFile.new()
	if current.load(path) == OK and current.has_section("meta"):   # A broken file never replaces the good copy.
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "active", active_id)
	cfg.set_value("meta", "count", profiles.size())
	for i in profiles.size():
		cfg.set_value("p%d" % i, "data", profiles[i].to_dict())
	last_save_ok = cfg.save(path) == OK


## Reads the file, or the `.bak` copy when the file cannot be read. An empty list when there is nothing.
func load_from_disk() -> void:
	profiles.clear()
	active_id = ""
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section("meta"):   # A file with no "meta" part is not one of ours: use the copy.
		cfg = ConfigFile.new()
		if cfg.load(path + ".bak") != OK or not cfg.has_section("meta"):
			return
	var n := clampi(int(cfg.get_value("meta", "count", 0)), 0, MAX_PROFILES)
	for i in n:
		var d = cfg.get_value("p%d" % i, "data", {})
		var p = Profile.from_dict(d) if d is Dictionary else null
		if p != null and find(p.id) == null:
			profiles.append(p)
	var act := String(cfg.get_value("meta", "active", ""))
	active_id = act if find(act) != null else ""
