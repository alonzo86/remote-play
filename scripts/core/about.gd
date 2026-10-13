extends RefCounted
## The content of the About screen (FD-25): what Wobble does with data, and the notices that the licences of the parts of Wobble
## ask for. The texts of the licences stay in English: they are legal texts. The Godot texts come from the engine itself
## (`Engine.get_license_text()`, `get_copyright_info()`, `get_license_info()`), so they are always those of the running version.

const Lang = preload("res://scripts/core/lang.gd")

const ANDROID_LIBRARIES := "res://assets/licenses/android-libraries.txt"

const FONT_LICENSES := {
	"Press Start 2P": "res://assets/fonts/OFL-PressStart2P.txt",
	"Wobble Pixel Hebrew": "res://assets/fonts/OFL-WobblePixelHebrew.txt",
}


## The pages of the About list, in order. Each is {"title": text, "kind": text, "arg": text}. `scanner` adds the note about the
## Google code scanner (the Android phone). "3rd Party Libraries" opens the list of `libraries()`.
static func pages(scanner := false) -> Array:
	var out: Array = [{"title": "Wobble", "kind": "summary", "arg": ""}]
	if scanner:
		out.append({"title": "QR scanner", "kind": "scanner", "arg": ""})
	out.append({"title": "Godot Engine", "kind": "godot", "arg": ""})
	out.append({"title": "about.third_party_libraries", "kind": "libraries", "arg": ""})
	return out


## The libraries of other makers, as pages: {"title": name, "kind": "library" or "file", "arg": name or file, "license": types}.
## The fonts of Wobble first, then (`android`, an Android app) the page of the Android libraries, then the parts that are inside
## Godot (the list of the running engine, without Godot itself). Each page shows the copyright lines and the text of the license.
static func libraries(android := false) -> Array:
	var out: Array = []
	for f in FONT_LICENSES:
		out.append({"title": f, "kind": "file", "arg": FONT_LICENSES[f], "license": "OFL-1.1"})
	if android:
		out.append({"title": "Android libraries", "kind": "file", "arg": ANDROID_LIBRARIES, "license": "Apache-2.0"})
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


## The text of one page.
static func text(page: Dictionary) -> String:
	match String(page.kind):
		"summary":
			return Lang.t("about.wobble_party_game_tv") + "\n\n" \
					+ Lang.t("about.wobble_has_no_account") \
					+ "\n\n" + Lang.t("about.phones_tv_communicate_over") \
					+ " " + Lang.t("about.refresh_scans_addresses") \
					+ " " + Lang.t("about.nothing_leaves_network") \
					+ "\n\n" + Lang.t("about.pages_below_list_parts")
		"scanner":
			return Lang.t("about.app_scans_with_google")
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
	t = t.replace("©", "(c)")
	var out := ""
	for i in t.length():
		var code := t.unicode_at(i)
		out += t[i] if code < 128 else "?"
	return out
