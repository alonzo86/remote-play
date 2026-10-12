extends RefCounted
## The content of the About screen (FD-25): what Wobble does with data, and the notices that the licences of the parts of Wobble
## ask for. The texts of the licences stay in English: they are legal texts. The Godot texts come from the engine itself
## (`Engine.get_license_text()`, `get_copyright_info()`, `get_license_info()`), so they are always those of the running version.

const Lang = preload("res://scripts/core/lang.gd")

const FONT_LICENSES := {
	"Press Start 2P": "res://assets/fonts/OFL-PressStart2P.txt",
	"Wobble Pixel Hebrew": "res://assets/fonts/OFL-WobblePixelHebrew.txt",
}


## The pages of the About list, in order. Each is {"title": text, "kind": text, "arg": text}. `scanner` adds the note about the
## Google code scanner (the Android phone).
static func pages(scanner := false) -> Array:
	var out: Array = [{"title": "Wobble", "kind": "summary", "arg": ""}]
	if scanner:
		out.append({"title": "QR scanner", "kind": "scanner", "arg": ""})
	out.append({"title": "Godot Engine", "kind": "godot", "arg": ""})
	out.append({"title": "Godot parts", "kind": "components", "arg": ""})
	for f in FONT_LICENSES:
		out.append({"title": f, "kind": "file", "arg": FONT_LICENSES[f]})
	var info := Engine.get_license_info()
	var names := info.keys()
	names.sort()
	for n in names:
		out.append({"title": "Licence " + String(n), "kind": "license", "arg": String(n)})
	return out


## The text of one page.
static func text(page: Dictionary) -> String:
	match String(page.kind):
		"summary":
			return Lang.t("about.wobble_party_game_tv") + "\n\n" \
					+ Lang.t("about.wobble_has_no_account") \
					+ "\n\n" + Lang.t("about.phones_tv_talk_over") \
					+ " " + Lang.t("about.refresh_tries_addresses") \
					+ "\n\n" + Lang.t("about.pages_below_list_parts")
		"scanner":
			return Lang.t("about.android_phone_scans_with")
		"godot":
			return safe(Engine.get_license_text())
		"components":
			return safe(godot_components())
		"file":
			return safe(FileAccess.get_file_as_string(String(page.arg)))
		"license":
			return safe(String(Engine.get_license_info().get(String(page.arg), "")))
	return ""


## The parts of Godot with their copyright lines and the name of their license.
static func godot_components() -> String:
	var out := PackedStringArray()
	for c in Engine.get_copyright_info():
		out.append(String(c.name))
		for p in c.parts:
			for line in p.copyright:
				out.append("  (c) " + String(line))
			out.append("  License: " + String(p.license))
		out.append("")
	return "\n".join(out)


## `t` for the pixel font, which draws ASCII only: the copyright sign becomes (c), another character outside ASCII becomes "?".
static func safe(t: String) -> String:
	t = t.replace("©", "(c)")
	var out := ""
	for i in t.length():
		var code := t.unicode_at(i)
		out += t[i] if code < 128 else "?"
	return out
