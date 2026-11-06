extends SceneTree
## The About pages and the About screen of the phone (FD-25): the pages, the rows, Back, touch and Hebrew.
## Run by tests/run_all.sh and tools/coverage.sh: godot --headless --path . --script tests/about_pages.gd -- --role=controller

const ControllerClient = preload("res://scripts/net/controller_client.gd")
const About = preload("res://scripts/core/about.gd")
const Lang = preload("res://scripts/core/lang.gd")

var _checks := 0
var _fails := 0
var _about_script: GDScript   # The screens use the autoloads (App, Role): load them when the test runs, not at compile time.
var _pad_script: GDScript
var _connect_script: GDScript


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
	await _run()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _run() -> void:
	_about_script = load("res://scripts/ui/about_screen.gd")
	_pad_script = load("res://scripts/ui/controller_pad.gd")
	_connect_script = load("res://scripts/ui/controller_connect.gd")
	_about()
	await _about_screen()
	await _get_the_app()


func _about() -> void:
	print("About pages")
	var pages := About.pages(false)
	var titles := pages.map(func(p): return p.title)
	_check(titles == ["Sababi", "Godot Engine", "about.third_party_libraries"], "the About list: Sababi, Godot, 3rd Party Libraries")
	_check(not ("about.qr_scanner" in titles) and "about.qr_scanner" in About.pages(true).map(func(p): return p.title),
			"the scanner note is only for the Android phone")
	var by := {}
	for p in pages:
		by[p.title] = p
	_check(About.text(by["Godot Engine"]).contains("Permission is hereby granted"), "the Godot page has the MIT license text")
	var libs := About.libraries()
	var has_android := func(list: Array): return list.any(func(l): return l.title == "about.android_libraries")
	_check(not has_android.call(libs) and has_android.call(About.libraries(true)),
			"the Android libraries page is only in the Android apps")
	var android_page: Dictionary = About.libraries(true).filter(func(l): return l.title == "about.android_libraries").front()
	var android_text := About.text(android_page)
	_check(android_page.license == "Apache-2.0" and android_text.contains("Apache License") and android_text.contains("Version 2.0")
			and android_text.contains("play-services-code-scanner") and android_text.contains("Kotlin standard library"),
			"the Android libraries page has the list and the Apache 2.0 text")
	var lib := {}
	for l in libs:
		lib[l.title] = l
	_check(lib.has("Press Start 2P") and lib.has("Sababi Pixel Hebrew") and lib["Press Start 2P"].license == "OFL-1.1",
			"the libraries list has both fonts with their license type")
	var press := About.text(lib["Press Start 2P"])
	_check(press.contains("SIL OPEN FONT LICENSE") and press.contains("cody@zone38.net"),
			"the Press Start 2P page has its copyright and the OFL text")
	_check(About.text(lib["Sababi Pixel Hebrew"]).contains("SIL OPEN FONT LICENSE"), "the Sababi Pixel Hebrew page has the OFL text")
	var ft: Dictionary = libs.filter(func(l): return String(l.title).contains("FreeType")).front()
	_check(ft.license == "FTL" and About.text(ft).contains("FreeType") and About.text(ft).contains("License: FTL"),
			"a part of Godot shows its name, its license type and its copyright lines")
	_check(libs.size() > 50 and not libs.any(func(l): return l.title == "Godot Engine"),
			"the list has the parts of Godot but not Godot itself, which has its own page")
	var bullet: Dictionary = libs.filter(func(l): return String(l.title).begins_with("Bullet")).front()
	_check(bullet.license == "MIT, Zlib" and About.text(bullet).contains("== Zlib =="),
			"a part with two licenses lists both, and Expat is written as MIT: %s" % bullet.license)
	_check(libs.all(func(l): return About.text(l).strip_edges() != "" and String(l.license) != ""),
			"every library has a license type and a text")
	_check(About.license_label(["Expat", "Zlib"]) == "MIT, Zlib", "Expat is the MIT license")
	_check(About.safe("© Café") == "(c) Caf?", "characters outside ASCII are made safe for the pixel font")


