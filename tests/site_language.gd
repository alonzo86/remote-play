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
			var us := pre + "flags/us.svg"
			var il := pre + "flags/il.svg"
			var mark := ' aria-current="true"'
			var en_entry := 'hreflang="en"%s><img src="%s"' % [mark if lang == "en" else "", us]
			var he_entry := 'hreflang="he"%s><img src="%s"' % [mark if lang == "he" else "", il]
			_check(html.contains(en_entry), "%s: the English entry has the flag of the United States (%s)" % [name, us])
			_check(html.contains(he_entry), "%s: the עברית entry has the flag of Israel (%s)" % [name, il])
			var own_flag := us if lang == "en" else il
			var own_label := "Language: English" if lang == "en" else "שפה: עברית"
			_check(html.contains('<summary aria-label="%s"><img src="%s"' % [own_label, own_flag]),
					"%s: the button shows the flag of its own language (%s)" % [name, own_flag])
			_check(html.contains('<script src="%slang.js" defer></script>' % pre), "%s loads the menu script" % name)
			_check(not html.contains('lang="he">עברית</a></nav>') and not html.contains('lang="en">English</a></nav>'),
					"%s has no old language link at the end of the navigation" % name)
			_check(html.contains('<link rel="icon" href="%sfavicon.ico" sizes="any">' % pre)
					and html.contains('<link rel="apple-touch-icon" href="%sicon-192.png">' % pre),
					"%s has the Sababi icon as its favicon" % name)
	_check(_exists("site/favicon.ico") and _exists("site/icon-192.png") and Image.load_from_file(
			"res://site/icon-192.png").get_size() == Vector2i(192, 192), "the favicon files exist (icon 192 x 192)")
	var get_html := FileAccess.get_file_as_string("res://site/get/index.html")
	_check(get_html.contains('<link rel="icon" href="../favicon.ico" sizes="any">'), "site/get/index.html has the favicon")
	# The store screenshots on the home page (owner request of 2026-11-09): 10 for the TV, 2 for the phone, with a text each.
	for lang in ["en", "he"]:
		var dir := "site/" if lang == "en" else "site/he/"
		var html := FileAccess.get_file_as_string("res://" + dir + "index.html")
		var pattern := '<img src="(?:\\.\\./)?(screens/[^"]+)" width="(\\d+)" height="(\\d+)" alt="([^"]+)"'
		var imgs := RegEx.create_from_string(pattern).search_all(html)
		_check(imgs.size() == 12 and html.count('class="shots tv"') == 1 and html.count('class="shots phone"') == 1,
				"%s home page: 12 screenshots (10 TV, 2 phone)" % dir)
		var ok := true
		for m in imgs:
			var path: String = "site/" + m.get_string(1)
			var size := Image.load_from_file("res://" + path).get_size() if _exists(path) else Vector2i.ZERO
			ok = ok and size == Vector2i(int(m.get_string(2)), int(m.get_string(3))) and m.get_string(4).strip_edges() != ""
		_check(ok, "%s home page: each screenshot file exists, its size is in the tag and it has a text" % dir)
	print("\n%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
