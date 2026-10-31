extends SceneTree
## Which requirement ids no test names (issue #306, REQ-GM-4: code comments and tests use the requirement ID). The ids come from
## docs/games/*.md (not the template), docs/GAME_REQUIREMENTS.md and docs/TV_FLOW.md. An id is named when its full text
## `REQ-XX-n` is in a test (tests/*.gd, tests/*.sh), a tool (tools/), docs/MANUAL_TESTS.md or
## docs/AUTOMATED_TESTS.md; a short list
## after one id, `REQ-PG-5, 6 and 21`, names each id of the list. A range (`REQ-GM-90 to 95`) and a wildcard
## (`REQ-MG-*`) name nothing.
## An id that no file names must be in tests/req_untested.txt: `ID | bucket | reason`. The buckets are
##   todo      a headless test can check it and nobody has written it yet; the reason says how. Take the line away with the test.
##   device    only a device or a person can check it; the row has the status Device, or the reason names the manual Test.
##   review    a rule of work or of taste that the code-reviewer or the localization-reviewer judges; no machine can.
##   obsolete  the requirement is removed, superseded or says something that is no longer true: the owner decides what to do.
## The suite fails for an id that is neither named nor listed, for a listed id that a test names now (take the line away), for a
## listed id that is not in a requirements file, for a bucket that is not one of the four and for a line with no reason. Run:
##   godot --headless --path . --script tests/req_ids.gd -- --role=controller

const BUCKETS := ["todo", "device", "review", "obsolete"]
const DEFINING := ["res://docs/GAME_REQUIREMENTS.md", "res://docs/TV_FLOW.md"]
const NAMING_DIRS := ["res://tests", "res://tools"]
const NAMING_FILES := ["res://docs/MANUAL_TESTS.md", "res://docs/AUTOMATED_TESTS.md"]
const ALLOWLIST := "res://tests/req_untested.txt"

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
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_scanner()
	_problems_of_lists()
	_real_files()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


## The ids that `text` names, as a set {id: true}.
static func named_in(text: String) -> Dictionary:
	var out := {}
	var head := RegEx.create_from_string("REQ-([A-Z0-9]+)-([0-9]+)([a-z]?)"
			+ "((?:(?:,|, and| and) [0-9]+[a-z]?(?![A-Za-z0-9-]))*)(?![A-Za-z0-9-])")
	var tail := RegEx.create_from_string("(?:,|, and| and) ([0-9]+[a-z]?)")
	for m in head.search_all(text):
		var prefix := m.get_string(1)
		out["REQ-%s-%s%s" % [prefix, m.get_string(2), m.get_string(3)]] = true
		for t in tail.search_all(m.get_string(4)):
			out["REQ-%s-%s" % [prefix, t.get_string(1)]] = true
	return out


## The ids that a requirements file defines: {id: the line}. An id is defined at the start of a row or of a list item.
static func defined_in(text: String) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("^[-|* #]*\\**(REQ-[A-Z0-9]+-[0-9]+[a-z]?)(?![A-Za-z0-9])")
	for line in text.split("\n"):
		var m := re.search(line)
		if m != null and not out.has(m.get_string(1)):
			out[m.get_string(1)] = line
	return out


## The lines of the list: {id: [bucket, reason]}; `errors` gets the lines that cannot be read.
static func list_of(text: String, errors: Array[String]) -> Dictionary:
	var out := {}
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var cells := line.split("|", true, 2)
		if cells.size() < 3:
			errors.append("not `id | bucket | reason`: " + line)
			continue
		var id := cells[0].strip_edges()
		if out.has(id):
			errors.append("listed twice: " + id)
		out[id] = [cells[1].strip_edges(), cells[2].strip_edges()]
	return out