func _about_screen() -> void:
	print("About screen")
	var screen: Control = _about_script.new()
	screen.theme = root.get_node("App").theme_res
	root.add_child(screen)
	await process_frame
	await process_frame
	_check(About.pages(false).size() > 0 and screen.chunks("a\nb").size() == 1, "a short text is one part")
	var long_text := "\n".join(range(100).map(func(n): return str(n)))
	_check(screen.chunks(long_text).size() == 3 and "\n".join(screen.chunks(long_text)) == long_text,
			"a long text is split in parts of 40 lines and nothing is lost")
	var buttons: Array = screen.find_children("*", "Button", true, false)
	_check(buttons.size() == About.pages(false).size() + 1 and screen.open_page == -1 and not screen.in_libraries,
			"the list has a button for each page and Back")
	screen.show_page(1)
	await process_frame
	_check(screen.open_page == 1 and not screen.find_children("*", "Label", true, false).filter(
			func(l): return String(l.text).contains("Permission is hereby granted")).is_empty(), "a page shows its text")
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	screen._unhandled_input(down)
	await process_frame
	_check(screen._scroll.scroll_vertical > 0, "Down scrolls the text of a page")
	var up := InputEventAction.new()
	up.action = "ui_up"
	up.pressed = true
	screen._unhandled_input(up)
	await process_frame
	_check(screen._scroll.scroll_vertical == 0, "Up scrolls back")
	screen.on_back()
	await process_frame
	_check(screen.open_page == -1 and not screen.in_libraries, "Back from a page returns to the list")
	screen._show_libraries()
	await process_frame
	buttons = screen.find_children("*", "Button", true, false)
	_check(screen.in_libraries and buttons.size() == About.libraries().size() + 1,
			"3rd Party Libraries has a row for each library and Back")
	_check(buttons.any(func(b): return String(b.text).contains("FREETYPE") and String(b.text).contains("(FTL)")),
			"a row has the name of the library and the type of its license")
	var long_row: Button = buttons.filter(func(b): return String(b.text).begins_with("BULLET CONTINUOUS")).front()
	_check(long_row.get_minimum_size().y > 84.0 and long_row.get_minimum_size().x < 100.0,
			"a long library name wraps to more lines, and the row does not force the screen wider")
	screen.show_page(0)
	await process_frame
	_check(screen.open_page == 0 and screen.in_libraries, "a library row opens its page")
	screen.on_back()
	await process_frame
	_check(screen.in_libraries and screen.open_page == -1, "Back from a library page returns to the list of libraries")
	screen.on_back()
	await process_frame
	_check(not screen.in_libraries and screen.open_page == -1, "Back from the list of libraries returns to the About list")
	screen.queue_free()
	await _about_extra()
	await _about_stays_open()
	await _about_titles_in_hebrew()


