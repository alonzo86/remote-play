extends SceneTree
## The language menu of the website (a <details class="lang"> in the header of every page, with a flag for each language).
## Run: godot --headless --path . --script tests/site_language.gd -- --role=controller
## Each page has exactly one menu with English and עברית, the flag pictures and the twin page exist, the current language is
## marked, the menu script is loaded, and the old language link of the navigation is gone.

const PAGES := ["index.html", "licenses.html", "privacy.html", "terms.html"]

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


func _exists(path: String) -> bool:
	return FileAccess.file_exists("res://" + path)


func _run() -> void:
	_check(_exists("site/flags/us.svg") and _exists("site/flags/il.svg") and _exists("site/lang.js"),
			"the two flag pictures and the menu script exist")
	for page in PAGES:
		for lang in ["en", "he"]:
			var dir := "site/" if lang == "en" else "site/he/"
			var html := FileAccess.get_file_as_string("res://" + dir + page)
			var name: String = dir + page
			_check(html.count('<details class="lang">') == 1 and html.count("</details>") == 1, "%s has one language menu" % name)
			var other_dir := "he/" if lang == "en" else "../"
			var twin_href: String = other_dir + page
			var twin_lang := "he" if lang == "en" else "en"
			_check(html.contains('href="%s" lang="%s" hreflang="%s"' % [twin_href, twin_lang, twin_lang]),
					"%s links to its twin %s inside the menu" % [name, twin_href])
			_check(_exists(dir + twin_href) if lang == "en" else _exists("site/" + page), "the twin page of %s exists" % name)
			var here_lang: String = lang
			_check(html.count('aria-current="true"') == 1 and html.contains('hreflang="%s"%s' % [here_lang, ' aria-current="true"']),
					"%s marks its own language in the menu" % name)
			_check(html.contains("English</a></li>") and html.contains("עברית</a></li>"), "%s lists English and עברית" % name)
			var pre := "" if lang == "en" else "../"
			_check(html.contains('src="%sflags/us.svg"' % pre) and html.contains('src="%sflags/il.svg"' % pre),
					"%s uses both flag pictures (%sflags/)" % [name, pre])
			_check(html.contains('<script src="%slang.js" defer></script>' % pre), "%s loads the menu script" % name)
			_check(not html.contains('lang="he">עברית</a></nav>') and not html.contains('lang="en">English</a></nav>'),
					"%s has no old language link at the end of the navigation" % name)
	print("\n%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
