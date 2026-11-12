extends SceneTree
## The privacy and terms pages of the website (issue #37). Run:
##   godot --headless --path . --script tests/legal_pages.gd -- --role=controller
## 1. The four pages are the output of tools/make_legal_pages.py for the four texts of docs/legal (a text changed and the pages
##    not made again fails here). 2. The words of each page, in order, are the words of its text (so a fault of the converter is
##    not copied into the page and called up to date). 3. Each page has the same number of headings as its text and no leftover
##    "Coming soon" and no raw Markdown. 4. The Hebrew pages are right to left and the pages link to each other. 5. The
##    converter stops on a kind of line that it does not know and keeps what it knows. python3 is needed: when it is missing the
##    checks 1 and 5 are skipped (the CI has it).

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


## The words of a text, in order, without the marks of Markdown.
func _md_words(md: String) -> PackedStringArray:
	var words := PackedStringArray()
	for line in md.split("\n"):
		if line.strip_edges() in ["<div dir=\"rtl\" lang=\"he\">", "</div>"]:
			continue
		# A link is its address, and a full stop after it is a word of its own.
		var plain := RegEx.create_from_string("<(https?://[^>\\s]+)>").sub(line, " $1 ", true)
		for t in plain.replace("**", " ").replace("`", " ").replace("|", " ").split(" ", false):
			var w := t.strip_edges()
			var marker := RegEx.create_from_string("^([#-]+|[-:]+)$").search(w) != null
			if w != "" and not marker:
				words.append(w)
	return words


## The words of a page between <main> and </main>, in order.
func _page_words(page: String) -> PackedStringArray:
	var main_part := page.get_slice("<main>", 1).get_slice("</main>", 0)
	var no_tags := RegEx.create_from_string("<[^>]+>").sub(main_part, " ", true)
	no_tags = no_tags.replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
	var words := PackedStringArray()
	for t in no_tags.split(" ", false):
		for u in String(t).split("\n", false):
			var w := String(u).strip_edges()
			if w != "":
				words.append(w)
	return words


## Runs the converter on `text`: {"code": the exit code, "out": the HTML or the message}.
func _convert(text: String) -> Dictionary:
	var out := []
	var script := "import sys; sys.path.insert(0, sys.argv[1]); import make_legal_pages as m; " \
			+ "print(m.convert(sys.argv[2])[1])"
	var code := OS.execute("python3", ["-c", script, ProjectSettings.globalize_path("res://tools"), text], out, true)
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
		var wm := _md_words(md)
		var wp := _page_words(page)
		var first_diff := -1
		for k in mini(wm.size(), wp.size()):
			if wm[k] != wp[k]:
				first_diff = k
				break
		var shown_md: String = wm[first_diff] if first_diff >= 0 else "-"
		var shown_page: String = wp[first_diff] if first_diff >= 0 else "-"
		_check(wm.size() == wp.size() and first_diff < 0,
				"%s has the words of its text, in order (text %d, page %d, first difference: %s | %s)"
				% [p[1], wm.size(), wp.size(), shown_md, shown_page])
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
	if int(r.code) != -1:
		for bad in ["a\n- x\n  more", "a\n2. b", "a\n> q", "*it*", "a _u_ b", "| a | b |\n|---|---|\n| 1 |", "a\n    code",
				"### three", "#tag", "#"]:
			_check(int(_convert(bad).code) != 0, "the converter stops on %s" % JSON.stringify(bad))
		var good := _convert("# T\n\nok **b** and `c`\n- x\n- y\n\n| a | b |\n|---|---|\n| 1 | 2 |")
		_check(int(good.code) == 0 and str(good.out).contains("<strong>b</strong>") and str(good.out).contains("<ul>")
				and str(good.out).contains("<td>2</td>"), "the converter turns bold, a list and a table into HTML")
	_check(_read("site/privacy.html").contains("<table>") and _read("site/he/privacy.html").contains("<table>"),
			"the table of the privacy notice is a table in both languages")
	_check(_read("site/get/index.html").contains("../privacy.html") and _read("site/get/index.html").contains("../terms.html"),
			"the page of the QR code links to the privacy notice and the terms")
	print("\n%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