## Marks a check that fails because of a real problem in the game that is not fixed yet: it is printed and not counted as a
## failure.
func _known_bug(issue: String, cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL (known bug) (", issue, ") ", what)


## A fresh About screen that fills the window, with the layout done.
## The TV About list has the page "Get the app" with only the QR code of the app.
## The phone has none.
func _get_the_app() -> void:
	print("get the app")
	var tv_pages: Array = About.pages(false, true)
	_check(String(tv_pages[1].kind) == "get_app" and tv_pages[1].arg == About.APP_URL
			and About.pages(false).size() == tv_pages.size() - 1
			and not About.pages(true).any(func(p): return p.kind == "get_app"), "only the TV list has the page Get the app")
	var screen: Control = await _open_about()
	screen._current = tv_pages
	screen.show_page(1)
	await process_frame
	var qr: Control = screen.find_child("AppQr", true, false)
	_check(qr != null and qr.text == About.APP_URL and qr.quiet == 4 and qr.custom_minimum_size.x >= 400.0,
			"the page shows the QR code of the app address with a quiet zone, and no room code")
	_check(screen.find_children("*", "Label", true, false).any(func(l): return l.text == "about.get_app_scan"),
			"and the line that says what the code is")
	screen.queue_free()


func _open_about(props := {}) -> Control:
	var screen: Control = _about_script.new()
	for k in props:
		screen.set(k, props[k])
	screen.theme = root.get_node("App").theme_res
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	await process_frame
	return screen


## Issue #292: the titles "QR scanner" and "Android libraries" are string rows, so they show in Hebrew: in the list of pages,
## in the list of libraries (with the license) and as the heading of the page. A name (Godot Engine, a font) stays as it is.
func _about_titles_in_hebrew() -> void:
	print("About titles in Hebrew")
	var app: Node = root.get_node("App")
	app.set_language("he", false)
	var qr := About.title_text({"title": "about.qr_scanner"})
	var android := About.title_text({"title": "about.android_libraries"})
	_check(qr == "סורק QR" and android == "ספריות אנדרואיד" and About.title_text({"title": "Godot Engine"}) == "Godot Engine",
			"a key title is translated and a name stays")
	var screen: Control = await _open_about({"scanner_note": true})
	_check(screen.find_children("*", "Button", true, false).any(func(b): return String(b.text) == "סורק QR"),
			"the About list shows the scanner page in Hebrew")
	screen._libs = About.libraries(true)
	screen._show_libraries()
	await process_frame
	var buttons: Array = screen.find_children("*", "Button", true, false)
	var row: Array = buttons.filter(func(b): return String(b.text).contains("ספריות אנדרואיד"))
	_check(row.size() == 1 and String(row[0].text).to_upper().contains("(APACHE-2.0)"),
			"the Android libraries row is in Hebrew with its license")
	screen.show_page(screen._libs.find_custom(func(l): return l.title == "about.android_libraries"))
	await process_frame
	_check(screen.find_children("*", "Label", true, false).any(func(l): return String(l.text) == "ספריות אנדרואיד"),
			"the heading of the Android libraries page is in Hebrew (not '?' marks)")
	screen.queue_free()
	app.set_language("en", false)


## More About steps of tests 21.8 to 21.10 (REQ-FL-85): every library row, the size of the text, the fourth Back, touch scrolling,
## the scanner note and the license text in Hebrew.
func _about_extra() -> void:
	print("About rows, Back, touch and Hebrew")
	var app: Node = root.get_node("App")
	var screen: Control = await _open_about()
	screen._show_libraries()
	await process_frame
	await process_frame
	var rows: Array = screen.find_children("*", "Button", true, false)
	rows.pop_back()   # The last button is Back.
	var libs := About.libraries()
	var bad: Array = []
	var outside: Array = []
	var edge := 60.0
	var window := screen.get_global_rect()
	for i in rows.size():
		var b: Button = rows[i]
		var shown := String(b.text)
		var font := b.get_theme_font("font")
		var size := b.get_theme_font_size("font_size")
		var box := b.get_theme_stylebox("normal")
		var room := b.size.x - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT)
		var needed := font.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, room, size).y \
				+ box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM)
		var r := b.get_global_rect()
		var name_ok := shown.to_upper().contains(About.title_text(libs[i]).to_upper())
		var license_ok := shown.to_upper().contains("(%s)" % String(libs[i].license).to_upper())
		if not (name_ok and license_ok and b.autowrap_mode != TextServer.AUTOWRAP_OFF and b.size.y + 0.5 >= needed):
			bad.append(String(libs[i].title))
		if not (r.position.x >= window.position.x + edge - 0.5 and r.end.x <= window.end.x - edge + 0.5):
			outside.append(String(libs[i].title))
	_check(rows.size() == libs.size() and bad.is_empty(),
			"every library row shows its name and license, wraps, and is tall enough for its lines: %s" % str(bad.slice(0, 5)))
	_check(outside.is_empty(),
			"every library row is inside the 60 px edge of a 1080 px phone screen (%d rows are not; the title is %d px wide)"
			% [outside.size(), int(screen._box.get_minimum_size().x)])
	screen.queue_free()

	# The size of the text (REQ-FL-40: TV text is 32 px or more; phone text 24 px or more).
	var script_size: int = _about_script.TEXT_SIZE
	_check(script_size >= 24, "the text of an About page is 24 px or more (the phone minimum)")
	_check(script_size >= 32,
			"the About text is 32 px or more, so it reads from the sofa on the TV (it is %d)" % script_size)

	# The fourth Back: from the About list to the screen that opened it.
	app.go(_about_script, {"back_screen": app.ControllerSettings})
	await process_frame
	await process_frame
	var about_list: Control = app.current_screen()
	about_list._show_libraries()
	about_list.on_back()
	_check(about_list.in_libraries == false and about_list.open_page == -1 and app.current_screen() == about_list,
			"Back from the libraries list stays on About (it shows the About list)")
	about_list.on_back()
	await process_frame
	await process_frame
	_check(app.current_screen().get_script() == app.ControllerSettings,
			"Back from the About list goes to the screen before (Settings)")

	# A page scrolls with a finger drag on the phone.
	var page_screen: Control = await _open_about()
	page_screen._show_libraries()   # The longest library text: many licenses, more than one screen.
	var longest := 0
	for k in page_screen._libs.size():
		if About.text(page_screen._libs[k]).length() > About.text(page_screen._libs[longest]).length():
			longest = k
	page_screen.show_page(longest)
	await process_frame
	await process_frame
	var sc: ScrollContainer = page_screen._scroll
	_check(sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			and sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			and sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page > 1000.0,
			"a long page can scroll up and down only, and its text is much taller than the window")
	# A finger drag is the engine's own ScrollContainer touch code, and a headless run has no touch screen to feed it: the check is
	# that the page is a vertical ScrollContainer that is not disabled, and that its end can be reached.
	# The end of a long text is reachable: the last part is a label of the page and the scroll goes to its end.
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
	await process_frame
	var labels: Array = page_screen.find_children("*", "Label", true, false)
	var last_text := String(page_screen.chunks(About.text(page_screen._libs[longest])).back())
	_check(not labels.is_empty() and String(labels.back().text) == last_text
			and sc.scroll_vertical >= int(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page) - 1,
			"the scroll goes to the end, where the last part of the text is")
	page_screen.queue_free()

	# The Android scanner note names Google and the technical data (REQ-FL-85).
	var scanner_page: Dictionary = About.pages(true).filter(func(p): return p.kind == "scanner").front()
	var note := About.text(scanner_page)
	_check(note.contains("Google") and note.contains("technical data") and note.contains("stays on your phone"),
			"the scanner page says that Google receives technical data and that the picture stays on the phone")

	# Hebrew: the lists come from the table, and the license texts are the English originals.
	var english_godot := About.text(About.pages(false)[1])
	var english_font := About.text(About.libraries()[0])
	var english_summary := About.text(About.pages(false)[0])
	app.set_language("he", false)
	var hebrew_summary := About.text(About.pages(false)[0])
	var hebrew_godot := About.text(About.pages(false)[1])
	var hebrew_font := About.text(About.libraries()[0])
	var has_hebrew := func(t: String) -> bool:
		for i in t.length():
			if t.unicode_at(i) >= 0x0590 and t.unicode_at(i) <= 0x05FF:
				return true
		return false
	_check(hebrew_godot == english_godot and hebrew_font == english_font and not has_hebrew.call(hebrew_godot)
			and not has_hebrew.call(hebrew_font), "a license text is the same bytes in Hebrew and has no Hebrew letter")
	_check(hebrew_summary != english_summary and has_hebrew.call(hebrew_summary),
			"the first page is in Hebrew when the language is Hebrew")
	var he_screen: Control = await _open_about()
	var he_texts: Array = he_screen.find_children("*", "Button", true, false).map(func(b): return String(b.text))
	_check(he_texts[0] == "SABABI" and has_hebrew.call(he_texts[2]),
			"the About list in Hebrew has the Hebrew name for 3rd Party Libraries")
	he_screen.queue_free()
	app.set_language("en", false)


## A phase message of the TV does not close the About screen of the phone (it closes Settings only to show the pad in a round).
func _about_stays_open() -> void:
	var app: Node = root.get_node("App")
	app.go(_about_script, {"back_screen": app.ControllerSettings})
	await process_frame
	app.client.state = ControllerClient.State.CONNECTED
	app.client.phase = "menu"
	app._show_phone_screen()
	await process_frame
	_check(app.current_screen().get_script() == _about_script, "a menu phase of the TV leaves the About screen open")
	app.client.phase = "playing"
	app._show_phone_screen()
	var on_pad: bool = app.current_screen().get_script() == _pad_script
	app.client.state = ControllerClient.State.IDLE   # Before the pad runs: there is no socket behind this state.
	await process_frame
	_check(on_pad, "a round still opens the pad")
	app.client.phase = "connect"
