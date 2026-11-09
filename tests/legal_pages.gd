extends SceneTree
## The privacy and terms pages of the website (issue #37). Run:
##   godot --headless --path . --script tests/legal_pages.gd -- --role=controller
## 1. The four pages are the output of tools/make_legal_pages.py for the four texts of docs/legal (a text changed and the pages
##    not made again fails here). 2. Each page has the same number of headings as its text and no leftover "Coming soon" and
##    no raw Markdown. 3. The Hebrew pages are right to left and the pages link to each other. 4. The converter stops on a kind
##    of line that it does not know, and it turns the one table into a table.

const PAIRS := [
	["docs/legal/privacy-notice.md", "site/privacy.html", "en"],
	["docs/legal/privacy-notice.he.md", "site/he/privacy.html", "he"],
	["docs/legal/terms.md", "site/terms.html", "en"],
	["docs/legal/terms.he.md", "site/he/terms.html", "he"],
]

var _fails := 0
var _checks := 0


func _initialize() -> void:
	if not preload("res://tests/import_guard.gd").ok():
		quit(1)
		return
	_run()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _read(path: String) -> String:
	return FileAccess.get_file_as_string("res://" + path)


func _python(args: Array) -> Dictionary:
	var out := []
	var argv := [ProjectSettings.globalize_path("res://tools/make_legal_pages.py")]
	argv.append_array(args)
	var code := OS.execute("python3", argv, out, true)
	return {"code": code, "out": "\n".join(out)}


func _run() -> void:
	var r := _python(["--check"])
	if int(r.code) == -1:
		print("  skip python3 is not installed: the pages are not compared")
	else:
		_check(int(r.code) == 0, "the four pages are up to date (tools/make_legal_pages.py --check): %s" % str(r.out).strip_edges())
	for p in PAIRS:
		var md := _read(p[0])
		var page := _read(p[1])
		var heads_md := 0
		for line in md.split("\n"):
			if line.begins_with("# ") or line.begins_with("## "):
				heads_md += 1
		var heads_page := page.count("<h1>") + page.count("<h2>")
		_check(heads_md > 5 and heads_md == heads_page, "%s has the %d headings of its text (%d)" % [p[1], heads_md, heads_page])
		_check(not page.contains("Coming soon") and not page.contains("בקרוב"), "%s has no placeholder text" % p[1])
		_check(not page.contains("**") and not page.contains("&lt;div"), "%s has no raw Markdown" % p[1])
		_check(page.contains('lang="he" dir="rtl"') == (p[2] == "he"), "%s: right to left only for the Hebrew page" % p[1])
		var other: String = "../" + String(p[1]).get_file() if p[2] == "he" else "he/" + String(p[1]).get_file()
		_check(page.contains('href="%s"' % other), "%s links to its twin in the other language (%s)" % [p[1], other])
	_check(_read("site/privacy.html").contains("<table>") and _read("site/he/privacy.html").contains("<table>"),
			"the table of the privacy notice is a table in both languages")
	_check(_read("site/get/index.html").contains("../privacy.html") and _read("site/get/index.html").contains("../terms.html"),
			"the page of the QR code links to the privacy notice and the terms")
	print("\n%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
