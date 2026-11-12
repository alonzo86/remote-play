extends RefCounted
## The content of the About screen (FD-25): what Sababi does with data, and the notices that the licences of the parts of Sababi
## ask for. The texts of the licences stay in English: they are legal texts. The Godot texts come from the engine itself
## (`Engine.get_license_text()`, `get_copyright_info()`, `get_license_info()`), so they are always those of the running version.

const Lang = preload("res://scripts/core/lang.gd")
const LegalText = preload("res://scripts/core/legal_text.gd")

static var _non_ascii: RegEx   # Any character outside ASCII (made on the first use).

const ANDROID_LIBRARIES := "res://assets/licenses/android-libraries.txt"

const FONT_LICENSES := {
	"Press Start 2P": "res://assets/fonts/OFL-PressStart2P.txt",
	"Sababi Pixel Hebrew": "res://assets/fonts/OFL-SababiPixelHebrew.txt",
}


## Where the QR code "GET THE PHONE APP TO PLAY" of the TV points: the page `site/get/` of the website (GitHub Pages of this
## repository), which sends each phone to its store (the store addresses are in `site/stores.js`). The TV draws this address in
## every installed copy, so it must stay: change where the page sends people, not this address.
const APP_URL := "https://alonzo86.github.io/remote-play/get/"


## The pages of the About list, in order. Each is {"title": text, "kind": text, "arg": text}. `scanner` adds the note about the
## Google code scanner (the Android phone). "3rd Party Libraries" opens the list of `libraries()`.
static func pages(scanner := false, tv := false) -> Array:
	var out: Array = [{"title": "Sababi", "kind": "summary", "arg": ""}]
	if tv:   # The TV shows the QR code of the phone app (a placeholder address until the app has a page in the stores).
		out.append({"title": "about.get_app", "kind": "get_app", "arg": APP_URL})
	if scanner:
		out.append({"title": "about.qr_scanner", "kind": "scanner", "arg": ""})
	out.append({"title": "Godot Engine", "kind": "godot", "arg": ""})
	out.append({"title": "about.privacy", "kind": "privacy", "arg": ""})
	out.append({"title": "about.third_party_libraries", "kind": "libraries", "arg": ""})
	return out


## The libraries of other makers, as pages: {"title": name, "kind": "library" or "file", "arg": name or file, "license": types}.
## The fonts of Sababi first, then (`android`, an Android app) the page of the Android libraries, then the parts that are inside
## Godot (the list of the running engine, without Godot itself). Each page shows the copyright lines and the text of the license.
static func libraries(android := false) -> Array:
	var out: Array = []
	for f in FONT_LICENSES:
		out.append({"title": f, "kind": "file", "arg": FONT_LICENSES[f], "license": "OFL-1.1"})
	if android:
		out.append({"title": "about.android_libraries", "kind": "file", "arg": ANDROID_LIBRARIES, "license": "Apache-2.0"})
	for c in Engine.get_copyright_info():
		if String(c.name) == "Godot Engine":
			continue
		out.append({"title": String(c.name), "kind": "library", "arg": String(c.name), "license": license_label(_licenses_of(c))})
	return out


## The names of the licenses of a part of Godot, once each: "Expat and Zlib" gives ["Expat", "Zlib"].
static func _licenses_of(component: Dictionary) -> Array:
	var out: Array = []
	for p in component.parts:
		for l in String(p.license).replace(" or ", " and ").split(" and "):
			var name := l.strip_edges()
			if name != "" and not (name in out):
				out.append(name)
	return out


## The license types for a row: "Expat" is the MIT license, and it is written as MIT.
static func license_label(names: Array) -> String:
	return ", ".join(names.map(func(n): return "MIT" if n == "Expat" else String(n)))


## The title of a page as it is shown: a key (about.qr_scanner) in the language of the app, a name (Godot Engine, a library) as it
## is, in the characters of the pixel font.
static func title_text(page: Dictionary) -> String:
	var t := String(page.title)
	return Lang.t(t) if Lang.has(t) else safe(t)


## The text of one page.
static func text(page: Dictionary) -> String:
	match String(page.kind):
		"summary":
			return Lang.t("about.sababi_game_tv") + "\n\n" \
					+ Lang.t("about.sababi_has_no_account") \
					+ "\n\n" + Lang.t("about.phones_tv_communicate_over") \
					+ " " + Lang.t("about.nothing_leaves_network") \
					+ "\n\n" + Lang.t("about.pages_below_list_parts")
		"scanner":
			return Lang.t("about.app_scans_with_google")
		"privacy":   # The privacy notice itself, from the file of the website (`legal_text.gd`), as plain text.
			return "\n\n".join(LegalText.privacy_blocks().map(func(b): return String(b.text)))
		"godot":
			return safe(Engine.get_license_text())
		"file":
			return safe(FileAccess.get_file_as_string(String(page.arg)))
		"library":
			return safe(library_text(String(page.arg)))
	return ""


## The page of a part of Godot: its copyright lines, then the text of each license it comes with.
static func library_text(component_name: String) -> String:
	var info := Engine.get_license_info()
	var out := PackedStringArray()
	for c in Engine.get_copyright_info():
		if String(c.name) != component_name:
			continue
		for p in c.parts:
			for line in p.copyright:
				out.append("(c) " + String(line))
			out.append("License: " + String(p.license))
		out.append("")
		for l in _licenses_of(c):
			out.append("== " + ("MIT" if l == "Expat" else l) + " ==")
			out.append(String(info.get(l, "")))
			out.append("")
		break
	return "\n".join(out)


## `t` for the pixel font, which draws ASCII only: the copyright sign becomes (c), another character outside ASCII becomes "?".
static func safe(t: String) -> String:
	if _non_ascii == null:
		_non_ascii = RegEx.create_from_string("[^\\x00-\\x7F]")
	return _non_ascii.sub(t.replace("©", "(c)"), "?", true)