## What is wrong between the defined ids, the named ids and the list. Empty when all is well.
static func problems(defined: Dictionary, named: Dictionary, listed: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in defined:
		if not named.has(id) and not listed.has(id):
			out.append("%s is named by no test and is not in the list" % id)
	for id in listed:
		var bucket: String = listed[id][0]
		var reason: String = listed[id][1]
		if not defined.has(id):
			out.append("%s is in the list, but no requirements file defines it" % id)
			continue
		if named.has(id):
			out.append("%s is named by a test now: take it out of the list" % id)
		if not BUCKETS.has(bucket):
			out.append("%s: the bucket '%s' is not one of %s" % [id, bucket, str(BUCKETS)])
		if reason.length() < 12:
			out.append("%s: the reason is missing or too short" % id)
		if bucket == "device" and not String(defined[id]).contains("| Device |") and not reason.contains("Test "):
			out.append("%s: a device id has the status Device or names its manual Test in the reason" % id)
	return out


func _scanner() -> void:
	print("the scanner")
	var n := named_in("# REQ-PG-5, 6 and 21, REQ-GM-47d, 47e. REQ-GM-90 to 95. REQ-MG-*. REQ-AB-3 m. See REQ-X1-2a.")
	_check(n.has("REQ-PG-5") and n.has("REQ-PG-6") and n.has("REQ-PG-21") and n.has("REQ-GM-47d") and n.has("REQ-GM-47e"),
			"a short list after an id names each id of the list")
	_check(n.has("REQ-GM-90") and not n.has("REQ-GM-91") and not n.has("REQ-GM-95") and n.size() == 8,
			"a range names its first id only, a wildcard names nothing: %s" % str(n.keys()))
	_check(n.has("REQ-AB-3") and n.has("REQ-X1-2a"), "an id with a letter or a digit in the prefix is read")
	_check(not named_in("REQ-MR-12-b and REQ-MR-4x").has("REQ-MR-4"),
			"an id that continues with a letter or a dash is not the shorter id")
	var d := defined_in("| REQ-AH-1 | text REQ-AH-2 | Done | x |\n- REQ-GM-3: rule\n  - REQ-GM-47c: sub\n"
			+ "| ID | head |\nsee REQ-FL-9\n")
	_check(d.keys() == ["REQ-AH-1",
			"REQ-GM-3", "REQ-GM-47c"], "an id is defined at the start of a row or a list item only: %s" % str(d.keys()))
	var errors: Array[String] = []
	var l := list_of("# note\n\nREQ-A-1 | todo | a long enough reason\nREQ-A-2 |obsolete| why\nbad line\n"
			+ "REQ-A-1 | review | again", errors)
	_check(l.size() == 2 and l["REQ-A-1"][0] == "review" and errors.size() == 2,
			"the list is read: %s %s" % [str(l), str(errors)])


func _problems_of_lists() -> void:
	print("the rules of the list")
	var defined := {"REQ-A-1": "| REQ-A-1 | x | Done | t |", "REQ-A-2": "| REQ-A-2 | x | Device | t |",
			"REQ-A-3": "| REQ-A-3 | x | Done | t |"}
	var ok := problems(defined, {"REQ-A-1": true}, {"REQ-A-2": ["device", "Device status, the feel of a swing"],
			"REQ-A-3": ["todo", "a headless test can read it"]})
	_check(ok.is_empty(), "named, listed and a listed device id with the status Device: no problem %s" % str(ok))
	_check(problems(defined, {}, {"REQ-A-2": ["device",
			"reason is long enough"], "REQ-A-3": ["review", "reason is long enough"]}).size() == 1,
			"an id that is not named and not listed is a problem")
	var bad := problems(defined, {"REQ-A-1": true},
			{"REQ-A-1": ["todo", "long enough reason"], "REQ-A-9": ["todo", "long enough reason"],
			"REQ-A-2": ["maybe", "long enough reason"], "REQ-A-3": ["review", "short"]})
	_check(bad.size() == 4,
			"a listed id that is named, one that is not defined, a wrong bucket and a missing reason: %s" % str(bad))
	var dev := problems({"REQ-A-3": "| REQ-A-3 | x | Done | t |"}, {}, {"REQ-A-3": ["device", "needs a person to look at it"]})
	_check(dev.size() == 1, "a device id with the status Done needs the manual Test in its reason")
	_check(problems({"REQ-A-3": "x"}, {}, {"REQ-A-3": ["device", "see Test 12 step 3 of the manual tests"]}).is_empty(),
			"a device id that names its manual Test is fine")


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _real_files() -> void:
	print("the requirement ids of the repository")
	var defined := {}
	var docs: Array[String] = []
	docs.append_array(DEFINING)
	for f in DirAccess.get_files_at("res://docs/games"):
		if f.ends_with(".md") and f != "TEMPLATE.md":
			docs.append("res://docs/games/" + f)
	for path in docs:
		defined.merge(defined_in(_read(path)))
	var named := {}
	var files: Array[String] = []
	files.append_array(NAMING_FILES)
	for dir in NAMING_DIRS:
		files.append_array(_text_files(dir))
	for path in files:
		if path == "res://tests/req_ids.gd":
			continue   # Its own examples are not tests of a requirement.
		named.merge(named_in(_read(path)))
	var errors: Array[String] = []
	var listed := list_of(_read(ALLOWLIST), errors)
	_check(defined.size() > 400 and named.size() > 300,
			"the scan finds the requirements and their tests: %d ids, %d named" % [defined.size(), named.size()])
	_check(errors.is_empty(), "every line of tests/req_untested.txt reads as `id | bucket | reason` %s" % str(errors))
	var found := problems(defined, named, listed)
	for p in found:
		print("    ", p)
	_check(found.is_empty(),
			"every requirement id is named by a test or listed in tests/req_untested.txt (%d listed)" % listed.size())


func _text_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_text_files(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".sh") or f.ends_with(".py") or f.ends_with(".txt") and f != "req_untested.txt":
			out.append(dir.path_join(f))
	return out
